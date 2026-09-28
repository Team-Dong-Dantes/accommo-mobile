-- OSAS gets reasons, end dates and softer restrictions on accounts.
--
-- Until now the admin console could only flip users.status, with no reason, no
-- end date and nothing in between "fine" and "locked out". This adds:
--
--   * account_standing — why an account is in its state, when a suspension
--     ends, and what it is restricted from. Its own table, not columns on
--     users: users_select_related lets a counterparty (a student's
--     landlord/landlady, anyone they have messaged) read the whole users row,
--     and a suspension reason is not theirs to read.
--   * admin_set_account_status() — the one door every status change in the
--     console goes through, so the reason, the decision trail and the
--     notification can't be forgotten by one caller.
--   * lift_expired_suspensions() on pg_cron — timed suspensions end on time.
--   * account_notes — OSAS's private notes on an account.
--
-- Also fixes reactivation: suspension clears student_profiles.osas_verified_at,
-- and going back to `verified` never put it back, so student_may_lease() stayed
-- false and a reactivated student could never be given a room.

begin;

-- ── Standing ────────────────────────────────────────────────────────────────

create table if not exists public.account_standing (
  user_id uuid primary key references public.users(id) on delete cascade,
  reason text,
  suspended_until timestamptz,
  -- apply: a student may not apply for rooms. listings: a landlord/landlady's
  -- accommodations are hidden from what students browse.
  restrictions text[] not null default '{}'
    constraint account_standing_known_restrictions check (restrictions <@ array['apply', 'listings']::text[]),
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.account_standing enable row level security;

-- Read by the person it is about (to be told why) and by OSAS. No write
-- policies: only admin_set_account_status() and the cron job write here.
drop policy if exists account_standing_select on public.account_standing;
create policy account_standing_select on public.account_standing
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin((select auth.uid())));

revoke all on public.account_standing from anon;
revoke insert, update, delete on public.account_standing from authenticated;
grant select on public.account_standing to authenticated;

-- Changes to standing are decisions; keep them in the audit trail with users'.
drop trigger if exists trg_audit_account_standing on public.account_standing;
create trigger trg_audit_account_standing
  after insert or update or delete on public.account_standing
  for each row execute function public.fn_audit_log_change();

-- ── The lease rule learns about the `apply` restriction ─────────────────────

