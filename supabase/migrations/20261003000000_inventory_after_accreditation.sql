-- Rooms, floors and shared facilities are added after OSAS accredits a listing,
-- not before: accreditation reviews the property and its permits, then the
-- landlord/landlady builds out what students can apply for. Until now only the
-- app's buttons followed that (and only for delisted listings); the database
-- took a room on a draft or a sent-back listing. Restrictive, so it narrows the
-- existing owner policies rather than replacing them. Editing and removing what
-- an older listing already has is untouched. OSAS is exempt.
create or replace function public.is_accredited_accommodation(p_id uuid) returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.accommodations where id = p_id and status = 'accredited');
$$;
revoke all on function public.is_accredited_accommodation(uuid) from public, anon;
grant execute on function public.is_accredited_accommodation(uuid) to authenticated, service_role;

drop policy if exists rooms_insert_accredited on public.rooms;
create policy rooms_insert_accredited on public.rooms as restrictive for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.is_admin((select auth.uid()))));

drop policy if exists accommodation_floors_insert_accredited on public.accommodation_floors;
create policy accommodation_floors_insert_accredited on public.accommodation_floors as restrictive for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.is_admin((select auth.uid()))));

drop policy if exists accommodation_facilities_insert_accredited on public.accommodation_facilities;
create policy accommodation_facilities_insert_accredited on public.accommodation_facilities as restrictive for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.is_admin((select auth.uid()))));
