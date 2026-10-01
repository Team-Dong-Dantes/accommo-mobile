-- Parking moves from the facilities to the amenities.
--
-- A facility is a space set on a floor, with photos and the rooms that share
-- it (a kitchen on the 2nd floor). Parking is none of that — it belongs to the
-- whole property, like CCTV or a generator — so it becomes an amenity chip.
--
-- Every existing parking facility becomes a 'parking' amenity on its
-- accommodation and is then deleted. None had photos; the labels/descriptions
-- were seed text. 'parking' stays allowed as a facility type for APKs released
-- before this one, which still offer it; current clients no longer do.

alter table public.accommodation_amenities
  drop constraint if exists accommodation_amenities_utilities_only;
alter table public.accommodation_amenities
  add constraint accommodation_amenities_utilities_only check (
    amenity::text = any (array[
      'wifi', 'cctv', 'water_dispenser', 'generator', 'fire_extinguisher', 'parking',
      'water', 'electric' -- legacy, see 20261001053825_amenities_and_utilities
    ])
  );

insert into public.accommodation_amenities (accommodation_id, amenity)
select distinct f.accommodation_id, 'parking'::public.amenity
  from public.accommodation_facilities f
 where f.facility_type = 'parking'
on conflict do nothing;

delete from public.accommodation_facilities where facility_type = 'parking';
