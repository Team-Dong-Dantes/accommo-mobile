-- A form must not be issued to a student who already holds a lease.
--
-- leases_one_current_per_student is a UNIQUE index on student_id over
-- ('pending','active','leave_requested'), so a second application fails at
-- INSERT with a raw 23505 -- which reached the student as a 409 Conflict only
-- after they had already been handed a form and filled it in. Refuse at the
-- point the form is issued instead, so the manager never hands out one that
-- cannot be used.
--
-- The client mirrors this check (ChatThread's loadApplicationState reads the
-- student's current lease across ALL managers, not just this thread's), but the
-- guard belongs here: it is the one place every caller routes through.

create or replace function public.invite_application(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room uuid;
  v_student uuid;
begin
  if v_me is null then
    raise exception 'Not signed in';
  end if;

  select c.inquiry_room_id,
         case when c.user_a_id = v_me then c.user_b_id else c.user_a_id end
    into v_room, v_student
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

  if exists (
    select 1 from public.leases l
    where l.student_id = v_student
      and l.status in ('pending', 'active', 'leave_requested')
  ) then
    raise exception 'This student already has a current application or stay';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $$;

revoke all on function public.invite_application(uuid) from public;
grant execute on function public.invite_application(uuid) to authenticated;
