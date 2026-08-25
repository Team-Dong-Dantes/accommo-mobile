-- Unify OSAS support tickets into the `tickets` table.
--
-- The app previously wrote landlord/student OSAS support submissions to the
-- `complaints` table, but the admin ticketing system (with ticket_messages,
-- assignment and status workflow) is built around the `tickets` table, which
-- already has an admin RLS policy (tickets_admin_all -> is_admin()). Nothing
-- was feeding `tickets`, so admin never saw submissions. This migration makes
-- `tickets` able to hold BOTH student- and landlord-filed tickets, backfills
-- the existing `complaints` rows, and adds reporter RLS so filers can insert
-- and read their own tickets.

-- 1) Allow tickets without a lease (landlord-filed tickets have no student lease)
--    and add reporter linkage columns.
ALTER TABLE public.tickets ALTER COLUMN lease_id DROP NOT NULL;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS student_id uuid;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS landlord_id uuid;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS property_id uuid;

-- 2) Allow the shared status vocabulary used by the app (complaints-style) in
--    addition to the original ticket statuses, so backfilled and new rows
--    validate against the check constraint.
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_status_check;
ALTER TABLE public.tickets ADD CONSTRAINT tickets_status_check
  CHECK (status = ANY (ARRAY[
    'open'::text, 'in_progress'::text, 'resolved'::text, 'closed'::text,
    'pending'::text, 'assigned'::text, 'under_review'::text
  ]));

-- 3) Backfill existing complaints into tickets (idempotent: skip if id exists,
--    and only rows whose id is a valid uuid to avoid cast errors).
INSERT INTO public.tickets (
  id, student_id, landlord_id, property_id,
  subject, description, category, priority, status, reported_at
)
SELECT
  c.id::uuid,
  c.student_id,
  c.landlord_id,
  c.property_id,
  c.subject,
  c.description,
  c.category::text,
  c.priority::text,
  c.status::text,
  c.filed_at
FROM public.complaints c
WHERE c.id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND NOT EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = c.id::uuid);

-- 4) Normalize any pre-existing sample tickets into the app vocabulary so the
--    admin inbox renders them correctly.
UPDATE public.tickets SET status = 'pending' WHERE status IN ('open', 'in_progress');
UPDATE public.tickets SET status = 'resolved' WHERE status = 'closed';

-- 5) Reporter RLS: a filer (student via student_id, or landlord via landlord_id)
--    may insert and read their own tickets. Admin keeps full access via the
--    existing tickets_admin_all policy.
DROP POLICY IF EXISTS "tickets_reporter_insert" ON public.tickets;
CREATE POLICY "tickets_reporter_insert" ON public.tickets
  FOR INSERT TO authenticated
  WITH CHECK (
    student_id = auth.uid()
    OR landlord_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS "tickets_reporter_select" ON public.tickets;
CREATE POLICY "tickets_reporter_select" ON public.tickets
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR landlord_id = auth.uid()
    OR lease_id IN (SELECT l.id FROM public.leases l WHERE l.student_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS "tickets_reporter_update" ON public.tickets;
CREATE POLICY "tickets_reporter_update" ON public.tickets
  FOR UPDATE TO authenticated
  USING (
    student_id = auth.uid()
    OR landlord_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  )
  WITH CHECK (
    student_id = auth.uid()
    OR landlord_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );
