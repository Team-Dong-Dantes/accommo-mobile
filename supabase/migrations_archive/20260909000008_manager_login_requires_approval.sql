-- Managers may not hold a session until OSAS approves their application.
--
-- A manager "cannot open an account… they can't login to their acc unless
-- they've been verified by OSAS". This is stricter than the previous behaviour,
-- which kept unverified managers signed in but restricted them by router
-- allowlist to their compliance screens.
--
-- The app now refuses the sign-in in login() and in the router guard, but both
-- are client-side and RLS knows nothing about users.status, so a direct API call
-- would sail past them. The auth user is banned instead — the same mechanism
-- suspension uses — and the ban is lifted when OSAS verifies.
--
-- Timing matters: the ban applies when REGISTRATION COMPLETES, not when the
-- account row is created. A manager needs a live session during registration to
-- upload their government ID and business permit; banning at account creation
-- would break the very flow this gates.
--
-- Students are deliberately unaffected: a pending student may sign in and browse,
-- and leases_insert_student_application already stops them acting before OSAS
-- verification.
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  unverified_manager boolean := new.role = 'accommodation_manager' and new.status <> 'verified';
begin
  if new.status in ('rejected','suspended') and old.status = 'verified' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = 'delisted'
      where accommodation_manager_id = new.id and status = 'accredited';
  end if;

  -- Suspension: always bans, any role.
  if new.status = 'suspended' and old.status is distinct from 'suspended' then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- A manager finishing registration, or losing approval afterwards, is locked
  -- out until OSAS verifies them.
  if unverified_manager and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- Approval (or lifting a suspension) restores sign-in.
  if new.status = 'verified' and old.status is distinct from 'verified' then
    update auth.users set banned_until = null where id = new.id;
  elsif old.status = 'suspended' and new.status is distinct from 'suspended'
        and not unverified_manager then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify
  after update of status, registered_at on public.users
  for each row execute function public.tg_revoke_on_unverify();

-- Apply the rule to managers who already exist; the trigger only fires on future
-- updates. Scoped to those who FINISHED registering, so anyone mid-registration
-- keeps the session they need to upload documents.
update auth.users a
set banned_until = now() + interval '100 years'
from public.users u
where u.id = a.id
  and u.role = 'accommodation_manager'
  and u.status <> 'verified'
  and u.registered_at is not null
  and a.banned_until is null;

delete from auth.sessions s
using public.users u
where s.user_id = u.id
  and u.role = 'accommodation_manager'
  and u.status <> 'verified'
  and u.registered_at is not null;

delete from auth.refresh_tokens r
using public.users u
where r.user_id = u.id::text
  and u.role = 'accommodation_manager'
  and u.status <> 'verified'
  and u.registered_at is not null;
