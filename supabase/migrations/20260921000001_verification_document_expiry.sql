-- Expiry date for a user's own verification documents.
--
-- `accommodation_documents` has carried issued_at/expires_at from the start, so
-- a property permit could always say when it lapses. The documents a person
-- uploads against their own account had no such column, which meant a manager's
-- government ID and business permit showed a review status and nothing else --
-- OSAS could see a permit had been approved but not that it had since expired.
--
-- Nullable on purpose: student documents (school ID, assessment of fees) do not
-- expire and are never asked for a date, and every row written before this
-- migration has none.
alter table public.verification_documents
  add column if not exists expires_at date;

comment on column public.verification_documents.expires_at is
  'Expiry of the document itself, as entered by the uploader. Null for document types that do not expire (school_id, assessment_of_fees) and for rows predating the column.';
