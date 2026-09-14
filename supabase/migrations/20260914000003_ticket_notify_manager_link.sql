-- The manager's ticket-reply notification linked to /manager/osas-compliance,
-- which is not a route this app has. resolveNotifLink() rejects any path
-- missing from its ROUTES set, so the link silently degraded to the BY_TYPE
-- fallback -- which lands on /manager/osas anyway, just by accident rather
-- than on purpose. Name the real route.
--
-- Body is otherwise identical to 20260909000000_ticket_reply_channel.sql.

create or replace function public.trg_ticket_message_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.tickets%rowtype;
  preview text;
begin
  if new.is_internal then
    return new;
  end if;

  select * into t from public.tickets where id = new.ticket_id;
  if not found then
    return new;
  end if;

  preview := coalesce(t.subject, 'Your ticket') || ': ' || left(new.body, 120);

  if new.author_role = 'agent' then
    if t.student_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.student_id, 'OSAS replied to your ticket', preview, 'ticket', '/student/support');
    end if;
    if t.accommodation_manager_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.accommodation_manager_id, 'OSAS replied to your ticket', preview, 'ticket', '/manager/osas');
    end if;
  else
    perform public.notify_admins(
      'New reply on a ticket',
      preview,
      'ticket',
      '/support-tickets?focus=ticket:' || t.id::text
    );
  end if;

  return new;
end;
$$;

-- Existing rows still carry the dead path; they resolve through the same
-- fallback, so this only has to stop new ones being written.
update public.notifications
   set link_url = '/manager/osas'
 where link_url = '/manager/osas-compliance';
