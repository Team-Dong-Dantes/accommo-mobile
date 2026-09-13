-- Fix mobile messaging end-to-end:
--   1. Let a conversation participant insert a message-notification for the
--      other participant (the old policy called is_admin(auth.uid()::text),
--      which errored because is_admin takes a uuid, so the message notify 403'd).
--   2. Add messages (and conversations) to the realtime publication so an open
--      chat updates live instead of only after a manual reload.
begin;

-- 1) Message notifications between conversation participants -----------------
drop policy if exists "Notifications visible to owner" on public.notifications;
create policy "Notifications visible to owner"
  on public.notifications
  for all to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin(auth.uid())
  )
  with check (
    user_id = auth.uid()
    or public.is_admin(auth.uid())
    or exists (
      select 1 from public.conversations c
      where (c.user_a_id = auth.uid() and c.user_b_id = user_id)
         or (c.user_b_id = auth.uid() and c.user_a_id = user_id)
    )
  );

-- 2) Realtime for chats ------------------------------------------------------
alter publication supabase_realtime add table public.messages, public.conversations;

commit;
