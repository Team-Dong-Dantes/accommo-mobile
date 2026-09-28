-- Manager-issued application forms.
--
-- A student could previously apply for a room with no screening step at all:
-- StudentRoomPage deep-linked into the chat thread with ?room=<id>, ChatThread saw the
-- param and opened the apply form on mount, and the insert policy asked only that the
-- student be OSAS-verified. Zero messages were required, so a manager's first contact
-- with an applicant was the lease row itself.
--
-- The form now comes from the manager. The student's inquiry carries the room -- they
-- picked it in discovery, so there is nothing for the manager to choose -- the manager
-- taps once to issue the form, and only then can the student insert.
--
-- Idempotent and self-contained.

-- ── 1  Invite columns on the conversation ───────────────────────────────────
-- invited_room_id is a COPY of inquiry_room_id, not a pointer to it. conversations
-- carries one FOR ALL policy granting UPDATE to either participant
-- (20260817000003_access_messaging.sql), so a student can PATCH their own row. Were the
-- apply card to read inquiry_room_id live, a student could take a form for the ₱2,500
-- room, repoint the column at the ₱4,000 one and submit against that. Freezing the room
-- at invite time is what makes the gate real rather than decorative.
alter table public.conversations
  add column if not exists inquiry_room_id uuid references public.rooms(id) on delete set null,
  add column if not exists invited_room_id uuid references public.rooms(id) on delete set null,
  add column if not exists invited_at timestamptz;

-- ── 2  Why a manager declined ───────────────────────────────────────────────
-- Distinct from ended_reason, which means "why the tenancy ended" and is legitimately
-- set to 'leave_approved' when a leave request is granted. respondToApplication() has
-- always accepted a reason and written it to ended_reason, but no caller ever passed
-- one -- so there is nothing to backfill here.
alter table public.leases add column if not exists decision_reason text;

-- ── 3  Issuing the form ─────────────────────────────────────────────────────
-- SECURITY DEFINER because the check that matters -- "is the caller the manager side of
-- this conversation, and do they own the room the student asked about" -- spans
-- conversations, rooms and accommodations, and must not be expressible as a plain
-- client-side UPDATE (see the note above about who can write this table).
--
-- Takes no room argument: the room is whatever the student asked about.
create or replace function public.invite_application(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room uuid;
begin
  if v_me is null then
    raise exception 'Not signed in';
  end if;

  select c.inquiry_room_id into v_room
  from public.conversations c
  where c.id = p_conversation
    and (c.user_a_id = v_me or c.user_b_id = v_me);

  if not found then
    raise exception 'Conversation not found';
  end if;

  if (select u.role::text from public.users u where u.id = v_me) <> 'accommodation_manager' then
    raise exception 'Only the accommodation manager can send an application form';
  end if;

  if v_room is null then
    raise exception 'This student has not asked about a room yet';
  end if;

  if not exists (
    select 1
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
    where r.id = v_room
      and a.accommodation_manager_id = v_me
      and r.status = 'available'
  ) then
    raise exception 'That room is not yours, or is no longer available';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $$;

revoke all on function public.invite_application(uuid) from public;
grant execute on function public.invite_application(uuid) to authenticated;

-- ── 4  The insert policy now requires an issued form ────────────────────────
-- Without this clause the whole feature is UI theatre: a student could still POST
-- straight to PostgREST and insert a pending lease having never spoken to anyone. The
-- four existing clauses (self, pending-only, room belongs to that manager, OSAS
-- verified) are preserved verbatim from 20260905010000_lease_application_guards.sql.
alter policy leases_insert_student_application on public.leases
with check (
  (student_id = (select auth.uid()))
  and (status = 'pending'::lease_status)
  and exists (
    select 1 from rooms r join accommodations a on a.id = r.accommodation_id
    where r.id = leases.room_id and a.accommodation_manager_id = leases.accommodation_manager_id
  )
  and exists (
    select 1 from student_profiles sp
    where sp.user_id = leases.student_id and sp.osas_verified_at is not null
  )
  and exists (
    select 1 from conversations c
    where c.invited_room_id = leases.room_id
      and (
        (c.user_a_id = leases.student_id and c.user_b_id = leases.accommodation_manager_id)
        or (c.user_b_id = leases.student_id and c.user_a_id = leases.accommodation_manager_id)
      )
  )
);

-- Verification (safe to paste into the SQL editor: the final RAISE rolls the whole
-- block back, so it leaves no test rows behind). Substitute a conversation between an
-- OSAS-verified student and the manager who owns an available room.
--
-- do $$
-- declare
--   cid uuid := '<conversation-id>';
--   rid uuid := '<available-room-owned-by-that-manager>';
--   sid uuid; mid uuid; ok boolean;
-- begin
--   select case when u.role::text = 'student' then c.user_a_id else c.user_b_id end,
--          case when u.role::text = 'student' then c.user_b_id else c.user_a_id end
--     into sid, mid
--   from conversations c join users u on u.id = c.user_a_id where c.id = cid;
--
--   update conversations set inquiry_room_id = rid, invited_room_id = null, invited_at = null
--    where id = cid;
--
--   -- No form issued yet -> the policy must refuse the insert.
--   begin
--     insert into leases (room_id, student_id, accommodation_manager_id, start_date, end_date, status)
--     values (rid, sid, mid, current_date, current_date + 365, 'pending');
--     raise exception 'FAIL: inserted a pending lease with no invite';
--   exception when insufficient_privilege or check_violation then
--     null; -- expected
--   end;
--
--   -- Issue the form, then the same insert must succeed.
--   update conversations set invited_room_id = rid, invited_at = now() where id = cid;
--   insert into leases (room_id, student_id, accommodation_manager_id, start_date, end_date, status)
--   values (rid, sid, mid, current_date, current_date + 365, 'pending');
--
--   raise exception 'ALL CHECKS PASSED (rolling back test rows)';
-- end $$;
--
-- invite_application() itself is best checked from the app, since it reads auth.uid():
-- calling it as the student must raise 'Only the accommodation manager…', and calling it
-- with inquiry_room_id null must raise 'has not asked about a room yet'.
