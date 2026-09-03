-- Combined Accommo access + backfill migrations (files 01-05 in order). Run ONCE in the Supabase SQL Editor. Idempotent and additive.  
-- ============================================================================
-- Student module access — Part 1: schema grants + core/listing tables
-- Additive only (no row data touched). Idempotent (DROP POLICY IF EXISTS).
-- Apply in Supabase SQL Editor, or `supabase db push`.
--
-- NOTE: Functions is_admin()/get_my_role() were created outside migrations
-- (Dashboard). Postgres grants EXECUTE on new functions to PUBLIC by default,
-- so explicit GRANT EXECUTE is not required and is intentionally omitted.
-- Any policy that depends on is_admin() is wrapped in a guarded DO block so a
-- signature mismatch skips ONLY that admin/landlord-management policy instead of
-- rolling back the whole script. Student DISCOVERY access (the public SELECT
-- policies + grants below) has NO is_admin dependency and always applies.
-- ============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- USERS ----------------------------------------------------------------------
GRANT SELECT, UPDATE ON public.users TO authenticated;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can view public profile info" ON public.users;
CREATE POLICY "Authenticated users can view public profile info"
  ON public.users FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Users manage own row" ON public.users;
CREATE POLICY "Users manage own row"
  ON public.users FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- STUDENT_PROFILES -----------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.student_profiles TO authenticated;
ALTER TABLE public.student_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Student profiles own" ON public.student_profiles;
CREATE POLICY "Student profiles own"
  ON public.student_profiles FOR ALL TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
