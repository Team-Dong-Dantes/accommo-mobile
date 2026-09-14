-- Two leftovers from when changing a PIN and resetting a forgotten one were
-- separate flows.
--
-- reset_pin() became a one-line alias for set_pin() once both hung on the same
-- proof (a JWT minted in the last five minutes). Nothing calls it, and a second
-- public name for one rule is a second thing to audit.
--
-- set_pin's p_current stopped being read at the same time, but stayed in the
-- signature -- an argument the server silently ignores is worse than one that
-- is not there, because a caller can believe it is being checked.

drop function if exists public.reset_pin(text);
drop function if exists public.set_pin(text, text);

create function public.set_pin(p_pin text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text; v_iat bigint;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'A PIN must be exactly 6 digits';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;

  -- Replacing an existing PIN needs a session minted in the last five minutes,
  -- which is what confirming an e-mail code produces. The old PIN is NOT asked
  -- for: it is exactly what someone who has forgotten it cannot supply, and
  -- demanding it as well guarded nothing once the mailbox alone could reset.
  -- Setting the FIRST PIN is exempt -- the owner is already signed in and has
  -- nothing yet to protect, and a round trip there only makes people skip it.
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

revoke all on function public.set_pin(text) from public;
grant execute on function public.set_pin(text) to authenticated;

-- Verification (passed as a rolled-back block):
--   1 the first PIN, on a fresh session, is accepted
--   2 a change on a stale session raises 'Confirm the code sent to your e-mail first'
--   3 a fresh session changes it with no old PIN, and the new PIN verifies
--   4 clear_pin still refuses the old PIN and accepts the new one
--   5 reset_pin and the two-argument set_pin no longer exist
