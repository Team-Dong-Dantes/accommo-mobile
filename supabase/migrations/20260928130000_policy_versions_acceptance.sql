-- Policy versions, policy acceptance, and announcement reach for OSAS.
--
-- 1. A policy carries a `revision`. OSAS bumps it when a change is a new
--    version everyone must accept again; the previous text is kept in
--    policy_versions. A save that leaves `revision` alone is a silent
--    correction (typos) and keeps no history.
-- 2. policy_acceptances records who accepted which revision. The notification
--    already told users to "read and accept" — now that is recorded. Writes go
--    only through accept_policy(), which stamps the current revision.
-- 3. A new revision of a live policy notifies everyone again.
-- 4. Admin read-outs: acceptance counts, who is still pending, and announcement
--    reach for every announcement in one call (announcement_reach() is
--    service-role only and per row).

-- 1 ---------------------------------------------------------------------------
alter table public.policies
  add column if not exists revision integer not null default 1,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.policy_versions (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.policies(id) on delete cascade,
  revision integer not null,
  version character varying,
  title character varying not null,
  body text not null,
  effective_date date not null,
  created_by uuid,
  superseded_at timestamptz not null default now(),
  unique (policy_id, revision)
);
alter table public.policy_versions enable row level security;
create policy "policy_versions_select_admin" on public.policy_versions
  for select to authenticated using (public.is_admin(auth.uid()));

create or replace function public.snapshot_policy_version() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  new.updated_at := now();
  if new.revision > old.revision then
    insert into public.policy_versions (policy_id, revision, version, title, body, effective_date, created_by)
    values (old.id, old.revision, old.version, old.title, old.body, old.effective_date, old.created_by)
    on conflict (policy_id, revision) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists trg_policy_version on public.policies;
create trigger trg_policy_version before update on public.policies
  for each row execute function public.snapshot_policy_version();

-- 2 ---------------------------------------------------------------------------
create table if not exists public.policy_acceptances (
  policy_id uuid not null references public.policies(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  revision integer not null,
  accepted_at timestamptz not null default now(),
  primary key (policy_id, user_id)
);
alter table public.policy_acceptances enable row level security;
create policy "policy_acceptances_select_own" on public.policy_acceptances
  for select to authenticated using (user_id = auth.uid() or public.is_admin(auth.uid()));
-- No insert/update/delete policies on purpose: accept_policy() is the only writer.

create or replace function public.accept_policy(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_rev integer;
begin
  if coalesce(public.get_my_role(), '') not in ('student', 'landlord') then
    raise exception 'only students and landlords accept policies';
  end if;
  select revision into v_rev from public.policies
   where id = p_id and not archived and effective_date <= now();
  if v_rev is null then
    raise exception 'policy is not in effect';
  end if;
  insert into public.policy_acceptances (policy_id, user_id, revision)
  values (p_id, auth.uid(), v_rev)
  on conflict (policy_id, user_id)
  do update set revision = excluded.revision, accepted_at = now();
end $$;

-- 3 ---------------------------------------------------------------------------
create or replace function public.notify_policy() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare v_revised boolean := tg_op = 'UPDATE' and new.revision > old.revision;
begin
  if new.archived or new.effective_date > now() then return new; end if;
  -- Already live before this update: only a new revision is news.
  if tg_op = 'UPDATE' and not (old.archived or old.effective_date > now()) and not v_revised then
    return new;
  end if;

  insert into public.notifications (user_id, title, body, type, link_url, ref_id, source)
  select
    u.id,
    new.title,
    case when v_revised then 'Updated' || coalesce(' to ' || new.version, '') || '. '
         else coalesce(new.version || ' · ', '') end
      || 'In effect from ' || to_char(new.effective_date AT TIME ZONE 'Asia/Manila', 'Mon DD, YYYY')
      || '. Open Policies & guidelines to read and accept it.',
    'policy',
    null,
    new.id,
    'System Admin'
  from public.users u
  where u.status <> 'suspended'
    and u.role in ('student', 'landlord');

  return new;
end $$;

drop trigger if exists trg_notify_policy on public.policies;
create trigger trg_notify_policy after insert or update of effective_date, archived, revision
  on public.policies for each row execute function public.notify_policy();

-- 4 ---------------------------------------------------------------------------
create or replace function public.policy_acceptance_stats()
returns table(policy_id uuid, accepted integer, eligible integer)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.is_admin(auth.uid()) then raise exception 'admins only'; end if;
  return query
    with elig as (
      select id from public.users where status <> 'suspended' and role in ('student', 'landlord')
    )
    select p.id,
           (select count(*) from public.policy_acceptances a
             where a.policy_id = p.id and a.revision = p.revision
               and a.user_id in (select id from elig))::int,
           (select count(*) from elig)::int
      from public.policies p;
end $$;

create or replace function public.policy_pending_users(p_id uuid)
returns table(id uuid, full_name text, email text, role text)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.is_admin(auth.uid()) then raise exception 'admins only'; end if;
  return query
    select u.id, u.full_name::text, u.email::text, u.role::text
      from public.users u
      join public.policies p on p.id = p_id
     where u.status <> 'suspended' and u.role in ('student', 'landlord')
       and not exists (select 1 from public.policy_acceptances a
                        where a.policy_id = p.id and a.user_id = u.id and a.revision = p.revision)
     order by u.full_name;
end $$;

create or replace function public.announcement_reach_all()
returns table(announcement_id uuid, sent integer, seen integer)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.is_admin(auth.uid()) then raise exception 'admins only'; end if;
  return query
    select n.ref_id, count(*)::int, count(*) filter (where n.read_at is not null)::int
      from public.notifications n
     where n.type = 'announcement' and n.ref_id is not null
     group by n.ref_id;
end $$;

revoke all on function public.accept_policy(uuid) from public, anon;
revoke all on function public.policy_acceptance_stats() from public, anon;
revoke all on function public.policy_pending_users(uuid) from public, anon;
revoke all on function public.announcement_reach_all() from public, anon;
revoke all on function public.snapshot_policy_version() from public, anon, authenticated;
grant execute on function public.accept_policy(uuid) to authenticated;
grant execute on function public.policy_acceptance_stats() to authenticated;
grant execute on function public.policy_pending_users(uuid) to authenticated;
grant execute on function public.announcement_reach_all() to authenticated;
