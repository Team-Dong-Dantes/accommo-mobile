-- 20261006000000 recreated nine policies that narrow landlord/landlady writes
-- without "as restrictive", so they became permissive and stopped narrowing:
-- an unverified landlord/landlady could add accommodations, rooms and
-- facilities, and permits on an accredited listing could be replaced or
-- edited. Same conditions (OSAS by area), restrictive again. Caught by
-- rls_guards U1, AC8 and AC9.

drop policy accommodation_documents_delete_unaccredited on public.accommodation_documents;
create policy accommodation_documents_delete_unaccredited on public.accommodation_documents
  as restrictive for delete to authenticated
  using ((not exists (select 1 from public.accommodations a
                       where a.id = accommodation_documents.accommodation_id
                         and a.status = any (array['accredited'::accommodation_status, 'delisted'::accommodation_status])))
         or (select public.can_edit('accreditation')));

drop policy accommodation_documents_update_unaccredited on public.accommodation_documents;
create policy accommodation_documents_update_unaccredited on public.accommodation_documents
  as restrictive for update to authenticated
  using ((not exists (select 1 from public.accommodations a
                       where a.id = accommodation_documents.accommodation_id
                         and a.status = any (array['accredited'::accommodation_status, 'delisted'::accommodation_status])))
         or (select public.can_edit('accreditation')));

drop policy accommodation_documents_insert_open on public.accommodation_documents;
create policy accommodation_documents_insert_open on public.accommodation_documents
  as restrictive for insert to authenticated
  with check (public.permit_replacement_open(accommodation_id, doc_type) or (select public.can_edit('accreditation')));

drop policy accommodation_facilities_insert_accredited on public.accommodation_facilities;
create policy accommodation_facilities_insert_accredited on public.accommodation_facilities
  as restrictive for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.can_edit('accommodations')));

drop policy accommodation_facilities_insert_verified on public.accommodation_facilities;
create policy accommodation_facilities_insert_verified on public.accommodation_facilities
  as restrictive for insert to authenticated
  with check (public.is_verified_landlord(auth.uid()) or (select public.can_edit('accommodations')));

drop policy accommodation_floors_insert_accredited on public.accommodation_floors;
create policy accommodation_floors_insert_accredited on public.accommodation_floors
  as restrictive for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.can_edit('accommodations')));

drop policy accommodations_insert_verified on public.accommodations;
create policy accommodations_insert_verified on public.accommodations
  as restrictive for insert to authenticated
  with check (public.is_verified_landlord(auth.uid()) or (select public.can_edit('accommodations')));

drop policy rooms_insert_accredited on public.rooms;
create policy rooms_insert_accredited on public.rooms
  as restrictive for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.can_edit('accommodations')));

drop policy rooms_insert_verified on public.rooms;
create policy rooms_insert_verified on public.rooms
  as restrictive for insert to authenticated
  with check (public.is_verified_landlord(auth.uid()) or (select public.can_edit('accommodations')));
