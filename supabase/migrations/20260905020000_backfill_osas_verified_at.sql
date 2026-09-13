-- accommo-web's verification-approval flow stamps student_profiles.osas_verified_at
-- alongside users.status = 'verified' (see accommo-web/src/composables/useVerifications.ts),
-- but that stamping was clearly added after most existing accounts were already
-- approved: 94 students have users.status = 'verified' while only 1 has
-- osas_verified_at set. Since the new lease-application RLS policy
-- (leases_insert_student_application) gates on osas_verified_at, this gap
-- silently blocked every already-verified student from applying. Backfill the
-- historical gap rather than change the policy — osas_verified_at is the
-- correct, deliberate gate (it also gates QR-code eligibility elsewhere).
insert into public.student_profiles (user_id, osas_verified_at)
select u.id, now()
from public.users u
where u.role = 'student' and u.status = 'verified'
on conflict (user_id) do update
set osas_verified_at = coalesce(student_profiles.osas_verified_at, excluded.osas_verified_at);
