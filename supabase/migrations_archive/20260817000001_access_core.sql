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
