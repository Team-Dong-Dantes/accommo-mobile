-- Run this in Supabase SQL Editor
-- Function to check if a student ID already exists (prevents enumeration)

CREATE OR REPLACE FUNCTION check_student_id_exists(p_student_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM student_profiles WHERE student_id = p_student_id
  ) INTO v_exists;
  RETURN v_exists;
END;
$$;

-- RLS Policy for the users table to prevent privilege escalation
-- Run these to enforce row-level security

-- Users table: users can only read/modify their own row
CREATE POLICY "Users can read own data"
ON public.users
FOR SELECT
TO authenticated
USING (id = auth.uid());

CREATE POLICY "Users can update own data"
ON public.users
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- student_profiles: users can only access their own
CREATE POLICY "Students can read own profile"
ON public.student_profiles
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Students can insert own profile"
ON public.student_profiles
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- landlord_profiles: landlords can only access their own
CREATE POLICY "Landlords can read own profile"
ON public.landlord_profiles
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Landlords can insert own profile"
ON public.landlord_profiles
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());