create or replace function public.student_may_lease(p_student uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $fn$
  select exists (
    select 1
      from public.users u
      join public.student_profiles sp on sp.user_id = u.id
     where u.id = p_student
       and u.role::text = 'student'
       and u.status::text = 'verified'
       and sp.osas_verified_at is not null
       and not exists (
         select 1 from public.account_standing s
          where s.user_id = u.id and 'apply' = any(s.restrictions)
       )
  );
$fn$;

revoke all on function public.student_may_lease(uuid) from public, anon;
grant execute on function public.student_may_lease(uuid) to authenticated, service_role;

-- ── Reactivation restores the verification stamp ────────────────────────────

create or replace function public.tg_revoke_on_unverify()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'auth'
as $function$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  awaiting_review boolean := new.role = 'landlord' and new.status = 'pending';
begin
  if new.status in ('rejected','suspended') and new.status is distinct from old.status then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = 'delisted'
      where landlord_id = new.id and status = 'accredited';
  end if;

  if new.status = 'suspended' and old.status is distinct from 'suspended' then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if new.status in ('verified','rejected','reviewing')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  -- `verified` is the decision and osas_verified_at is its cached copy, which
  -- suspension and rejection clear. Coming back to verified by any path —
  -- Reactivate, Mark as Verified, a suspension running out — restores it.
  if new.status = 'verified' and new.status is distinct from old.status
     and new.role = 'student' then
    update public.student_profiles
       set osas_verified_at = coalesce(osas_verified_at, now())
     where user_id = new.id;
  end if;

  return new;
end $function$;

-- ── The one door ────────────────────────────────────────────────────────────

create or replace function public.admin_set_account_status(
  p_user uuid,
  p_status public.user_status,
  p_reason text default null,
  p_until timestamptz default null,
  p_restrictions text[] default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_me uuid := auth.uid();
  v_user public.users;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_old_restr text[];
  v_restr text[];
  v_added text[];
  v_removed text[];
  v_until_txt text;
begin
  if not public.is_admin(v_me) then
    raise exception 'Only OSAS can change an account''s status.' using errcode = '42501';
  end if;

  select * into v_user from public.users where id = p_user for update;
  if not found then
    raise exception 'That account no longer exists.';
  end if;
  if v_user.role = 'admin' or v_user.is_superadmin then
    raise exception 'Administrator accounts are managed under Settings.';
  end if;

  select restrictions into v_old_restr from public.account_standing where user_id = p_user;
  v_old_restr := coalesce(v_old_restr, '{}');
  v_restr := coalesce(p_restrictions, v_old_restr);
  v_added := array(select unnest(v_restr) except select unnest(v_old_restr));
  v_removed := array(select unnest(v_old_restr) except select unnest(v_restr));

  if 'apply' = any(v_added) and v_user.role <> 'student' then
    raise exception 'Only a student can be stopped from applying for rooms.';
  end if;
  if 'listings' = any(v_added) and v_user.role <> 'landlord' then
    raise exception 'Only a landlord/landlady has listings to hide.';
  end if;

  -- Taking something away needs a reason the person can be told.
  if v_reason is null and (
       (p_status in ('suspended', 'rejected') and p_status is distinct from v_user.status)
       or cardinality(v_added) > 0
     ) then
    raise exception 'Give a reason — the person is told it.';
  end if;

  if p_until is not null then
    if p_status <> 'suspended' then
      raise exception 'An end date only applies to a suspension.';
    end if;
    if p_until <= now() then
      raise exception 'The end date must be in the future.';
    end if;
    -- A suspension that runs out puts the account back to `verified`, so it
    -- only makes sense for an account that was verified to begin with.
    if v_user.status not in ('verified', 'suspended') then
      raise exception 'Only a verified account can be suspended until a date.';
    end if;
  end if;

  if p_status is distinct from v_user.status then
    update public.users set status = p_status, updated_at = now() where id = p_user;
  end if;

  insert into public.account_standing (user_id, reason, suspended_until, restrictions, updated_by, updated_at)
  values (
    p_user,
    v_reason,
    case when p_status = 'suspended' then p_until end,
    v_restr,
    v_me,
    now()
  )
  on conflict (user_id) do update
    set reason = excluded.reason,
        suspended_until = excluded.suspended_until,
        restrictions = excluded.restrictions,
        updated_by = excluded.updated_by,
        updated_at = excluded.updated_at;

  -- `listings` is carried out through the flag OSAS already owns.
  -- ponytail: lifting it un-hides every one of their accommodations, including
  -- any OSAS had hidden on its own; track who hid what if that ever matters.
  if 'listings' = any(v_added) then
    update public.accommodations set hidden_from_listings = true where landlord_id = p_user;
  elsif 'listings' = any(v_removed) then
    update public.accommodations set hidden_from_listings = false where landlord_id = p_user;
  end if;

  -- The same decision trail the verification queue writes, so the mobile
  -- resubmit screens show OSAS's note without knowing where it came from.
  if p_status is distinct from v_user.status and p_status in ('rejected', 'verified') then
    insert into public.verification_requests
      (entity_type, entity_id, type, status, reviewed_by, reviewed_at, decision_notes)
    values (
      'user',
      p_user,
      case when v_user.role = 'landlord' then 'Landlord/Landlady Identity' else 'Enrollment Form / COR' end,
      case when p_status = 'rejected' then 'resubmission_requested' else 'approved' end,
      v_me,
      now(),
      v_reason
    );
  end if;

  -- Tell them. A suspended person reads this once they are let back in.
  v_until_txt := case when p_until is not null
    then ' until ' || to_char(p_until at time zone 'Asia/Manila', 'Mon FMDD, YYYY')
    else '' end;

  if p_status is distinct from v_user.status then
    insert into public.notifications (user_id, type, title, body, link_url)
    select p_user, 'verification', t.title, t.body, '/profile'
    from (values
      (case p_status
         when 'suspended' then 'Account suspended'
         when 'rejected' then 'Resubmission requested'
         when 'verified' then case when v_user.status = 'suspended' then 'Account reactivated' else 'Verification approved' end
       end,
       case p_status
         when 'suspended' then 'OSAS suspended your account' || v_until_txt || '. Reason: ' || v_reason
         when 'rejected' then 'OSAS needs new requirements from you. Note: ' || v_reason
         when 'verified' then case when v_user.status = 'suspended'
           then 'Your account is active again.' || coalesce(' Note: ' || v_reason, '')
           else 'Your account has been verified.' end
       end)
    ) as t(title, body)
    where t.title is not null;
  end if;

  if 'apply' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Room applications paused',
            'OSAS has paused your room applications. Reason: ' || v_reason, '/profile');
  end if;
  if 'apply' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Room applications restored', 'You can apply for rooms again.', '/profile');
  end if;
  if 'listings' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Listings hidden',
            'OSAS has hidden your accommodations from students. Reason: ' || v_reason, '/profile');
  end if;
  if 'listings' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Listings visible again', 'Students can see your accommodations again.', '/profile');
  end if;
