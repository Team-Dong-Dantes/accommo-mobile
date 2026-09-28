-- Amenities are the utilities and services that come with the whole place:
-- Wi-Fi, water, electricity, CCTV. The amenity list used to also carry
--   * kitchen, laundry and parking — spaces, which are shared facilities, and
--   * air-con — a feature of a room, which is a private facility.
-- Each moves to where it belongs, and the amenity list is closed to the rest.

-- Air-con is filed per room, as a private facility.
alter table public.accommodation_facilities drop constraint accommodation_facilities_type_check;
alter table public.accommodation_facilities add constraint accommodation_facilities_type_check
  check (facility_type = any (array['bathroom', 'kitchen', 'laundry', 'balcony', 'common_area',
    'study_area', 'parking', 'aircon', 'other']));

-- A kitchen/laundry/parking amenity becomes a shared facility on the lowest
-- floor, unless the accommodation already lists one of that type.
insert into public.accommodation_facilities (accommodation_id, facility_type, access_scope, floor, sort_order)
select a.accommodation_id,
       a.amenity::text,
       'shared',
       coalesce((select min(fl.floor_number) from public.accommodation_floors fl
                 where fl.accommodation_id = a.accommodation_id), 1),
       coalesce((select max(f.sort_order) + 1 from public.accommodation_facilities f
                 where f.accommodation_id = a.accommodation_id), 0)
         + row_number() over (partition by a.accommodation_id order by a.amenity::text) - 1
from public.accommodation_amenities a
where a.amenity::text in ('kitchen', 'laundry', 'parking')
  and not exists (
    select 1 from public.accommodation_facilities f
    where f.accommodation_id = a.accommodation_id
      and f.facility_type = a.amenity::text
      and f.access_scope = 'shared');

-- An air-con amenity never said which rooms have it, so every room of that
-- accommodation gets it; the landlord/landlady removes it where it is wrong.
insert into public.accommodation_facilities (accommodation_id, room_id, facility_type, access_scope, sort_order)
select r.accommodation_id, r.id, 'aircon', 'private',
       coalesce((select max(f.sort_order) + 1 from public.accommodation_facilities f
                 where f.accommodation_id = r.accommodation_id), 0)
         + row_number() over (partition by r.accommodation_id order by r.id) - 1
from public.rooms r
where exists (
    select 1 from public.accommodation_amenities a
    where a.accommodation_id = r.accommodation_id and a.amenity = 'aircon')
  and not exists (
    select 1 from public.accommodation_facilities f
    where f.room_id = r.id and f.facility_type = 'aircon');

delete from public.accommodation_amenities
where amenity::text not in ('wifi', 'water', 'electric', 'cctv');

-- The enum keeps its old labels (dropping enum values means rebuilding the
-- type); this constraint is what closes the list, older app builds included.
alter table public.accommodation_amenities add constraint accommodation_amenities_utilities_only
  check (amenity::text in ('wifi', 'water', 'electric', 'cctv'));
