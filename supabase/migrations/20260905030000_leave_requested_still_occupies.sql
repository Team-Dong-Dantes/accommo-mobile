-- recompute_room_occupancy (20260905000000_sync_room_occupancy.sql) only
-- counted status = 'active' as occupying a bed. The pre-existing
-- enforce_room_capacity() trigger (found live in the DB, undocumented in any
-- tracked migration) correctly treats 'leave_requested' as still occupying
-- one too — a tenant mid-notice-period hasn't actually moved out. Match that
-- definition so a room doesn't falsely show as available while someone with
-- a pending leave request is still living in it. No existing rows are
-- affected (zero leases currently in 'leave_requested'), but this must be
-- correct before the student-facing leave-request workflow ships.
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
  select count(*) into v_active_count from leases where room_id = p_room_id and status in ('active', 'leave_requested');
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
