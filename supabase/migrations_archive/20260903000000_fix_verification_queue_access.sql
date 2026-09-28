-- Keep the verification queue usable without the optional is_admin() helper.
-- Admin access is determined by the same public.users role used by the app.

DROP POLICY IF EXISTS "Verification documents visible to owner/admin" ON public.verification_documents;
GRANT SELECT, INSERT, UPDATE ON public.verification_documents TO authenticated;
ALTER TABLE public.verification_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Verification documents visible to owner/admin"
  ON public.verification_documents FOR ALL TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
