-- A PIN check cannot both count the attempt and raise about it.
--
-- 20260913180214_pin_lock throttled verify_pin() but not set_pin() or
-- clear_pin(), which also compare the current PIN -- so "Turn off PIN" was an
-- unthrottled brute-force surface that walked straight around the lockout.
--
-- Routing them through a shared pin_attempt() helper was not enough on its own:
-- both then raised 'That is not your current PIN', and a raise aborts the
-- transaction, discarding the very increment just made. PostgREST gives each
-- RPC its own transaction, so every wrong guess silently undid its own tally.
-- verify_pin() escaped it only because it RETURNS false rather than raising.
--
-- So the wrong-PIN answer is a return value, not an exception. Exceptions are
-- kept only for cases with no state to preserve: not signed in, a malformed
-- PIN, or an account already locked (that lock was committed by the attempt
-- that set it). Both functions change return type, hence the drops.

-- One place that compares, counts, locks and notifies.
create or replace function public.pin_attempt(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
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

-- Internal: the three below call it as the definer. Nothing gains by exposing a
-- bare "is this the PIN" endpoint to clients.
revoke all on function public.pin_attempt(text) from public, anon, authenticated;

create or replace function public.verify_pin(p_pin text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  return public.pin_attempt(p_pin);
end $$;

drop function if exists public.set_pin(text, text);
drop function if exists public.clear_pin(text);

create function public.set_pin(p_pin text, p_current text default null)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'A PIN must be exactly 6 digits';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is not null then
    -- false, not an exception: the increment inside pin_attempt has to commit.
    if p_current is null or not public.pin_attempt(p_current) then
      return false;
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
  return true;
end $$;

create function public.clear_pin(p_current text)
returns boolean
language plpgsql security definer set search_path = public as $$
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

revoke all on function public.verify_pin(text) from public;
revoke all on function public.set_pin(text, text) from public;
revoke all on function public.clear_pin(text) from public;
grant execute on function public.verify_pin(text) to authenticated;
grant execute on function public.set_pin(text, text) to authenticated;
grant execute on function public.clear_pin(text) to authenticated;

-- Verification (passed as a rolled-back block):
--   1 clear_pin counts a wrong guess, and the count survives
--   2 set_pin shares the same ledger; 5 mixed guesses lock the account
--   3 while locked, the correct PIN is refused on every path
--   4 the lockout wrote the owner a 'security' notification
