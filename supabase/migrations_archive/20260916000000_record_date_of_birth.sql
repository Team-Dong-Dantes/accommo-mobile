-- Record a date of birth against every account.
--
-- OSAS verifies an identity against a school ID or a government ID, and until
-- now the only thing on the account to check a document against was a name.
-- A birth date is on both kinds of document, so it is the field that makes the
-- comparison a check rather than a guess.
--
-- Nullable on purpose. There are 172 existing accounts with no birth date and
-- no way to invent one, and `public.users` is written by accommo-mobile's signup
-- trigger on every registration — a NOT NULL column would reject those writes
-- until every client shipped. The requirement lives in the registration form,
-- which is where a person can actually be asked; the column records what they
-- answered. Backfill first, then tighten, if it ever needs to be mandatory in
-- the database.

alter table public.users
  add column if not exists date_of_birth date;

comment on column public.users.date_of_birth is
  'Self-declared birth date, collected at registration. Nullable: accounts created before this column exists have none.';

-- A date of birth in the future is a typo or a probe, never a fact, and nobody
-- boarding at ISU Echague was born before 1900. The bounds are deliberately wide
-- — this rejects nonsense, it does not enforce a minimum age, which is a policy
-- question for OSAS rather than a constraint.
alter table public.users
  drop constraint if exists users_date_of_birth_plausible;
alter table public.users
  add constraint users_date_of_birth_plausible
  check (date_of_birth is null or (date_of_birth > date '1900-01-01' and date_of_birth <= current_date));

-- ── carry it through signup ────────────────────────────────────────────────
-- The account row is created by this trigger from auth metadata, so a birth date
-- typed into the registration form only survives if it is read here — the same
-- path `sex`, `full_name` and `avatar_color` already take. Recreated whole
-- because Postgres has no way to amend a function body in place; everything
-- other than the four date_of_birth lines is unchanged from
-- 20260915000001_lock_registration_columns.sql.
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_domain text;
  -- The twin of ALLOWED_EMAIL_DOMAINS in accommo-mobile/src/utils/config.ts.
  v_allowed text[] := array['gmail.com', 'isu.edu.ph'];
  v_dob date;
begin
  -- A malformed date must not take the whole signup down with it: the account is
  -- created without one and OSAS sees the field as missing.
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
      coalesce((new.raw_user_meta_data ->> 'sex')::text, 'M'),
      v_dob,
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
          -- Never blank a birth date already on file with an empty re-signup.
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
