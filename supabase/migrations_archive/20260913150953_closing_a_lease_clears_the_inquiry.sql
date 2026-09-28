-- Leaving resets the thread: the student must ask again.
--
-- conversations.inquiry_room_id was stamped once, when the student first tapped
-- "Ask about this room", and never cleared. So after a tenancy ended the thread
-- still claimed the student was asking about that room, and the manager's
-- "Send application form" button stayed live -- letting them re-issue a form to
-- a former tenant who never asked for one, possibly for a room that had since
-- been taken.
--
-- Done as a trigger rather than in the client because every way a tenancy can
-- close routes through this one status change: leave approved (TenantProfile
-- sets 'ended' with ended_reason 'leave_approved'), termination, and anything
-- added later.
--
-- Only closure clears it. A DECLINED application deliberately does not: the two
-- are still talking, and making the student walk back to the room page to retry
-- a different move-in date would be friction for no gain.

create or replace function public.tg_lease_closed_clears_inquiry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations c
     set inquiry_room_id = null,
         invited_room_id = null,
         invited_at = null
   where (c.user_a_id = NEW.student_id and c.user_b_id = NEW.accommodation_manager_id)
      or (c.user_b_id = NEW.student_id and c.user_a_id = NEW.accommodation_manager_id);
  return NEW;
end $$;

drop trigger if exists trg_lease_closed_clears_inquiry on public.leases;
create trigger trg_lease_closed_clears_inquiry
  after update of status on public.leases
  for each row
  when (NEW.status in ('ended', 'terminated') and OLD.status is distinct from NEW.status)
  execute function public.tg_lease_closed_clears_inquiry();

-- Verification (safe to paste into the SQL editor: the final RAISE rolls the
-- whole block back). Substitute a student/manager pair that share a conversation
-- and an available room belonging to that manager.
--
-- do $$
-- declare
--   cid uuid := '<conversation-id>'; sid uuid := '<student>'; mid uuid := '<manager>';
--   rid uuid := '<available-room>'; lid uuid; inq uuid; inv uuid;
-- begin
--   insert into leases (room_id, student_id, accommodation_manager_id, start_date, end_date, status)
--   values (rid, sid, mid, current_date, current_date + 365, 'active') returning id into lid;
--   update conversations set inquiry_room_id = rid, invited_room_id = rid, invited_at = now() where id = cid;
--   update leases set status = 'ended', ended_reason = 'leave_approved', end_date = current_date where id = lid;
--   select inquiry_room_id, invited_room_id into inq, inv from conversations where id = cid;
--   if inq is not null or inv is not null then raise exception 'FAIL: survived closing'; end if;
--   raise exception 'PASSED (rolling back)';
-- end $$;
