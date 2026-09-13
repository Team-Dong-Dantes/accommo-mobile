-- Prove the applicant actually reads the address they signed up with.
--
-- Auto-confirm is on (mailer_autoconfirm = true), so Supabase marks every address
-- confirmed the moment the account is created and the "type your code" step gated
-- nothing: the account existed and worked whether or not the code was entered.
-- Verified by registering a mailbox that does not exist and getting a live
-- session. Anyone could sign up on an address they do not own and, because e-mail
-- is unique, take it from the real owner.
--
-- The OTP itself IS real proof — GoTrue checks a code it mailed. What was missing
-- was a record of it the database could trust. A Supabase access token carries an
-- `amr` claim naming how it was obtained, signed by GoTrue:
--     password sign-in -> [{"method":"password"}]
--     e-mail code      -> [{"method":"otp"}]
-- A client cannot forge that, so users.email_verified_at is set ONLY by
-- confirm_email_ownership(), and only for a caller holding such a token.
--
-- ALSO CHANGED OUTSIDE MIGRATIONS (project auth config, via the Management API):
--   jwt_exp 3600 -> 900. Suspension already deletes sessions and refresh tokens,
--   so the only remaining gap was one unexpired access token; this bounds it to
--   15 minutes instead of an hour. Access tokens are stateless, so they cannot be
--   revoked individually — shortening the lifetime is the only lever.

-- 1. Grandfather every account that already exists. 96 of 169 rows had no stamp
--    (29 of them OSAS-verified) because the old trigger only copied
--    auth.email_confirmed_at, so gating without this would lock them all out.
update public.users
set email_verified_at = coalesce(email_verified_at, created_at, now())
where email_verified_at is null;

-- 2. Stop fabricating the stamp: auto-confirm sets email_confirmed_at instantly,
--    so copying it made every new account born "verified".
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
begin
  if tg_op = 'INSERT' then
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
      null,          -- only confirm_email_ownership() may stamp this
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          -- status and email_verified_at deliberately NOT carried over.
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          updated_at = now();
    return new;

  elsif tg_op = 'UPDATE' then
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, phone),
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

-- 3. The attestation. SECURITY DEFINER does not change auth.uid(), so the guard
--    below would otherwise see this as the user editing their own verification —
--    hence the transaction-local flag, the pattern resubmit_verification uses.
create or replace function public.confirm_email_ownership()
returns boolean
language plpgsql security definer set search_path = public, auth
as $fn$
declare
  methods jsonb := coalesce(auth.jwt() -> 'amr', '[]'::jsonb);
  provider text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  select raw_app_meta_data ->> 'provider' into provider from auth.users where id = auth.uid();

  -- Either the current token came from an e-mail code (a password token cannot be
  -- used to claim inbox ownership), or an OAuth provider already vouched for the
  -- address, in which case there is no code to type.
  if not (
    exists (
      select 1 from jsonb_array_elements(methods) m
      where m ->> 'method' in ('otp', 'magiclink', 'email', 'oauth')
    )
    or coalesce(provider, 'email') <> 'email'
  ) then
    raise exception 'Verify your e-mail with the code first.';
  end if;

  perform set_config('app.confirming_email', 'true', true);
  update public.users set email_verified_at = now(), updated_at = now()
  where id = auth.uid() and email_verified_at is null;
  return true;
end $fn$;

revoke all on function public.confirm_email_ownership() from public, anon;
grant execute on function public.confirm_email_ownership() to authenticated;

-- 4. email_verified_at joins role/status as a column its owner may not set.
create or replace function public.lock_user_privileges() returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  allow_resubmit boolean := coalesce(current_setting('app.resubmitting', true), 'false') = 'true';
  allow_email boolean := coalesce(current_setting('app.confirming_email', true), 'false') = 'true';
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
      raise exception 'You are not allowed to change your own role.';
    end if;
    if new.email_verified_at is distinct from old.email_verified_at and not allow_email then
      raise exception 'You are not allowed to change your own e-mail verification.';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = 'pending' and old.status in ('rejected','unverified') then
        return new;
      end if;
      raise exception 'You are not allowed to change your own account status.';
    end if;
  end if;
  return new;
end $fn$;

-- 5. Release addresses occupied by registrations that never proved ownership.
--    NOT SCHEDULED — it deletes auth accounts, so it stays manual until someone
--    decides that is wanted. To enable it weekly:
--      select cron.schedule('purge-unverified-accounts','30 18 * * 0',
--        'select public.purge_unverified_accounts();');
create or replace function public.purge_unverified_accounts(p_older_than interval default interval '30 days')
returns integer
language plpgsql security definer set search_path = public, auth
as $fn$
declare
  n integer;
begin
  with doomed as (
    select u.id
    from public.users u
    where u.email_verified_at is null
      and u.status = 'pending'
      and u.created_at < now() - p_older_than
      and not exists (select 1 from public.verification_documents d where d.user_id = u.id)
      and not exists (select 1 from public.leases l where l.student_id = u.id or l.accommodation_manager_id = u.id)
      and not exists (select 1 from public.accommodations a where a.accommodation_manager_id = u.id)
      and not exists (select 1 from public.messages m where m.sender_id = u.id)
  )
  delete from auth.users a using doomed d where a.id = d.id;
  get diagnostics n = row_count;

  if n > 0 then
    insert into public.audit_logs (action, actor_id, entity_type, after_json)
    values ('auth.purge_unverified', null, 'user',
            jsonb_build_object('deleted', n, 'older_than', p_older_than::text));
  end if;
  return n;
end $fn$;

revoke all on function public.purge_unverified_accounts(interval) from public, anon, authenticated;
