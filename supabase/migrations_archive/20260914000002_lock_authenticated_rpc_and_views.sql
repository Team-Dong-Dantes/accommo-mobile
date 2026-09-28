-- Three things the first pair of migrations left open.
--
--   1. notify_admins() was closed to anonymous callers but still open to any
--      signed-in one, so a student could still fill every admin's feed.
--   2. The three review_* views are SECURITY DEFINER — the last ERROR-level
--      lint on the project.
--   3. 39 foreign keys have no covering index.


-- 1. The signed-in RPC surface --------------------------------------------------
--
-- Same treatment as anon in 20260914000001, narrower keep-list. Revoking from
-- `authenticated` takes EXECUTE off every function in the schema, then the 13
-- the apps actually call are granted back. That list came from grepping every
-- `.rpc(` call site in both clients, not from guesswork.
--
-- What loses its grant: notify_admins, announce_due, fanout_announcement,
-- archive_expired_announcements, purge_unverified_accounts,
-- sweep_expired_permits, recompute_room_occupancy, announcement_reach,
-- set_audit_context, and every tg_*/trg_*/fn_* trigger body.
--
-- Triggers keep working. PostgreSQL checks EXECUTE on a trigger function when
-- the trigger is created, not each time it fires, and the SECURITY DEFINER
-- functions that call notify_admins internally (trg_new_ticket,
-- trg_new_verification, trg_payment_flag...) run as their definer, which still
-- holds the grant.

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;

-- The 13 the apps call.
GRANT EXECUTE ON FUNCTION public.clear_pin(text)                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_email_ownership()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_qr_token()                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_verification_queue()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_pin()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_application(uuid)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(uuid)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.resubmit_verification()            TO authenticated;
GRANT EXECUTE ON FUNCTION public.rotate_qr_token()                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_pin(text)                      TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_pin(text)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_student_qr(text)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_student_review(uuid, uuid, uuid, integer, text, integer, text)
  TO authenticated;

-- The five predicates RLS policies evaluate. Without these, a signed-in read of
-- any table whose policy calls is_admin() fails outright.
GRANT EXECUTE ON FUNCTION public.is_admin(uuid)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_notify(uuid)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_accommodation_ids()  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_is_superadmin() TO authenticated;

-- So the next new function does not arrive pre-granted, the way notify_admins did.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM authenticated;


-- 2. The review views ------------------------------------------------------------
--
-- These are NOT dead code: review_inbox is read by ManagerDashboard,
-- ManagerHistoryPage and StudentHistoryPage; review_written_leases by
-- TenantProfile and StudentHistoryPage. The tables are empty because nobody has
-- written a review yet.
--
-- Both views already filter on auth.uid(), and the *_select_involved policies
-- on the underlying tables grant exactly those rows, so switching to
-- security_invoker changes no result — it just means the caller's own RLS is
-- what enforces it, rather than the view owner's rights.

ALTER VIEW public.review_inbox          SET (security_invoker = true);
ALTER VIEW public.review_written_leases SET (security_invoker = true);

-- review_admin_feed has no caller in either app, and under security_invoker it
-- would return nothing anyway: the three review tables have no admin SELECT
-- policy. Dropping it rather than leaving a SECURITY DEFINER view lying around.
DROP VIEW IF EXISTS public.review_admin_feed;


-- 3. Policies on `users` that are now provably redundant -------------------------
--
-- users_select_related (20260914000000) is `can_notify(id) OR <accredited
-- manager>`, and can_notify() already returns true for `id = auth.uid()` and for
-- anyone sharing a lease with the caller. That makes these three strictly
-- narrower than a policy already in place, so each one only costs an extra OR
-- branch evaluated per row.
--
-- Note this is the only place the "multiple permissive policies" lint is real
-- duplication. Elsewhere (leases, accommodations, boarding_history...) the
-- several policies encode genuinely different rules — admin OR owner OR
-- involved — and merging those would be a rewrite, not a cleanup.

DROP POLICY IF EXISTS users_select_own ON public.users;
DROP POLICY IF EXISTS "Users can read their own profile" ON public.users;
DROP POLICY IF EXISTS accommodation_managers_read_lease_tenant_users ON public.users;


-- 4. Covering indexes for every unindexed foreign key -----------------------------

create index if not exists idx_accommodation_facilities_accommodation_id on accommodation_facilities (accommodation_id);
create index if not exists idx_accommodation_facilities_room_id on accommodation_facilities (room_id);
create index if not exists idx_accommodation_facility_images_facility_id on accommodation_facility_images (facility_id);
create index if not exists idx_accommodation_images_accommodation_id on accommodation_images (accommodation_id);
create index if not exists idx_accommodation_manager_reviews_accommodation_manager_id on accommodation_manager_reviews (accommodation_manager_id);
create index if not exists idx_accommodation_manager_reviews_student_id on accommodation_manager_reviews (student_id);
create index if not exists idx_accommodation_reviews_accommodation_id on accommodation_reviews (accommodation_id);
create index if not exists idx_accommodation_reviews_student_id on accommodation_reviews (student_id);
create index if not exists idx_accommodations_accommodation_manager_id on accommodations (accommodation_manager_id);
create index if not exists idx_announcements_author_id on announcements (author_id);
create index if not exists idx_audit_logs_actor_id on audit_logs (actor_id);
create index if not exists idx_boarding_history_accommodation_id on boarding_history (accommodation_id);
create index if not exists idx_boarding_history_student_id on boarding_history (student_id);
create index if not exists idx_conversations_inquiry_room_id on conversations (inquiry_room_id);
create index if not exists idx_conversations_invited_room_id on conversations (invited_room_id);
create index if not exists idx_conversations_last_sender_id on conversations (last_sender_id);
create index if not exists idx_conversations_user_a_id on conversations (user_a_id);
create index if not exists idx_conversations_user_b_id on conversations (user_b_id);
create index if not exists idx_leases_accommodation_manager_id on leases (accommodation_manager_id);
create index if not exists idx_leases_room_id on leases (room_id);
create index if not exists idx_messages_conversation_id on messages (conversation_id);
create index if not exists idx_messages_sender_id on messages (sender_id);
create index if not exists idx_notifications_user_id on notifications (user_id);
create index if not exists idx_payments_lease_id on payments (lease_id);
create index if not exists idx_payments_verified_by on payments (verified_by);
create index if not exists idx_policies_created_by on policies (created_by);
create index if not exists idx_room_images_room_id on room_images (room_id);
create index if not exists idx_rooms_accommodation_id on rooms (accommodation_id);
create index if not exists idx_tenant_reviews_accommodation_manager_id on tenant_reviews (accommodation_manager_id);
create index if not exists idx_tenant_reviews_student_id on tenant_reviews (student_id);
create index if not exists idx_ticket_messages_author_id on ticket_messages (author_id);
create index if not exists idx_tickets_accommodation_id on tickets (accommodation_id);
create index if not exists idx_tickets_accommodation_manager_id on tickets (accommodation_manager_id);
create index if not exists idx_tickets_assignee_id on tickets (assignee_id);
create index if not exists idx_tickets_lease_id on tickets (lease_id);
create index if not exists idx_tickets_student_id on tickets (student_id);
create index if not exists idx_verification_documents_user_id on verification_documents (user_id);
create index if not exists idx_verification_documents_verified_by on verification_documents (verified_by);
create index if not exists idx_verification_requests_reviewed_by on verification_requests (reviewed_by);
