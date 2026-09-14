-- Accepting the Terms of Service and consenting to data processing were one
-- checkbox and one timestamp. Under the Data Privacy Act (RA 10173) consent to
-- processing should be its own affirmative act rather than something folded into
-- agreeing to a contract, and with a single column there was no way to show when
-- a user consented to processing as distinct from when they accepted the terms.
--
-- No backfill: every account has terms_accepted_at = null anyway, so both gates
-- already treat everyone as never having consented, which is accurate.

alter table public.users add column privacy_accepted_at timestamptz;

-- NOT optional. public.users has no table-level grant for `authenticated` —
-- only column-level ones (see 20260914000000). A new column without its own
-- grant is invisible to the app and every write to it fails with
-- "permission denied for column privacy_accepted_at".
-- No anon grant: anon holds only id and full_name on this table.
grant select, insert, update (privacy_accepted_at) on public.users to authenticated;
