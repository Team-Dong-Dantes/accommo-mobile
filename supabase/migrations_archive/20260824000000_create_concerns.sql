-- Create the `concerns` table (missing from the live DB; no prior migration created it).
-- Self-contained + idempotent: CREATE TABLE IF NOT EXISTS, and the RLS policy is
-- guarded with DROP POLICY IF EXISTS so re-running is safe.
-- Run AFTER this, run apply_all_migrations.sql (or the access_*.sql migrations) so
-- the remaining grants/policies attach to the now-existing table.

CREATE TABLE IF NOT EXISTS public.concerns (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lease_id      uuid NOT NULL REFERENCES public.leases(id) ON DELETE CASCADE,
  category      text NOT NULL,                                  -- maintenance | noise | cleanliness | amenities | security | others
  description   text,
  status        text NOT NULL DEFAULT 'open',                  -- open | in_progress | resolved | rejected
  reported_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS concerns_lease_id_idx ON public.concerns (lease_id);

ALTER TABLE public.concerns ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.concerns TO authenticated;

DO $$
BEGIN
  DROP POLICY IF EXISTS "Concerns visible to tenant/admin" ON public.concerns;
  CREATE POLICY "Concerns visible to tenant/admin"
    ON public.concerns FOR ALL TO authenticated
    USING (
      lease_id IN (SELECT id FROM public.leases WHERE student_id = auth.uid())
      OR public.is_admin(auth.uid()::text)
    )
    WITH CHECK (
      lease_id IN (SELECT id FROM public.leases WHERE student_id = auth.uid())
      OR public.is_admin(auth.uid()::text)
    );
  RAISE NOTICE 'Applied policy "Concerns visible to tenant/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Concerns visible to tenant/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;
