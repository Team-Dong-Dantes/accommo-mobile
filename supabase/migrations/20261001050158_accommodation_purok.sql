-- Purok, the sub-barangay division. Optional and typed by the landlord/landlady:
-- Mapbox has no purok level for these towns, so the map pick cannot fill it.
alter table public.accommodations
  add column if not exists purok text;
