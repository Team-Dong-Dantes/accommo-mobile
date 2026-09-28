-- accommo-web shows the applicant's profile photo in the verification queue, and
-- this function is the only source the queue reads from. Adding a column to a
-- set-returning function means dropping it first; everything else is verbatim.
drop function if exists public.get_verification_queue();

create function public.get_verification_queue()
returns table(
  user_id uuid, full_name text, email text, role text, user_status text,
  avatar_url text,
  created_at timestamp with time zone, reviewing_by uuid, reviewing_at timestamp with time zone,
  doc_id uuid, doc_type text, file_url text, filename text, doc_status text
)
language sql
security definer
set search_path to 'public'
as $function$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.avatar_url,
         u.created_at, u.reviewing_by, u.reviewing_at,
         d.id, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = 'pending'
  where public.is_admin(auth.uid())
    and u.status::text in ('pending','reviewing')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$function$;

grant execute on function public.get_verification_queue() to anon, authenticated, service_role;
