-- One `reviews` table instead of three (accommodation_reviews, landlord_reviews,
-- tenant_reviews). They had the same columns and differed only in what was
-- rated, so `kind` says that:
--
--   accommodation  a student rates the place      (accommodation_id set)
--   landlord       a student rates the landlord/landlady
--   tenant         a landlord/landlady rates the boarder
--
-- Every row keeps its id and created_at. The copy is checked row for row before
-- anything else changes, and the old tables move to the `archive` schema rather
-- than being dropped. The three review views keep their exact output (including
-- 'manager' for a landlord rating), so screens reading them are unaffected.
--
-- `tenant_reviews` stays reachable as a view onto the new table until every
-- phone runs a build that writes to `reviews` (1.101+); drop it then.

create schema if not exists archive;
revoke all on schema archive from public, anon, authenticated;

-- Table -----------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('accommodation', 'landlord', 'tenant')),
  lease_id uuid not null references public.leases(id) on delete cascade,
  student_id uuid not null references public.users(id) on delete cascade,
  landlord_id uuid references public.users(id) on delete cascade,
  accommodation_id uuid references public.accommodations(id) on delete cascade,
  rating integer not null constraint reviews_rating_range check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  -- One rating of each kind per stay, as each old table's unique (lease_id) said.
  unique (lease_id, kind),
  -- The rated thing must be there, and only an accommodation rating names one.
  constraint reviews_target check (
    (kind = 'accommodation' and accommodation_id is not null)
    or (kind <> 'accommodation' and accommodation_id is null and landlord_id is not null)
  )
);
create index idx_reviews_student_id on public.reviews (student_id);
create index idx_reviews_landlord_id on public.reviews (landlord_id);
create index idx_reviews_accommodation_id on public.reviews (accommodation_id);

-- Copy and check ----------------------------------------------------------------
insert into public.reviews (id, kind, lease_id, student_id, landlord_id, accommodation_id, rating, comment, created_at)
select id, 'accommodation', lease_id, student_id, null, accommodation_id, rating, comment, created_at
  from public.accommodation_reviews
union all
select id, 'landlord', lease_id, student_id, landlord_id, null, rating, comment, created_at
  from public.landlord_reviews
union all
select id, 'tenant', lease_id, student_id, landlord_id, null, rating, comment, created_at
  from public.tenant_reviews;

do $$
declare
  v_old text;
  v_new text;
begin
  select md5(coalesce(string_agg(x, '|' order by x), '')) into v_old from (
    select concat_ws(',', id, 'accommodation', lease_id, student_id, '', accommodation_id, rating, comment, created_at) as x from public.accommodation_reviews
    union all
    select concat_ws(',', id, 'landlord', lease_id, student_id, landlord_id, '', rating, comment, created_at) from public.landlord_reviews
    union all
    select concat_ws(',', id, 'tenant', lease_id, student_id, landlord_id, '', rating, comment, created_at) from public.tenant_reviews
  ) o;
  select md5(coalesce(string_agg(x, '|' order by x), '')) into v_new from (
    select concat_ws(',', id, kind, lease_id, student_id, coalesce(landlord_id::text, ''), coalesce(accommodation_id::text, ''), rating, comment, created_at) as x
      from public.reviews
  ) n;
  if v_old is distinct from v_new then
    raise exception 'reviews copy does not match the old tables; nothing was changed';
  end if;
end $$;

-- Access ----------------------------------------------------------------------
-- The three tables' rules, side by side: who may read, write and edit each kind.
alter table public.reviews enable row level security;

create policy reviews_select_admin on public.reviews for select to authenticated
  using ((select public.is_admin((select auth.uid()))));

create policy reviews_select_involved on public.reviews for select to authenticated
  using (
    student_id = (select auth.uid())
    or (kind <> 'accommodation' and landlord_id = (select auth.uid()))
    or (kind = 'accommodation' and exists (
          select 1 from public.accommodations a
           where a.id = reviews.accommodation_id and a.landlord_id = (select auth.uid())))
  );

