-- Once OSAS accredits a listing its permits are what OSAS checked, so the
-- landlord/landlady may not swap them at will. A new version of a permit is
-- taken on an accredited (or delisted) listing only when
--   * the one on file expires within 30 days, has expired, or has no date —
--     so it can be renewed before sweep_expired_permits takes the listing down;
--   * or OSAS flagged that permit when it last sent something back, and no
--     newer version has been uploaded since.
-- Every other status (draft, pending, needs revision, rejected, expired,
-- suspended) is not "accredited", and stays open. Editing or deleting a permit
-- row in place is closed on an accredited listing outright: neither app does
-- it, and it would dodge the permit_update review a new version opens.
-- OSAS is exempt from all three.
create or replace function public.permit_replacement_open(p_acc uuid, p_doc text) returns boolean
language plpgsql stable security definer set search_path to 'public' as $$
declare
  v_status text;
  d record;
begin
  select status::text into v_status from public.accommodations where id = p_acc;
  if v_status is null or v_status not in ('accredited', 'delisted') then return true; end if;

  select expires_at, uploaded_at into d from public.accommodation_documents
   where accommodation_id = p_acc and doc_type = p_doc
   order by version desc limit 1;
  if not found or d.expires_at is null then return true; end if;
  if d.expires_at < (now() at time zone 'Asia/Manila')::date + 30 then return true; end if;

  return exists (
    select 1 from public.accreditation_rounds r
     where r.accommodation_id = p_acc and r.decision = 'returned'
       and p_doc = any(r.flagged_docs)
       and r.decided_at > d.uploaded_at::timestamptz
  );
end $$;
revoke all on function public.permit_replacement_open(uuid, text) from public, anon;
grant execute on function public.permit_replacement_open(uuid, text) to authenticated, service_role;

drop policy if exists accommodation_documents_insert_open on public.accommodation_documents;
create policy accommodation_documents_insert_open on public.accommodation_documents as restrictive for insert to authenticated
  with check (public.permit_replacement_open(accommodation_id, doc_type) or (select public.is_admin((select auth.uid()))));

drop policy if exists accommodation_documents_update_unaccredited on public.accommodation_documents;
create policy accommodation_documents_update_unaccredited on public.accommodation_documents as restrictive for update to authenticated
  using (
    not exists (select 1 from public.accommodations a
                 where a.id = accommodation_id and a.status in ('accredited', 'delisted'))
    or (select public.is_admin((select auth.uid())))
  );

drop policy if exists accommodation_documents_delete_unaccredited on public.accommodation_documents;
create policy accommodation_documents_delete_unaccredited on public.accommodation_documents as restrictive for delete to authenticated
  using (
    not exists (select 1 from public.accommodations a
                 where a.id = accommodation_id and a.status in ('accredited', 'delisted'))
    or (select public.is_admin((select auth.uid())))
  );
