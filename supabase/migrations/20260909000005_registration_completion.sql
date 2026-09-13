-- "Continue with Google" on the LOGIN screen silently created a full account.
--
-- signInWithOAuth has no sign-in-only mode: it always provisions the user. The
-- auth-sync trigger then wrote a public.users row with role defaulting to
-- 'student', because an OAuth signup carries no role in user_metadata. So a
-- manager who signed in with Google became a student, the role picker was never
-- shown, and no student_profiles row was created. Live at the time: 11 Google
-- accounts, every one role='student', 9 with no profile at all.
--
-- The register screen detected "new Google user" as "has a session but NO users
-- row" — a condition the trigger makes impossible — so its profile-completion
-- mode was dead code, and the router then evicted them with "account already
-- exists" because it treated the mere existence of a users row as proof of
-- registration.
--
-- registered_at is the missing signal: null means the account exists but its
-- owner never finished onboarding, so route them to /register/role.
alter table public.users add column if not exists registered_at timestamptz;

comment on column public.users.registered_at is
  'When the owner completed registration. Null means an account exists (e.g. created by an OAuth sign-in) but onboarding was never finished; the app routes these to /register/role.';

-- Grandfather anyone who demonstrably went through registration: a role-specific
-- profile, submitted documents, or an OSAS decision. Accounts with none of those
-- are genuinely half-finished and are asked to complete onboarding.
update public.users u
set registered_at = coalesce(u.registered_at, u.created_at, now())
where u.registered_at is null
  and (
    exists (select 1 from public.student_profiles sp
             where sp.user_id = u.id
               and (sp.college is not null or sp.program is not null or sp.student_id is not null))
    or exists (select 1 from public.accommodation_manager_profiles mp where mp.user_id = u.id)
    or exists (select 1 from public.verification_documents d where d.user_id = u.id)
    or u.status in ('verified','rejected','suspended')
    or u.role = 'admin'
  );

-- During onboarding the user must be able to pick their role, because OAuth
-- defaulted it to 'student' without asking. Once registered_at is set the role
-- locks again, and 'admin' is never self-assignable.
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
      -- Choosing student vs manager is part of onboarding, and only then.
      if not (old.registered_at is null
              and new.role in ('student','accommodation_manager')
              and old.role <> 'admin') then
        raise exception 'You are not allowed to change your own role.';
      end if;
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
    -- Registration completes once; it cannot be un-set to re-open role changes.
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception 'Registration is already complete.';
    end if;
  end if;
  return new;
end $fn$;
