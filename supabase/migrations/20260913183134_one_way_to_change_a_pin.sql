-- Changing a PIN and resetting a forgotten one were the same act, so they are
-- now one function.
--
-- 20260913182851 had made a change need BOTH the old PIN and a fresh e-mail
-- confirmation, while reset_pin() needed only the confirmation. Anyone who
-- could pass the first could simply call the second, so the old PIN was never
-- a security boundary -- just a field that locked out the one person it was
-- meant to help: someone who has forgotten the PIN.
--
-- The mailbox is the root of trust. set_pin() now asks only for a session
-- minted in the last five minutes, which is what verifying an e-mail code
-- produces, and reset_pin() becomes an alias for it. Turning a PIN OFF still
-- takes the current PIN, against the same lockout ledger -- that one has a
-- real forgot path already (change it, then turn it off).

create or replace function public.set_pin(p_pin text, p_current text default null)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text; v_iat bigint;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'A PIN must be exactly 6 digits';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;

  -- Replacing an existing PIN needs a session minted in the last five minutes.
  -- Setting the FIRST PIN is exempt: the owner is already signed in and has
  -- nothing yet to protect, and an e-mail round trip there would only push
  -- people to skip it.
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

create or replace function public.reset_pin(p_new text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.set_pin(p_new);
end $$;

-- Verification (passed as a rolled-back block):
--   1 the first PIN still needs no e-mail confirmation
--   2 a change is still refused without a fresh confirmation
--   3 the confirmation alone changes it; the old PIN is no longer asked for
--   4 reset_pin shares the rule -- a stale session is refused
--   5 turning the PIN off still needs the current PIN, still throttled
