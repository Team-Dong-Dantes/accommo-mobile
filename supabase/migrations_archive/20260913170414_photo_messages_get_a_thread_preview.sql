-- A photo with no caption left the thread list saying "No messages yet".
--
-- tg_message_after_insert copied new.body straight into conversations.last_message,
-- and a photo-only message has an empty body -- so the inbox row for a perfectly
-- real conversation read as empty. Fixed here rather than in the client because
-- last_message is written in exactly one place and read by every surface
-- (ThreadList, the messages store, and anything added later).
--
-- Precedence: a caption always wins, so "look at this" + a photo still previews
-- as "look at this"; only a genuinely empty body falls back to the marker.

create or replace function public.tg_message_after_insert()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  update conversations c
     set last_message = coalesce(
           nullif(trim(new.body), ''),
           case when new.attachment_url is not null then '📷 Photo' else '' end
         ),
         last_time    = new.sent_at,
         unread_a = case when c.user_a_id <> new.sender_id then c.unread_a + 1 else c.unread_a end,
         unread_b = case when c.user_b_id <> new.sender_id then c.unread_b + 1 else c.unread_b end
   where c.id = new.conversation_id;
  return new;
end;
$function$;

-- Repair the threads whose newest message is an uncaptioned photo. Threads with
-- no messages at all keep a blank preview -- "No messages yet" is true for them.
update public.conversations c
   set last_message = '📷 Photo'
  from (
    select distinct on (conversation_id) conversation_id, body, attachment_url
      from public.messages
     order by conversation_id, sent_at desc
  ) newest
 where newest.conversation_id = c.id
   and coalesce(trim(c.last_message), '') = ''
   and coalesce(trim(newest.body), '') = ''
   and newest.attachment_url is not null;

-- Verification (safe to paste into the SQL editor: the final RAISE rolls it back).
--
-- do $$
-- declare cid uuid := '<a conversation id>'; uid uuid; got text;
-- begin
--   select user_a_id into uid from conversations where id = cid;
--   insert into messages (conversation_id, sender_id, body, attachment_url)
--   values (cid, uid, '', 'https://example.com/x.jpg');
--   select last_message into got from conversations where id = cid;
--   if got <> '📷 Photo' then raise exception 'FAIL: photo preview was %', got; end if;
--
--   insert into messages (conversation_id, sender_id, body, attachment_url)
--   values (cid, uid, 'look at this', 'https://example.com/y.jpg');
--   select last_message into got from conversations where id = cid;
--   if got <> 'look at this' then raise exception 'FAIL: caption should win, got %', got; end if;
--
--   raise exception 'PASSED (rolling back)';
-- end $$;
