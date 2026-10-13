-- Fixes from the pre-audit security review.
--
-- 1. Account pre-hijacking. E-mail auto-confirm is on (registration keeps the
--    session while the applicant types the mailed code), so Supabase treats
--    every e-mail/password account as confirmed. Someone could register
--    victim@gmail.com with their own password; when the real owner later signs
--    in with Google, Supabase links that Google identity onto the same account
--    and the stranger's password still opens it. When a Google identity lands on
--    an account whose e-mail was never proven, the password is dropped and every
--    earlier session ended. The Google sign-in itself is unaffected: its session
--    is issued after the identity row is written. Someone who really did
--    register with a password and skipped the code resets it with "Forgot
--    password".
--
-- 2. confirm_email_ownership() took any OAuth sign-in as proof of the e-mail.
--    Now it needs a provider identity carrying the same address.
--
-- 3. tickets_reporter_select let any users.role = 'admin' read every ticket,
--    skipping is_admin()'s two-factor and expiry checks and the per-area
--    support access. tickets_admin_select already covers admins properly.
--
-- 4. The anon role held table grants it never uses (RLS blocked them) and could
--    run purge_rate_limit_hits(). Removed for defence in depth.

-- 1 ------------------------------------------------------------------------

create or replace function public.tg_google_identity_claims_account()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.provider = 'email'
     or not exists (select 1 from auth.identities i where i.user_id = new.user_id and i.provider = 'email')
     or not exists (select 1 from public.users u where u.id = new.user_id and u.email_verified_at is null) then
    return new;
  end if;

  update auth.users set encrypted_password = null where id = new.user_id;
  delete from auth.sessions where user_id = new.user_id;

  perform set_config('app.confirming_email', 'true', true);
  update public.users set email_verified_at = now(), updated_at = now()
  where id = new.user_id and email_verified_at is null;
  return new;
end $$;

revoke all on function public.tg_google_identity_claims_account() from public, anon, authenticated;

drop trigger if exists trg_google_identity_claims_account on auth.identities;
create trigger trg_google_identity_claims_account
  after insert on auth.identities
  for each row execute function public.tg_google_identity_claims_account();

-- 2 ------------------------------------------------------------------------

create or replace function public.confirm_email_ownership()
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  methods jsonb := coalesce(auth.jwt() -> 'amr', '[]'::jsonb);
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  if not (
    exists (
      select 1 from jsonb_array_elements(methods) m
      where m ->> 'method' in ('otp', 'magiclink', 'email')
    )
    or exists (
      select 1 from auth.identities i
      join public.users u on u.id = i.user_id
      where i.user_id = auth.uid()
        and i.provider <> 'email'
        and lower(i.identity_data ->> 'email') = lower(u.email)
    )
  ) then
    raise exception 'Verify your e-mail with the code first.';
  end if;

  perform set_config('app.confirming_email', 'true', true);
  update public.users set email_verified_at = now(), updated_at = now()
  where id = auth.uid() and email_verified_at is null;
  return true;
end $$;

-- 3 ------------------------------------------------------------------------

drop policy if exists tickets_reporter_select on public.tickets;
create policy tickets_reporter_select on public.tickets
  for select to authenticated
  using (
    student_id = auth.uid()
    or landlord_id = auth.uid()
    or lease_id in (select l.id from public.leases l where l.student_id = auth.uid())
  );

-- 4 ------------------------------------------------------------------------

revoke execute on function public.purge_rate_limit_hits() from public, anon;
revoke all on public.map_areas, public.payment_reminders, public.push_tokens,
  public.rate_limit_hits, public.utility_bills from anon;
