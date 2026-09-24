-- OSAS can help someone who is locked out, and can correct what they typed.
--
--   * admin_sign_in_methods() — whether an account has a password and/or a
--     linked Google account, so the console offers only what applies.
--   * admin_sign_out_everywhere() — ends every session, for a lost phone.
--   * admin_disconnect_google() — unlinks Google, refused unless a password
--     exists, or the person would have no way left to sign in.
--   * handle_auth_user_sync copies phone and date of birth from auth only when
--     auth's copy actually changed. It used to copy them on every auth.users
--     update — every sign-in is one — so a correction OSAS made on
--     public.users was quietly put back the next time the person signed in.
--
-- Changing the sign-in e-mail and setting a temporary password go through
-- auth's admin API instead, in the manage-user edge function.

begin;

create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_domain text;
  v_allowed text[] := array['gmail.com', 'isu.edu.ph'];
  v_dob date;
begin
  begin
    v_dob := nullif(new.raw_user_meta_data ->> 'date_of_birth', '')::date;
  exception when others then
    v_dob := null;
  end;

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
      date_of_birth, email_verified_at, created_at, updated_at, last_login_at
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
      nullif(new.raw_user_meta_data ->> 'sex', ''),
      v_dob,
      case when v_provider <> 'email' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = coalesce(excluded.sex, public.users.sex),
          date_of_birth = coalesce(excluded.date_of_birth, public.users.date_of_birth),
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = 'UPDATE' then
    perform set_config('app.syncing_auth', 'true', true);
    update public.users
    set email = new.email,
        -- Only when auth's own copy moved: the person changed it in the app.
        phone = case
          when new.phone is distinct from old.phone
            or (new.raw_user_meta_data ->> 'phone') is distinct from (old.raw_user_meta_data ->> 'phone')
          then coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, phone)
          else phone
        end,
        date_of_birth = case
          when (new.raw_user_meta_data ->> 'date_of_birth') is distinct from (old.raw_user_meta_data ->> 'date_of_birth')
          then coalesce(v_dob, public.users.date_of_birth)
          else public.users.date_of_birth
        end,
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

-- Shared guard: an admin acting on a student or landlord/landlady.
create or replace function public.assert_admin_over(p_user uuid)
returns void
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Only OSAS can do this.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.users where id = p_user and role in ('student', 'landlord') and not is_superadmin) then
    raise exception 'This only applies to student and landlord/landlady accounts.';
  end if;
end $fn$;

revoke all on function public.assert_admin_over(uuid) from public, anon;
grant execute on function public.assert_admin_over(uuid) to authenticated;

create or replace function public.admin_sign_in_methods(p_user uuid)
returns table (has_password boolean, has_google boolean, last_sign_in_at timestamptz)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $fn$
begin
  perform public.assert_admin_over(p_user);
  return query
    select coalesce(a.encrypted_password, '') <> '',
           exists (select 1 from auth.identities i where i.user_id = a.id and i.provider = 'google'),
           a.last_sign_in_at
      from auth.users a
     where a.id = p_user;
end $fn$;

create or replace function public.admin_sign_out_everywhere(p_user uuid)
returns integer
language plpgsql
security definer
set search_path to 'public', 'auth'
as $fn$
declare
  v_count integer;
begin
  perform public.assert_admin_over(p_user);
  delete from auth.sessions where user_id = p_user;
  get diagnostics v_count = row_count;
  delete from auth.refresh_tokens where user_id = p_user::text;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), 'account.sign_out_everywhere', 'users', p_user::text, jsonb_build_object('sessions', v_count), now());
  return v_count;
end $fn$;

create or replace function public.admin_disconnect_google(p_user uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth'
as $fn$
begin
  perform public.assert_admin_over(p_user);
  if not exists (select 1 from auth.identities where user_id = p_user and provider = 'google') then
    raise exception 'This account has no Google account connected.';
  end if;
  if (select coalesce(encrypted_password, '') = '' from auth.users where id = p_user) then
    raise exception 'Set a temporary password first — without Google they would have no way to sign in.';
  end if;

  delete from auth.identities where user_id = p_user and provider = 'google';
  update auth.users
     set raw_app_meta_data = jsonb_set(
           jsonb_set(coalesce(raw_app_meta_data, '{}'), '{provider}', '"email"'),
           '{providers}',
           coalesce((select jsonb_agg(p) from jsonb_array_elements_text(raw_app_meta_data -> 'providers') p where p <> 'google'), '["email"]')
         )
   where id = p_user;
  -- A Google session would otherwise keep working until it expired.
  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), 'account.disconnect_google', 'users', p_user::text, '{}'::jsonb, now());
end $fn$;

revoke all on function public.admin_sign_in_methods(uuid) from public, anon;
revoke all on function public.admin_sign_out_everywhere(uuid) from public, anon;
revoke all on function public.admin_disconnect_google(uuid) from public, anon;
grant execute on function public.admin_sign_in_methods(uuid) to authenticated;
grant execute on function public.admin_sign_out_everywhere(uuid) to authenticated;
grant execute on function public.admin_disconnect_google(uuid) to authenticated;

commit;
