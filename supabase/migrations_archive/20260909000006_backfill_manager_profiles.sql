-- Manager registration never created an accommodation_manager_profiles row, so
-- managers had no profile record while every student had one. Nothing crashed —
-- all five read sites use maybeSingle() — but the manager side had nowhere to
-- hang responsiveness stats or admin review data.
--
-- The row is now created during registration (stores/auth.ts,
-- submitManagerVerificationDocuments, which every manager path goes through).
-- This backfills the 11 managers who predate that.
insert into public.accommodation_manager_profiles (user_id)
select u.id
from public.users u
where u.role = 'accommodation_manager'
  and not exists (
    select 1 from public.accommodation_manager_profiles mp where mp.user_id = u.id
  )
on conflict (user_id) do nothing;

-- Note: students missing a student_profiles row are deliberately NOT backfilled.
-- All of them are half-finished registrations (registered_at is null, no
-- documents, none OSAS-verified); onboarding creates the row properly with their
-- college, program and year. An empty row would only render blank academic
-- details on the QR and OSAS screens.
