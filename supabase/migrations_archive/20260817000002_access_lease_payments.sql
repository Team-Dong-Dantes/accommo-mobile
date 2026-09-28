-- ============================================================================
-- Student module access — Part 2: leases, payments, concerns, complaints
-- Additive only. Idempotent.
-- Every policy below depends on is_admin(); each is wrapped in a guarded DO
-- block so a signature mismatch skips ONLY that policy (with a NOTICE) instead
-- of rolling back the whole file. Grants + RLS enable are applied directly.
-- ============================================================================

-- LEASES ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.leases TO authenticated;
ALTER TABLE public.leases ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Leases visible to tenant/landlord/admin" ON public.leases;
  CREATE POLICY "Leases visible to tenant/landlord/admin"
    ON public.leases FOR ALL TO authenticated
    USING (student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Leases visible to tenant/landlord/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Leases visible to tenant/landlord/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PAYMENTS -------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.payments TO authenticated;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Payments visible to lease parties" ON public.payments;
  CREATE POLICY "Payments visible to lease parties"
    ON public.payments FOR ALL TO authenticated
    USING (lease_id IN (
      SELECT id FROM public.leases
      WHERE student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text))
      OR public.is_admin(auth.uid()::text))
    WITH CHECK (lease_id IN (
      SELECT id FROM public.leases
      WHERE student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text))
      OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Payments visible to lease parties".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Payments visible to lease parties" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- CONCERNS -------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.concerns TO authenticated;
ALTER TABLE public.concerns ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Concerns visible to tenant/admin" ON public.concerns;
  CREATE POLICY "Concerns visible to tenant/admin"
    ON public.concerns FOR ALL TO authenticated
    USING (lease_id IN (SELECT id FROM public.leases WHERE student_id = auth.uid() OR public.is_admin(auth.uid()::text))
           OR public.is_admin(auth.uid()::text))
    WITH CHECK (lease_id IN (SELECT id FROM public.leases WHERE student_id = auth.uid())
           OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Concerns visible to tenant/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Concerns visible to tenant/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- COMPLAINTS -----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.complaints TO authenticated;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Complaints visible to parties" ON public.complaints;
  CREATE POLICY "Complaints visible to parties"
    ON public.complaints FOR ALL TO authenticated
    USING (student_id = auth.uid() OR landlord_id = auth.uid() OR osas_officer_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Complaints visible to parties".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Complaints visible to parties" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- COMPLAINT_TIMELINE ---------------------------------------------------------
GRANT SELECT, INSERT ON public.complaint_timeline TO authenticated;
ALTER TABLE public.complaint_timeline ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Complaint timeline visible to parties" ON public.complaint_timeline;
  CREATE POLICY "Complaint timeline visible to parties"
    ON public.complaint_timeline FOR SELECT TO authenticated
    USING (complaint_id IN (
      SELECT id FROM public.complaints
      WHERE student_id = auth.uid() OR landlord_id = auth.uid() OR osas_officer_id = auth.uid() OR public.is_admin(auth.uid()::text)));
  RAISE NOTICE 'Applied policy "Complaint timeline visible to parties".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Complaint timeline visible to parties" — is_admin() signature may differ. %', SQLERRM;
END $$;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Complaint timeline insert by actor" ON public.complaint_timeline;
  CREATE POLICY "Complaint timeline insert by actor"
    ON public.complaint_timeline FOR INSERT TO authenticated
    WITH CHECK (actor_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Complaint timeline insert by actor".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Complaint timeline insert by actor" — is_admin() signature may differ. %', SQLERRM;
END $$;
