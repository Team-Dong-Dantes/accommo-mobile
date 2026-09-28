-- Ticket integrity: what a reporter can write, and what happens after resolve.
--
-- 1. A reporter's message must be their own and must not claim to be OSAS.
--    The insert policy never looked at author_role or author_id, so a student
--    could post author_role = 'agent' and it rendered as an OSAS reply.
-- 2. Reporters no longer update tickets at all. Neither app does it; the policy
--    let a student set their own ticket's status, priority or assignee. A new
--    ticket must also arrive as open / medium / unassigned — the priority is
--    OSAS's call, and 'urgent' pages every admin.
-- 3. A reporter's reply on a resolved ticket reopens it. The queue only counts
--    unresolved tickets as waiting, so that reply used to go unseen.
-- 4. Resolving a ticket tells the reporter. Only replies notified before.
-- 5. Both ticket tables join the realtime publication (live board and thread).

-- 1 ---------------------------------------------------------------------------
drop policy if exists "ticket_messages_reporter_insert" on public.ticket_messages;
create policy "ticket_messages_reporter_insert" on public.ticket_messages
  for insert to authenticated
  with check (
    is_internal = false
    and author_role = 'student'
    and author_id = auth.uid()
    and exists (
      select 1 from public.tickets t
       where t.id = ticket_messages.ticket_id
         and (t.student_id = auth.uid()
              or t.landlord_id = auth.uid()
              or t.lease_id in (select l.id from public.leases l where l.student_id = auth.uid()))
    )
  );

-- 2 ---------------------------------------------------------------------------
drop policy if exists "tickets_reporter_update" on public.tickets;

drop policy if exists "tickets_reporter_insert" on public.tickets;
create policy "tickets_reporter_insert" on public.tickets
  for insert to authenticated
  with check (
    public.is_admin(auth.uid())
    or (
      (student_id = auth.uid() or landlord_id = auth.uid())
      and status = 'open'
      and priority = 'medium'
      and assignee_id is null
    )
  );

-- 3 ---------------------------------------------------------------------------
create or replace function public.trg_ticket_message_notify() returns trigger
  language plpgsql security definer
  set search_path to 'public'
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
    if t.landlord_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.landlord_id, 'OSAS replied to your ticket', preview, 'ticket', '/manager/osas');
    end if;
  else
    if t.status = 'resolved' then
      update public.tickets set status = 'open', resolved_at = null where id = t.id;
    end if;
    perform public.notify_admins(
      case when t.status = 'resolved' then 'Ticket reopened by a reply' else 'New reply on a ticket' end,
      preview,
      'ticket',
      '/support-tickets?focus=ticket:' || t.id::text
    );
  end if;

  return new;
end;
$$;

-- 4 ---------------------------------------------------------------------------
create or replace function public.trg_ticket_resolved_notify() returns trigger
  language plpgsql security definer
  set search_path to 'public'
as $$
declare
  msg text := coalesce(new.subject, 'Your ticket') || ' was marked resolved. Not fixed? Reply to reopen it.';
begin
  if new.status = 'resolved' and old.status is distinct from 'resolved' then
    if new.student_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (new.student_id, 'Your ticket was resolved', msg, 'ticket', '/student/support');
    end if;
    if new.landlord_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (new.landlord_id, 'Your ticket was resolved', msg, 'ticket', '/manager/osas');
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.trg_ticket_resolved_notify() from public, anon, authenticated;
grant all on function public.trg_ticket_resolved_notify() to service_role;

drop trigger if exists trg_ticket_resolved_notify on public.tickets;
create trigger trg_ticket_resolved_notify
  after update of status on public.tickets
  for each row execute function public.trg_ticket_resolved_notify();

-- 5 ---------------------------------------------------------------------------
-- Live updates. Neither ticket table was in the realtime publication, so the
-- OSAS board and the mobile ticket thread subscribed to changes that never
-- came. Realtime applies RLS per subscriber: reporters still only receive
-- their own tickets, and never internal notes.
do $$
begin
  alter publication supabase_realtime add table public.tickets;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.ticket_messages;
exception when duplicate_object then null;
end $$;
