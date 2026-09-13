-- Fix: a Google sign-in landed with email_verified_at = null, so the e-mail gate
-- added in 20260909000003 bounced it to a "type the code we mailed you" screen —
-- for an address Google had already verified, and for which no code would ever
-- arrive. Combined with a guard that redirected unconditionally, that produced an
-- infinite redirect (VUE_ROUTER_R0009) and a black screen on boot.
--
-- OAuth is proof of ownership by definition: the provider authenticated the
-- account holder against that address. Stamp it in the sync trigger rather than
-- relying on the client to call confirm_email_ownership() during profile
-- completion, because a RETURNING OAuth user never runs that path at all.
--
-- E-mail+password sign-ups still land unstamped and must type the code.
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
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

-- Unstick any OAuth account already created without a stamp.
update public.users u
set email_verified_at = coalesce(u.email_verified_at, a.email_confirmed_at, u.created_at, now())
from auth.users a
where a.id = u.id
  and u.email_verified_at is null
  and coalesce(a.raw_app_meta_data ->> 'provider', 'email') <> 'email';
