-- Shared facilities gain the two facts OSAS's accommodation record shows for
-- them: whether the facility is usable right now, and which rooms share it.
-- A shared facility still belongs to the whole accommodation (`room_id` null);
-- the link table only records which of its rooms the landlord/landlady says use it.
-- No backfill: existing facilities start with no rooms linked rather than
-- invented ones.

alter table public.accommodation_facilities
  add column if not exists status text not null default 'available'
    check (status in ('available', 'under_repair'));

create table if not exists public.accommodation_facility_rooms (
  facility_id uuid not null references public.accommodation_facilities (id) on delete cascade,
  room_id uuid not null references public.rooms (id) on delete cascade,
  primary key (facility_id, room_id)
);
create index if not exists idx_accommodation_facility_rooms_room_id
  on public.accommodation_facility_rooms (room_id);

-- Only a shared facility can be shared, and only with a room of its own
-- accommodation.
create or replace function public.guard_facility_room_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from accommodation_facilities f
    join rooms r on r.accommodation_id = f.accommodation_id
    where f.id = new.facility_id
      and r.id = new.room_id
      and f.access_scope = 'shared'
  ) then
    raise exception 'A room can only be linked to a shared facility of its own accommodation'
      using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_facility_room_link() from public, anon, authenticated;

drop trigger if exists accommodation_facility_rooms_guard on public.accommodation_facility_rooms;
create trigger accommodation_facility_rooms_guard
  before insert or update on public.accommodation_facility_rooms
  for each row execute function public.guard_facility_room_link();

alter table public.accommodation_facility_rooms enable row level security;

-- Readable exactly when the facility is: the subquery runs under the caller's
-- own RLS on accommodation_facilities, so this follows that table's policies.
create policy accommodation_facility_rooms_select on public.accommodation_facility_rooms
  for select to anon, authenticated
  using (exists (
    select 1 from public.accommodation_facilities f
    where f.id = accommodation_facility_rooms.facility_id));

-- Written only by the accommodation's landlord/landlady, like the facility itself.
create policy accommodation_facility_rooms_write_own on public.accommodation_facility_rooms
  for all to authenticated
  using (exists (
    select 1 from public.accommodation_facilities f
    join public.accommodations a on a.id = f.accommodation_id
    where f.id = accommodation_facility_rooms.facility_id
      and a.landlord_id = auth.uid()))
  with check (exists (
    select 1 from public.accommodation_facilities f
    join public.accommodations a on a.id = f.accommodation_id
    where f.id = accommodation_facility_rooms.facility_id
      and a.landlord_id = auth.uid()));

revoke truncate, references, trigger on public.accommodation_facility_rooms from anon, authenticated;
revoke insert, update, delete on public.accommodation_facility_rooms from anon;
grant select on public.accommodation_facility_rooms to anon, authenticated;
grant insert, update, delete on public.accommodation_facility_rooms to authenticated;
