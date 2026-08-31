-- Allow conversation participants to notify each other.
--
-- The previous notifications policy used WITH CHECK (user_id = auth.uid()),
-- which only lets a user create notifications addressed to themselves. Message
-- senders insert a notification for the recipient (user_id = the other party),
-- so those inserts failed with 403. This adds an exception for users who share
-- a conversation with the recipient.

DROP POLICY IF EXISTS "Notifications visible to owner" ON public.notifications;
CREATE POLICY "Notifications visible to owner"
  ON public.notifications FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.is_admin(auth.uid()::text))
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_admin(auth.uid()::text)
    OR EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE (c.user_a_id = auth.uid() AND c.user_b_id = user_id)
         OR (c.user_b_id = auth.uid() AND c.user_a_id = user_id)
    )
  );
