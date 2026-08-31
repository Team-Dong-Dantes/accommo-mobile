-- Allow the 'landlord' role in addition to 'student'.
--
-- The users.role CHECK constraint previously only accepted 'student', which
-- made landlord registration fail with a 500 ("Database error saving new
-- user") because the auth -> public.users sync trigger inserts the role from
-- signup metadata and 'landlord' violated the constraint.
--
-- There is no admin role in this app (login/signup only offer student and
-- landlord), so it is intentionally excluded.
--
-- This finds and drops any CHECK constraint on users whose definition mentions
-- 'role', then re-adds one allowing 'student' and 'landlord'. Idempotent.

DO $$
DECLARE
  cname text;
BEGIN
  SELECT conname INTO cname
  FROM pg_constraint
  WHERE conrelid = 'public.users'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) ILIKE '%role%';

  IF cname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.users DROP CONSTRAINT %I', cname);
  END IF;
END $$;

ALTER TABLE public.users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('student', 'landlord'));
