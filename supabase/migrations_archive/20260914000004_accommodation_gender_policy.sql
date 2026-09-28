-- An accommodation said what kind of building it was but never who it accepts,
-- which is one of the first things a student filters on in their head.
--
-- Text plus a check rather than an enum: accommodation_type on this same table
-- is already varchar rendered through a label map, and a check constraint is
-- cheaper to extend later than ALTER TYPE.
--
-- Nullable with no backfill. The existing rows genuinely do not carry this
-- information, so they read as "not set" until a manager says otherwise --
-- guessing would put a claim about who may live somewhere into the listing.
-- New listings are required to pick one, enforced in the create form.

alter table public.accommodations
  add column if not exists gender_policy text;

alter table public.accommodations
  drop constraint if exists accommodations_gender_policy_check;

alter table public.accommodations
  add constraint accommodations_gender_policy_check
  check (gender_policy in ('male', 'female', 'co_ed'));
