-- The notifications one user's action sends another (payment verified, leave
-- requested, application accepted, ...) were written by the acting client as a
-- second, fire-and-forget request after the action itself. A dropped connection
-- or a closed app between the two saved the action and lost the notice. They
-- are written here instead, in the same transaction as the change they report.
--
-- Titles, bodies and links match what the app used to send, so the bell and
-- push read the same. The one notice with no database state behind it —
-- "Application form requested", a pure nudge — stays client-side.

-- notify_system with a sender: the bell shows who a peer notice is from.
create or replace function public.notify_peer(
  p_user uuid, p_type text, p_title text, p_body text, p_link text, p_from uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  prev text := coalesce(current_setting('app.system_notice', true), 'false');
begin
  if p_user is null then return; end if;
  perform set_config('app.system_notice', 'true', true);
  insert into public.notifications (user_id, type, title, body, link_url, source)
  values (p_user, p_type, p_title, p_body, p_link,
          (select nullif(trim(full_name), '') from public.users where id = p_from));
  perform set_config('app.system_notice', prev, true);
end $$;

revoke all on function public.notify_peer(uuid, text, text, text, text, uuid) from public, anon, authenticated;

-- How the app labels a room: its label, else "Room <number>".
create or replace function public.room_display(p_room uuid)
returns text
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim(r.label), ''), 'Room ' || nullif(trim(r.room_number), ''), 'your room')
    from public.rooms r where r.id = p_room
$$;

revoke all on function public.room_display(uuid) from public, anon, authenticated;

-- Pesos as the app shows them: no centavos unless there are any.
create or replace function public.peso(p numeric)
returns text
language sql immutable as $$
  select '₱' || case when p = trunc(p) then to_char(p, 'FM999,999,990') else to_char(p, 'FM999,999,990.00') end
$$;

-- ── Leases: applications, walk-ins, leaving ─────────────────────────────────

create or replace function public.tg_lease_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_room text := public.room_display(new.room_id);
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' and new.added_by_landlord then
      perform public.notify_peer(new.student_id, 'lease', 'Added to a room',
        'Your landlord/landlady added you to ' || v_room || '. Show them your student QR to confirm.',
        '/student/profile/qr', new.landlord_id);
    elsif new.status = 'pending' then
      perform public.notify_peer(new.landlord_id, 'lease', 'New application',
        'Applied for ' || v_room, '/manager/messages?to=' || new.student_id, new.student_id);
    end if;
    return null;
  end if;

  if new.status is not distinct from old.status then return null; end if;

  if old.status = 'pending' and new.status = 'active' then
    if new.added_by_landlord then
      perform public.notify_peer(new.student_id, 'lease', 'Stay confirmed',
        'Your stay at ' || v_room || ' is confirmed.', '/student/stay', new.landlord_id);
    else
      perform public.notify_peer(new.student_id, 'lease', 'Application accepted',
        'You''re in! Your application for ' || v_room || ' was accepted.', '/student/stay', new.landlord_id);
    end if;
  elsif old.status = 'pending' and new.status = 'rejected' then
    perform public.notify_peer(new.student_id, 'lease', 'Application declined',
      'Your application for ' || v_room || ' was declined.'
        || coalesce(' Reason: ' || nullif(trim(new.decision_reason), ''), ''),
      '/student/profile', new.landlord_id);
  elsif new.status = 'leave_requested' then
    perform public.notify_peer(new.landlord_id, 'lease', 'Leave request',
      'A tenant requested to leave '
        || coalesce((select a.name from public.rooms r join public.accommodations a on a.id = r.accommodation_id
                      where r.id = new.room_id), 'their room') || '.',
      '/manager/tenant/' || new.id, new.student_id);
  elsif old.status = 'leave_requested' and new.status = 'ended' then
    perform public.notify_peer(new.student_id, 'lease', 'Leave request approved',
      'Your move-out from ' || v_room || ' was approved. You can now rate your stay.',
      '/student/profile/history', new.landlord_id);
  elsif old.status = 'leave_requested' and new.status = 'active' then
    perform public.notify_peer(new.student_id, 'lease', 'Leave request declined',
      'Your request to leave ' || v_room || ' was declined.'
        || coalesce(' Reason: ' || nullif(trim(new.decision_reason), ''), ''),
      '/student/stay', new.landlord_id);
  end if;
  return null;
