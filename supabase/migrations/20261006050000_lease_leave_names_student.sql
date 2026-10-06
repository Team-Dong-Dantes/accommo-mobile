-- The admins' "Lease leave request" notice named nobody: "A student requested to
-- leave their lease early", linked to the room. It now says who, which room and
-- where, and opens the student's record.

create or replace function public.trg_lease_leave()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.status = 'leave_requested'
     and old.status is distinct from 'leave_requested' then
    perform public.notify_admins(
      'Lease leave request',
      coalesce((select full_name from public.users where id = new.student_id), 'A student')
        || ' asked to leave ' || public.room_display(new.room_id)
        || coalesce(' at ' || (select a.name from public.rooms r join public.accommodations a on a.id = r.accommodation_id
                               where r.id = new.room_id), '')
        || ' early.',
      'lease',
      '/users?user=' || new.student_id::text
    );
  end if;
  return new;
end;
$$;

-- Earlier notices: the lease is the one moved to leave_requested at that moment.
update public.notifications n
   set body = u.full_name || ' asked to leave ' || public.room_display(l.room_id)
                || coalesce(' at ' || acc.name, '') || ' early.',
       link_url = '/users?user=' || l.student_id::text
  from public.audit_logs a
  join public.leases l on l.id = a.entity_id::uuid
  join public.users u on u.id = l.student_id
  left join public.rooms r on r.id = l.room_id
  left join public.accommodations acc on acc.id = r.accommodation_id
 where n.title = 'Lease leave request'
   and n.body = 'A student requested to leave their lease early.'
   and a.entity_type in ('leases', 'lease')
   and a.after_json ->> 'status' = 'leave_requested'
   and a.created_at between n.created_at - interval '5 seconds' and n.created_at + interval '5 seconds';
