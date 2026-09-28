-- Accommo accepts accounts on two e-mail domains: gmail.com and isu.edu.ph.
--
-- That rule existed only in the register screen's domain dropdown, which is a
-- suggestion, not an enforcement: a Google Workspace account on any other domain
-- could connect, and a direct API call could create an account on any address at
-- all. It belongs on auth.users, which every account in the system passes
-- through — both apps, both providers, the Supabase dashboard, and anything
-- talking to the API directly — rather than in a client that can be bypassed.
--
-- The check sits ONLY in the INSERT branch. The UPDATE branch runs on every
-- sign-in (last_sign_in_at), and there are existing accounts on seed domains
-- (example.com, accommo.test, test.com, accommo.dev) that must keep working;
-- guarding UPDATE would lock them out of an app they already have.
--
-- This is an AFTER trigger, so raising here aborts the transaction and the
-- auth.users row rolls back with it. A rejected signup leaves nothing behind.
--
-- CONSEQUENCE: seed data must use allowed domains from now on. Rows already in
-- the database are untouched, but a seed script that creates NEW auth users on
-- example.com and friends will fail against this.
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_domain text;
  -- The twin of ALLOWED_EMAIL_DOMAINS in accommo-mobile/src/utils/config.ts.
  -- Change both together.
  v_allowed text[] := array['gmail.com', 'isu.edu.ph'];
begin
  if tg_op = 'INSERT' then
    v_domain := lower(split_part(coalesce(new.email, ''), '@', 2));
    if v_domain <> all (v_allowed) then
      -- Distinct message and errcode so this is tellable from a real failure in
      -- the Postgres logs. The client never sees it: Supabase's auth server
      -- flattens any trigger failure into "Database error saving new user", so
      -- the register and login screens explain the domain rule themselves.
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

-- The binding itself has been live since before this migration set and appears
-- in none of it — the function was replaced three times without anyone recording
-- what attaches it. Recreating it here is a no-op against the current database
-- and means a rebuild from migrations alone produces a working signup.
drop trigger if exists sync_public_users_from_auth on auth.users;
create trigger sync_public_users_from_auth
  after insert or delete or update on auth.users
  for each row execute function public.handle_auth_user_sync();
