-- Put back the revoke that 20260916000006 undid.
--
-- 20260909000000 deliberately took get_verification_queue() away from everyone
-- and handed it to `authenticated` alone: it is the OSAS review queue, listing
-- every pending applicant's name, e-mail and document ids. 20260916000006 had to
-- drop and recreate the function to add an avatar column, and recreating it
-- restored PostgreSQL's default PUBLIC grant -- then granted `anon` on top, so
-- the ACL ended up reading {=X, anon=X, authenticated=X, ...}.
--
-- Nothing leaked: the function body is `where public.is_admin(auth.uid())`, which
-- is false for anon and for every signed-in non-admin, so the call returns zero
-- rows. This is about the surface, not a breach -- an unauthenticated POST should
-- not reach the verification queue at all, and the next change to the body is
-- one `where` clause away from that mattering.
--
-- 20260914000001 tried to stop exactly this with ALTER DEFAULT PRIVILEGES, and
-- it did not hold across this recreate. Re-assert explicitly rather than trust
-- it: a function is granted by whoever creates it, and the default only follows
-- the role that set it.

revoke execute on function public.get_verification_queue() from public, anon;
grant  execute on function public.get_verification_queue() to authenticated, service_role;
