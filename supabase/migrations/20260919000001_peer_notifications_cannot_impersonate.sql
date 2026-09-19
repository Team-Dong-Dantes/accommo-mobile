-- A notification you did not address to yourself is attributed to you.
--
-- `notifications_insert_counterparty` allows an insert wherever can_notify() says
-- yes, which is "we share a lease, or we share a conversation" -- a message
-- sender has to be able to ring the other party's bell. Nothing narrowed what
-- that insert could say, and a conversation is free to start: the mobile client
-- will open one with any manager on request (findOrCreate in
-- src/stores/messages.ts). So any account could put arbitrary text, an arbitrary
-- `type` and an arbitrary `source` into any manager's or student's notification
-- list -- "OSAS: your account has been suspended" in the same row shape the real
-- thing uses, indistinguishable in the UI.
--
-- The insert itself stays allowed; what it may claim does not. A row written by
-- somebody other than its recipient gets `source` replaced with the writer's own
-- name and `type` forced into the set peers legitimately send, so a forged
-- notice can still be sent but can no longer pretend to come from anyone else.
-- Rows an admin writes, and rows you write to yourself, are untouched.

begin;

create or replace function public.tg_notification_attribution()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  sender_name text;
begin
  -- Addressed to yourself, or written by OSAS: nothing to attribute.
  if new.user_id = auth.uid() or public.is_admin(auth.uid()) then
    return new;
  end if;

  -- Service-role and trigger-driven writes have no auth.uid() at all; those are
  -- the backend's own fan-outs and are equally not somebody's peer.
  if auth.uid() is null then
    return new;
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

revoke all on function public.tg_notification_attribution() from anon, authenticated;

drop trigger if exists notification_attribution on public.notifications;
create trigger notification_attribution
  before insert on public.notifications
  for each row execute function public.tg_notification_attribution();

commit;
