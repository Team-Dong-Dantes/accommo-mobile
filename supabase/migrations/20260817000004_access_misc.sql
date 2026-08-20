-- ============================================================================
-- Student module access — Part 4: reviews, announcements, history, docs, audit
-- Additive only. Idempotent.
-- Public-read policies (no is_admin) are applied directly. is_admin-dependent
-- policies are wrapped in guarded DO blocks so a signature mismatch skips ONLY
-- that policy (with a NOTICE) instead of rolling back the whole file.
-- ============================================================================

-- ANNOUNCEMENTS (public read) ------------------------------------------------
GRANT SELECT ON public.announcements TO anon, authenticated;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Announcements public read" ON public.announcements;
CREATE POLICY "Announcements public read"
  ON public.announcements FOR SELECT TO anon, authenticated USING (true);

-- POLICIES (app policy document, public read) --------------------------------
GRANT SELECT ON public.policies TO anon, authenticated;
ALTER TABLE public.policies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Policies public read" ON public.policies;
CREATE POLICY "Policies public read"
  ON public.policies FOR SELECT TO anon, authenticated USING (true);

-- BOARDING_HISTORY -----------------------------------------------------------
GRANT SELECT ON public.boarding_history TO authenticated;
ALTER TABLE public.boarding_history ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Boarding history visible to student/admin" ON public.boarding_history;
  CREATE POLICY "Boarding history visible to student/admin"
    ON public.boarding_history FOR SELECT TO authenticated
    USING (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Boarding history visible to student/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Boarding history visible to student/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PROPERTY_REVIEWS (public read; students author their own) ------------------
GRANT SELECT ON public.property_reviews TO anon, authenticated;
GRANT INSERT, UPDATE ON public.property_reviews TO authenticated;
ALTER TABLE public.property_reviews ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property reviews visible with property" ON public.property_reviews;
  CREATE POLICY "Property reviews visible with property"
    ON public.property_reviews FOR SELECT TO anon, authenticated
    USING (property_id IN (
      SELECT id FROM public.properties
      WHERE status = 'accredited' OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text)));
  RAISE NOTICE 'Applied policy "Property reviews visible with property".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property reviews visible with property" — is_admin() signature may differ. %', SQLERRM;
END $$;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property reviews authored by student" ON public.property_reviews;
  CREATE POLICY "Property reviews authored by student"
    ON public.property_reviews FOR INSERT TO authenticated
    WITH CHECK (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Property reviews authored by student".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property reviews authored by student" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- LANDLORD_REVIEWS (public read; students author their own) ------------------
GRANT SELECT ON public.landlord_reviews TO authenticated;
GRANT INSERT, UPDATE ON public.landlord_reviews TO authenticated;
ALTER TABLE public.landlord_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Landlord reviews public read" ON public.landlord_reviews;
CREATE POLICY "Landlord reviews public read"
  ON public.landlord_reviews FOR SELECT TO authenticated USING (true);
DO $$
BEGIN
  DROP POLICY IF EXISTS "Landlord reviews authored by student" ON public.landlord_reviews;
  CREATE POLICY "Landlord reviews authored by student"
    ON public.landlord_reviews FOR INSERT TO authenticated
    WITH CHECK (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Landlord reviews authored by student".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Landlord reviews authored by student" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- TENANT_REVIEWS (public read; students author their own) --------------------
GRANT SELECT ON public.tenant_reviews TO authenticated;
GRANT INSERT, UPDATE ON public.tenant_reviews TO authenticated;
ALTER TABLE public.tenant_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Tenant reviews public read" ON public.tenant_reviews;
CREATE POLICY "Tenant reviews public read"
  ON public.tenant_reviews FOR SELECT TO authenticated USING (true);
DO $$
BEGIN
  DROP POLICY IF EXISTS "Tenant reviews authored by student" ON public.tenant_reviews;
  CREATE POLICY "Tenant reviews authored by student"
    ON public.tenant_reviews FOR INSERT TO authenticated
    WITH CHECK (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Tenant reviews authored by student".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Tenant reviews authored by student" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- VERIFICATION_DOCUMENTS (owner / OSAS-admin) --------------------------------
GRANT SELECT, INSERT, UPDATE ON public.verification_documents TO authenticated;
ALTER TABLE public.verification_documents ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Verification documents visible to owner/admin" ON public.verification_documents;
  CREATE POLICY "Verification documents visible to owner/admin"
    ON public.verification_documents FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Verification documents visible to owner/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Verification documents visible to owner/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- AUDIT_LOGS (admin only) ----------------------------------------------------
GRANT SELECT ON public.audit_logs TO authenticated;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Audit logs admin only" ON public.audit_logs;
  CREATE POLICY "Audit logs admin only"
    ON public.audit_logs FOR SELECT TO authenticated
    USING (public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Audit logs admin only".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Audit logs admin only" — is_admin() signature may differ. %', SQLERRM;
END $$;
