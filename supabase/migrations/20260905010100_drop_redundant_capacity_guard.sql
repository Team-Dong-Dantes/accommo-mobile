-- trg_enforce_room_capacity / enforce_room_capacity() already existed live in
-- the DB (undocumented in any tracked migration) and does the same job as the
-- trigger briefly added in 20260905010000_lease_application_guards.sql, more
-- completely (it also counts leave_requested as still occupying a bed).
-- Drop the redundant duplicate rather than run two capacity guards.
drop trigger if exists trg_guard_room_capacity on public.leases;
drop function if exists public.guard_room_capacity();
