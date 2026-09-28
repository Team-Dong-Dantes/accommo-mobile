-- OSAS verification gate for the new student-apply workflow.
--
-- The RLS policy letting a student insert a pending application never
-- actually checked OSAS verification, despite older app code assuming RLS
-- was the real backstop. Close that gap.
--
-- (A room-capacity guard was also drafted here, but the live DB already had
-- an equivalent trigger — trg_enforce_room_capacity / enforce_room_capacity(),
-- undocumented in any tracked migration, and slightly more complete (it also
-- counts leave_requested as still occupying a bed). See
-- 20260905010100_drop_redundant_capacity_guard.sql for the cleanup of the
-- short-lived duplicate.)

alter policy leases_insert_student_application on public.leases
with check (
  (student_id = (select auth.uid()))
  and (status = 'pending'::lease_status)
  and exists (
    select 1 from rooms r join accommodations a on a.id = r.accommodation_id
    where r.id = leases.room_id and a.accommodation_manager_id = leases.accommodation_manager_id
  )
  and exists (
    select 1 from student_profiles sp
    where sp.user_id = leases.student_id and sp.osas_verified_at is not null
  )
);
