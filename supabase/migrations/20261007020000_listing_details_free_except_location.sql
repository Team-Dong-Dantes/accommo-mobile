-- A landlord/landlady edits an accommodation's name, type and who it accepts
-- directly, at any status. Only the location (the map pin and the address it
-- fills) still goes through OSAS once a listing has left draft; permits keep
-- their own rule (permit_replacement_open).
--
-- Both functions are edited from their live definitions so nothing else in them
-- can drift.
do $$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.lock_verification_columns()'::regprocedure);
  v_def := replace(v_def,
    '(new.name, new.accommodation_type, new.gender_policy, new.lat, new.lng, new.purok, new.barangay, new.city)',
    '(new.lat, new.lng, new.purok, new.barangay, new.city)');
  v_def := replace(v_def,
    '(old.name, old.accommodation_type, old.gender_policy, old.lat, old.lng, old.purok, old.barangay, old.city)',
    '(old.lat, old.lng, old.purok, old.barangay, old.city)');
  v_def := replace(v_def,
    'OSAS checked this when it reviewed the listing. Ask OSAS for the change instead.',
    'OSAS checked the location when it reviewed the listing. Ask OSAS for the change instead.');
  if position('new.gender_policy' in v_def) > 0 then
    raise exception 'lock_verification_columns still locks name/type/gender policy';
  end if;
  execute v_def;

  v_def := pg_get_functiondef('public.request_details_change(uuid, jsonb, text)'::regprocedure);
  v_def := replace(v_def,
    'if k not in (''name'', ''accommodation_type'', ''gender_policy'', ''lat'', ''lng'', ''purok'', ''barangay'', ''city'') then',
    'if k not in (''lat'', ''lng'', ''purok'', ''barangay'', ''city'') then');
  if position('''gender_policy'', ''lat''' in v_def) > 0 then
    raise exception 'request_details_change still accepts name/type/gender policy';
  end if;
  execute v_def;
end $$;
