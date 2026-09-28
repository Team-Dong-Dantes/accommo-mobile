-- Close the three columns a user could still write on their own row.
--
-- Probed against the live database: `email_verified_at` and `status` were
-- already refused, `is_superadmin` and `role='admin'` blocked, and
-- `registered_at` could not be un-set to re-open the role choice. What remained
-- writable by the account holder was:
--
--   registered_at (while null)  -- mark onboarding finished having done none of it
--   terms_accepted_at           -- write or alter their own RA 10173 consent evidence
--   privacy_accepted_at         -- likewise
--   email                       -- set the displayed address to anything at all,
--                                  including a domain the signup trigger rejects
--
-- None is a privilege bypass; what they cost is the integrity of the record OSAS
-- relies on. Consent timestamps are supposed to be evidence, and the e-mail is
-- shown in the web console as fact.
--
-- A plain REVOKE would not do: markRegistered() in the mobile client is the only
-- writer of the three timestamps and runs with the *user's* privileges, and
-- public.users.email is written legitimately by handle_auth_user_sync whenever
-- someone changes their address through auth.updateUser. So the privileged write
-- moves behind a definer function, and the column is locked against everything
-- else — the same shape as `app.resubmitting` (the resubmit RPC) and
-- `app.confirming_email` (confirm_email_ownership) already in this trigger.

-- ── The one way to complete a registration ──────────────────────────────────
-- coalesce(col, now()) makes the three append-only: calling this twice cannot
-- move a timestamp that is already set, so consent cannot be back-dated or
-- rewritten after the fact. The precondition is the part a client cannot fake —
-- no completed registration without a confirmed address.
create or replace function public.complete_registration()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in.';
  end if;

  perform set_config('app.completing_registration', 'true', true);

  update public.users
     set registered_at       = coalesce(registered_at, now()),
         terms_accepted_at   = coalesce(terms_accepted_at, now()),
         privacy_accepted_at = coalesce(privacy_accepted_at, now()),
         updated_at          = now()
   where id = v_uid
     and email_verified_at is not null;

  if not found then
    raise exception 'Confirm your e-mail address before completing registration.'
      using errcode = 'check_violation';
  end if;
end;
$$;

revoke all on function public.complete_registration() from public;
grant execute on function public.complete_registration() to authenticated;

-- ── The guard ───────────────────────────────────────────────────────────────
-- Every existing rule is carried over unchanged; the two new blocks are at the
-- end. `is distinct from` throughout, so a write of the same value is a no-op
-- and passes — which is what keeps ensureUserRow's idempotent upsert working,
-- since it writes the e-mail back on every conflict.
create or replace function public.lock_user_privileges()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  allow_resubmit boolean := coalesce(current_setting('app.resubmitting', true), 'false') = 'true';
  allow_email boolean := coalesce(current_setting('app.confirming_email', true), 'false') = 'true';
  allow_complete boolean := coalesce(current_setting('app.completing_registration', true), 'false') = 'true';
  allow_sync boolean := coalesce(current_setting('app.syncing_auth', true), 'false') = 'true';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = 'INSERT' then
    if new.role = 'admin' and not public.is_admin(auth.uid()) then
      raise exception 'Insufficient privileges to assign the admin role.';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      -- Choosing student vs manager is part of onboarding, and only then.
      if not (old.registered_at is null
              and new.role in ('student','accommodation_manager')
              and old.role <> 'admin') then
        raise exception 'You are not allowed to change your own role.';
      end if;
    end if;
    -- `allow_sync` joins `allow_email` here because the sync's UPDATE branch
    -- stamps this column itself when an OAuth identity is linked later. In
    -- practice auth.uid() is null for a write driven by the auth server and this
    -- whole block is skipped, but that depends on how GoTrue happens to connect,
    -- which is not a thing to leave a security guard resting on.
    if new.email_verified_at is distinct from old.email_verified_at
       and not (allow_email or allow_sync) then
      raise exception 'You are not allowed to change your own e-mail verification.';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = 'pending' and old.status in ('rejected','unverified') then
        return new;
      end if;
      raise exception 'You are not allowed to change your own account status.';
    end if;
    -- Registration completes once; it cannot be un-set to re-open role changes.
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception 'Registration is already complete.';
    end if;

    -- NEW: completing a registration, and stamping the consent that goes with
    -- it, happens only through complete_registration().
    if not allow_complete then
      if new.registered_at is distinct from old.registered_at then
        raise exception 'Registration is completed by the server, not the client.';
      end if;
      if new.terms_accepted_at is distinct from old.terms_accepted_at
         or new.privacy_accepted_at is distinct from old.privacy_accepted_at then
        raise exception 'Consent timestamps are recorded by the server, not the client.';
      end if;
    end if;

    -- NEW: the address shown across both apps follows auth.users, and is only
    -- ever written by the sync trigger. Changing it directly let someone display
    -- an address they had never proved — on any domain, signup rule or not.
    if new.email is distinct from old.email and not allow_sync then
      raise exception 'Change your e-mail address through your account settings.';
    end if;
  end if;
  return new;
end;
$$;

-- ── The sync's escape ───────────────────────────────────────────────────────
-- handle_auth_user_sync is SECURITY DEFINER, but auth.uid() inside it is still
-- the signed-in person, so the guard above would otherwise refuse the one
-- legitimate e-mail change: the one auth.users just made.
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_domain text;
  -- The twin of ALLOWED_EMAIL_DOMAINS in accommo-mobile/src/utils/config.ts.
  v_allowed text[] := array['gmail.com', 'isu.edu.ph'];
begin
  if tg_op = 'INSERT' then
    v_domain := lower(split_part(coalesce(new.email, ''), '@', 2));
    if v_domain <> all (v_allowed) then
      raise exception using
        errcode = 'check_violation',
        message = format('accommo: e-mail domain %L is not accepted', v_domain),
        hint = 'Accommo accounts must use @gmail.com or @isu.edu.ph.';
    end if;

    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, '+639000000000'),
      coalesce((new.raw_user_meta_data ->> 'role')::text, 'student')::user_role,
      'pending'::user_status,
      coalesce(new.raw_user_meta_data ->> 'full_name', 'Demo User'),
      coalesce(new.raw_user_meta_data ->> 'initials', 'DU'),
      coalesce((new.raw_user_meta_data ->> 'avatar_color'), 'blue'),
      coalesce((new.raw_user_meta_data ->> 'sex')::text, 'M'),
      -- OAuth vouches for the address; e-mail+password must prove it with a code.
      case when v_provider <> 'email' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          -- status deliberately NOT carried over: only OSAS moves it.
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = 'UPDATE' then
    perform set_config('app.syncing_auth', 'true', true);
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, phone),
        -- Linking an OAuth identity later also proves ownership.
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> 'email' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = 'DELETE' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;
