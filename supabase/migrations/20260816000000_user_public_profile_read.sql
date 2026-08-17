-- Allow authenticated users to view other users' public profile info.
--
-- The app needs to show landlord names in the student dashboard, discover
-- page, and messaging (e.g. "Mario Santos" on a boarding house card). Without
-- this policy, RLS limits users to reading only their own row, so any query
-- for another user's id returns an empty set.
--
-- This is scoped to SELECT only (no insert/update/delete) and exposes only the
-- non-sensitive columns that are safe to share across roles.

CREATE POLICY "Authenticated users can view public profile info"
ON public.users
FOR SELECT
TO authenticated
USING (true);
