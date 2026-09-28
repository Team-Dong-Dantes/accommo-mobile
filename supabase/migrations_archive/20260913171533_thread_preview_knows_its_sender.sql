-- "You sent a photo" vs "Maria sent a photo" depends on who is READING, and
-- last_message is one string shared by both participants -- so the wording
-- cannot be decided here. Record who sent it instead and let each client phrase
-- it for its own viewer. The emoji marker from
-- 20260913170414_photo_messages_get_a_thread_preview.sql is dropped.
--
-- No "was it a photo" flag is needed: ChatThread's send() refuses a message with
-- neither a body nor a file, so an empty body implies an attachment. The client
-- (components/messages/ThreadList.vue, preview()) reads:
--   last_sender_id is null -> no messages yet
--   last_message is empty  -> a photo, phrased for the viewer
--   otherwise              -> the text itself

alter table public.conversations
  add column if not exists last_sender_id uuid references public.users(id) on delete set null;

create or replace function public.tg_message_after_insert()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  update conversations c
     set last_message   = coalesce(trim(new.body), ''),
         last_sender_id = new.sender_id,
         last_time      = new.sent_at,
         unread_a = case when c.user_a_id <> new.sender_id then c.unread_a + 1 else c.unread_a end,
         unread_b = case when c.user_b_id <> new.sender_id then c.unread_b + 1 else c.unread_b end
   where c.id = new.conversation_id;
  return new;
end;
$function$;

-- Backfill from each thread's newest message, and undo the emoji marker.
update public.conversations c
   set last_sender_id = newest.sender_id,
       last_message   = coalesce(trim(newest.body), '')
  from (
    select distinct on (conversation_id) conversation_id, sender_id, body
      from public.messages
     order by conversation_id, sent_at desc
  ) newest
 where newest.conversation_id = c.id;
