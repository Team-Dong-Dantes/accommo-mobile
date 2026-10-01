-- Utilities move from the accommodation to the room.
--
-- One house rarely bills every room the same way: the air-con rooms are on
-- their own meter while the fan rooms have power in the rent, one floor gets
-- Wi-Fi and another does not. A setting on the accommodation could not say
-- that, so each room now carries its own terms, and a tenant's flat fees and
-- posted bills follow the room they actually rent.
--
-- Rooms inherit what their accommodation had, then the accommodation columns
-- go. They were added today and no released APK reads them.

alter table public.rooms
  add column if not exists water_billing public.utility_billing,
  add column if not exists water_flat_fee numeric,
  add column if not exists electric_billing public.utility_billing,
  add column if not exists electric_flat_fee numeric,
  add column if not exists wifi_billing public.utility_billing,
  add column if not exists wifi_flat_fee numeric;

update public.rooms r set
  water_billing = a.water_billing, water_flat_fee = a.water_flat_fee,
  electric_billing = a.electric_billing, electric_flat_fee = a.electric_flat_fee,
  wifi_billing = a.wifi_billing, wifi_flat_fee = a.wifi_flat_fee
from public.accommodations a
where a.id = r.accommodation_id;

-- A flat fee carries its amount; every other mode carries none. Null billing
-- is "not specified yet" — rooms made before utilities existed.
alter table public.rooms
  add constraint rooms_water_flat_fee check (
    case when water_billing = 'flat_fee' then coalesce(water_flat_fee, 0) > 0 else water_flat_fee is null end),
  add constraint rooms_electric_flat_fee check (
    case when electric_billing = 'flat_fee' then coalesce(electric_flat_fee, 0) > 0 else electric_flat_fee is null end),
  add constraint rooms_wifi_flat_fee check (
    case when wifi_billing = 'flat_fee' then coalesce(wifi_flat_fee, 0) > 0 else wifi_flat_fee is null end);

alter table public.accommodations
  drop constraint if exists accommodations_water_flat_fee,
  drop constraint if exists accommodations_electric_flat_fee,
  drop constraint if exists accommodations_wifi_flat_fee,
  drop column if exists water_billing,
  drop column if exists water_flat_fee,
  drop column if exists electric_billing,
  drop column if exists electric_flat_fee,
  drop column if exists wifi_billing,
  drop column if exists wifi_flat_fee;

-- Submitting now asks that every room says how its utilities are paid.
create or replace function public.submit_accommodation(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  p public.accommodation_policies;
  missing text[] := '{}';
  doc text;
begin
  select * into a from public.accommodations where id = p_id;
  if a.id is null or a.landlord_id is distinct from auth.uid() then
    raise exception 'Accommodation not found.';
  end if;
  if a.status::text <> 'draft' then
    raise exception 'This accommodation has already been submitted.';
  end if;

  if a.accommodation_type is null or a.gender_policy is null then missing := array_append(missing, 'type and who it accepts'); end if;
  if a.lat is null or a.lng is null or a.barangay is null or a.city is null then missing := array_append(missing, 'location'); end if;
  if exists (
    select 1 from public.rooms r
     where r.accommodation_id = p_id
       and (r.water_billing is null or r.electric_billing is null or r.wifi_billing is null)
  ) then
    missing := array_append(missing, 'utilities on every room');
  end if;

  select * into p from public.accommodation_policies where accommodation_id = p_id;
  if p.curfew_time is null or p.quiet_hours is null or p.visitor_policy is null then missing := array_append(missing, 'house rules'); end if;

  if not exists (select 1 from public.accommodation_images where accommodation_id = p_id) then
    missing := array_append(missing, 'an exterior photo');
  end if;
  foreach doc in array array['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] loop
    if not exists (select 1 from public.accommodation_documents where accommodation_id = p_id and doc_type = doc) then
      missing := array_append(missing, 'all four permits');
      exit;
    end if;
  end loop;

  if array_length(missing, 1) > 0 then
    raise exception 'Still missing: %.', array_to_string(missing, ', ');
  end if;

  perform set_config('app.submit_review', 'true', true);
  update public.accommodations set status = 'pending' where id = p_id;
  perform set_config('app.submit_review', 'false', true);

  perform public.notify_admins(
    'New accommodation for accreditation',
    coalesce(a.name, 'An accommodation') || ' was submitted for accreditation.',
    'accommodation',
    '/verifications?focus=verification:' || p_id::text
  );
end;
$$;
revoke all on function public.submit_accommodation(uuid) from public, anon;
grant execute on function public.submit_accommodation(uuid) to authenticated, service_role;
