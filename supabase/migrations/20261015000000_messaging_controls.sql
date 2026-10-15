-- Messaging controls: edit, unsend, reply, reactions, listing cards, files,
-- per-person pin/mute/archive, and a delivered tick that actually lights.

-- 1 ---------------------------------------------------------------------------
-- New message columns. `deleted_at` is the one the client sets itself (unsend);
-- the rest are written by triggers/RPCs or only on insert.
alter table public.messages
  add column if not exists edited_at        timestamptz,
  add column if not exists deleted_at       timestamptz,
  add column if not exists reply_to_id      uuid references public.messages(id) on delete set null,
  add column if not exists reactions        jsonb not null default '{}'::jsonb,
  add column if not exists accommodation_id uuid references public.accommodations(id) on delete set null;

-- lock_columns runs first (name order) and only sees what the client sent, so
-- edited_at can still be stamped by messages_before_update below.
drop trigger if exists lock_columns on public.messages;
create trigger lock_columns before update on public.messages
  for each row execute function public.lock_columns(
    'conversation_id', 'sender_id', 'sent_at', 'edited_at', 'reactions', 'reply_to_id', 'accommodation_id');

-- Unsend wipes the content for both people and is final; an edit is stamped by
-- the database so "edited" cannot be left off. RPCs (read ticks, reactions) run
-- as their owner and pass straight through.
create or replace function public.tg_message_before_update() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user <> 'authenticated' then return new; end if;
  if old.deleted_at is not null then
    raise exception 'This message was removed.' using errcode = '42501';
  end if;
  if new.deleted_at is not null then
    new.deleted_at       := now();
    new.body             := '';
    new.attachment_url   := null;
    new.accommodation_id := null;
    new.reactions        := '{}'::jsonb;
    return new;
  end if;
  if new.attachment_url is distinct from old.attachment_url then
    raise exception 'A sent file cannot be swapped. Unsend it instead.' using errcode = '42501';
  end if;
  if new.body is distinct from old.body then
    if trim(new.body) = '' and old.attachment_url is null then
      raise exception 'A message cannot be edited to nothing. Unsend it instead.' using errcode = '22023';
    end if;
    new.edited_at := now();
  end if;
  return new;
end $$;

drop trigger if exists messages_before_update on public.messages;
create trigger messages_before_update before update on public.messages
  for each row execute function public.tg_message_before_update();

-- The inbox preview follows an edit or unsend of the newest message.
create or replace function public.tg_message_after_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.body is not distinct from old.body and new.deleted_at is not distinct from old.deleted_at then
    return null;
  end if;
  update conversations c
     set last_message = case when new.deleted_at is not null then 'Message removed' else trim(new.body) end
   where c.id = new.conversation_id
     and c.last_time = new.sent_at
     and c.last_sender_id = new.sender_id;
  return null;
end $$;

revoke all on function public.tg_message_after_update() from public, anon, authenticated;

drop trigger if exists messages_after_update on public.messages;
create trigger messages_after_update after update on public.messages
  for each row execute function public.tg_message_after_update();

-- A file or a listing card has no text, and the inbox can't tell either from a
-- photo, which ThreadList words per viewer. These two get a fixed preview.
create or replace function public.tg_message_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update conversations c
     set last_message   = case
                            when trim(new.body) <> '' then trim(new.body)
                            when new.accommodation_id is not null then 'Shared a listing'
                            when new.attachment_url like 'cld:raw:%' then 'Sent a file'
                            else ''
                          end,
         last_sender_id = new.sender_id,
         last_time      = new.sent_at,
         unread_a = case when c.user_a_id <> new.sender_id then c.unread_a + 1 else c.unread_a end,
         unread_b = case when c.user_b_id <> new.sender_id then c.unread_b + 1 else c.unread_b end
   where c.id = new.conversation_id;
  return new;
end $$;

