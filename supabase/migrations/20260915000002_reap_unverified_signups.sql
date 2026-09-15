-- Stop unproven accounts from squatting an address forever.
--
-- Registration is account-first: signUp creates the auth user on the password
-- screen, before the code has been typed. That is deliberate and it is what lets
-- the OTP attach to a real session — but it means anyone can take an address
-- they do not own. They cannot *use* it (email_verified_at is refused to the
-- account holder, so the OTP genuinely cannot be bypassed), but the real owner
-- then hits "This email is already registered" and has nowhere to go. Denial of
-- registration rather than takeover, and until now permanent.
--
-- The fix is lifecycle, not permissions: an account that never proved its
-- address and never finished onboarding is not an account, and after a few days
-- it should stop holding the address hostage.
--
-- Deleting from auth.users is what matters — handle_auth_user_sync's DELETE
-- branch removes the public.users row with it, and every foreign key pointing at
-- that row is CASCADE or SET NULL, so nothing else breaks. Checked before
-- writing this; there are no RESTRICT references.

-- 72 hours, not 24: the cost of reaping too eagerly falls on a genuine student
-- who starts on Friday evening and finishes on Monday, and who then has to redo
-- the whole form. The cost of waiting falls on someone whose address is briefly
-- held, which OSAS can resolve by hand in the meantime. One number, one place,
-- and callable with a shorter interval for testing.
create or replace function public.reap_unverified_signups(p_older_than interval default '72 hours')
returns integer
language plpgsql security definer set search_path = public, auth
as $$
declare
  v_count integer;
begin
  with doomed as (
    delete from auth.users a
     where a.created_at < now() - p_older_than
       and exists (
         select 1
           from public.users u
          where u.id = a.id
            and u.email_verified_at is null   -- never proved the address
            and u.registered_at is null       -- never finished onboarding
            -- Belt and braces. Neither can be true of an unfinished account,
            -- but a reaper is not the place to find that out.
            and u.role <> 'admin'
            and u.is_superadmin = false
       )
    returning a.id
  )
  select count(*) into v_count from doomed;
  return v_count;
end;
$$;

-- Nobody but the scheduler. SECURITY DEFINER with no grant means only the
-- superuser role that pg_cron runs as can call it.
revoke all on function public.reap_unverified_signups(interval) from public;

-- An auth.users row with no public.users row is deliberately left alone: the
-- sync trigger always creates one, so its absence means something unusual, and
-- a nightly job should not be the thing that quietly deletes the evidence.

do $$
begin
  perform cron.unschedule('reap-unverified-signups');
exception when others then
  null;  -- not scheduled yet, which is the normal case on first run
end $$;

-- 03:23 daily. Off the hour because every other cron on every other system in
-- the world runs at :00.
select cron.schedule(
  'reap-unverified-signups',
  '23 3 * * *',
  $$select public.reap_unverified_signups()$$
);