end $$;

drop trigger if exists trg_lease_notify on public.leases;
create trigger trg_lease_notify
  after insert or update of status on public.leases
  for each row execute function public.tg_lease_notify();

-- ── Application form issued ─────────────────────────────────────────────────

create or replace function public.tg_invite_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_landlord uuid := (select a.landlord_id from public.rooms r join public.accommodations a on a.id = r.accommodation_id
                       where r.id = new.invited_room_id);
begin
  if new.invited_room_id is null or new.invited_at is not distinct from old.invited_at then return null; end if;
  perform public.notify_peer(
    case when new.user_a_id = v_landlord then new.user_b_id else new.user_a_id end,
    'application', 'Application form sent',
    'Your landlord/landlady sent you an application form for ' || public.room_display(new.invited_room_id) || '.',
    '/student/messages?c=' || new.id, v_landlord);
  return null;
end $$;

drop trigger if exists trg_invite_notify on public.conversations;
create trigger trg_invite_notify
  after update of invited_room_id, invited_at on public.conversations
  for each row execute function public.tg_invite_notify();

-- ── Payments ────────────────────────────────────────────────────────────────

create or replace function public.tg_payment_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  l public.leases;
begin
  select * into l from public.leases where id = new.lease_id;
  if not found then return null; end if;

  if tg_op = 'INSERT' then
    if new.status = 'pending_verification' then
      perform public.notify_peer(l.landlord_id, 'payment', 'Payment submitted',
        'A payment of ' || public.peso(new.amount) || ' was submitted for verification.',
        '/manager/tenant/' || l.id, l.student_id);
    end if;
  elsif new.status is distinct from old.status and old.status = 'pending_verification' then
    if new.status = 'paid' then
      perform public.notify_peer(l.student_id, 'payment', 'Payment verified',
        'Your payment for ' || public.room_display(l.room_id) || ' was marked as paid.',
        '/student/payments', l.landlord_id);
    elsif new.status = 'rejected' then
      perform public.notify_peer(l.student_id, 'payment', 'Payment rejected',
        'Your payment for ' || public.room_display(l.room_id) || ' was rejected.'
          || coalesce(' Reason: ' || nullif(trim(new.rejection_reason), ''), ''),
        '/student/payments', l.landlord_id);
    end if;
  end if;
  return null;
end $$;

drop trigger if exists trg_payment_notify on public.payments;
create trigger trg_payment_notify
  after insert or update of status on public.payments
  for each row execute function public.tg_payment_notify();

-- ── Utility bills: one notice per posting, not one per utility row ──────────

create or replace function public.tg_bill_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  b record;
begin
  for b in
    select n.lease_id, n.month, min(n.due_date) as due, sum(n.amount) as total
      from new_bills n group by n.lease_id, n.month
  loop
    perform public.notify_peer(l.student_id, 'payment', 'New utility bill',
      public.peso(b.total) || ' in utilities for ' || trim(to_char(b.month, 'FMMonth YYYY'))
        || ' is due ' || to_char(b.due, 'FMMon FMDD') || '.',
      '/student/payments', l.landlord_id)
    from public.leases l where l.id = b.lease_id;
  end loop;
  return null;
end $$;

drop trigger if exists trg_bill_notify on public.utility_bills;
create trigger trg_bill_notify
  after insert on public.utility_bills
  referencing new table as new_bills
  for each statement execute function public.tg_bill_notify();

-- ── Concerns ────────────────────────────────────────────────────────────────