-- 2 ---------------------------------------------------------------------------
-- One reaction per person per message, stored as {user_id: emoji}. Through an
-- RPC because messages_update_own only lets the sender touch the row. An empty
-- emoji takes mine off.
create or replace function public.react_to_message(p_message uuid, p_emoji text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_emoji text := nullif(p_emoji, '');
begin
  if v_emoji is not null and v_emoji not in ('👍', '❤️', '😂', '😮', '😢', '🙏') then
    raise exception 'Unsupported reaction.' using errcode = '22023';
  end if;
  update messages m
     set reactions = case when v_emoji is null then m.reactions - v_uid::text
                          else m.reactions || jsonb_build_object(v_uid::text, v_emoji) end
   where m.id = p_message
     and m.deleted_at is null
     and exists (select 1 from conversations c
                  where c.id = m.conversation_id and v_uid in (c.user_a_id, c.user_b_id));
  if not found then
    raise exception 'Message not found.' using errcode = 'P0002';
  end if;
end $$;

revoke all on function public.react_to_message(uuid, text) from public, anon;
grant execute on function public.react_to_message(uuid, text) to authenticated;

-- The recipient's device used to flip status to 'delivered' with a plain
-- update, which messages_update_own (sender only) silently refused — so the
-- double tick only ever appeared on read. Same shape as mark_conversation_read.
-- No argument: on app start it also catches what arrived while offline.
create or replace function public.mark_messages_delivered() returns void
language sql security definer set search_path = public as $$
  update messages m
     set status = 'delivered'
   where m.status = 'sent'
     and m.sender_id <> auth.uid()
     and exists (select 1 from conversations c
                  where c.id = m.conversation_id and auth.uid() in (c.user_a_id, c.user_b_id));
$$;

revoke all on function public.mark_messages_delivered() from public, anon;
grant execute on function public.mark_messages_delivered() to authenticated;

create index if not exists messages_unsent_idx on public.messages (conversation_id) where status = 'sent';
create index if not exists messages_conversation_sent_idx on public.messages (conversation_id, sent_at desc);

-- 3 ---------------------------------------------------------------------------
-- Pin, mute and archive are each person's own view of a shared conversation,
-- so they live beside it rather than as _a/_b columns on it. A thread counts
-- as archived only while nothing newer than archived_at has arrived.
create table if not exists public.conversation_prefs (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null default auth.uid() references public.users(id) on delete cascade,
  pinned          boolean not null default false,
  muted           boolean not null default false,
  archived_at     timestamptz,
  primary key (conversation_id, user_id)
);

alter table public.conversation_prefs enable row level security;

drop policy if exists "conversation_prefs_own" on public.conversation_prefs;
create policy "conversation_prefs_own" on public.conversation_prefs
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.conversations c
                 where c.id = conversation_id and (select auth.uid()) in (c.user_a_id, c.user_b_id))
  );

revoke all on public.conversation_prefs from anon;

-- A muted thread does not buzz. Otherwise unchanged from 20261004030000.
create or replace function public.tg_message_push()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  c         public.conversations;
  v_to      uuid;
  v_unread  int;
  v_sender  public.users;
  v_to_role public.user_role;
begin
  select * into c from public.conversations where id = new.conversation_id;
  if not found then return null; end if;

  if c.user_a_id = new.sender_id then
    v_to := c.user_b_id; v_unread := c.unread_b;
  else
    v_to := c.user_a_id; v_unread := c.unread_a;
  end if;

  -- messages_after_insert has already counted this message, so 1 means it is
  -- the first one the recipient has not read yet.
  if v_to is null or v_unread <> 1 then return null; end if;

  if exists (select 1 from public.conversation_prefs p
              where p.conversation_id = c.id and p.user_id = v_to and p.muted) then
    return null;
  end if;

  select * into v_sender from public.users where id = new.sender_id;
  select role into v_to_role from public.users where id = v_to;

  perform public.send_push(v_to, case
    when v_sender.role = 'student' and v_to_role = 'landlord' then jsonb_build_object(
      'type', 'message', 'title', 'New inquiry', 'body', 'A student wants to inquire.')
    else jsonb_build_object(
      'type', 'message', 'title', 'New message',
      'body', coalesce(nullif(trim(v_sender.full_name), ''), 'Someone') || ' sent you a message.')
  end);
  return null;
end $$;

revoke all on function public.tg_message_push() from public, anon, authenticated;
