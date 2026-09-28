-- Three statuses a property needed and did not have.
--
--   expired         accreditation ran out and was not renewed
--   suspended       OSAS pulled an accredited property, temporarily
--   needs_revision  refused, but the manager may fix it and resubmit
--
-- Until now everything that was not `accredited` collapsed into one of the four
-- remaining values, and two server-side jobs had to borrow `reviewing` — which
-- in this system means a reviewer currently has the request open — to say
-- "this lapsed". That is why properties sat in the queue marked as being
-- reviewed by nobody. The writers are corrected in the next migration.
--
-- Nothing else may share this file: Postgres allows ALTER TYPE ... ADD VALUE
-- inside a transaction, but the new label cannot be USED in that same
-- transaction.

alter type public.accommodation_status add value if not exists 'expired';
alter type public.accommodation_status add value if not exists 'suspended';
alter type public.accommodation_status add value if not exists 'needs_revision';
