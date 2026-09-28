-- Backfill student_id/landlord_id for pre-existing tickets that were created
-- against the legacy lease-only schema (student_id/landlord_id were NULL).
-- Idempotent: only touches rows that still lack both owner ids.
update public.tickets t
set student_id = le.student_id,
    landlord_id = le.landlord_id
from public.leases le
where t.lease_id = le.id
  and t.student_id is null
  and t.landlord_id is null;