-- Only after the stay is over, only about that stay.
create policy reviews_insert_own on public.reviews for insert to authenticated
  with check (
    (kind = 'accommodation' and student_id = (select auth.uid()) and exists (
       select 1 from public.leases l
        where l.id = reviews.lease_id and l.student_id = (select auth.uid())
          and l.status = any (array['ended'::public.lease_status, 'terminated'::public.lease_status])
          and exists (select 1 from public.rooms r
                       where r.id = l.room_id and r.accommodation_id = reviews.accommodation_id)))
    or (kind = 'landlord' and student_id = (select auth.uid()) and exists (
       select 1 from public.leases l
        where l.id = reviews.lease_id and l.student_id = (select auth.uid())
          and l.status = any (array['ended'::public.lease_status, 'terminated'::public.lease_status])
          and l.landlord_id = reviews.landlord_id))
    or (kind = 'tenant' and landlord_id = (select auth.uid()) and exists (
       select 1 from public.leases l
        where l.id = reviews.lease_id and l.landlord_id = (select auth.uid())
          and l.status = any (array['ended'::public.lease_status, 'terminated'::public.lease_status])
          and l.student_id = reviews.student_id))
  );

-- The author edits or deletes their own rating.
create policy reviews_update_own on public.reviews for update to authenticated
  using ((kind <> 'tenant' and student_id = (select auth.uid())) or (kind = 'tenant' and landlord_id = (select auth.uid())))
  with check ((kind <> 'tenant' and student_id = (select auth.uid())) or (kind = 'tenant' and landlord_id = (select auth.uid())));

create policy reviews_delete_own on public.reviews for delete to authenticated
  using ((kind <> 'tenant' and student_id = (select auth.uid())) or (kind = 'tenant' and landlord_id = (select auth.uid())));

revoke all on table public.reviews from public, anon;
grant select, insert, update, delete on table public.reviews to authenticated;
grant all on table public.reviews to service_role;

-- Behaviour the old tables' triggers carried ------------------------------------
create or replace function public.refresh_accommodation_rating()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  target uuid := coalesce(new.accommodation_id, old.accommodation_id);
begin
  if coalesce(new.kind, old.kind) <> 'accommodation' then
    return null;
  end if;
  update public.accommodations a
     set rating_avg = sub.avg_rating,
         reviews_count = sub.n
    from (
      select avg(rating)::numeric(3, 2) as avg_rating,
             count(*)::int as n
        from public.reviews
       where kind = 'accommodation' and accommodation_id = target
    ) sub
   where a.id = target;
  return null;
end;
$function$;

create or replace function public.tg_review_notify()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.kind = 'tenant' then
    perform public.notify_peer(new.student_id, 'review', 'You received a rating',
      'A landlord/landlady rated you after one of your past stays.', '/student/profile/history', null);
  else
    perform public.notify_peer(new.landlord_id, 'review', 'New rating',
      'A past tenant rated their stay.', '/manager/profile/history', null);
  end if;
  return null;
end $function$;

create trigger reviews_refresh_rating after insert or delete or update on public.reviews
  for each row execute function public.refresh_accommodation_rating();
create trigger lock_columns before update on public.reviews
  for each row execute function public.lock_columns('lease_id', 'student_id', 'landlord_id', 'accommodation_id', 'kind');
-- The limit is counted per person and table. A student wrote at most 5 of each
-- of two kinds a day (now one table, so 10); a landlord/landlady 30 tenant ratings.
create trigger rate_limit_student before insert on public.reviews
  for each row when (new.kind <> 'tenant') execute function public.enforce_rate_limit('10', '86400', 'ratings');
create trigger rate_limit_tenant before insert on public.reviews
  for each row when (new.kind = 'tenant') execute function public.enforce_rate_limit('30', '86400', 'ratings');
create trigger trg_review_notify after insert on public.reviews
  for each row when (new.kind <> 'accommodation') execute function public.tg_review_notify();

