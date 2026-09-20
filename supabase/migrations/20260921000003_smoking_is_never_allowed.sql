-- Smoking is never allowed in an accredited accommodation, so it is not a
-- policy a manager gets to set.
--
-- `accommodation_policies.smoking` presented it as a choice: the manager's
-- listing form had a "Smoking allowed" toggle, and the student listing, My Stay
-- and the OSAS verification review all rendered it as Yes/No alongside cooking,
-- laundry and pets. A rule that has one answer does not belong in a column
-- beside the ones that genuinely vary.
--
-- Dropped rather than left unused. Every reader and writer is gone in the same
-- change (accommo-mobile: NewAccommodation.vue, StudentListingPage.vue,
-- StudentStayPage.vue; accommo-web: api/accommodations.ts,
-- VerificationReview.vue), and a column nothing reads or writes is a schema
-- that lies about what the app does.
alter table public.accommodation_policies
  drop column if exists smoking;
