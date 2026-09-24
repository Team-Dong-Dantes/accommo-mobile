-- Presentation data for 20260923100000_facility_rooms_and_status: which rooms
-- share each shared facility, and a few facilities under repair.
-- Safe to re-run: links are inserted with `on conflict do nothing` and the
-- repair pick is deterministic.
--
-- Bathrooms are shared by the rooms on their own floor; every other shared
-- facility (kitchen, laundry, study area, ...) by the whole accommodation. A
-- bathroom on a floor with no rooms falls back to the whole accommodation too.

insert into public.accommodation_facility_rooms (facility_id, room_id)
select f.id, r.id
from public.accommodation_facilities f
join public.rooms r on r.accommodation_id = f.accommodation_id
where f.access_scope = 'shared'
  and (
    f.facility_type <> 'bathroom'
    or r.floor = f.floor
    or not exists (
      select 1 from public.rooms r2
      where r2.accommodation_id = f.accommodation_id and r2.floor = f.floor)
  )
on conflict do nothing;

-- Roughly one shared facility in eight is under repair.
update public.accommodation_facilities f
set status = case when s.n % 8 = 3 then 'under_repair' else 'available' end
from (
  select id, row_number() over (order by accommodation_id, sort_order, id) as n
  from public.accommodation_facilities
  where access_scope = 'shared'
) s
where f.id = s.id;
