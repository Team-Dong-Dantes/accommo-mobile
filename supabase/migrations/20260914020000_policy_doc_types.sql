-- `policies` was one bucket holding three different kinds of document: the
-- Terms of Service and the Privacy notice, which a user must accept before an
-- account exists, and OSAS guidelines and house rules, which are regulations
-- that simply apply. Without a column telling them apart, the register screen's
-- single "I agree" gated signup on all of them, and TermsGate re-prompted every
-- account whenever ANY row got a newer effective_date — so an OSAS quiet-hours
-- edit would have thrown a blocking re-consent wall at all 173 users.
--
-- Called doc_type rather than `kind`: accommo-web's ComposerDialog already uses
-- a `kind` prop for announcements-vs-policies, and a second meaning of that word
-- in the same file is a trap. It also matches accommodation_documents.doc_type.
--
-- 'guideline' is the default because it is the safe one: a row nobody classified
-- stays out of the consent path rather than silently becoming something users
-- are forced to accept.

alter table public.policies
  add column doc_type text not null default 'guideline'
    check (doc_type in ('tos', 'privacy', 'guideline'));
