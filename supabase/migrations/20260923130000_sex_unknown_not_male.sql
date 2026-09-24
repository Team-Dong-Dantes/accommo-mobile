-- handle_auth_user_sync used to store sex = 'M' whenever the sign-up carried no sex
-- (a Google connection before registration is finished, or an account made
-- outside the app). users.sex is how the apps title a landlord/landlady — M is
-- Landlord, F is Landlady, unknown is the neutral Landlord/Landlady — so the
-- default silently titled women Landlord. Unknown is now stored as null, and a
-- repeat insert no longer overwrites a sex already on file with nothing.
CREATE OR REPLACE FUNCTION public.handle_auth_user_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, phone),
        date_of_birth = coalesce(v_dob, public.users.date_of_birth),
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
