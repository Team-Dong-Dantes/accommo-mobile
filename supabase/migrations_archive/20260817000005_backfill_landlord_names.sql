-- ============================================================================
-- Backfill landlord display names (DATA only — NULL-safe, idempotent)
-- Run in Supabase SQL Editor AFTER the access grants are applied.
-- Only fills missing values; never overwrites existing real names.
-- ============================================================================

-- 0) Make sure authenticated can read the name tables (idempotent).
GRANT SELECT ON public.users TO authenticated;
GRANT SELECT ON public.landlord_profiles TO authenticated;

-- 1) Ensure every user has a full_name (fallback to the email local-part).
UPDATE public.users
SET full_name = COALESCE(NULLIF(full_name, ''), split_part(email, '@', 1))
WHERE full_name IS NULL OR full_name = '';

-- 2) Backfill landlord_profiles.business_name from the owner's full_name.
UPDATE public.landlord_profiles lp
SET business_name = COALESCE(
  lp.business_name,
  (SELECT u.full_name FROM public.users u WHERE u.id = lp.user_id),
  'Property Owner'
)
WHERE lp.business_name IS NULL;

-- 3) Diagnostic: list properties that have NO linked landlord.
--    If any show up, the card will still say "Landlord" until you link them, e.g.:
--    UPDATE public.properties SET landlord_id = '<owner-user-id>'
--    WHERE landlord_id IS NULL;
-- SELECT id, name, landlord_id FROM public.properties WHERE landlord_id IS NULL;
