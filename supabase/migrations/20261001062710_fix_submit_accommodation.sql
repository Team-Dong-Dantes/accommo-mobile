-- submit_accommodation() raised "malformed array literal" instead of listing
-- what a draft is missing: `text[] || 'a string'` parses the string as an array
-- literal. array_append() says what was meant. Otherwise unchanged.
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
  if a.water_billing is null or a.electric_billing is null or a.wifi_billing is null then missing := array_append(missing, 'utilities'); end if;

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

  -- Same notice trg_new_accommodation sends for a listing created as pending.
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

