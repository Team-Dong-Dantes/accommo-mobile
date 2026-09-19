-- Re-consent has been broken since 20260915000001.
--
-- When a bundled legal document's effective date moves past the date on the
-- account, TermsGate.vue blocks the app and asks for the new version. It
-- recorded that by writing terms_accepted_at / privacy_accepted_at straight
-- from the client — and 20260915000001 closed exactly those two columns to the
-- account holder. So every "I accept" since has failed with
--
--   Consent timestamps are recorded by the server, not the client.
--
-- leaving the gate unpassable: the user can only sign out.
--
-- complete_registration() cannot stand in for it. Its coalesce() makes the
-- stamps append-only, which is the right rule for a first acceptance and the
-- wrong one here — a new version of a document is precisely the case where the
-- date has to move forward. It also stamps both columns and registered_at
-- together, and re-accepting the Privacy Notice must not restamp Terms the user
-- agreed to months ago.
--
-- So: a second definer function that takes the documents being accepted, and
-- only ever writes now(). Consent still cannot be back-dated, still cannot be
-- forged by the client, and each document keeps its own date.

create or replace function public.record_consent(p_documents text[])
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_unknown text[];
begin
  if v_uid is null then
    raise exception 'Not signed in.';
  end if;

  if p_documents is null or cardinality(p_documents) = 0 then
    raise exception 'Name the document being accepted.'
      using errcode = 'check_violation';
  end if;

  -- The column a name maps to is decided here, not by the caller, so the
  -- argument cannot reach any other column.
  select array_agg(d)
    into v_unknown
    from unnest(p_documents) as d
   where d not in ('terms', 'privacy');

  if v_unknown is not null then
    raise exception 'Unknown legal document: %', array_to_string(v_unknown, ', ')
      using errcode = 'check_violation';
  end if;

  perform set_config('app.recording_consent', 'true', true);

  update public.users
     set terms_accepted_at = case
           when 'terms' = any (p_documents) then now() else terms_accepted_at end,
         privacy_accepted_at = case
           when 'privacy' = any (p_documents) then now() else privacy_accepted_at end,
         updated_at = now()
   where id = v_uid;

  if not found then
    raise exception 'Account not found.';
  end if;
end;
$$;

revoke all on function public.record_consent(text[]) from public;
revoke all on function public.record_consent(text[]) from anon;
grant execute on function public.record_consent(text[]) to authenticated;

-- ── The guard ───────────────────────────────────────────────────────────────
-- Carried over from 20260915000001 unchanged except for `allow_consent`. The
-- two consent columns now have two legitimate writers — the first acceptance
-- during registration, and a later re-acceptance — while registered_at keeps
-- complete_registration() as its only one.
create or replace function public.lock_user_privileges()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  allow_resubmit boolean := coalesce(current_setting('app.resubmitting', true), 'false') = 'true';
  allow_email boolean := coalesce(current_setting('app.confirming_email', true), 'false') = 'true';
  allow_complete boolean := coalesce(current_setting('app.completing_registration', true), 'false') = 'true';
  allow_sync boolean := coalesce(current_setting('app.syncing_auth', true), 'false') = 'true';
  allow_consent boolean := coalesce(current_setting('app.recording_consent', true), 'false') = 'true';
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

    -- Completing a registration happens only through complete_registration().
    if new.registered_at is distinct from old.registered_at and not allow_complete then
      raise exception 'Registration is completed by the server, not the client.';
    end if;

    -- Consent is stamped by complete_registration() the first time and by
    -- record_consent() when a document is revised. Never by the client.
    if (new.terms_accepted_at is distinct from old.terms_accepted_at
        or new.privacy_accepted_at is distinct from old.privacy_accepted_at)
       and not (allow_complete or allow_consent) then
      raise exception 'Consent timestamps are recorded by the server, not the client.';
    end if;

    -- The address shown across both apps follows auth.users, and is only ever
    -- written by the sync trigger. Changing it directly let someone display an
    -- address they had never proved — on any domain, signup rule or not.
    if new.email is distinct from old.email and not allow_sync then
      raise exception 'Change your e-mail address through your account settings.';
    end if;
  end if;
  return new;
end;
$$;