create or replace function public.tg_concern_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  l public.leases;
  v_cat text := case new.category
    when 'maintenance' then 'Maintenance' when 'safety' then 'Safety'
    when 'billing' then 'Billing' when 'other' then 'Other' else new.category end;
begin
  select * into l from public.leases where id = new.lease_id;
  if not found then return null; end if;

  if tg_op = 'INSERT' then
    perform public.notify_peer(l.landlord_id, 'concern', 'New concern reported',
      'A ' || v_cat || ' concern was reported.', '/manager/support', l.student_id);
  elsif new.status is distinct from old.status
        and new.status in ('acknowledged', 'in_progress', 'resolved', 'rejected') then
    perform public.notify_peer(l.student_id, 'concern', 'Concern update',
      'Your ' || v_cat || ' concern was '
        || case new.status when 'in_progress' then 'marked in progress' else new.status end || '.',
      '/student/concerns', l.landlord_id);
  end if;
  return null;
end $$;

drop trigger if exists trg_concern_notify on public.concerns;
create trigger trg_concern_notify
  after insert or update of status on public.concerns
  for each row execute function public.tg_concern_notify();

-- ── Ratings: anonymous both ways, so no sender ──────────────────────────────

create or replace function public.tg_review_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'tenant_reviews' then
    perform public.notify_peer(new.student_id, 'review', 'You received a rating',
      'A landlord/landlady rated you after one of your past stays.', '/student/profile/history', null);
  else
    perform public.notify_peer(new.landlord_id, 'review', 'New rating',
      'A past tenant rated their stay.', '/manager/profile/history', null);
  end if;
  return null;
end $$;

drop trigger if exists trg_review_notify on public.tenant_reviews;
create trigger trg_review_notify
  after insert on public.tenant_reviews
  for each row execute function public.tg_review_notify();

drop trigger if exists trg_review_notify on public.landlord_reviews;
create trigger trg_review_notify
  after insert on public.landlord_reviews
  for each row execute function public.tg_review_notify();

revoke all on function public.tg_lease_notify(), public.tg_invite_notify(), public.tg_payment_notify(),
  public.tg_bill_notify(), public.tg_concern_notify(), public.tg_review_notify()
  from public, anon, authenticated;

-- ── Transition: drop the copy an older app still sends ──────────────────────
-- Until every phone has the build without these client writes, the old app
-- follows each action with its own copy of the notice. The server's row is
-- already there by then, so a peer insert matching a recent row to the same
-- person with the same title is skipped. Returning null makes the client's
-- insert a silent no-op rather than an error.
-- ponytail: title match within 2 minutes; drop this block once old builds are gone.
create or replace function public.tg_notification_attribution()
returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  sender_name text;
begin
  -- Sent by the backend itself (notify_system), not by the signed-in user.
  if coalesce(current_setting('app.system_notice', true), 'false') = 'true' then
    return new;
  end if;

  -- Addressed to yourself, or written by OSAS: nothing to attribute.
  if new.user_id = auth.uid() or public.is_admin(auth.uid()) then
    return new;
  end if;

  -- Service-role and trigger-driven writes have no auth.uid() at all; those are
  -- the backend's own fan-outs and are equally not somebody's peer.
  if auth.uid() is null then
    return new;
  end if;

  if exists (
    select 1 from public.notifications n
     where n.user_id = new.user_id and n.title = new.title
       and n.created_at > now() - interval '2 minutes'
  ) then
    return null;
  end if;

  select u.full_name into sender_name from public.users u where u.id = auth.uid();
  new.source := coalesce(nullif(trim(sender_name), ''), 'Another user');

  -- The types a conversation peer has any business sending. Anything else --
  -- 'verification', 'policy', 'announcement', 'system' -- is OSAS's voice, so it
  -- is demoted rather than rejected: a refused insert would fail the message
  -- send that carried it.
  if new.type is null or new.type not in ('message', 'application', 'lease', 'leave', 'payment', 'concern', 'review') then
    new.type := 'message';
  end if;

  return new;
end;
$$;
