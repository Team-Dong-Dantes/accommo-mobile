-- Add a "who can stay" policy to boarding houses (Boys only / Girls only / Co-ed).
-- Captured by the Add Boarding House wizard and shown on the property detail page.
-- Applied safely even if run more than once.

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS gender_policy text;

ALTER TABLE public.properties
  DROP CONSTRAINT IF EXISTS properties_gender_policy_check;

ALTER TABLE public.properties
  ADD CONSTRAINT properties_gender_policy_check
  CHECK (gender_policy IS NULL OR gender_policy IN ('boys', 'girls', 'coed'));
