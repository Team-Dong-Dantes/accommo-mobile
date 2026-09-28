-- Follow-up to 20260914000000: the anon revoke in that migration did nothing.
--
-- It said REVOKE EXECUTE ... FROM anon, which removes only the grant held
-- *directly* by anon. PostgreSQL also grants EXECUTE on every new function to
-- the PUBLIC pseudo-role by default, and anon inherits that. So the ACL went
-- from {=X, anon=X, authenticated=X, ...} to {=X, authenticated=X, ...} and the
-- anonymous POST to notify_admins still returned 204.
--
-- The grant that has to go is the PUBLIC one. Revoking it takes EXECUTE away
-- from every role at once, so authenticated and service_role are granted back
-- explicitly -- exactly the access they had before this pair of migrations.
-- Signed-in users are unchanged; only anon loses the RPC surface.

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- The five predicates that RLS policies evaluate for anon as well. Without
-- these, an anonymous read of the public listings fails on rooms_select_admin,
-- which calls is_admin(). All of them key off auth.uid(), null for anon.
GRANT EXECUTE ON FUNCTION public.is_admin(uuid)          TO anon;
GRANT EXECUTE ON FUNCTION public.can_notify(uuid)        TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_role()           TO anon;
GRANT EXECUTE ON FUNCTION public.my_accommodation_ids()  TO anon;
GRANT EXECUTE ON FUNCTION public.current_is_superadmin() TO anon;

-- Re-assert after the blanket grants above, which would otherwise hand this
-- student-number existence oracle back to authenticated.
REVOKE EXECUTE ON FUNCTION public.check_student_id_exists(text) FROM PUBLIC, anon, authenticated;

-- New functions default to a PUBLIC grant too, so the next migration that adds
-- one would quietly reopen this. Change the default for anything created by the
-- postgres role in this schema from here on.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
