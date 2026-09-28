-- Unverified landlords/landladies may sign in, but may not add inventory.
--
-- Until now a landlord/landlady held no session at all until OSAS verified
-- them, and that was the only thing standing between an unverified account
-- and a new listing: accommodations_insert_own and rooms_insert_own check
-- ownership and nothing else. The app now lets them in straight after
-- registering (to upload requirements, raise tickets, message), so the rule
-- "no properties or rooms before verification" has to live here.
--
-- RESTRICTIVE policies, so each is ANDed with the existing permissive
-- ownership policies instead of replacing them. Only INSERT is covered:
-- reading and editing what already exists are unaffected, and a verified
-- account that is later sent back ('reviewing') keeps its existing listings.

create or replace function public.is_verified_landlord(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = uid and u.role = 'landlord' and u.status = 'verified'
  );
$$;

revoke all on function public.is_verified_landlord(uuid) from public;
grant execute on function public.is_verified_landlord(uuid) to authenticated;

drop policy if exists accommodations_insert_verified on public.accommodations;
create policy accommodations_insert_verified on public.accommodations
  as restrictive
  for insert
  to authenticated
  with check (public.is_verified_landlord(auth.uid()) or public.is_admin(auth.uid()));

drop policy if exists rooms_insert_verified on public.rooms;
create policy rooms_insert_verified on public.rooms
  as restrictive
  for insert
  to authenticated
  with check (public.is_verified_landlord(auth.uid()) or public.is_admin(auth.uid()));

drop policy if exists accommodation_facilities_insert_verified on public.accommodation_facilities;
create policy accommodation_facilities_insert_verified on public.accommodation_facilities
  as restrictive
  for insert
  to authenticated
  with check (public.is_verified_landlord(auth.uid()) or public.is_admin(auth.uid()));
