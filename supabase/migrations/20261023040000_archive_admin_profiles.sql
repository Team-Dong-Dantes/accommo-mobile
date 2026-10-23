-- admin_profiles (office, position, employee number per admin) was never used:
-- no rows, and neither app reads or writes it. Archived rather than dropped.
-- Its audit trigger goes; past audit entries (none today) still render in the
-- web audit log, which keeps the label.

drop trigger if exists trg_audit_admin_profiles on public.admin_profiles;
alter table public.admin_profiles set schema archive;
revoke all on archive.admin_profiles from public, anon, authenticated;
