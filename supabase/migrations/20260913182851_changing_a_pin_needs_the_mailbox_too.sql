-- Changing an existing PIN now needs proof of the mailbox as well as the old PIN.
--
-- Knowing the current PIN was the only barrier, so anyone who watched it being
-- typed -- or guessed it inside the five allowed attempts -- could quietly
-- replace it and lock the owner out of their own money and tenancy actions. A
-- PIN is meant to survive exactly that kind of shoulder-surfing.
--
-- The proof is the same one reset_pin() already uses: a JWT minted in the last
-- five minutes, which is what verifying an e-mail code produces. No new mail
-- plumbing -- registration's sendEmailOtp/verifyEmailOtp already deliver it.
--
-- Setting the FIRST PIN is deliberately exempt: the account was just created or
-- the owner is already signed in and holds nothing to protect yet, and demanding
-- an e-mail round trip there would only push people to skip it.
--
-- NOTE on what this does and does not buy. With reset_pin() available, which
-- needs the mailbox and NOT the old PIN, the mailbox is now the root of trust
-- for PIN changes and the old PIN is a convenience check rather than a security
-- boundary -- anyone able to pass this check could have used reset_pin instead.
-- That is the ordinary shape of account recovery, but it should be described
-- honestly rather than presented as two independent factors.

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

  if v_hash is not null then
    -- Changing: the mailbox first, so a wrong-PIN answer never reveals whether
    -- the e-mail step would have passed.
    v_iat := nullif(auth.jwt() ->> 'iat', '')::bigint;
    if v_iat is null or v_iat < extract(epoch from now()) - 300 then
      raise exception 'Confirm the code sent to your e-mail first';
    end if;

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

revoke all on function public.set_pin(text, text) from public;
grant execute on function public.set_pin(text, text) to authenticated;

-- Verification (passed as a rolled-back block):
--   1 the first PIN needs no e-mail confirmation, even on a stale session
--   2 a change is refused without a fresh confirmation, and the old PIN still works
--   3 a fresh confirmation alone is not enough; a wrong current PIN still counts
--     against the lockout
--   4 current PIN + fresh confirmation changes it
