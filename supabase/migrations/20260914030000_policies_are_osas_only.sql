-- Undoes 20260914020000. Adding doc_type to `policies` was the wrong shape: it
-- put the Terms of Service and the Privacy Notice into a table an OSAS
-- administrator can edit, which means a school office could silently rewrite the
-- agreement users had already accepted — and, as the empty table proved, a
-- consent document backed by a row can simply be missing, leaving the register
-- screen's "I agree" checkbox agreeing to nothing.
--
-- Those two documents now ship inside the app (accommo-mobile/src/constants/
-- legal.ts), versioned in git and impossible to render empty. `policies` goes
-- back to being exactly what its composer was built for: OSAS policies,
-- guidelines and house rules.
--
-- Kept as a drop rather than deleting the earlier migration, which is already
-- recorded against the live database — a fresh checkout should follow the same
-- path rather than pretend the column never existed.

alter table public.policies drop column doc_type;

-- The register screen was the only signed-out reader of this table, and it now
-- reads the bundle instead. Guidelines become authenticated-only, consistent
-- with the anon tightening in 20260914000001 and 20260914000002.
revoke select on public.policies from anon;
