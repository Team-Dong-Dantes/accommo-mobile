-- Follow-up to 20260914000002: switching review_inbox and review_written_leases
-- to security_invoker broke them.
--
-- The views were SECURITY DEFINER for a reason I missed — they were the ONLY
-- read path into the three review tables. `authenticated` holds INSERT, UPDATE
-- and DELETE on accommodation_reviews, accommodation_manager_reviews and
-- tenant_reviews, but never SELECT; the definer view was what let a student see
-- their own review back. Under security_invoker the caller needs the table
-- grant themselves, so every read started failing with
--
--     42501: permission denied for table accommodation_reviews
--
-- which would have broken StudentHistoryPage, TenantProfile, ManagerDashboard
-- and ManagerHistoryPage.
--
-- The grant is the right fix rather than reverting: each table already has a
-- *_select_involved policy scoping rows to the student and the manager on the
-- lease, so RLS does the work it does everywhere else in this schema. The
-- definer view was standing in for a grant that should always have been there.

GRANT SELECT ON public.accommodation_reviews         TO authenticated;
GRANT SELECT ON public.accommodation_manager_reviews TO authenticated;
GRANT SELECT ON public.tenant_reviews                TO authenticated;

-- anon was carrying SELECT/REFERENCES/TRIGGER on both views. It returned []
-- while they were SECURITY DEFINER and would return a permission error now;
-- either way no signed-out screen reads a review. Take the grants back.
REVOKE ALL ON public.review_inbox          FROM anon;
REVOKE ALL ON public.review_written_leases FROM anon;
