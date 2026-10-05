-- Security hardening, part two (same review as 20261005000000).
--
--  1. Contact details. users_select_related hands a conversation or lease
--     counterparty the other person's whole row, and an accredited
--     landlord/landlady's row to every signed-in user: e-mail, phone and date
--     of birth included. Those three columns are no longer readable on
--     public.users at all; users_full serves them — e-mail and phone to
--     yourself, OSAS and the other side of a current lease, date of birth to
--     yourself and OSAS only.
--  2. is_admin() and friends answered "is this id an admin?" to anyone with the
--     anon key. Policies that apply to every role are narrowed to signed-in
--     users first, so revoking anon's EXECUTE cannot break public browsing.
--  3. A signed-out session kept working until its access token expired (up to
--     an hour), so "sign out everywhere", a role change or closing an account
--     left an already-open device in. Every API request now checks that its
--     session still exists.
--  4. A landlord/landlady read a former tenant's student profile (emergency
--     contact included) forever. Current leases and applications only.

-- 1 ---------------------------------------------------------------------------
-- Column grants, because RLS can hide rows but not columns. A column added to
-- users later must be granted here too, or clients cannot see it.
revoke select on public.users from authenticated;
grant select (id, role, status, full_name, initials, avatar_color, sex, email_verified_at, created_at,
              updated_at, last_login_at, is_superadmin, onboarding_complete, notification_prefs,
              avatar_url, registered_at, terms_accepted_at, privacy_accepted_at, reviewing_by,
              reviewing_at, closed_at, login_alerts)
   on public.users to authenticated;

-- Runs as its owner (security_invoker off) so it can read the hidden columns;
-- the WHERE clause is the whole of its access rule.
create or replace view public.users_full with (security_invoker = false) as
  select u.id, u.email, u.phone, u.role, u.status, u.full_name, u.initials, u.avatar_color, u.sex,
         u.email_verified_at, u.created_at, u.updated_at, u.last_login_at, u.is_superadmin,
         u.onboarding_complete, u.notification_prefs, u.avatar_url, u.registered_at,
         u.terms_accepted_at, u.privacy_accepted_at, u.reviewing_by, u.reviewing_at, u.closed_at,
         u.login_alerts,
         case when u.id = (select auth.uid()) or (select public.is_admin((select auth.uid())))
              then u.date_of_birth end as date_of_birth
    from public.users u
   where u.id = (select auth.uid())
      or (select public.is_admin((select auth.uid())))
      or exists (select 1 from public.leases l
                  where l.status in ('pending', 'active', 'leave_requested')
                    and ((l.student_id = (select auth.uid()) and l.landlord_id = u.id)
                      or (l.landlord_id = (select auth.uid()) and l.student_id = u.id)));

revoke all on public.users_full from public, anon;
grant select on public.users_full to authenticated, service_role;

-- 2 ---------------------------------------------------------------------------
do $$
declare
  p record;
  fns text := 'is_admin|current_is_superadmin|get_my_role|my_accommodation_ids|can_notify';
begin
  for p in
    select * from pg_policies
     where schemaname = 'public'
       and coalesce(qual, '') || coalesce(with_check, '') ~ fns
  loop
    if p.roles = '{public}' then
      execute format('alter policy %I on public.%I to authenticated', p.policyname, p.tablename);
    elsif 'anon' = any(p.roles) then
      raise exception 'Policy % on % lets anon call %; narrow it before revoking.', p.policyname, p.tablename, fns;
    end if;
  end loop;
end $$;

revoke execute on function public.is_admin(uuid) from public, anon;
revoke execute on function public.current_is_superadmin() from public, anon;
revoke execute on function public.get_my_role() from public, anon;
revoke execute on function public.my_accommodation_ids() from public, anon;
revoke execute on function public.can_notify(uuid) from public, anon;
grant execute on function public.is_admin(uuid), public.current_is_superadmin(), public.get_my_role(),
                          public.my_accommodation_ids(), public.can_notify(uuid)
   to authenticated, service_role;

-- 3 ---------------------------------------------------------------------------
-- PostgREST runs this before every request. A user token carries the id of the
-- session it was issued for; once that session is gone (sign out everywhere,
-- admin_change_role, admin_close_account, a password reset by OSAS) the token
-- is refused with a 401. The anon and service keys carry no session and pass.
-- Realtime and Storage do not go through PostgREST and still honour the token
-- until it expires.
create or replace function public.check_session() returns void
language plpgsql stable security definer set search_path = public as $$
declare
  sid text := auth.jwt() ->> 'session_id';
begin
  if sid is not null and not exists (select 1 from auth.sessions s where s.id = sid::uuid) then
    raise sqlstate 'PT401' using message = 'Your session has ended. Sign in again.';
  end if;
end $$;

revoke all on function public.check_session() from public;
grant execute on function public.check_session() to anon, authenticated, service_role;

alter role authenticator set pgrst.db_pre_request = 'public.check_session';
notify pgrst, 'reload config';

-- 4 ---------------------------------------------------------------------------
drop policy if exists "accommodation_managers_read_lease_student_profiles" on public.student_profiles;
create policy "accommodation_managers_read_lease_student_profiles" on public.student_profiles
  for select to authenticated
  using (exists (select 1 from public.leases l
                  where l.student_id = student_profiles.user_id
                    and l.landlord_id = (select auth.uid())
                    and l.status in ('pending', 'active', 'leave_requested')));
