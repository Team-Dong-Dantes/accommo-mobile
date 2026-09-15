-- The reaper added in 20260915000002 was exposed on the REST API.
--
-- `revoke all ... from public` does not remove the EXECUTE that Supabase grants
-- directly to `anon` and `authenticated` through default privileges on the
-- public schema. So the function was reachable at
-- /rest/v1/rpc/reap_unverified_signups by anyone holding the anon key — and it
-- takes an interval, so `'0 seconds'` would have deleted every unverified,
-- unfinished account in a single unauthenticated call.
--
-- Caught by Supabase's own security advisor, not by the migration that wrote it.
-- The lesson for anything added here later: on this platform, revoking from
-- PUBLIC is not the same as revoking from the API roles, and a SECURITY DEFINER
-- function in the `public` schema is an internet-facing endpoint by default.
revoke all on function public.reap_unverified_signups(interval) from anon, authenticated, public;

-- complete_registration is for signed-in users. It already raises 'Not signed
-- in.' when auth.uid() is null, so anon could do no harm — but an endpoint that
-- exists only to refuse people should not be published at all.
revoke all on function public.complete_registration() from anon;

-- Belt and braces, so a future default-privilege grant cannot quietly re-expose
-- this. pg_cron and service_role both run without a JWT, so a null auth.uid() is
-- exactly the caller this is meant for; anything with a user behind it is not.
create or replace function public.reap_unverified_signups(p_older_than interval default '72 hours')
returns integer
language plpgsql security definer set search_path = public, auth
as $$
declare
  v_count integer;
begin
  if auth.uid() is not null then
    raise exception 'reap_unverified_signups is not callable by a client.';
  end if;

  with doomed as (
    delete from auth.users a
     where a.created_at < now() - p_older_than
       and exists (
         select 1
           from public.users u
          where u.id = a.id
            and u.email_verified_at is null   -- never proved the address
            and u.registered_at is null       -- never finished onboarding
            and u.role <> 'admin'
            and u.is_superadmin = false
       )
    returning a.id
  )
  select count(*) into v_count from doomed;
  return v_count;
end;
$$;

-- Again after the replace: CREATE OR REPLACE re-applies default privileges.
revoke all on function public.reap_unverified_signups(interval) from anon, authenticated, public;
