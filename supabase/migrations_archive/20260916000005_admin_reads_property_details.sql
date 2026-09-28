-- The accreditation review panel in accommo-web reads a property's house rules
-- and amenities, but both tables only ever let the owning manager or the public
-- read them, and a request under review is neither owned by the reviewer nor
-- accredited yet. OSAS saw "Not set" for every rule. `accommodations` itself,
-- its documents and its rooms already carry the matching admin policy.
create policy accommodation_policies_select_admin on accommodation_policies
  for select to authenticated using (is_admin(auth.uid()));

create policy accommodation_amenities_select_admin on accommodation_amenities
  for select to authenticated using (is_admin(auth.uid()));
