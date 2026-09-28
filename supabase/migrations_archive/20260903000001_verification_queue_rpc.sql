-- Return the verification queue as one server-side result. This avoids losing
-- users when the admin client can see document rows but cannot join public.users
-- through the browser's RLS context.
CREATE OR REPLACE FUNCTION public.get_verification_queue()
RETURNS TABLE (
  user_id uuid,
  full_name text,
  email text,
  role text,
  user_status text,
  created_at timestamptz,
  doc_type text,
  file_url text,
  filename text,
  doc_status text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id,
    u.full_name,
    u.email,
    u.role::text,
    u.status::text,
    u.created_at,
    d.doc_type,
    d.file_url,
    d.filename,
    d.status::text
  FROM public.users AS u
  LEFT JOIN public.verification_documents AS d
    ON d.user_id = u.id
   AND d.status = 'pending'
  WHERE u.status::text IN ('pending', 'reviewing')
     OR d.id IS NOT NULL
  ORDER BY u.created_at DESC NULLS LAST, d.uploaded_at DESC NULLS LAST;
$$;

REVOKE ALL ON FUNCTION public.get_verification_queue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_verification_queue() TO authenticated;
