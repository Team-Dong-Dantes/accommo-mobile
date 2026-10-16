-- The fire safety document is a certificate (the BFP's Fire Safety Inspection
-- Certificate), not a permit. Both apps now call it that; this brings the
-- landlord/landlady notices built from permit_label() in line.
create or replace function public.permit_label(p_type text) returns text
language sql immutable
set search_path = ''
as $$
  select case p_type
    when 'sanitary_permit' then 'sanitary permit'
    when 'fire_safety' then 'fire safety certificate'
    when 'business_permit' then 'business permit'
    when 'building_permit' then 'building permit'
    else replace(p_type, '_', ' ')
  end
$$;
