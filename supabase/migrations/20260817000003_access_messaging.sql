-- ============================================================================
-- Student module access — Part 3: conversations, messages, notifications
-- Additive only. Idempotent.
-- Every policy depends on is_admin(); each is wrapped in a guarded DO block so
-- a signature mismatch skips ONLY that policy (with a NOTICE) instead of
-- rolling back the whole file. Grants + RLS enable are applied directly.
-- ============================================================================

-- CONVERSATIONS --------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.conversations TO authenticated;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Conversations visible to participants" ON public.conversations;
  CREATE POLICY "Conversations visible to participants"
    ON public.conversations FOR ALL TO authenticated
    USING (user_a_id = auth.uid() OR user_b_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (user_a_id = auth.uid() OR user_b_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Conversations visible to participants".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Conversations visible to participants" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- MESSAGES -------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Messages visible to conversation participants" ON public.messages;
  CREATE POLICY "Messages visible to conversation participants"
    ON public.messages FOR ALL TO authenticated
    USING (conversation_id IN (
      SELECT id FROM public.conversations
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid() OR public.is_admin(auth.uid()::text)))
    WITH CHECK (sender_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Messages visible to conversation participants".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Messages visible to conversation participants" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- NOTIFICATIONS --------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Notifications visible to owner" ON public.notifications;
  CREATE POLICY "Notifications visible to owner"
    ON public.notifications FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Notifications visible to owner".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Notifications visible to owner" — is_admin() signature may differ. %', SQLERRM;
END $$;
