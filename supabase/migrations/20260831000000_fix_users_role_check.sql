-- Allow the 'landlord' role in addition to 'student'.
--
-- users.role is an enum type (user_role) that only contained 'student', which
-- made landlord registration fail with a 500 ("Database error saving new
-- user") because the auth -> public.users sync trigger inserts the role from
-- signup metadata and 'landlord' was not a valid enum value
-- (error: invalid input value for enum user_role: "landlord").
--
-- There is no admin role in this app (login/signup only offer student and
-- landlord), so it is intentionally excluded.
--
-- ALTER TYPE ... ADD VALUE IF NOT EXISTS requires Postgres 12+ (Supabase uses
-- 15+). Idempotent via IF NOT EXISTS.

ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'landlord';
