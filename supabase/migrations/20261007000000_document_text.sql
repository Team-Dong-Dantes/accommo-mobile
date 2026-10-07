-- The text the phone read off a student's school ID and assessment of fees, so
-- the console can check it against the profile without reading the files again.
-- Shape: { "school_id": { "text": "...", "read_at": "..." }, "assessment_of_fees": {...} }
-- (utils/docReading.ts in both apps).
--
-- Written by the student, so it is a hint for OSAS, never a verdict: the
-- documents stay what gets approved. Deliberately not in lock_verified_identity,
-- because a verified student re-uploading a new term's assessment must still be
-- able to replace the old reading.
alter table public.student_profiles
  add column document_text jsonb
  constraint student_profiles_document_text_shape
    check (document_text is null or (jsonb_typeof(document_text) = 'object' and octet_length(document_text::text) <= 60000));

-- Column grants, per 20261005000000: a column added to student_profiles is
-- invisible to clients until granted.
grant select (document_text), insert (document_text), update (document_text)
  on public.student_profiles to authenticated;