end $fn$;

revoke all on function public.admin_set_account_status(uuid, public.user_status, text, timestamptz, text[]) from public, anon;
grant execute on function public.admin_set_account_status(uuid, public.user_status, text, timestamptz, text[]) to authenticated;

-- ── Timed suspensions end on time ───────────────────────────────────────────

create or replace function public.lift_expired_suspensions()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_count integer;
begin
  if auth.uid() is not null then
    raise exception 'lift_expired_suspensions is not callable by a client.';
  end if;

  with due as (
    select s.user_id
      from public.account_standing s
      join public.users u on u.id = s.user_id
     where u.status = 'suspended'
       and s.suspended_until is not null
       and s.suspended_until <= now()
  ), lifted as (
    update public.users u set status = 'verified', updated_at = now()
      from due where u.id = due.user_id
    returning u.id
  ), cleared as (
    update public.account_standing s
       set suspended_until = null, reason = null, updated_by = null, updated_at = now()
      from lifted where s.user_id = lifted.id
    returning s.user_id
  )
  insert into public.notifications (user_id, type, title, body, link_url)
  select user_id, 'verification', 'Account reactivated', 'Your suspension has ended. You can sign in again.', '/profile'
    from cleared;

  get diagnostics v_count = row_count;
  return v_count;
end $fn$;

revoke all on function public.lift_expired_suspensions() from public, anon, authenticated;

do $$
begin
  perform cron.unschedule('lift-expired-suspensions')
    where exists (select 1 from cron.job where jobname = 'lift-expired-suspensions');
  perform cron.schedule('lift-expired-suspensions', '*/15 * * * *', 'select public.lift_expired_suspensions()');
end $$;

-- ── OSAS's private notes on an account ──────────────────────────────────────

create table if not exists public.account_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  author_id uuid references public.users(id) on delete set null default auth.uid(),
  body text not null constraint account_notes_body_size check (length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists account_notes_user_created on public.account_notes (user_id, created_at desc);

alter table public.account_notes enable row level security;

drop policy if exists account_notes_select_admin on public.account_notes;
create policy account_notes_select_admin on public.account_notes
  for select to authenticated using (public.is_admin((select auth.uid())));

drop policy if exists account_notes_insert_admin on public.account_notes;
create policy account_notes_insert_admin on public.account_notes
  for insert to authenticated
  with check (public.is_admin((select auth.uid())) and author_id = (select auth.uid()));

drop policy if exists account_notes_delete_author on public.account_notes;
create policy account_notes_delete_author on public.account_notes
  for delete to authenticated
  using (author_id = (select auth.uid()) and public.is_admin((select auth.uid())));

revoke all on public.account_notes from anon;
grant select, insert, delete on public.account_notes to authenticated;

commit;
