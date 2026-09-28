-- Refines 20260909000008. The sign-in block applies only while OSAS still owes
-- the manager a decision. Once OSAS has replied and wants something changed, the
-- manager must be able to get in and act on it — otherwise a rejection is a
-- permanent dead end and the documents can never be corrected.
--
--   pending             -> blocked, OSAS has not reviewed it yet
--   reviewing/rejected  -> allowed in, and the app routes them to
--                          /register/manager?resubmit=true with OSAS's reason
--   verified            -> normal access
--   suspended           -> blocked, any role
--
-- Resubmitting calls resubmit_verification(), which returns the account to
-- 'pending' — and this trigger then re-closes the door until OSAS decides again.
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  -- Only 'pending' is a closed door.
  awaiting_review boolean := new.role = 'accommodation_manager' and new.status = 'pending';
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

  -- A manager finishing registration, or sent back to pending, waits outside.
  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- OSAS approving, or asking for changes, reopens sign-in.
  if new.status in ('verified','rejected','reviewing')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify
  after update of status, registered_at on public.users
  for each row execute function public.tg_revoke_on_unverify();

-- Let already-rejected managers back in to fix their application.
update auth.users a
set banned_until = null
from public.users u
where u.id = a.id
  and u.role = 'accommodation_manager'
  and u.status in ('rejected','reviewing')
  and a.banned_until is not null;
