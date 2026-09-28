-- A 6-digit PIN in front of money and tenancy actions, and in front of the app
-- itself after it has been backgrounded.
--
-- What this defends: someone else driving a session that is already signed in --
-- the flatmate with your unlocked phone, which is the realistic case in a
-- boarding house. It is also a weak second factor if a password leaks.
--
-- What it does NOT defend: the account holder themselves (they set it), and it
-- does not change who is ALLOWED to do anything -- RLS remains the authority.
-- The gating is in the client, so a technical attacker holding a session token
-- can still call PostgREST directly. Closing that means requiring an elevation
-- window inside the leases/payments policies, which carry the OSAS gate and the
-- one-lease-per-student index, and is deliberately left for later.
--
-- The hash and every check live here rather than in the app, so the PIN cannot
-- be read out of local storage or compared in JavaScript that anyone can edit.

-- Separate table, not columns on users: users carries lock_user_privileges and
-- several policies, and this must never be client-readable at all.
create table if not exists public.user_pins (
  user_id      uuid primary key references public.users(id) on delete cascade,
  pin_hash     text not null,
  attempts     int  not null default 0,
  locked_until timestamptz,
  updated_at   timestamptz not null default now()
);

alter table public.user_pins enable row level security;
-- No policies at all. Every read and write goes through the SECURITY DEFINER
-- functions below, so there is no path by which a client sees a hash.
revoke all on public.user_pins from anon, authenticated;

-- ── Is a PIN set? ───────────────────────────────────────────────────────────
create or replace function public.has_pin()
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from public.user_pins where user_id = auth.uid());
$$;

-- ── Set or change ───────────────────────────────────────────────────────────
-- Six digits exactly, enforced HERE and not merely in the pad: a million
-- combinations instead of ten thousand, and the rule cannot be edited away in
-- the client. Changing an existing PIN requires the current one, so a held
-- session cannot silently replace it and lock the owner out.
create or replace function public.set_pin(p_pin text, p_current text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'A PIN must be exactly 6 digits';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is not null then
    if p_current is null or v_hash <> extensions.crypt(p_current, v_hash) then
      raise exception 'That is not your current PIN';
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
end $$;

-- ── Turn it off ─────────────────────────────────────────────────────────────
create or replace function public.clear_pin(p_current text)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is null then return; end if;
  if v_hash <> extensions.crypt(p_current, v_hash) then
    raise exception 'That is not your current PIN';
  end if;
  delete from public.user_pins where user_id = v_me;
end $$;

-- ── Verify ──────────────────────────────────────────────────────────────────
-- Throttled. Six digits makes offline guessing impractical, but an online
-- attacker with the phone in hand can still try one after another, so five
-- wrong attempts buys a 15-minute lockout -- and tells the owner it happened,
-- which is often the real value of a second factor.
create or replace function public.verify_pin(p_pin text)
returns boolean language plpgsql security definer set search_path = public as $$
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

-- ── Forgotten PIN ───────────────────────────────────────────────────────────
-- Resetting without the current PIN is only safe behind a fresh proof of
-- identity. Verifying an e-mail OTP mints a brand-new session, so requiring a
-- recently-issued JWT is exactly that proof -- and it reuses the OTP plumbing
-- registration already has, with no new mail to send.
create or replace function public.reset_pin(p_new text)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_iat bigint;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if p_new !~ '^[0-9]{6}$' then raise exception 'A PIN must be exactly 6 digits'; end if;

  v_iat := nullif(auth.jwt() ->> 'iat', '')::bigint;
  if v_iat is null or v_iat < extract(epoch from now()) - 300 then
    raise exception 'Confirm the code sent to your e-mail first';
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_new, extensions.gen_salt('bf')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
end $$;

revoke all on function public.has_pin() from public;
revoke all on function public.set_pin(text, text) from public;
revoke all on function public.clear_pin(text) from public;
revoke all on function public.verify_pin(text) from public;
revoke all on function public.reset_pin(text) from public;
grant execute on function public.has_pin() to authenticated;
grant execute on function public.set_pin(text, text) to authenticated;
grant execute on function public.clear_pin(text) to authenticated;
grant execute on function public.verify_pin(text) to authenticated;
grant execute on function public.reset_pin(text) to authenticated;

-- Verification (all passed as a rolled-back block before this was applied):
--   1 set + verify; a wrong PIN returns false
--   2 only 6 digits accepted -- '1234', '1234567' and 'abcdef' are all refused
--   3 changing requires the current PIN
--   4 a correct entry resets the attempt counter
--   5 five failures lock for 15 minutes, write a 'security' notification, and
--     the correct PIN is refused while locked
--   6 reset_pin refuses a stale JWT and succeeds on a fresh one
--   7 clear_pin removes it
-- And user_pins reports 0 grants, 0 policies, RLS enabled.
