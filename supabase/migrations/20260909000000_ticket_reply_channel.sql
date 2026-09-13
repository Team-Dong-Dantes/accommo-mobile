-- Make the ticket conversation two-way.
--
-- Before this, a reporter (student or accommodation manager) could file a
-- ticket and admin could answer it, but the answer never reached anyone: the
-- mobile app has no thread UI and nothing notified the reporter. Three fixes:
--
--   1. Retire the legacy `pending` status vocabulary, which the admin inbox
--      cannot render (its tabs and counts only know open/in_progress/resolved),
--      so those tickets were reachable only under "All".
--   2. Stop internal notes leaking to reporters. `ticket_messages_reporter_select`
--      only checked ticket ownership, so the notes the web UI labels "not visible
--      to the requester" were in fact readable by them the moment a reporter-side
--      thread existed.
--   3. Notify the other side when a public message is posted.

-- 1) Legacy statuses -> the vocabulary both apps actually render.
update public.tickets set status = 'open' where status = 'pending';
update public.tickets set status = 'in_progress' where status in ('assigned', 'under_review');

-- 2) Reporters read public messages on their own tickets only.
drop policy if exists "ticket_messages_reporter_select" on public.ticket_messages;
create policy "ticket_messages_reporter_select" on public.ticket_messages
  for select to authenticated
  using (
    is_internal = false
    and exists (
      select 1 from public.tickets t
      where t.id = ticket_messages.ticket_id
        and (
          t.student_id = auth.uid()
          or t.accommodation_manager_id = auth.uid()
          or t.lease_id in (select l.id from public.leases l where l.student_id = auth.uid())
        )
    )
  );

-- 3) A public reply notifies whoever is on the other end. Admin replies reach
--    the reporter(s) on their own app's route; reporter replies reach admins on
--    the deep link that opens the ticket window.
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
      values (t.accommodation_manager_id, 'OSAS replied to your ticket', preview, 'ticket', '/manager/osas-compliance');
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

drop trigger if exists trg_ticket_message_notify on public.ticket_messages;
create trigger trg_ticket_message_notify
  after insert on public.ticket_messages
  for each row execute function public.trg_ticket_message_notify();

-- Verification (safe to paste into the SQL editor: the final RAISE rolls the
-- whole block back, so it leaves no test rows behind). Substitute a ticket id
-- that has both student_id and accommodation_manager_id set.
--
-- do $$
-- declare n int; tid uuid := '<ticket-with-both-owners>';
-- begin
--   insert into ticket_messages (ticket_id, author_role, body, is_internal)
--   values (tid, 'agent', 'check-agent', false);
--   select count(*) into n from notifications where body like '%check-agent%';
--   if n <> 2 then raise exception 'agent reply: expected 2 notifications, got %', n; end if;
--
--   insert into ticket_messages (ticket_id, author_role, body, is_internal)
--   values (tid, 'agent', 'check-internal', true);
--   select count(*) into n from notifications where body like '%check-internal%';
--   if n <> 0 then raise exception 'internal note leaked % notifications', n; end if;
--
--   insert into ticket_messages (ticket_id, author_role, body, is_internal)
--   values (tid, 'student', 'check-reporter', false);
--   select count(*) into n from notifications n2 where n2.body like '%check-reporter%'
--     and n2.user_id in (select id from users where role = 'admin' or is_superadmin);
--   if n < 1 then raise exception 'reporter reply notified no admin'; end if;
--
--   raise exception 'ALL CHECKS PASSED (rolling back test rows)';
-- end $$;