create or replace function public.submit_student_review(p_lease_id uuid, p_accommodation_id uuid, p_landlord_id uuid, p_acc_rating integer, p_acc_comment text, p_manager_rating integer, p_manager_comment text)
 returns void
 language sql
 set search_path to 'public'
as $function$
  insert into public.reviews (kind, lease_id, student_id, landlord_id, accommodation_id, rating, comment)
  values
    ('accommodation', p_lease_id, auth.uid(), null, p_accommodation_id, p_acc_rating,
     nullif(btrim(coalesce(p_acc_comment, '')), '')),
    ('landlord', p_lease_id, auth.uid(), p_landlord_id, null, p_manager_rating,
     nullif(btrim(coalesce(p_manager_comment, '')), ''));
$function$;

-- Views, same columns and meaning as before -----------------------------------
create or replace view public.review_admin_feed with (security_invoker = true) as
  select r.id,
         case r.kind when 'landlord' then 'manager' else r.kind end as kind,
         case r.kind when 'tenant' then r.student_id when 'landlord' then r.landlord_id else r.accommodation_id end as subject_id,
         case r.kind when 'tenant' then r.landlord_id else r.student_id end as author_id,
         r.rating,
         r.comment,
         r.created_at,
         r.lease_id,
         case when r.kind = 'accommodation' then r.accommodation_id end as accommodation_id
    from public.reviews r;

create or replace view public.review_inbox with (security_invoker = true) as
  select r.id,
         case r.kind when 'landlord' then 'manager' else r.kind end as kind,
         r.rating,
         r.comment,
         r.created_at,
         a.id as accommodation_id,
         a.name::text as accommodation_name
    from public.reviews r
    left join public.accommodations a on r.kind = 'accommodation' and a.id = r.accommodation_id
   where (r.kind = 'landlord' and r.landlord_id = auth.uid())
      or (r.kind = 'accommodation' and a.landlord_id = auth.uid())
      or (r.kind = 'tenant' and r.student_id = auth.uid());

create or replace view public.review_written_leases with (security_invoker = true) as
  select r.lease_id,
         case r.kind when 'landlord' then 'manager' else r.kind end as kind,
         r.rating,
         r.comment
    from public.reviews r
   where (r.kind <> 'tenant' and r.student_id = auth.uid())
      or (r.kind = 'tenant' and r.landlord_id = auth.uid());

revoke all on public.review_admin_feed, public.review_inbox, public.review_written_leases from public, anon;
grant select on public.review_admin_feed, public.review_inbox, public.review_written_leases to authenticated;

-- Archive the old tables ------------------------------------------------------
drop trigger if exists accommodation_reviews_refresh_rating on public.accommodation_reviews;
drop trigger if exists lock_columns on public.accommodation_reviews;
drop trigger if exists rate_limit on public.accommodation_reviews;
drop trigger if exists lock_columns on public.landlord_reviews;
drop trigger if exists rate_limit on public.landlord_reviews;
drop trigger if exists trg_review_notify on public.landlord_reviews;
drop trigger if exists lock_columns on public.tenant_reviews;
drop trigger if exists rate_limit on public.tenant_reviews;
drop trigger if exists trg_review_notify on public.tenant_reviews;

alter table public.accommodation_reviews set schema archive;
alter table public.landlord_reviews set schema archive;
alter table public.tenant_reviews set schema archive;
revoke all on archive.accommodation_reviews, archive.landlord_reviews, archive.tenant_reviews from public, anon, authenticated;

-- Builds before 1.101 insert tenant ratings into `tenant_reviews` directly. This
-- view takes those inserts into `reviews` (as the caller, so the rules above
-- apply). Drop it once 1.101 is everywhere.
create view public.tenant_reviews with (security_invoker = true) as
  select id, lease_id, landlord_id, student_id, rating, comment, created_at, kind
    from public.reviews
   where kind = 'tenant'
  with cascaded check option;
alter view public.tenant_reviews alter column kind set default 'tenant';
revoke all on public.tenant_reviews from public, anon;
grant select, insert on public.tenant_reviews to authenticated;
