-- Register/login audit fixes.
--
-- Findings: login ignored users.status entirely (pending, rejected AND suspended
-- all received a session, verified live); the manager flow's post-registration
-- signOut() pretended to hold applicants at the door but login let them back in;
-- users.status was derived from e-mail confirmation, conflating "this mailbox
-- answered" with "OSAS reviewed my documents"; and the registration duplicate-ID
-- check could never return true.

-- users.status means "OSAS reviewed this account". It must never come from e-mail
-- confirmation. The old branch set status='verified' whenever email_confirmed_at
-- was present on the inserted auth row, which would mint an OSAS-verified account
-- that get_verification_queue() (filters on pending/reviewing) never shows to a
-- reviewer. Dormant today only because GoTrue confirms in a second UPDATE — too
-- fragile to rely on. New accounts always start pending.
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
      new.email_confirmed_at,
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
          email_verified_at = excluded.email_verified_at,
          updated_at = now();
    return new;

  elsif tg_op = 'UPDATE' then
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, phone),
        email_verified_at = coalesce(public.users.email_verified_at, new.email_confirmed_at),
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

-- The registration duplicate-ID warning never fired: SECURITY INVOKER meant RLS
-- limited the lookup to the caller's own student_profiles row, so it answered
-- "not taken" for every id and only the unique constraint caught duplicates, at
-- insert time. The boolean return leaks nothing beyond exists/not-exists.
create or replace function public.check_student_id_exists(p_student_id text)
returns boolean
language sql stable security definer set search_path = public
as $function$
  select exists (
    select 1 from public.student_profiles
    where student_id = p_student_id
  );
$function$;

revoke all on function public.check_student_id_exists(text) from public, anon;
grant execute on function public.check_student_id_exists(text) to authenticated;

-- Suspension has to bite below the app. The client now refuses to hold a session
-- for a suspended account, but Supabase Auth still issued the token, and RLS
-- knows nothing about users.status — so a direct REST call would sail past the
-- client check. Suspending now bans the auth user and drops their live sessions;
-- lifting the suspension un-bans. Extends the existing revocation trigger so
-- every path that suspends (web UI, SQL console, future callers) is covered.
-- 'infinity' is avoided: GoTrue cannot serialise it and returns an opaque 500.
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
begin
  if new.status in ('rejected','suspended') and old.status = 'verified' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = 'delisted'
      where accommodation_manager_id = new.id and status = 'accredited';
  end if;

  if new.status = 'suspended' and old.status is distinct from 'suspended' then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
  elsif old.status = 'suspended' and new.status is distinct from 'suspended' then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify after update of status on public.users
  for each row execute function public.tg_revoke_on_unverify();
