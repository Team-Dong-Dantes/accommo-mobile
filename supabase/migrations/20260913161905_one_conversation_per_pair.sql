-- One conversation per pair, enforced rather than hoped for.
--
-- findOrCreate() in src/stores/messages.ts was read-then-insert with nothing in
-- the database behind it, so two entry points opening the same thread at once
-- (a listing's "Ask" and the messages tab, or a double tap) both found nothing
-- and both inserted. Three pairs ended up with two rows each, splitting their
-- history between them.
--
-- The client now resolves the losing side of that race by re-reading the row the
-- winner created -- but that only works because of the index below, which is
-- what actually makes the second insert fail instead of succeed.

-- The one duplicate that carried history: move its message to the survivor.
update public.messages
   set conversation_id = '425c09c8-628c-4f86-824d-78acf47e0a74'
 where conversation_id = 'b2106250-f558-4675-8d73-3f2b45447efd';

update public.conversations c
   set unread_b = c.unread_b + coalesce(
         (select unread_b from public.conversations
           where id = 'b2106250-f558-4675-8d73-3f2b45447efd'), 0)
 where c.id = '425c09c8-628c-4f86-824d-78acf47e0a74';

-- Restate the preview from the messages that now belong to the survivor.
update public.conversations c
   set last_message = m.body, last_time = m.sent_at
  from (select body, sent_at from public.messages
         where conversation_id = '425c09c8-628c-4f86-824d-78acf47e0a74'
         order by sent_at desc limit 1) m
 where c.id = '425c09c8-628c-4f86-824d-78acf47e0a74';

-- The other two duplicates held no messages at all.
delete from public.conversations
 where id in (
   'f3602484-14a7-48b1-a867-928d7c11bef7',
   '8d3a81d8-7dcd-4885-ab26-37fbbeb61aa1',
   'b2106250-f558-4675-8d73-3f2b45447efd'
 );

-- least/greatest normalises the pair, since either user can be user_a.
create unique index if not exists conversations_unique_pair
  on public.conversations (least(user_a_id, user_b_id), greatest(user_a_id, user_b_id));

-- Verification (safe to paste into the SQL editor: the final RAISE rolls it back).
--
-- do $$
-- declare a uuid; b uuid; got text;
-- begin
--   select user_a_id, user_b_id into a, b from conversations limit 1;
--   begin
--     insert into conversations (user_a_id, user_b_id) values (b, a);  -- reversed
--     raise exception 'FAIL: a duplicate pair was accepted';
--   exception when unique_violation then got := SQLERRM;
--   end;
--   raise exception 'PASSED -> %', got;
-- end $$;
