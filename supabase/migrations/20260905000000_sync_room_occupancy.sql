-- Keep rooms.status/current_pax in sync with active leases.
-- No existing app code writes to rooms.status/current_pax (verified against
-- both accommo-web and accommo-mobile), so this trigger can own both columns
-- outright. 'maintenance' is left alone as a manually-set state.

create or replace function public.recompute_room_occupancy(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_count integer;
  v_capacity integer;
  v_status room_status;
begin
  select count(*) into v_active_count from leases where room_id = p_room_id and status = 'active';
  select capacity, status into v_capacity, v_status from rooms where id = p_room_id;
  if v_capacity is null then
    return;
  end if;

  update rooms
  set current_pax = v_active_count,
      status = case
        when v_active_count >= v_capacity then 'occupied'::room_status
        when v_status = 'maintenance' then 'maintenance'::room_status
        else 'available'::room_status
      end
  where id = p_room_id;
end;
$$;

create or replace function public.sync_room_occupancy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recompute_room_occupancy(new.room_id);
  if tg_op = 'UPDATE' and old.room_id is distinct from new.room_id then
    perform public.recompute_room_occupancy(old.room_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_room_occupancy on public.leases;
create trigger trg_sync_room_occupancy
after insert or update of status, room_id on public.leases
for each row
execute function public.sync_room_occupancy();

-- One-time backfill for rows already out of sync.
select public.recompute_room_occupancy(id) from public.rooms;
