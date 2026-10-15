-- Two-factor is now mandatory for admins. mfa_ok() used to pass an admin who had
-- never enrolled an authenticator app (`not exists verified factor`), so a
-- password alone was enough until someone chose to turn 2FA on.
--
-- Now the caller's own session needs aal2, full stop. An admin with no factor
-- cannot reach the console's data until they enrol, which also lifts the session
-- to aal2 (challengeAndVerify); the console sends them to /auth/mfa-setup. They
-- can still read their own row, which is how it knows to do that.
-- Other people's ids and service-role calls (no auth.uid()) behave as before.
--
-- Ship the console build with /auth/mfa-setup before inviting a new admin.
create or replace function public.mfa_ok(p_uid uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select p_uid is distinct from auth.uid()
      or coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2';
$$;