-- Admin override (guarded — depends on is_admin()).
DO $$
BEGIN
  DROP POLICY IF EXISTS "Student profiles admin override" ON public.student_profiles;
  CREATE POLICY "Student profiles admin override"
    ON public.student_profiles FOR ALL TO authenticated
    USING (public.is_admin(auth.uid()::text))
    WITH CHECK (public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Student profiles admin override".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Student profiles admin override" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- LANDLORD_PROFILES (business_name is public for discovery) ------------------
GRANT SELECT, INSERT, UPDATE ON public.landlord_profiles TO authenticated;
GRANT SELECT ON public.landlord_profiles TO anon;
ALTER TABLE public.landlord_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Landlord profiles public read" ON public.landlord_profiles;
CREATE POLICY "Landlord profiles public read"
  ON public.landlord_profiles FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Landlord profiles self manage" ON public.landlord_profiles;
CREATE POLICY "Landlord profiles self manage"
  ON public.landlord_profiles FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ADMIN_PROFILES (admin only — guarded; depends on is_admin()) --------------
GRANT SELECT ON public.admin_profiles TO authenticated;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Admin profiles admin only" ON public.admin_profiles;
  CREATE POLICY "Admin profiles admin only"
    ON public.admin_profiles FOR SELECT TO authenticated
    USING (public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Admin profiles admin only".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Admin profiles admin only" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PROPERTIES (public accredited listings + owner/landlord manage) ------------
GRANT SELECT ON public.properties TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.properties TO authenticated;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Properties public accredited" ON public.properties;
CREATE POLICY "Properties public accredited"
  ON public.properties FOR SELECT TO anon, authenticated
  USING (status = 'accredited' OR landlord_id = auth.uid());
-- Owner manage (admin override guarded).
DO $$
BEGIN
  DROP POLICY IF EXISTS "Properties owner manage" ON public.properties;
  CREATE POLICY "Properties owner manage"
    ON public.properties FOR ALL TO authenticated
    USING (landlord_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (landlord_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Properties owner manage".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Properties owner manage" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- ROOMS (public available rooms + owner/landlord manage) --------------------
GRANT SELECT ON public.rooms TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.rooms TO authenticated;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Rooms public available" ON public.rooms;
CREATE POLICY "Rooms public available"
  ON public.rooms FOR SELECT TO anon, authenticated
  USING (status = 'available'
         OR property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()));
DO $$
BEGIN
  DROP POLICY IF EXISTS "Rooms owner manage" ON public.rooms;
  CREATE POLICY "Rooms owner manage"
    ON public.rooms FOR ALL TO authenticated
    USING (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text))
    WITH CHECK (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Rooms owner manage".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Rooms owner manage" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- ROOM_IMAGES ----------------------------------------------------------------
GRANT SELECT ON public.room_images TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.room_images TO authenticated;
ALTER TABLE public.room_images ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Room images visible with room" ON public.room_images;
CREATE POLICY "Room images visible with room"
  ON public.room_images FOR SELECT TO anon, authenticated
  USING (room_id IN (
    SELECT id FROM public.rooms
    WHERE status = 'available'
       OR property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid())));
DO $$
BEGIN
  DROP POLICY IF EXISTS "Room images owner manage" ON public.room_images;
  CREATE POLICY "Room images owner manage"
    ON public.room_images FOR ALL TO authenticated
    USING (room_id IN (SELECT id FROM public.rooms WHERE property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid())) OR public.is_admin(auth.uid()::text))
    WITH CHECK (room_id IN (SELECT id FROM public.rooms WHERE property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid())) OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Room images owner manage".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Room images owner manage" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PROPERTY_IMAGES ------------------------------------------------------------
GRANT SELECT ON public.property_images TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.property_images TO authenticated;
ALTER TABLE public.property_images ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Property images visible with property" ON public.property_images;
CREATE POLICY "Property images visible with property"
  ON public.property_images FOR SELECT TO anon, authenticated
  USING (property_id IN (
    SELECT id FROM public.properties
    WHERE status = 'accredited' OR landlord_id = auth.uid()));
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property images owner manage" ON public.property_images;
  CREATE POLICY "Property images owner manage"
    ON public.property_images FOR ALL TO authenticated
    USING (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text))
    WITH CHECK (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Property images owner manage".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property images owner manage" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PROPERTY_AMENITIES ----------------------------------------------------------
GRANT SELECT ON public.property_amenities TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.property_amenities TO authenticated;
ALTER TABLE public.property_amenities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Property amenities visible with property" ON public.property_amenities;
CREATE POLICY "Property amenities visible with property"
  ON public.property_amenities FOR SELECT TO anon, authenticated
  USING (property_id IN (
    SELECT id FROM public.properties
    WHERE status = 'accredited' OR landlord_id = auth.uid()));
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property amenities owner manage" ON public.property_amenities;
  CREATE POLICY "Property amenities owner manage"
    ON public.property_amenities FOR ALL TO authenticated
    USING (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text))
    WITH CHECK (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Property amenities owner manage".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property amenities owner manage" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PROPERTY_POLICIES -----------------------------------------------------------
GRANT SELECT ON public.property_policies TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.property_policies TO authenticated;
ALTER TABLE public.property_policies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Property policies visible with property" ON public.property_policies;
CREATE POLICY "Property policies visible with property"
  ON public.property_policies FOR SELECT TO anon, authenticated
  USING (property_id IN (
    SELECT id FROM public.properties
    WHERE status = 'accredited' OR landlord_id = auth.uid()));
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property policies owner manage" ON public.property_policies;
  CREATE POLICY "Property policies owner manage"
    ON public.property_policies FOR ALL TO authenticated
    USING (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text))
    WITH CHECK (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Property policies owner manage".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property policies owner manage" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PROPERTY_DOCUMENTS (sensitive: authenticated only) -------------------------
GRANT SELECT, INSERT, UPDATE ON public.property_documents TO authenticated;
ALTER TABLE public.property_documents ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property documents visible with property" ON public.property_documents;
  CREATE POLICY "Property documents visible with property"
    ON public.property_documents FOR SELECT TO authenticated
    USING (property_id IN (
      SELECT id FROM public.properties
      WHERE status = 'accredited' OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text)));
  RAISE NOTICE 'Applied policy "Property documents visible with property".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property documents visible with property" — is_admin() signature may differ. %', SQLERRM;
