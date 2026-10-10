-- Named areas OSAS draws on the web Map View to filter accommodations by, like
-- districts in a city builder. The outline is an open ring of [lng, lat] pairs;
-- jsonb keeps it simple, since containment is only ever tested in the browser
-- against tens of pins. OSAS-only: neither app's students or landlords see them.

create table public.map_areas (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  color text not null,
  ring jsonb not null check (jsonb_typeof(ring) = 'array' and jsonb_array_length(ring) >= 3),
  created_by uuid references public.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index idx_map_areas_created_by on public.map_areas (created_by);

alter table public.map_areas enable row level security;

create policy map_areas_select_admin on public.map_areas for select to authenticated
  using (public.get_my_role() = 'admin');
create policy map_areas_insert_admin on public.map_areas for insert to authenticated
  with check (public.get_my_role() = 'admin');
create policy map_areas_update_admin on public.map_areas for update to authenticated
  using (public.get_my_role() = 'admin') with check (public.get_my_role() = 'admin');
create policy map_areas_delete_admin on public.map_areas for delete to authenticated
  using (public.get_my_role() = 'admin');

create trigger trg_audit_map_areas after insert or delete or update on public.map_areas
  for each row execute function public.fn_audit_log_change();
