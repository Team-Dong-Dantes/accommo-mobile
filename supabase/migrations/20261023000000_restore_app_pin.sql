-- Bring the app PIN back (dropped in 20261007010000_drop_app_pin): the resume
-- lock, the PIN pad on actions, the optional PIN in registration and Settings,
-- and the e-mail reset. Recreated from the baseline definitions; PINs set before
-- the drop are gone, so everyone starts without one.

create table if not exists public.user_pins (
  user_id uuid not null primary key references public.users(id) on delete cascade,
  pin_hash text not null,
  attempts integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);
-- No policies on purpose: the functions below are the only way in.
alter table public.user_pins enable row level security;
revoke all on table public.user_pins from public, anon, authenticated;
grant all on table public.user_pins to service_role;

create or replace function public.pin_attempt(p_pin text) returns boolean
language plpgsql security definer set search_path to 'public' as $$
declare v_me uuid := auth.uid(); v_row public.user_pins; v_ok boolean;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  select * into v_row from public.user_pins where user_id = v_me;
  if v_row.user_id is null then
    raise exception 'No PIN is set on this account';
  end if;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    raise exception 'Too many attempts. Try again after %',
      to_char(v_row.locked_until at time zone 'Asia/Manila', 'HH12:MI AM');
  end if;

  v_ok := v_row.pin_hash = extensions.crypt(p_pin, v_row.pin_hash);

  if v_ok then
    update public.user_pins set attempts = 0, locked_until = null where user_id = v_me;
    return true;
  end if;

  update public.user_pins
     set attempts = attempts + 1,
         locked_until = case when attempts + 1 >= 5 then now() + interval '15 minutes' end
   where user_id = v_me
  returning * into v_row;

  if v_row.locked_until is not null then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (
      v_me, 'security', 'Incorrect PIN attempts',
      'Someone entered the wrong PIN 5 times on your account. If that was not you, change your password.',
      null
    );
  end if;

  return false;
end $$;

create or replace function public.verify_pin(p_pin text) returns boolean
language plpgsql security definer set search_path to 'public' as $$
begin
  return public.pin_attempt(p_pin);
end $$;

create or replace function public.has_pin() returns boolean
language sql security definer set search_path to 'public' as $$
  select exists (select 1 from public.user_pins where user_id = auth.uid());
$$;

create or replace function public.set_pin(p_pin text) returns boolean
language plpgsql security definer set search_path to 'public' as $$
declare v_me uuid := auth.uid(); v_hash text; v_iat bigint;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'A PIN must be exactly 6 digits';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;

  -- Replacing an existing PIN needs a session minted in the last five minutes,
  -- which is what confirming an e-mail code produces. The old PIN is NOT asked
  -- for: it is exactly what someone who has forgotten it cannot supply.
  -- Setting the FIRST PIN is exempt -- the owner is already signed in and has
  -- nothing yet to protect.
  if v_hash is not null then
    v_iat := nullif(auth.jwt() ->> 'iat', '')::bigint;
    if v_iat is null or v_iat < extract(epoch from now()) - 300 then
      raise exception 'Confirm the code sent to your e-mail first';
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
  return true;
end $$;

create or replace function public.clear_pin(p_current text) returns boolean
language plpgsql security definer set search_path to 'public' as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is null then return true; end if;
  if not public.pin_attempt(p_current) then
    return false;
  end if;
  delete from public.user_pins where user_id = v_me;
  return true;
end $$;

-- pin_attempt is internal: verify_pin and clear_pin reach it as its owner.
revoke all on function public.pin_attempt(text) from public, anon, authenticated;
revoke all on function public.verify_pin(text) from public, anon;
revoke all on function public.has_pin() from public, anon;
revoke all on function public.set_pin(text) from public, anon;
revoke all on function public.clear_pin(text) from public, anon;
grant execute on function public.verify_pin(text), public.has_pin(), public.set_pin(text),
                          public.clear_pin(text)
   to authenticated;
grant execute on function public.pin_attempt(text), public.verify_pin(text), public.has_pin(),
                          public.set_pin(text), public.clear_pin(text)
   to service_role;

-- admin_close_account wipes a closed account's PIN again. Edit the live
-- definition rather than restating it, so nothing else in the function drifts.
do $$
declare
  v_anchor text := E'  delete from public.notifications where user_id = p_user;\n';
  v_def text := pg_get_functiondef('public.admin_close_account(uuid, text)'::regprocedure);
begin
  if position(v_anchor in v_def) = 0 then
    raise exception 'admin_close_account no longer clears notifications where expected';
  end if;
  v_def := replace(v_def, v_anchor, v_anchor || E'  delete from public.user_pins where user_id = p_user;\n');
  execute v_def;
end $$;