END $$;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property documents owner manage" ON public.property_documents;
  CREATE POLICY "Property documents owner manage"
    ON public.property_documents FOR ALL TO authenticated
    USING (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text))
    WITH CHECK (property_id IN (SELECT id FROM public.properties WHERE landlord_id = auth.uid()) OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Property documents owner manage".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property documents owner manage" — is_admin() signature may differ. %', SQLERRM;
END $$;
-- ============================================================================
-- Student module access — Part 2: leases, payments, concerns, complaints
-- Additive only. Idempotent.
-- Every policy below depends on is_admin(); each is wrapped in a guarded DO
-- block so a signature mismatch skips ONLY that policy (with a NOTICE) instead
-- of rolling back the whole file. Grants + RLS enable are applied directly.
-- ============================================================================

-- LEASES ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.leases TO authenticated;
ALTER TABLE public.leases ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Leases visible to tenant/landlord/admin" ON public.leases;
  CREATE POLICY "Leases visible to tenant/landlord/admin"
    ON public.leases FOR ALL TO authenticated
    USING (student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Leases visible to tenant/landlord/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Leases visible to tenant/landlord/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PAYMENTS -------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.payments TO authenticated;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Payments visible to lease parties" ON public.payments;
  CREATE POLICY "Payments visible to lease parties"
    ON public.payments FOR ALL TO authenticated
    USING (lease_id IN (
      SELECT id FROM public.leases
      WHERE student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text))
      OR public.is_admin(auth.uid()::text))
    WITH CHECK (lease_id IN (
      SELECT id FROM public.leases
      WHERE student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text))
      OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Payments visible to lease parties".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Payments visible to lease parties" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- CONCERNS -------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.concerns TO authenticated;
ALTER TABLE public.concerns ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Concerns visible to tenant/admin" ON public.concerns;
  CREATE POLICY "Concerns visible to tenant/admin"
    ON public.concerns FOR ALL TO authenticated
    USING (lease_id IN (SELECT id FROM public.leases WHERE student_id = auth.uid() OR public.is_admin(auth.uid()::text))
           OR public.is_admin(auth.uid()::text))
    WITH CHECK (lease_id IN (SELECT id FROM public.leases WHERE student_id = auth.uid())
           OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Concerns visible to tenant/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Concerns visible to tenant/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- COMPLAINTS -----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.complaints TO authenticated;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Complaints visible to parties" ON public.complaints;
  CREATE POLICY "Complaints visible to parties"
    ON public.complaints FOR ALL TO authenticated
    USING (student_id = auth.uid() OR landlord_id = auth.uid() OR osas_officer_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (student_id = auth.uid() OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Complaints visible to parties".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Complaints visible to parties" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- COMPLAINT_TIMELINE ---------------------------------------------------------
GRANT SELECT, INSERT ON public.complaint_timeline TO authenticated;
ALTER TABLE public.complaint_timeline ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Complaint timeline visible to parties" ON public.complaint_timeline;
  CREATE POLICY "Complaint timeline visible to parties"
    ON public.complaint_timeline FOR SELECT TO authenticated
    USING (complaint_id IN (
      SELECT id FROM public.complaints
      WHERE student_id = auth.uid() OR landlord_id = auth.uid() OR osas_officer_id = auth.uid() OR public.is_admin(auth.uid()::text)));
  RAISE NOTICE 'Applied policy "Complaint timeline visible to parties".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Complaint timeline visible to parties" — is_admin() signature may differ. %', SQLERRM;
END $$;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Complaint timeline insert by actor" ON public.complaint_timeline;
  CREATE POLICY "Complaint timeline insert by actor"
    ON public.complaint_timeline FOR INSERT TO authenticated
    WITH CHECK (actor_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Complaint timeline insert by actor".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Complaint timeline insert by actor" — is_admin() signature may differ. %', SQLERRM;
END $$;
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
-- ============================================================================
-- Student module access — Part 4: reviews, announcements, history, docs, audit
-- Additive only. Idempotent.
-- Public-read policies (no is_admin) are applied directly. is_admin-dependent
-- policies are wrapped in guarded DO blocks so a signature mismatch skips ONLY
-- that policy (with a NOTICE) instead of rolling back the whole file.
-- ============================================================================

-- ANNOUNCEMENTS (public read) ------------------------------------------------
GRANT SELECT ON public.announcements TO anon, authenticated;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Announcements public read" ON public.announcements;
CREATE POLICY "Announcements public read"
  ON public.announcements FOR SELECT TO anon, authenticated USING (true);

-- POLICIES (app policy document, public read) --------------------------------
GRANT SELECT ON public.policies TO anon, authenticated;
ALTER TABLE public.policies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Policies public read" ON public.policies;
CREATE POLICY "Policies public read"
  ON public.policies FOR SELECT TO anon, authenticated USING (true);

-- BOARDING_HISTORY -----------------------------------------------------------
GRANT SELECT ON public.boarding_history TO authenticated;
ALTER TABLE public.boarding_history ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Boarding history visible to student/admin" ON public.boarding_history;
  CREATE POLICY "Boarding history visible to student/admin"
    ON public.boarding_history FOR SELECT TO authenticated
    USING (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Boarding history visible to student/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Boarding history visible to student/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- PROPERTY_REVIEWS (public read; students author their own) ------------------
GRANT SELECT ON public.property_reviews TO anon, authenticated;
GRANT INSERT, UPDATE ON public.property_reviews TO authenticated;
ALTER TABLE public.property_reviews ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property reviews visible with property" ON public.property_reviews;
  CREATE POLICY "Property reviews visible with property"
    ON public.property_reviews FOR SELECT TO anon, authenticated
    USING (property_id IN (
      SELECT id FROM public.properties
      WHERE status = 'accredited' OR landlord_id = auth.uid() OR public.is_admin(auth.uid()::text)));
  RAISE NOTICE 'Applied policy "Property reviews visible with property".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property reviews visible with property" — is_admin() signature may differ. %', SQLERRM;
END $$;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Property reviews authored by student" ON public.property_reviews;
  CREATE POLICY "Property reviews authored by student"
    ON public.property_reviews FOR INSERT TO authenticated
    WITH CHECK (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Property reviews authored by student".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Property reviews authored by student" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- LANDLORD_REVIEWS (public read; students author their own) ------------------
GRANT SELECT ON public.landlord_reviews TO authenticated;
GRANT INSERT, UPDATE ON public.landlord_reviews TO authenticated;
ALTER TABLE public.landlord_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Landlord reviews public read" ON public.landlord_reviews;
CREATE POLICY "Landlord reviews public read"
  ON public.landlord_reviews FOR SELECT TO authenticated USING (true);
DO $$
BEGIN
  DROP POLICY IF EXISTS "Landlord reviews authored by student" ON public.landlord_reviews;
  CREATE POLICY "Landlord reviews authored by student"
    ON public.landlord_reviews FOR INSERT TO authenticated
    WITH CHECK (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Landlord reviews authored by student".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Landlord reviews authored by student" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- TENANT_REVIEWS (public read; students author their own) --------------------
GRANT SELECT ON public.tenant_reviews TO authenticated;
GRANT INSERT, UPDATE ON public.tenant_reviews TO authenticated;
ALTER TABLE public.tenant_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Tenant reviews public read" ON public.tenant_reviews;
CREATE POLICY "Tenant reviews public read"
  ON public.tenant_reviews FOR SELECT TO authenticated USING (true);
DO $$
BEGIN
  DROP POLICY IF EXISTS "Tenant reviews authored by student" ON public.tenant_reviews;
  CREATE POLICY "Tenant reviews authored by student"
    ON public.tenant_reviews FOR INSERT TO authenticated
    WITH CHECK (student_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Tenant reviews authored by student".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Tenant reviews authored by student" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- VERIFICATION_DOCUMENTS (owner / OSAS-admin) --------------------------------
GRANT SELECT, INSERT, UPDATE ON public.verification_documents TO authenticated;
ALTER TABLE public.verification_documents ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Verification documents visible to owner/admin" ON public.verification_documents;
  CREATE POLICY "Verification documents visible to owner/admin"
    ON public.verification_documents FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin(auth.uid()::text))
    WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Verification documents visible to owner/admin".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Verification documents visible to owner/admin" — is_admin() signature may differ. %', SQLERRM;
END $$;

-- AUDIT_LOGS (admin only) ----------------------------------------------------
GRANT SELECT ON public.audit_logs TO authenticated;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  DROP POLICY IF EXISTS "Audit logs admin only" ON public.audit_logs;
  CREATE POLICY "Audit logs admin only"
    ON public.audit_logs FOR SELECT TO authenticated
    USING (public.is_admin(auth.uid()::text));
  RAISE NOTICE 'Applied policy "Audit logs admin only".';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'SKIPPED "Audit logs admin only" — is_admin() signature may differ. %', SQLERRM;
END $$;
-- ============================================================================
-- Backfill landlord display names (DATA only — NULL-safe, idempotent)
-- Run in Supabase SQL Editor AFTER the access grants are applied.
-- Only fills missing values; never overwrites existing real names.
-- ============================================================================

-- 0) Make sure authenticated can read the name tables (idempotent).
GRANT SELECT ON public.users TO authenticated;
GRANT SELECT ON public.landlord_profiles TO authenticated;

-- 1) Ensure every user has a full_name (fallback to the email local-part).
UPDATE public.users
SET full_name = COALESCE(NULLIF(full_name, ''), split_part(email, '@', 1))
WHERE full_name IS NULL OR full_name = '';

-- 2) Backfill landlord_profiles.business_name from the owner's full_name.
UPDATE public.landlord_profiles lp
SET business_name = COALESCE(
  lp.business_name,
  (SELECT u.full_name FROM public.users u WHERE u.id = lp.user_id),
  'Property Owner'
)
WHERE lp.business_name IS NULL;

-- 3) Diagnostic: list properties that have NO linked landlord.
--    If any show up, the card will still say "Landlord" until you link them, e.g.:
--    UPDATE public.properties SET landlord_id = '<owner-user-id>'
--    WHERE landlord_id IS NULL;
-- SELECT id, name, landlord_id FROM public.properties WHERE landlord_id IS NULL;
-- Verification queue access fix: admin role check does not depend on is_admin().
DROP POLICY IF EXISTS "Verification documents visible to owner/admin" ON public.verification_documents;
GRANT SELECT, INSERT, UPDATE ON public.verification_documents TO authenticated;
ALTER TABLE public.verification_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Verification documents visible to owner/admin"
  ON public.verification_documents FOR ALL TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- Verification queue RPC: joins users and pending documents server-side so the
-- admin queue does not depend on client-side RLS joins.
CREATE OR REPLACE FUNCTION public.get_verification_queue()
RETURNS TABLE (
  user_id uuid, full_name text, email text, role text, user_status text,
  created_at timestamptz, doc_type text, file_url text, filename text, doc_status text
)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT u.id, u.full_name, u.email, u.role::text, u.status::text, u.created_at,
         d.doc_type, d.file_url, d.filename, d.status::text
  FROM public.users u
  LEFT JOIN public.verification_documents d
    ON d.user_id = u.id AND d.status = 'pending'
  WHERE u.status::text IN ('pending', 'reviewing')
     OR d.id IS NOT NULL
  ORDER BY u.created_at DESC NULLS LAST, d.uploaded_at DESC NULLS LAST;
$$;
REVOKE ALL ON FUNCTION public.get_verification_queue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_verification_queue() TO authenticated;
