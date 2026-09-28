-- Who holds a review, and since when.
--
-- `status = 'reviewing'` means a reviewer currently has the request open, but
-- the tables carried no record of WHICH reviewer or from WHEN, so the claim was
-- asserted and never checked. Any close that did not run the release path — a
-- crash, a killed browser, a dropped connection — left the row `reviewing` with
-- nobody in it, and the queue went on showing "In review" on requests no admin
-- was looking at.
--
-- These two columns let the console prove the opposite: a lock whose holder is
-- absent from the review presence channel AND whose timestamp has aged out is
-- abandoned, and is swept back to `pending`. Presence answers the online case in
-- seconds; `reviewing_at` is the floor that keeps a live lock from being freed
-- merely because Realtime is slow, disabled or stubbed.
--
-- Nullable, no defaults, no RLS change: admins already hold row-level update on
-- both tables and Postgres policies are row-level, not column-level.

alter table public.users
  add column if not exists reviewing_by uuid references public.users(id) on delete set null,
  add column if not exists reviewing_at timestamptz;

alter table public.accommodations
  add column if not exists reviewing_by uuid references public.users(id) on delete set null,
  add column if not exists reviewing_at timestamptz;

comment on column public.users.reviewing_by is
  'Admin who currently has this verification request open. Null when nobody does.';
comment on column public.users.reviewing_at is
  'When the current review claim was taken. Used to age out an abandoned lock.';
comment on column public.accommodations.reviewing_by is
  'Admin who currently has this accreditation request open. Null when nobody does.';
comment on column public.accommodations.reviewing_at is
  'When the current review claim was taken. Used to age out an abandoned lock.';

-- The queue has to return the lock so the console can judge it. Return type
-- changes, hence drop rather than replace.
drop function if exists public.get_verification_queue();

create function public.get_verification_queue()
returns table (user_id uuid, full_name text, email text, role text, user_status text,
               created_at timestamptz, reviewing_by uuid, reviewing_at timestamptz,
               doc_id uuid, doc_type text, file_url text,
               filename text, doc_status text)
language sql security definer set search_path = public as $$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.created_at, u.reviewing_by, u.reviewing_at,
         d.id, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = 'pending'
  where public.is_admin(auth.uid())
    and u.status::text in ('pending','reviewing')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$$;

revoke all on function public.get_verification_queue() from public;
grant execute on function public.get_verification_queue() to authenticated;
