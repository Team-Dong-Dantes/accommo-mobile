-- Admin two-factor authentication, enforced by the database rather than only
-- by the web router, and sign-in alerts for admins.

-- ── 1. MFA ──────────────────────────────────────────────────────────────────
-- An admin who has enrolled an authenticator app only counts as an admin once
-- the session has proven it (aal2). Until then they can still read their own
-- row (so the console can send them to the code screen) but nothing that
-- is_admin() or get_my_role() = 'admin' guards — which is all of OSAS.
--
-- Only the caller's own session is judged: is_admin(someone_else) still just
-- answers "is that person an admin". Service-role calls have no auth.uid() and
-- are unaffected.
create or replace function public.mfa_ok(p_uid uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select p_uid is distinct from auth.uid()
      or coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
      or not exists (
        select 1 from auth.mfa_factors f
        where f.user_id = p_uid and f.status = 'verified'
      );
$$;

revoke all on function public.mfa_ok(uuid) from public, anon;
grant execute on function public.mfa_ok(uuid) to authenticated, service_role;

create or replace function public.is_admin(p_uid uuid)
returns boolean
language sql stable security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1 from public.users
    where id = p_uid and (role = 'admin' or is_superadmin = true)
  ) and public.mfa_ok(p_uid);
$$;

create or replace function public.get_my_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select case when u.role = 'admin' and not public.mfa_ok(u.id) then null else u.role::text end
  from public.users u
  where u.id = auth.uid();
$$;

-- ── 2. Sign-in alerts ───────────────────────────────────────────────────────
-- Replaces the Settings toggle that only lived in localStorage.
alter table public.users add column if not exists login_alerts boolean not null default true;

create or replace function public.notify_admin_sign_in()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.users u
    where u.id = new.user_id and u.role = 'admin' and u.login_alerts
  ) then
    insert into public.notifications (user_id, type, title, body, link_url, source)
    values (
      new.user_id, 'system', 'New sign-in to your OSAS account',
      'Signed in' || coalesce(' from ' || host(new.ip), '')
        || coalesce(' using ' || left(new.user_agent, 120), '')
        || '. If this was not you, change your password in Settings.',
      '/settings', 'system'
    );
  end if;
  return new;
end;
$$;

revoke all on function public.notify_admin_sign_in() from public, anon, authenticated;

drop trigger if exists admin_sign_in_alert on auth.sessions;
create trigger admin_sign_in_alert
  after insert on auth.sessions
  for each row execute function public.notify_admin_sign_in();
