-- Consolidate complaints row-level security into a single robust policy.
-- The original policy (20260817000002) was created inside a guarded DO block that
-- referenced public.is_admin(auth.uid()::text). is_admin() was created outside
-- migrations (Dashboard) and is not reliably present, so the guarded block SKIPPED
-- policy creation. The policies that actually exist on the live database were later
-- added by hand via the Dashboard and some of them still depend on is_admin(), which
-- is fragile (it can be missing on a fresh deploy, and it diverges from the app's
-- own admin gate that checks users.role = 'admin').
--
-- This migration replaces all of that with ONE policy that derives OSAS admin access
-- directly from public.users.role = 'admin', keeping it consistent with the app
-- (MainLayout.vue / OSASComplaintsPage.vue gate on role === 'admin').
--
-- Idempotent and safe to re-run: we CREATE the new policy BEFORE dropping the old
-- ones, so at no point is the table left with zero policies (which, with RLS enabled,
-- would deny every operation). Errors are surfaced, not swallowed.

-- 1) Ensure the new consolidated policy exists (no-op if already present).
DROP POLICY IF EXISTS "Complaints access for involved parties" ON public.complaints;

CREATE POLICY "Complaints access for involved parties"
  ON public.complaints
  FOR ALL
  TO authenticated
  USING (
    student_id = auth.uid()
    OR landlord_id = auth.uid()
    OR osas_officer_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  )
  WITH CHECK (
    student_id = auth.uid()
    OR landlord_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );

-- 2) Remove the legacy per-operation policies (Dashboard-created / guarded attempt).
DROP POLICY IF EXISTS "complaints_select_admin" ON public.complaints;
DROP POLICY IF EXISTS "complaints_select_involved" ON public.complaints;
DROP POLICY IF EXISTS "complaints_insert_student" ON public.complaints;
DROP POLICY IF EXISTS "complaints_update_admin" ON public.complaints;
DROP POLICY IF EXISTS "complaints_update_involved" ON public.complaints;
DROP POLICY IF EXISTS "complaints_delete_involved" ON public.complaints;
DROP POLICY IF EXISTS "Complaints visible to parties" ON public.complaints;
-- Legacy Dashboard-created policies used quoted mixed-case names; drop those too.
DROP POLICY IF EXISTS "Complaints select admin" ON public.complaints;
DROP POLICY IF EXISTS "Complaints update admin" ON public.complaints;
