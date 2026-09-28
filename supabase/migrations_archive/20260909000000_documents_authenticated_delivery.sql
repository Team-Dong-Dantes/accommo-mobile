-- Sensitive documents move to Cloudinary `authenticated` delivery.
--
-- Cloudinary's default `upload` type serves assets at unauthenticated URLs, so
-- the link itself was the credential: readable by anyone who ever saw it and
-- unaffected by a later rejection. A private Supabase bucket is deliberately NOT
-- the answer here — this project stores every file in Cloudinary — so documents
-- are uploaded with delivery type `authenticated` and read through short-lived
-- signed URLs minted by the `doc-access` edge function, which holds the API
-- secret and authorizes each read by re-running the caller's own RLS.
--
-- file_url now holds a reference, not a URL:
--   cld:<resource_type>:<type>:<format>:<public_id>
-- Rows predating the move keep a plain URL and are passed through unchanged.
--
-- The accompanying data migration (run once, out of band) converted all 64
-- existing documents: 25 were pulled out of the old Supabase bucket and
-- re-uploaded, 39 public Cloudinary assets were renamed to `authenticated`, and
-- their cached derived variants were invalidated so the CDN copies died too.

-- The reviewer needs the document row id to request a signed URL, so the queue
-- returns it. Return type changes, hence drop rather than replace.
drop function if exists public.get_verification_queue();

create function public.get_verification_queue()
returns table (user_id uuid, full_name text, email text, role text, user_status text,
               created_at timestamptz, doc_id uuid, doc_type text, file_url text,
               filename text, doc_status text)
language sql security definer set search_path = public as $$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.created_at, d.id, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = 'pending'
  where public.is_admin(auth.uid())
    and u.status::text in ('pending','reviewing')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$$;

revoke all on function public.get_verification_queue() from public;
grant execute on function public.get_verification_queue() to authenticated;

-- Buckets are not used in this project. The `documents` bucket was emptied and
-- deleted through the Storage API once every file had been migrated and verified;
-- these policies have nothing left to govern.
drop policy if exists "Admins can read all documents" on storage.objects;
drop policy if exists "Users can read their own documents" on storage.objects;
drop policy if exists "Users can upload their own documents" on storage.objects;
drop policy if exists "Users can delete their own documents" on storage.objects;
