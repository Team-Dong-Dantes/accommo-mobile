-- An accommodation could be one of five kinds of building. It should be three:
-- a boarding house, a residence, or a dormitory. Apartment and condominium are
-- retired, and `residence_hall` is renamed to plain `residence` so the stored
-- code reads the same as the word on screen.
--
-- Text plus a check rather than an enum, for the reason the gender_policy
-- migration on this same table already gives: accommodation_type is varchar
-- rendered through a label map, and a check constraint is cheaper to extend
-- later than ALTER TYPE. The generated types stay `string | null`, so neither
-- app needs them regenerated.

-- The rewrite is by exclusion rather than by naming the old values. The three
-- known retired codes are apartment_building, condominium_unit and
-- residence_hall, but this column has been free text for its whole life and
-- accommo-web's own note says it "also holds condominium_unit, residence_hall
-- and a few others" — so anything that is not already one of the two codes we
-- keep becomes a residence, whatever it turns out to be. Nothing is left
-- behind for the constraint below to choke on.
update public.accommodations
   set accommodation_type = 'residence'
 where accommodation_type is not null
   and accommodation_type not in ('boarding_house', 'dormitory');

-- Null stays legal and needs no special case: a check only fails when it
-- evaluates to false, and null comparisons evaluate to null. The create form
-- saves `form.accommodationType || null`, so "not set" remains a real state for
-- a listing whose manager has not said yet.
alter table public.accommodations
  drop constraint if exists accommodations_accommodation_type_check;

alter table public.accommodations
  add constraint accommodations_accommodation_type_check
  check (accommodation_type in ('boarding_house', 'residence', 'dormitory'));

-- Post-migration check: should return only boarding_house / residence /
-- dormitory, plus null.
--
--   select accommodation_type, count(*)
--     from public.accommodations
--    group by 1
--    order by 1;
