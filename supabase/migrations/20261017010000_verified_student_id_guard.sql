-- A student ID belongs to an account once OSAS has verified it, not before.
--
-- student_profiles_student_id_key made the first account to type a number its
-- owner. Anyone could register with another student's ID (they are printed on
-- the school ID and run in sequence) and the real student could then never
-- sign up: the insert failed, and OSAS had no way to hand the number over.
--
-- Now unverified claims may share a number; a verified holder may not be
-- shared with. The partial index guarantees one verified holder even under a
-- race (OSAS verifying two claimants of one number at once); the trigger
-- refuses a new claim on a number a verified account already has, and gives
-- OSAS a readable reason when they try to verify the second claimant.

alter table public.student_profiles drop constraint student_profiles_student_id_key;

create unique index student_profiles_verified_student_id_key
  on public.student_profiles (student_id)
  where osas_verified_at is not null;

-- unique_violation, and "duplicate key" in the text: the apps already map both
-- (profile edits check the 23505 code, registration's sanitizeError the text).
create or replace function public.guard_verified_student_id() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.student_id is not null and exists (
    select 1 from public.student_profiles sp
     where sp.student_id = new.student_id
       and sp.osas_verified_at is not null
       and sp.user_id <> new.user_id
  ) then
    raise exception 'Student ID % already belongs to a verified account (duplicate key).', new.student_id
      using errcode = 'unique_violation';
  end if;
  return new;
end $$;

revoke all on function public.guard_verified_student_id() from public, anon, authenticated;

create trigger trg_guard_verified_student_id
  before insert or update of student_id, osas_verified_at on public.student_profiles
  for each row execute function public.guard_verified_student_id();

-- The registration pre-check. It was revoked from every client (20260914000000)
-- as "an existence oracle over student IDs, which are guessable", which left
-- the app's call failing silently and the clash surfacing only at submit.
-- It comes back narrower than it went:
--   * signed-in only — registration creates the account before this screen;
--   * it answers for verified holders only, the same thing the trigger above
--     already tells anyone who tries to save the number, so it adds no leak;
--   * a verified student gets false: they have nothing to register;
--   * 10 checks an hour per account, so it is no faster than typing.
create or replace function public.check_student_id_exists(p_student_id text) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or exists (
    select 1 from public.student_profiles where user_id = v_uid and osas_verified_at is not null
  ) then
    return false;
  end if;
  if not public.rate_limit_hit(v_uid::text || ':student_id_check', 10, 3600) then
    raise exception 'Too many student ID checks. Please wait an hour and try again.' using errcode = 'P0001';
  end if;
  return exists (
    select 1 from public.student_profiles
     where student_id = p_student_id
       and osas_verified_at is not null
       and user_id <> v_uid
  );
end $$;

revoke all on function public.check_student_id_exists(text) from public, anon;
grant execute on function public.check_student_id_exists(text) to authenticated;
