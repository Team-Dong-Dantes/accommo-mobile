-- users_full runs as its owner so it can expose the columns hidden on
-- public.users, and it was auto-updatable with INSERT/UPDATE/DELETE granted to
-- `authenticated`. A write through it ran with the owner's rights, skipping the
-- RLS policies and column grants on users; only the guard triggers stood in the
-- way (a superadmin flip was refused by one). Nothing in either app writes
-- through the view, so it becomes read-only.
revoke insert, update, delete, truncate, references, trigger on public.users_full from authenticated, service_role;
