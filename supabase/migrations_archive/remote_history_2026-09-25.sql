SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict VlGLV72KO2ONmNHSEtT07eXgBK3EPWPgvwkvtPDMmXzVqOFabdxhjnJlJniVYDN

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: supabase_migrations; Owner: postgres
--

INSERT INTO "supabase_migrations"."schema_migrations" ("version", "statements", "name", "created_by", "idempotency_key", "rollback") VALUES
	('20260720000000', '{}', 'remote', NULL, NULL, NULL),
	('20260720000002', '{}', 'remote', NULL, NULL, NULL),
	('20260720000003', '{}', 'remote', NULL, NULL, NULL),
	('20260720000004', '{}', 'remote', NULL, NULL, NULL),
	('20260730132551', '{"-- Function: check if student ID exists (used by registration form)
CREATE OR REPLACE FUNCTION check_student_id_exists(p_student_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM student_profiles WHERE student_id = p_student_id) INTO v_exists;
  RETURN v_exists;
END;
$$","-- Create documents storage bucket (5MB limit, images + PDF)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  ''documents'',
  ''documents'',
  true,
  5242880,
  ARRAY[''image/jpeg'', ''image/png'', ''image/webp'', ''application/pdf'']::text[]
)
ON CONFLICT (id) DO NOTHING","-- Allow users to upload their own documents
CREATE POLICY \"Users can upload their own documents\"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = ''documents''
  AND (storage.foldername(name))[1] = auth.uid()::text
)","-- Allow users to read their own documents
CREATE POLICY \"Users can read their own documents\"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = ''documents''
  AND (storage.foldername(name))[1] = auth.uid()::text
)","-- Allow public read (needed for displaying uploaded files)
CREATE POLICY \"Anyone can read documents\"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = ''documents'')"}', 'setup_accommo', NULL, NULL, NULL),
	('20260816000000', '{"-- Allow authenticated users to view other users'' public profile info.
--
-- The app needs to show landlord names in the student dashboard, discover
-- page, and messaging (e.g. \"Mario Santos\" on a boarding house card). Without
-- this policy, RLS limits users to reading only their own row, so any query
-- for another user''s id returns an empty set.
--
-- This is scoped to SELECT only (no insert/update/delete) and exposes only the
-- non-sensitive columns that are safe to share across roles.

CREATE POLICY \"Authenticated users can view public profile info\"
ON public.users
FOR SELECT
TO authenticated
USING (true)"}', 'user_public_profile_read', NULL, NULL, NULL),
	('20260904175957', '{"-- Keep rooms.status/current_pax in sync with active leases.
-- No existing app code writes to rooms.status/current_pax (verified against
-- both accommo-web and accommo-mobile), so this trigger can own both columns
-- outright. ''maintenance'' is left alone as a manually-set state.

create or replace function public.recompute_room_occupancy(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_count integer;
  v_capacity integer;
  v_status room_status;
begin
  select count(*) into v_active_count from leases where room_id = p_room_id and status = ''active'';
  select capacity, status into v_capacity, v_status from rooms where id = p_room_id;
  if v_capacity is null then
    return;
  end if;

  update rooms
  set current_pax = v_active_count,
      status = case
        when v_active_count >= v_capacity then ''occupied''::room_status
        when v_status = ''maintenance'' then ''maintenance''::room_status
        else ''available''::room_status
      end
  where id = p_room_id;
end;
$$;

create or replace function public.sync_room_occupancy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recompute_room_occupancy(new.room_id);
  if tg_op = ''UPDATE'' and old.room_id is distinct from new.room_id then
    perform public.recompute_room_occupancy(old.room_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_room_occupancy on public.leases;
create trigger trg_sync_room_occupancy
after insert or update of status, room_id on public.leases
for each row
execute function public.sync_room_occupancy();

-- One-time backfill for rows already out of sync.
select public.recompute_room_occupancy(id) from public.rooms;
"}', 'sync_room_occupancy', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260905203934', '{"alter table public.accommodation_facilities add column floor integer;"}', 'add_facility_floor', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260905212912', '{"create policy accommodations_delete_rejected_own
  on public.accommodations for delete
  to authenticated
  using (accommodation_manager_id = auth.uid() and status = ''rejected'');"}', 'allow_delete_rejected_accommodations', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260906115119', '{"ALTER TABLE public.messages ADD COLUMN attachment_url text;"}', 'add_message_attachment_url', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260907084405', '{"-- Managers can now reject a payment (not just verify it), with a reason.
alter type payment_status add value if not exists ''rejected'';

alter table payments add column if not exists rejection_reason text;
"}', 'add_payment_rejection', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260907101602', '{"alter table public.concerns add column if not exists in_progress_at timestamptz;
alter table public.concerns add column if not exists photo_url text;
alter publication supabase_realtime add table public.concerns;"}', 'concerns_trail_photo_realtime', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260907114012', '{"alter table public.users add column if not exists avatar_url text;"}', 'add_users_avatar_url', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260904182807', '{"-- Two guards for the new student-apply / manager-review workflow:
--
-- (a) Nothing today stops a manager from accepting more active leases than a
--     room''s capacity. Guard it at the source, not in app code, so it holds
--     under concurrent accepts too.
-- (b) The RLS policy letting a student insert a pending application never
--     actually checked OSAS verification, despite older app code assuming
--     RLS was the real backstop. Close that gap.

create or replace function public.guard_room_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_capacity integer;
  v_active_count integer;
begin
  select capacity into v_capacity from rooms where id = new.room_id;
  if v_capacity is null then
    return new;
  end if;

  select count(*) into v_active_count
  from leases
  where room_id = new.room_id
    and status = ''active''
    and id is distinct from new.id;

  if v_active_count + 1 > v_capacity then
    raise exception ''This room is already at full capacity.'';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_room_capacity on public.leases;
create trigger trg_guard_room_capacity
before insert or update of status on public.leases
for each row
when (new.status = ''active'')
execute function public.guard_room_capacity();

alter policy leases_insert_student_application on public.leases
with check (
  (student_id = (select auth.uid()))
  and (status = ''pending''::lease_status)
  and exists (
    select 1 from rooms r join accommodations a on a.id = r.accommodation_id
    where r.id = leases.room_id and a.accommodation_manager_id = leases.accommodation_manager_id
  )
  and exists (
    select 1 from student_profiles sp
    where sp.user_id = leases.student_id and sp.osas_verified_at is not null
  )
);
"}', 'lease_application_guards', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260904183601', '{"-- trg_enforce_room_capacity / enforce_room_capacity() already existed live in
-- the DB (undocumented in any tracked migration) and does the same job as the
-- trigger just added in 20260905010000_lease_application_guards.sql, more
-- completely (it also counts leave_requested as still occupying a bed).
-- Drop the redundant duplicate rather than run two capacity guards.
drop trigger if exists trg_guard_room_capacity on public.leases;
drop function if exists public.guard_room_capacity();"}', 'drop_redundant_capacity_guard', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260904185548', '{"insert into public.student_profiles (user_id, osas_verified_at)
select u.id, now()
from public.users u
where u.role = ''student'' and u.status = ''verified''
on conflict (user_id) do update
set osas_verified_at = coalesce(student_profiles.osas_verified_at, excluded.osas_verified_at);"}', 'backfill_osas_verified_at', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260904190503', '{"create or replace function public.recompute_room_occupancy(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_count integer;
  v_capacity integer;
  v_status room_status;
begin
  select count(*) into v_active_count from leases where room_id = p_room_id and status in (''active'', ''leave_requested'');
  select capacity, status into v_capacity, v_status from rooms where id = p_room_id;
  if v_capacity is null then
    return;
  end if;

  update rooms
  set current_pax = v_active_count,
      status = case
        when v_active_count >= v_capacity then ''occupied''::room_status
        when v_status = ''maintenance'' then ''maintenance''::room_status
        else ''available''::room_status
      end
  where id = p_room_id;
end;
$$;
"}', 'leave_requested_still_occupies', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260904195756', '{"-- All three review tables had RLS that made them unusable as designed. The
-- bug wasn''t limited to INSERT — UPDATE and DELETE on two of the three
-- tables had the identical mistake: every write policy checked the SUBJECT
-- of the review instead of its AUTHOR.
--
-- - accommodation_manager_reviews (student reviews manager): insert/update/
--   delete all checked accommodation_manager_id = auth.uid() — the manager
--   being reviewed, not the student writing the review. A student could
--   never write, edit, or delete their own review. No student SELECT policy
--   either, so a correctly-inserted row (impossible anyway) couldn''t even
--   be read back by its author.
-- - tenant_reviews (manager reviews student): insert/update/delete all
--   checked student_id = auth.uid() — the tenant being reviewed, not the
--   manager writing the review. Same bug, opposite direction. No manager
--   SELECT policy.
-- - accommodation_reviews (student reviews accommodation): write policies
--   were correct, but a `roles: public, qual: true` SELECT policy made
--   every review readable by anyone, including anonymous visitors —
--   contradicting the intended design.
--
-- Design: a review is visible to the party who wrote it and the party it''s
-- about, never to anyone else. Writes are gated on the author actually
-- having a completed (ended/terminated) lease connecting them to the party
-- being reviewed, so a review can''t be fabricated against an unrelated
-- lease/accommodation/manager/tenant.

-- ---- accommodation_reviews (student -> accommodation), author = student ----
drop policy if exists accommodation_reviews_select_public on public.accommodation_reviews;

drop policy if exists accommodation_reviews_insert_own_student on public.accommodation_reviews;
create policy accommodation_reviews_insert_own_student on public.accommodation_reviews
for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (
    select 1 from leases l
    where l.id = accommodation_reviews.lease_id
      and l.student_id = auth.uid()
      and l.status in (''ended'', ''terminated'')
      and exists (
        select 1 from rooms r
        where r.id = l.room_id and r.accommodation_id = accommodation_reviews.accommodation_id
      )
  )
);

drop policy if exists accommodation_reviews_select_own_student on public.accommodation_reviews;
create policy accommodation_reviews_select_involved on public.accommodation_reviews
for select to authenticated
using (
  student_id = auth.uid()
  or exists (
    select 1 from accommodations a
    where a.id = accommodation_reviews.accommodation_id and a.accommodation_manager_id = auth.uid()
  )
);

alter table public.accommodation_reviews
  add constraint accommodation_reviews_rating_range check (rating between 1 and 5);

-- ---- accommodation_manager_reviews (student -> manager), author = student ----
drop policy if exists accommodation_manager_reviews_insert_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_insert_own_student on public.accommodation_manager_reviews
for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (
    select 1 from leases l
    where l.id = accommodation_manager_reviews.lease_id
      and l.student_id = auth.uid()
      and l.status in (''ended'', ''terminated'')
      and l.accommodation_manager_id = accommodation_manager_reviews.accommodation_manager_id
  )
);

drop policy if exists accommodation_manager_reviews_update_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_update_own_student on public.accommodation_manager_reviews
for update to authenticated
using (student_id = auth.uid())
with check (student_id = auth.uid());

drop policy if exists accommodation_manager_reviews_delete_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_delete_own_student on public.accommodation_manager_reviews
for delete to authenticated
using (student_id = auth.uid());

drop policy if exists accommodation_manager_reviews_select_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_select_involved on public.accommodation_manager_reviews
for select to authenticated
using (accommodation_manager_id = auth.uid() or student_id = auth.uid());

alter table public.accommodation_manager_reviews
  add constraint accommodation_manager_reviews_rating_range check (rating between 1 and 5);

-- ---- tenant_reviews (manager -> student), author = manager ----
drop policy if exists tenant_reviews_insert_own_student on public.tenant_reviews;
create policy tenant_reviews_insert_own_manager on public.tenant_reviews
for insert to authenticated
with check (
  accommodation_manager_id = auth.uid()
  and exists (
    select 1 from leases l
    where l.id = tenant_reviews.lease_id
      and l.accommodation_manager_id = auth.uid()
      and l.status in (''ended'', ''terminated'')
      and l.student_id = tenant_reviews.student_id
  )
);

drop policy if exists tenant_reviews_update_own_student on public.tenant_reviews;
create policy tenant_reviews_update_own_manager on public.tenant_reviews
for update to authenticated
using (accommodation_manager_id = auth.uid())
with check (accommodation_manager_id = auth.uid());

drop policy if exists tenant_reviews_delete_own_student on public.tenant_reviews;
create policy tenant_reviews_delete_own_manager on public.tenant_reviews
for delete to authenticated
using (accommodation_manager_id = auth.uid());

drop policy if exists tenant_reviews_select_own_student on public.tenant_reviews;
create policy tenant_reviews_select_involved on public.tenant_reviews
for select to authenticated
using (student_id = auth.uid() or accommodation_manager_id = auth.uid());

alter table public.tenant_reviews
  add constraint tenant_reviews_rating_range check (rating between 1 and 5);
"}', 'fix_review_rls', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260905065419', '{"alter table public.users
  add column if not exists notification_prefs jsonb not null default ''{\"push\": true, \"email\": true}''::jsonb;
"}', 'add_notification_prefs', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260905183249', '{"alter table public.rooms
  add column advance_months integer,
  add column deposit_months integer;"}', 'add_room_advance_deposit_months', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260905184551', '{"alter table public.rooms
  add column rent_basis text not null default ''room''
  check (rent_basis in (''room'', ''person''));"}', 'add_room_rent_basis', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260905192004', '{"alter table public.leases
  drop constraint leases_room_id_fkey,
  add constraint leases_room_id_fkey
    foreign key (room_id) references public.rooms(id)
    on delete restrict;"}', 'restrict_lease_room_delete', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260905194211', '{"create table public.accommodation_floors (
  accommodation_id uuid not null references public.accommodations(id) on delete cascade,
  floor_number integer not null,
  created_at timestamptz not null default now(),
  primary key (accommodation_id, floor_number)
);

alter table public.accommodation_floors enable row level security;

create policy accommodation_floors_select_own
  on public.accommodation_floors for select
  to authenticated
  using (
    exists (
      select 1 from public.accommodations a
      where a.id = accommodation_floors.accommodation_id
        and a.accommodation_manager_id = auth.uid()
    )
  );

create policy accommodation_floors_insert_own
  on public.accommodation_floors for insert
  to authenticated
  with check (
    exists (
      select 1 from public.accommodations a
      where a.id = accommodation_floors.accommodation_id
        and a.accommodation_manager_id = auth.uid()
    )
  );

create policy accommodation_floors_delete_own
  on public.accommodation_floors for delete
  to authenticated
  using (
    exists (
      select 1 from public.accommodations a
      where a.id = accommodation_floors.accommodation_id
        and a.accommodation_manager_id = auth.uid()
    )
  );"}', 'add_accommodation_floors', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908145505', '{"create or replace function public.is_admin(p_uid uuid) returns boolean
language sql stable security definer set search_path = public set row_security = off as $$
  select exists (
    select 1 from public.users
    where id = p_uid and (role = ''admin'' or is_superadmin = true)
  );
$$;

create or replace function public.lock_user_privileges() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  allow_resubmit boolean := coalesce(current_setting(''app.resubmitting'', true), ''false'') = ''true'';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = ''INSERT'' then
    if new.role = ''admin'' and not public.is_admin(auth.uid()) then
      raise exception ''Insufficient privileges to assign the admin role.'';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      raise exception ''You are not allowed to change your own role.'';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = ''pending'' and old.status in (''rejected'',''unverified'') then
        return new;
      end if;
      raise exception ''You are not allowed to change your own account status.'';
    end if;
  end if;
  return new;
end $$;

update public.users set role = ''student''
where id = ''bbbb0001-0000-4000-8000-000000000001'' and role = ''admin'';

drop policy if exists admin_select_all_users on public.users;
create policy admin_select_all_users on public.users
  for select to authenticated using (public.is_admin(auth.uid()));

drop policy if exists \"Admins can update user statuses\" on public.users;
create policy users_update_admin on public.users
  for update to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists admin_select_all_accommodation_manager_profiles on public.accommodation_manager_profiles;
create policy admin_select_all_accommodation_manager_profiles on public.accommodation_manager_profiles
  for select to authenticated using (public.is_admin(auth.uid()));

drop policy if exists admin_select_all_verification_documents on public.verification_documents;
create policy admin_all_verification_documents on public.verification_documents
  for all to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists \"Verification documents visible to owner/admin\" on public.verification_documents;

drop policy if exists admin_select_all_student_profiles on public.student_profiles;
create policy admin_all_student_profiles on public.student_profiles
  for all to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = ''student_profiles'' then
    if tg_op = ''INSERT'' then
      if new.osas_verified_at is not null then
        raise exception ''Only OSAS may set verification status.'';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception ''Only OSAS may change verification status.'';
    end if;
  end if;

  if tg_table_name = ''accommodations'' then
    if tg_op = ''INSERT'' then
      if new.status <> ''pending'' then
        raise exception ''A new accommodation must start as pending.'';
      end if;
    elsif new.status is distinct from old.status then
      if not (coalesce(current_setting(''app.permit_review'', true), ''false'') = ''true''
              and old.status = ''accredited'' and new.status = ''reviewing'') then
        raise exception ''Only OSAS may change accreditation status.'';
      end if;
    end if;
  end if;

  if tg_table_name = ''verification_documents'' and new.status = ''approved'' then
    raise exception ''Only OSAS may approve a document.'';
  end if;

  return new;
end $$;

drop trigger if exists trg_lock_osas on public.student_profiles;
create trigger trg_lock_osas before insert or update on public.student_profiles
  for each row execute function public.lock_verification_columns();

drop trigger if exists trg_lock_accreditation on public.accommodations;
create trigger trg_lock_accreditation before insert or update on public.accommodations
  for each row execute function public.lock_verification_columns();

drop trigger if exists trg_lock_doc_review on public.verification_documents;
create trigger trg_lock_doc_review before insert or update on public.verification_documents
  for each row execute function public.lock_verification_columns();

drop policy if exists verification_documents_delete_own on public.verification_documents;
create policy verification_documents_delete_own on public.verification_documents
  for delete to authenticated
  using (user_id = (select auth.uid()) and status = ''pending'');

create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status in (''rejected'',''suspended'') and old.status = ''verified'' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where accommodation_manager_id = new.id and status = ''accredited'';
  end if;
  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify after update of status on public.users
  for each row execute function public.tg_revoke_on_unverify();

drop policy if exists leases_insert_student_application on public.leases;
create policy leases_insert_student_application on public.leases
  for insert to authenticated with check (
    student_id = (select auth.uid())
    and status = ''pending''
    and exists (
      select 1 from public.rooms r
      join public.accommodations a on a.id = r.accommodation_id
      where r.id = leases.room_id
        and a.accommodation_manager_id = leases.accommodation_manager_id
        and a.status = ''accredited'')
    and exists (
      select 1 from public.student_profiles sp
      where sp.user_id = leases.student_id and sp.osas_verified_at is not null)
  );

create or replace function public.get_verification_queue()
returns table (user_id uuid, full_name text, email text, role text, user_status text,
               created_at timestamptz, doc_type text, file_url text, filename text, doc_status text)
language sql security definer set search_path = public as $$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.created_at, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = ''pending''
  where public.is_admin(auth.uid())
    and u.status::text in (''pending'',''reviewing'')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$$;

revoke all on function public.get_verification_queue() from public;
grant execute on function public.get_verification_queue() to authenticated;

create or replace function public.resubmit_verification() returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select id, status into r from public.users where id = auth.uid();
  if r.id is null then raise exception ''Not signed in''; end if;
  if r.status in (''pending'',''reviewing'',''verified'') then return; end if;
  if r.status = ''suspended'' then raise exception ''Suspended accounts cannot resubmit.''; end if;
  perform set_config(''app.resubmitting'', ''true'', true);
  update public.users set status = ''pending'', updated_at = now() where id = r.id;
end $$;

create or replace function public.trg_new_verification() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if new.status = ''pending'' and new.user_id is not null
     and (tg_op = ''INSERT'' or new.file_url is distinct from old.file_url) then
    select coalesce(full_name, email) into v_name from public.users where id = new.user_id;
    perform public.notify_admins(
      ''New verification request'',
      coalesce(v_name, ''A user'') || '' submitted ''
        || coalesce(new.doc_type, ''documents'') || '' for review.'',
      ''verification'',
      ''/verifications?focus=verification:'' || new.user_id::text);
  end if;
  return new;
end $$;

drop trigger if exists trg_new_verification on public.verification_documents;
create trigger trg_new_verification after insert or update on public.verification_documents
  for each row execute function public.trg_new_verification();

create or replace function public.tg_permit_needs_review() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config(''app.permit_review'', ''true'', true);
  update public.accommodations set status = ''reviewing''
  where id = new.accommodation_id and status = ''accredited'';
  perform set_config(''app.permit_review'', ''false'', true);
  return new;
end $$;

drop trigger if exists trg_permit_needs_review on public.accommodation_documents;
create trigger trg_permit_needs_review after insert on public.accommodation_documents
  for each row execute function public.tg_permit_needs_review();

create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in (''user'',''accommodation'')),
  entity_id uuid not null,
  type text,
  status text not null check (status in (''approved'',''rejected'',''resubmission_requested'')),
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz not null default now(),
  rejection_reasons text[],
  decision_notes text,
  created_at timestamptz not null default now()
);
create index if not exists verification_requests_entity_idx
  on public.verification_requests (entity_type, entity_id, reviewed_at desc);

alter table public.verification_requests enable row level security;
grant select, insert on public.verification_requests to authenticated;

drop policy if exists verification_requests_admin_all on public.verification_requests;
create policy verification_requests_admin_all on public.verification_requests
  for all to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists verification_requests_select_subject on public.verification_requests;
create policy verification_requests_select_subject on public.verification_requests
  for select to authenticated using (
    (entity_type = ''user'' and entity_id = auth.uid())
    or (entity_type = ''accommodation'' and exists (
      select 1 from public.accommodations a
      where a.id = verification_requests.entity_id
        and a.accommodation_manager_id = auth.uid()))
  );

revoke truncate, references, trigger on
  public.accommodation_documents, public.accommodation_facilities,
  public.accommodation_facility_images, public.accommodation_floors,
  public.concerns, public.tickets, public.ticket_messages,
  public.latest_accommodation_documents
  from anon, authenticated;
revoke insert, update, delete on
  public.accommodation_documents, public.accommodation_facilities,
  public.accommodation_facility_images, public.accommodation_floors,
  public.latest_accommodation_documents
  from anon;

update public.verification_documents d
set status = (case when u.status = ''verified'' then ''approved'' else ''rejected'' end)::doc_status,
    verified_at = coalesce(d.verified_at, now())
from public.users u
where u.id = d.user_id and d.status = ''pending''
  and u.status not in (''pending'',''reviewing'');

insert into public.student_profiles (user_id, osas_verified_at)
select u.id, now() from public.users u
where u.role = ''student'' and u.status = ''verified''
on conflict (user_id) do update
set osas_verified_at = coalesce(student_profiles.osas_verified_at, excluded.osas_verified_at);

update public.accommodations a set status = ''reviewing''
where a.status = ''accredited''
  and (exists (select 1 from public.users u
               where u.id = a.accommodation_manager_id and u.status <> ''verified'')
   or not exists (select 1 from public.accommodation_documents d
                  where d.accommodation_id = a.id));"}', 'verification_hardening', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908150143', '{"-- Verification documents move off unauthenticated Cloudinary URLs into the
-- private `documents` bucket. OSAS could not read that bucket at all: the only
-- SELECT policy scoped rows to the uploader''s own folder.
drop policy if exists \"Admins can read all documents\" on storage.objects;
create policy \"Admins can read all documents\" on storage.objects
  for select to authenticated
  using (bucket_id = ''documents'' and public.is_admin(auth.uid()));

-- A user may replace their own document (a resubmission overwrites nothing, but
-- an aborted upload leaves a stale object behind).
drop policy if exists \"Users can delete their own documents\" on storage.objects;
create policy \"Users can delete their own documents\" on storage.objects
  for delete to authenticated
  using (bucket_id = ''documents'' and (storage.foldername(name))[1] = auth.uid()::text);"}', 'documents_bucket_admin_read', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908162428', '{"-- verification_requests inherited the stock Supabase default ACL, which grants
-- anon the full DML set including TRUNCATE. TRUNCATE is not subject to RLS, so
-- it is the one privilege in that set that RLS does not backstop.
revoke truncate, references, trigger on public.verification_requests from anon, authenticated;
revoke insert, update, delete on public.verification_requests from anon;

-- Stop the next table from inheriting the same thing. Only TRUNCATE is narrowed:
-- SELECT/INSERT/UPDATE/DELETE stay as Supabase expects, gated by RLS.
alter default privileges in schema public revoke truncate on tables from anon, authenticated;"}', 'revoke_truncate_defaults', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908164508', '{"-- Documents now live behind Cloudinary `authenticated` delivery, so the reviewer
-- needs the document row id to ask the doc-access function for a signed URL.
-- Return type changes, so the function has to be dropped rather than replaced.
drop function if exists public.get_verification_queue();

create function public.get_verification_queue()
returns table (user_id uuid, full_name text, email text, role text, user_status text,
               created_at timestamptz, doc_id uuid, doc_type text, file_url text,
               filename text, doc_status text)
language sql security definer set search_path = public as $$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.created_at, d.id, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = ''pending''
  where public.is_admin(auth.uid())
    and u.status::text in (''pending'',''reviewing'')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$$;

revoke all on function public.get_verification_queue() from public;
grant execute on function public.get_verification_queue() to authenticated;"}', 'queue_expose_doc_id', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908165148', '{"-- #10 (remainder): a permit that simply lapses used to change nothing.
-- expires_at was read only by three mobile manager screens; an accreditation
-- once granted never expired. A renewal already reopens review via
-- trg_permit_needs_review; this covers the permit nobody replaces.
create extension if not exists pg_cron;

create or replace function public.sweep_expired_permits() returns void
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  -- Latest version per (accommodation, doc_type); an accreditation lapses when
  -- the newest copy of any required permit is past its expiry.
  with latest as (
    select distinct on (d.accommodation_id, d.doc_type)
           d.accommodation_id, d.doc_type, d.expires_at
    from public.accommodation_documents d
    order by d.accommodation_id, d.doc_type, d.version desc
  ),
  lapsed as (
    select distinct accommodation_id from latest
    where expires_at is not null and expires_at < now()
  )
  update public.accommodations a
  set status = ''reviewing''
  where a.status = ''accredited''
    and a.id in (select accommodation_id from lapsed);
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      ''Accreditation needs review'',
      n || '' accommodation(s) have a permit that has expired and were sent back for review.'',
      ''verification'', ''/verifications'');
  end if;
end $$;

revoke all on function public.sweep_expired_permits() from public, anon, authenticated;

-- Daily at 18:00 UTC (02:00 Manila).
select cron.unschedule(''sweep-expired-permits'')
where exists (select 1 from cron.job where jobname = ''sweep-expired-permits'');

select cron.schedule(''sweep-expired-permits'', ''0 18 * * *'',
                     $$select public.sweep_expired_permits();$$);"}', 'permit_expiry_delist', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908165416', '{"-- Buckets are not used in this project: Cloudinary is the only file store, and
-- sensitive documents use its `authenticated` delivery with server-signed URLs.
-- Every document was migrated and verified, the bucket was emptied and deleted
-- through the Storage API, so these policies have nothing left to govern.
drop policy if exists \"Admins can read all documents\" on storage.objects;
drop policy if exists \"Users can read their own documents\" on storage.objects;
drop policy if exists \"Users can upload their own documents\" on storage.objects;
drop policy if exists \"Users can delete their own documents\" on storage.objects;"}', 'drop_storage_policies', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908172949', '{"-- users.status means \"OSAS reviewed this account''s documents\". It must never be
-- derived from e-mail confirmation, which only means \"this mailbox answered\".
-- The old branch set status=''verified'' whenever email_confirmed_at was already
-- present on the inserted auth row, which would mint an OSAS-verified account
-- that get_verification_queue() (it filters on pending/reviewing) never shows to
-- a reviewer. It is dormant today only because GoTrue confirms in a second
-- UPDATE — a fragile thing to rely on. New accounts always start pending.
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
begin
  if tg_op = ''INSERT'' then
    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      coalesce((new.raw_user_meta_data ->> ''sex'')::text, ''M''),
      new.email_confirmed_at,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          -- status deliberately NOT carried over: only OSAS moves it.
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          email_verified_at = excluded.email_verified_at,
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone),
        email_verified_at = coalesce(public.users.email_verified_at, new.email_confirmed_at),
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;

-- The registration duplicate-ID warning never fired: SECURITY INVOKER meant RLS
-- limited the lookup to the caller''s own student_profiles row, so it answered
-- \"not taken\" for every id. Only the unique constraint was catching duplicates,
-- at insert time. Definer + a narrow boolean return keeps this from leaking any
-- profile data — it answers exists/not-exists and nothing else.
create or replace function public.check_student_id_exists(p_student_id text)
returns boolean
language sql stable security definer set search_path = public
as $function$
  select exists (
    select 1 from public.student_profiles
    where student_id = p_student_id
  );
$function$;

revoke all on function public.check_student_id_exists(text) from public, anon;
grant execute on function public.check_student_id_exists(text) to authenticated;"}', 'auth_status_and_dup_check', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910183345', '{"DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = ''supabase_realtime'' AND tablename = ''announcements''
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
  END IF;
END $$;"}', 'announcements_realtime', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908173251', '{"-- Suspension has to bite below the app. The client now refuses to hold a session
-- for a suspended account, but Supabase Auth still issues the token — so anyone
-- calling the REST API directly with it would sail past that check, since RLS
-- knows nothing about users.status.
--
-- Suspending therefore bans the auth user and drops their live sessions; lifting
-- the suspension un-bans. This extends the existing revocation trigger rather
-- than adding a second one, so every path that suspends (web UI, SQL console,
-- future callers) gets it.
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
begin
  if new.status in (''rejected'',''suspended'') and old.status = ''verified'' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where accommodation_manager_id = new.id and status = ''accredited'';
  end if;

  if new.status = ''suspended'' and old.status is distinct from ''suspended'' then
    -- Far-future ban: GoTrue refuses new tokens and refreshes for a banned user.
    update auth.users set banned_until = ''infinity''::timestamptz where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
  elsif old.status = ''suspended'' and new.status is distinct from ''suspended'' then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify after update of status on public.users
  for each row execute function public.tg_revoke_on_unverify();"}', 'suspension_revokes_sessions', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908173334', '{"-- ''infinity'' is a valid timestamptz but GoTrue cannot serialise it, so a banned
-- user got an opaque HTTP 500 on sign-in instead of a clean refusal. A concrete
-- far-future timestamp bans just as effectively and keeps the error legible.
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
begin
  if new.status in (''rejected'',''suspended'') and old.status = ''verified'' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where accommodation_manager_id = new.id and status = ''accredited'';
  end if;

  if new.status = ''suspended'' and old.status is distinct from ''suspended'' then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
  elsif old.status = ''suspended'' and new.status is distinct from ''suspended'' then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify after update of status on public.users
  for each row execute function public.tg_revoke_on_unverify();"}', 'suspension_ban_finite_timestamp', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908174645', '{"-- Prove the applicant actually reads the address they signed up with.
--
-- Auto-confirm is on, so Supabase marks every e-mail confirmed the moment the
-- account is created and the \"type your code\" step gates nothing: the account
-- exists and works whether or not the code is ever entered. Anyone could sign up
-- on an address they do not own (and, because e-mail is unique, take it).
--
-- The OTP itself IS real proof — GoTrue checks a code it mailed. What was missing
-- was a record of it that the database could trust. A Supabase access token
-- carries an `amr` claim naming how it was obtained (\"password\" vs \"otp\"), signed
-- by GoTrue, so a token minted by an e-mail code is not forgeable by a client.
-- users.email_verified_at is therefore set ONLY here, only for a caller holding
-- such a token.

-- 1. Grandfather every account that already exists. 96 of 169 rows have no stamp
--    (29 of them OSAS-verified) because the old trigger only copied
--    auth.email_confirmed_at, so gating without this would lock them all out.
update public.users
set email_verified_at = coalesce(email_verified_at, created_at, now())
where email_verified_at is null;

-- 2. Stop fabricating the stamp. Previously the sync trigger copied
--    email_confirmed_at, which auto-confirm sets immediately — so every new
--    account was born \"verified\" and the gate would mean nothing.
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
begin
  if tg_op = ''INSERT'' then
    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      coalesce((new.raw_user_meta_data ->> ''sex'')::text, ''M''),
      null,          -- only confirm_email_ownership() may stamp this
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          -- status and email_verified_at deliberately NOT carried over.
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone),
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;

-- 3. The attestation itself.
create or replace function public.confirm_email_ownership()
returns boolean
language plpgsql security definer set search_path = public, auth
as $$
declare
  methods jsonb := coalesce(auth.jwt() -> ''amr'', ''[]''::jsonb);
  provider text;
begin
  if auth.uid() is null then
    raise exception ''Not signed in.'';
  end if;

  select raw_app_meta_data ->> ''provider'' into provider from auth.users where id = auth.uid();

  -- Either the current token came from an e-mail code (a password token cannot be
  -- used to claim inbox ownership), or an OAuth provider already vouched for the
  -- address, in which case there is no code to type.
  if not (
    exists (
      select 1 from jsonb_array_elements(methods) m
      where m ->> ''method'' in (''otp'', ''magiclink'', ''email'', ''oauth'')
    )
    or coalesce(provider, ''email'') <> ''email''
  ) then
    raise exception ''Verify your e-mail with the code first.'';
  end if;

  update public.users set email_verified_at = now(), updated_at = now()
  where id = auth.uid() and email_verified_at is null;
  return true;
end $$;

revoke all on function public.confirm_email_ownership() from public, anon;
grant execute on function public.confirm_email_ownership() to authenticated;

-- 4. email_verified_at joins role/status as a column its owner may not set.
create or replace function public.lock_user_privileges() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  allow_resubmit boolean := coalesce(current_setting(''app.resubmitting'', true), ''false'') = ''true'';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = ''INSERT'' then
    if new.role = ''admin'' and not public.is_admin(auth.uid()) then
      raise exception ''Insufficient privileges to assign the admin role.'';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      raise exception ''You are not allowed to change your own role.'';
    end if;
    -- Only confirm_email_ownership() (SECURITY DEFINER, so it bypasses this
    -- check) may stamp e-mail ownership; a client must not simply claim it.
    if new.email_verified_at is distinct from old.email_verified_at then
      raise exception ''You are not allowed to change your own e-mail verification.'';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = ''pending'' and old.status in (''rejected'',''unverified'') then
        return new;
      end if;
      raise exception ''You are not allowed to change your own account status.'';
    end if;
  end if;
  return new;
end $$;"}', 'email_ownership_attestation', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908174708', '{"-- SECURITY DEFINER does not change auth.uid(), so lock_user_privileges saw the
-- attestation''s own UPDATE as the user editing their own verification and refused
-- it. Same transaction-local flag the resubmit RPC uses: set by the one function
-- allowed to stamp, and unset automatically when the transaction ends.
create or replace function public.confirm_email_ownership()
returns boolean
language plpgsql security definer set search_path = public, auth
as $$
declare
  methods jsonb := coalesce(auth.jwt() -> ''amr'', ''[]''::jsonb);
  provider text;
begin
  if auth.uid() is null then
    raise exception ''Not signed in.'';
  end if;

  select raw_app_meta_data ->> ''provider'' into provider from auth.users where id = auth.uid();

  if not (
    exists (
      select 1 from jsonb_array_elements(methods) m
      where m ->> ''method'' in (''otp'', ''magiclink'', ''email'', ''oauth'')
    )
    or coalesce(provider, ''email'') <> ''email''
  ) then
    raise exception ''Verify your e-mail with the code first.'';
  end if;

  perform set_config(''app.confirming_email'', ''true'', true);
  update public.users set email_verified_at = now(), updated_at = now()
  where id = auth.uid() and email_verified_at is null;
  return true;
end $$;

revoke all on function public.confirm_email_ownership() from public, anon;
grant execute on function public.confirm_email_ownership() to authenticated;

create or replace function public.lock_user_privileges() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  allow_resubmit boolean := coalesce(current_setting(''app.resubmitting'', true), ''false'') = ''true'';
  allow_email boolean := coalesce(current_setting(''app.confirming_email'', true), ''false'') = ''true'';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = ''INSERT'' then
    if new.role = ''admin'' and not public.is_admin(auth.uid()) then
      raise exception ''Insufficient privileges to assign the admin role.'';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      raise exception ''You are not allowed to change your own role.'';
    end if;
    -- Only confirm_email_ownership() sets this flag, and only after checking the
    -- caller''s token really came from an e-mail code.
    if new.email_verified_at is distinct from old.email_verified_at and not allow_email then
      raise exception ''You are not allowed to change your own e-mail verification.'';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = ''pending'' and old.status in (''rejected'',''unverified'') then
        return new;
      end if;
      raise exception ''You are not allowed to change your own account status.'';
    end if;
  end if;
  return new;
end $$;"}', 'email_attestation_guard_escape', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908175059', '{"-- Someone can still occupy an e-mail address they do not own by starting a
-- registration and never confirming it — e-mail is unique, so the real owner is
-- then locked out. This releases addresses whose account never proved ownership.
--
-- NOT SCHEDULED. It deletes auth accounts, so it stays manual until someone
-- decides that is wanted:
--   select cron.schedule(''purge-unverified-accounts'',''30 18 * * 0'',
--                        $$select public.purge_unverified_accounts();$$);
--
-- Conservative by design: 30 days old, never confirmed, still pending, and with
-- nothing attached — no documents, no leases, no accommodations, no messages.
create or replace function public.purge_unverified_accounts(p_older_than interval default interval ''30 days'')
returns integer
language plpgsql security definer set search_path = public, auth
as $$
declare
  n integer;
begin
  with doomed as (
    select u.id
    from public.users u
    where u.email_verified_at is null
      and u.status = ''pending''
      and u.created_at < now() - p_older_than
      and not exists (select 1 from public.verification_documents d where d.user_id = u.id)
      and not exists (select 1 from public.leases l where l.student_id = u.id or l.accommodation_manager_id = u.id)
      and not exists (select 1 from public.accommodations a where a.accommodation_manager_id = u.id)
      and not exists (select 1 from public.messages m where m.sender_id = u.id)
  )
  delete from auth.users a using doomed d where a.id = d.id;
  get diagnostics n = row_count;

  if n > 0 then
    insert into public.audit_logs (action, actor_id, entity_type, after_json)
    values (''auth.purge_unverified'', null, ''user'',
            jsonb_build_object(''deleted'', n, ''older_than'', p_older_than::text));
  end if;
  return n;
end $$;

revoke all on function public.purge_unverified_accounts(interval) from public, anon, authenticated;"}', 'purge_unverified_accounts_fn', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913180214', '{"-- A 6-digit PIN in front of money and tenancy actions, and in front of the app
-- itself after it has been backgrounded.
--
-- What this defends: someone else driving a session that is already signed in --
-- the flatmate with your unlocked phone, which is the realistic case in a
-- boarding house. It is also a weak second factor if a password leaks.
--
-- What it does NOT defend: the account holder themselves (they set it), and it
-- does not change who is ALLOWED to do anything -- RLS remains the authority.
-- The gating is in the client, so a technical attacker holding a session token
-- can still call PostgREST directly. Closing that means requiring an elevation
-- window inside the leases/payments policies, which carry the OSAS gate and the
-- one-lease-per-student index, and is deliberately left for later.
--
-- The hash and every check live here rather than in the app, so the PIN cannot
-- be read out of local storage or compared in JavaScript that anyone can edit.

-- Separate table, not columns on users: users carries lock_user_privileges and
-- several policies, and this must never be client-readable at all.
create table if not exists public.user_pins (
  user_id      uuid primary key references public.users(id) on delete cascade,
  pin_hash     text not null,
  attempts     int  not null default 0,
  locked_until timestamptz,
  updated_at   timestamptz not null default now()
);

alter table public.user_pins enable row level security;
-- No policies at all. Every read and write goes through the SECURITY DEFINER
-- functions below, so there is no path by which a client sees a hash.
revoke all on public.user_pins from anon, authenticated;

-- ── Is a PIN set? ───────────────────────────────────────────────────────────
create or replace function public.has_pin()
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from public.user_pins where user_id = auth.uid());
$$;

-- ── Set or change ───────────────────────────────────────────────────────────
-- Six digits exactly, enforced HERE and not merely in the pad: a million
-- combinations instead of ten thousand, and the rule cannot be edited away in
-- the client. Changing an existing PIN requires the current one, so a held
-- session cannot silently replace it and lock the owner out.
create or replace function public.set_pin(p_pin text, p_current text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  if p_pin !~ ''^[0-9]{6}$'' then
    raise exception ''A PIN must be exactly 6 digits'';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is not null then
    if p_current is null or v_hash <> extensions.crypt(p_current, v_hash) then
      raise exception ''That is not your current PIN'';
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt(''bf'')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
end $$;

-- ── Turn it off ─────────────────────────────────────────────────────────────
create or replace function public.clear_pin(p_current text)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is null then return; end if;
  if v_hash <> extensions.crypt(p_current, v_hash) then
    raise exception ''That is not your current PIN'';
  end if;
  delete from public.user_pins where user_id = v_me;
end $$;

-- ── Verify ──────────────────────────────────────────────────────────────────
-- Throttled. Six digits makes offline guessing impractical, but an online
-- attacker with the phone in hand can still try one after another, so five
-- wrong attempts buys a 15-minute lockout -- and tells the owner it happened,
-- which is often the real value of a second factor.
create or replace function public.verify_pin(p_pin text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_row public.user_pins; v_ok boolean;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  select * into v_row from public.user_pins where user_id = v_me;
  if v_row.user_id is null then
    raise exception ''No PIN is set on this account'';
  end if;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    raise exception ''Too many attempts. Try again after %'',
      to_char(v_row.locked_until at time zone ''Asia/Manila'', ''HH12:MI AM'');
  end if;

  v_ok := v_row.pin_hash = extensions.crypt(p_pin, v_row.pin_hash);

  if v_ok then
    update public.user_pins set attempts = 0, locked_until = null where user_id = v_me;
    return true;
  end if;

  update public.user_pins
     set attempts = attempts + 1,
         locked_until = case when attempts + 1 >= 5 then now() + interval ''15 minutes'' end
   where user_id = v_me
  returning * into v_row;

  if v_row.locked_until is not null then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (
      v_me, ''security'', ''Incorrect PIN attempts'',
      ''Someone entered the wrong PIN 5 times on your account. If that was not you, change your password.'',
      null
    );
  end if;

  return false;
end $$;

-- ── Forgotten PIN ───────────────────────────────────────────────────────────
-- Resetting without the current PIN is only safe behind a fresh proof of
-- identity. Verifying an e-mail OTP mints a brand-new session, so requiring a
-- recently-issued JWT is exactly that proof -- and it reuses the OTP plumbing
-- registration already has, with no new mail to send.
create or replace function public.reset_pin(p_new text)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_iat bigint;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  if p_new !~ ''^[0-9]{6}$'' then raise exception ''A PIN must be exactly 6 digits''; end if;

  v_iat := nullif(auth.jwt() ->> ''iat'', '''')::bigint;
  if v_iat is null or v_iat < extract(epoch from now()) - 300 then
    raise exception ''Confirm the code sent to your e-mail first'';
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_new, extensions.gen_salt(''bf'')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
end $$;

revoke all on function public.has_pin() from public;
revoke all on function public.set_pin(text, text) from public;
revoke all on function public.clear_pin(text) from public;
revoke all on function public.verify_pin(text) from public;
revoke all on function public.reset_pin(text) from public;
grant execute on function public.has_pin() to authenticated;
grant execute on function public.set_pin(text, text) to authenticated;
grant execute on function public.clear_pin(text) to authenticated;
grant execute on function public.verify_pin(text) to authenticated;
grant execute on function public.reset_pin(text) to authenticated;"}', 'pin_lock', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908180937', '{"-- A Google sign-in was landing with email_verified_at = null, so the new e-mail
-- gate bounced it to a \"type the code we mailed you\" screen — for an address
-- Google had already verified, and which the user would never need a code for.
--
-- OAuth is proof of ownership by definition: the provider authenticated the
-- account holder against that address. Stamp it at insert rather than relying on
-- the client to call confirm_email_ownership() during profile completion, because
-- a returning OAuth user never runs that path at all.
--
-- Password sign-ups still get null and must type the code.
create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> ''provider'', ''email'');
begin
  if tg_op = ''INSERT'' then
    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      coalesce((new.raw_user_meta_data ->> ''sex'')::text, ''M''),
      -- OAuth vouches for the address; e-mail+password must prove it with a code.
      case when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          -- status deliberately NOT carried over: only OSAS moves it.
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone),
        -- Linking an OAuth identity later also proves ownership.
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;

-- Unstick any OAuth account already created without a stamp (including the one
-- that hit the redirect loop).
update public.users u
set email_verified_at = coalesce(u.email_verified_at, a.email_confirmed_at, u.created_at, now())
from auth.users a
where a.id = u.id
  and u.email_verified_at is null
  and coalesce(a.raw_app_meta_data ->> ''provider'', ''email'') <> ''email'';"}', 'oauth_signups_are_email_verified', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908181724', '{"-- \"Continue with Google\" on the LOGIN screen silently created a full account.
--
-- signInWithOAuth has no sign-in-only mode: it always provisions the user. The
-- auth-sync trigger then wrote a public.users row with role defaulting to
-- ''student'', because an OAuth signup carries no role in user_metadata. So a
-- manager who signed in with Google became a student, nobody ever saw the role
-- picker, and no student_profiles row was created. Live: 11 Google accounts, all
-- role=''student'', 9 with no profile at all.
--
-- Worse, the register screen detected \"new Google user\" as \"has a session but NO
-- users row\" — a condition the trigger makes impossible — so the whole
-- profile-completion path was dead code, and the router then bounced them with
-- \"account already exists\".
--
-- registered_at is the missing signal: null means the account exists but its
-- owner never finished registration, so send them to onboarding rather than into
-- the app.
alter table public.users add column if not exists registered_at timestamptz;

comment on column public.users.registered_at is
  ''When the owner completed registration. Null means an account exists (e.g. created by an OAuth sign-in) but onboarding was never finished; the app routes these to /register/role.'';

-- Grandfather anyone who demonstrably went through registration: a role-specific
-- profile, submitted documents, or an OSAS decision. Accounts with none of those
-- are genuinely half-finished and will be asked to complete onboarding.
update public.users u
set registered_at = coalesce(u.registered_at, u.created_at, now())
where u.registered_at is null
  and (
    exists (select 1 from public.student_profiles sp
             where sp.user_id = u.id and (sp.college is not null or sp.program is not null or sp.student_id is not null))
    or exists (select 1 from public.accommodation_manager_profiles mp where mp.user_id = u.id)
    or exists (select 1 from public.verification_documents d where d.user_id = u.id)
    or u.status in (''verified'',''rejected'',''suspended'')
    or u.role = ''admin''
  );

-- During onboarding the user must be able to pick their role, because OAuth
-- defaulted it to ''student'' without asking. Once registered_at is set it locks
-- again, and ''admin'' is never self-assignable.
create or replace function public.lock_user_privileges() returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  allow_resubmit boolean := coalesce(current_setting(''app.resubmitting'', true), ''false'') = ''true'';
  allow_email boolean := coalesce(current_setting(''app.confirming_email'', true), ''false'') = ''true'';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = ''INSERT'' then
    if new.role = ''admin'' and not public.is_admin(auth.uid()) then
      raise exception ''Insufficient privileges to assign the admin role.'';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      -- Choosing student vs manager is part of onboarding, and only then.
      if not (old.registered_at is null
              and new.role in (''student'',''accommodation_manager'')
              and old.role <> ''admin'') then
        raise exception ''You are not allowed to change your own role.'';
      end if;
    end if;
    if new.email_verified_at is distinct from old.email_verified_at and not allow_email then
      raise exception ''You are not allowed to change your own e-mail verification.'';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = ''pending'' and old.status in (''rejected'',''unverified'') then
        return new;
      end if;
      raise exception ''You are not allowed to change your own account status.'';
    end if;
    -- Registration completes once; it cannot be un-set to re-open role changes.
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception ''Registration is already complete.'';
    end if;
  end if;
  return new;
end $fn$;"}', 'registration_completion_flag', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908182647', '{"-- Manager registration never created an accommodation_manager_profiles row, so
-- managers had no profile record while every student had one. Nothing crashed —
-- all five read sites use maybeSingle() — but the manager side had nowhere to
-- hang responsiveness stats or admin review data, and the row is now created at
-- registration. Backfill the managers who predate that.
insert into public.accommodation_manager_profiles (user_id)
select u.id
from public.users u
where u.role = ''accommodation_manager''
  and not exists (
    select 1 from public.accommodation_manager_profiles mp where mp.user_id = u.id
  )
on conflict (user_id) do nothing;"}', 'backfill_manager_profiles', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908183736', '{"-- BUG: this guard is attached to three tables, and the verification_documents
-- check sat in a FLAT condition:
--     if tg_table_name = ''verification_documents'' and new.status = ''approved''
-- PL/pgSQL hands the whole expression to the SQL executor, which must resolve
-- every field reference before any short-circuit can happen. On student_profiles
-- — which has no `status` column — that raised
--     record \"new\" has no field \"status\"  (SQLSTATE 42703)
-- so EVERY non-admin write to student_profiles failed, breaking student
-- registration outright.
--
-- Why it was missed: the earlier checks all ran either as postgres (auth.uid() is
-- null, which returns before this line) or hit the osas_verified_at guard first
-- and raised there. The guard appeared to pass, for the wrong reason.
--
-- Fix: nest the check inside its own table branch so the field is only resolved
-- for the table that has it. Same shape as the other two branches already used.
create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  -- No JWT means service_role, the SQL console or a migration.
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = ''student_profiles'' then
    if tg_op = ''INSERT'' then
      if new.osas_verified_at is not null then
        raise exception ''Only OSAS may set verification status.'';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception ''Only OSAS may change verification status.'';
    end if;
  end if;

  if tg_table_name = ''accommodations'' then
    if tg_op = ''INSERT'' then
      if new.status <> ''pending'' then
        raise exception ''A new accommodation must start as pending.'';
      end if;
    elsif new.status is distinct from old.status then
      -- tg_permit_needs_review sends an accredited listing back to review on the
      -- manager''s behalf; that one transition is allowed through.
      if not (coalesce(current_setting(''app.permit_review'', true), ''false'') = ''true''
              and old.status = ''accredited'' and new.status = ''reviewing'') then
        raise exception ''Only OSAS may change accreditation status.'';
      end if;
    end if;
  end if;

  if tg_table_name = ''verification_documents'' then
    -- ''approved'' is the only doc status that grants anything, so guard just that
    -- and leave the owner''s own resubmission (back to ''pending'') working.
    if new.status = ''approved'' then
      raise exception ''Only OSAS may approve a document.'';
    end if;
  end if;

  return new;
end $fn$;"}', 'fix_lock_verification_columns_field_ref', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908184927', '{"-- Managers may not hold a session until OSAS approves the application.
--
-- The app refuses the sign-in, but that is a client-side check and RLS knows
-- nothing about users.status, so a direct API call would sail past it. Ban the
-- auth user instead, the same mechanism suspension already uses, and lift it when
-- OSAS verifies.
--
-- Timing matters: the ban is applied when REGISTRATION COMPLETES, not when the
-- account row is created. A manager needs a live session during registration to
-- upload their government ID and business permit — banning at account creation
-- would break the flow it is meant to gate.
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  unverified_manager boolean := new.role = ''accommodation_manager'' and new.status <> ''verified'';
begin
  if new.status in (''rejected'',''suspended'') and old.status = ''verified'' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where accommodation_manager_id = new.id and status = ''accredited'';
  end if;

  -- Suspension: always bans, any role.
  if new.status = ''suspended'' and old.status is distinct from ''suspended'' then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- A manager finishing registration, or losing approval afterwards, is locked
  -- out until OSAS verifies them.
  if unverified_manager and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- Approval (or lifting a suspension) restores sign-in.
  if new.status = ''verified'' and old.status is distinct from ''verified'' then
    update auth.users set banned_until = null where id = new.id;
  elsif old.status = ''suspended'' and new.status is distinct from ''suspended''
        and not unverified_manager then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify
  after update of status, registered_at on public.users
  for each row execute function public.tg_revoke_on_unverify();"}', 'manager_login_requires_approval', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908185019', '{"-- Apply the manager sign-in rule to managers who already exist. The trigger only
-- fires on future updates, so without this a manager who registered before the
-- rule could still sign in while unapproved.
--
-- Scoped to managers who have FINISHED registering: one who is mid-registration
-- still needs their session to upload documents. 8 verified managers keep their
-- access; 16 unapproved ones (15 pending + 1 rejected) are locked out until OSAS
-- decides, which is the requested behaviour.
update auth.users a
set banned_until = now() + interval ''100 years''
from public.users u
where u.id = a.id
  and u.role = ''accommodation_manager''
  and u.status <> ''verified''
  and u.registered_at is not null
  and a.banned_until is null;

delete from auth.sessions s
using public.users u
where s.user_id = u.id
  and u.role = ''accommodation_manager''
  and u.status <> ''verified''
  and u.registered_at is not null;

delete from auth.refresh_tokens r
using public.users u
where r.user_id = u.id::text
  and u.role = ''accommodation_manager''
  and u.status <> ''verified''
  and u.registered_at is not null;"}', 'ban_existing_unapproved_managers', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260914072631', '{"create table public.app_release (
  id                         int  primary key default 1 check (id = 1),
  latest_version_code        int  not null,
  latest_version_name        text not null,
  min_supported_version_code int  not null default 1,
  apk_url                    text not null,
  release_notes              text,
  updated_at                 timestamptz not null default now()
);

alter table public.app_release enable row level security;

create policy app_release_read_all on public.app_release for select using (true);
grant select on public.app_release to anon, authenticated;

insert into public.app_release (latest_version_code, latest_version_name, apk_url)
values (
  1,
  ''1.0'',
  ''https://github.com/Team-Dong-Dantes/accommo-mobile/releases/latest/download/app-release.apk''
);"}', 'app_release_version_gate', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908190524', '{"-- Refinement: the sign-in block applies only while OSAS still owes the manager a
-- decision. Once OSAS has responded and needs something back, the manager has to
-- be able to get in and act on it — otherwise a rejection is a permanent dead end
-- and the documents can never be corrected.
--
--   pending             -> blocked (not reviewed yet)
--   reviewing/rejected  -> allowed in, routed to resubmission with the reason
--   verified            -> normal access
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public, auth
as $$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  -- Only ''pending'' is a closed door; a manager OSAS has replied to must be able
  -- to sign in and fix what was asked for.
  awaiting_review boolean := new.role = ''accommodation_manager'' and new.status = ''pending'';
begin
  if new.status in (''rejected'',''suspended'') and old.status = ''verified'' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where accommodation_manager_id = new.id and status = ''accredited'';
  end if;

  -- Suspension: always bans, any role.
  if new.status = ''suspended'' and old.status is distinct from ''suspended'' then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- A manager finishing registration, or sent back to pending, waits outside.
  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- OSAS approving, or asking for changes, reopens sign-in. Suspension is the
  -- exception and is handled above.
  if new.status in (''verified'',''rejected'',''reviewing'')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify
  after update of status, registered_at on public.users
  for each row execute function public.tg_revoke_on_unverify();

-- Let the already-rejected manager back in to fix their application.
update auth.users a
set banned_until = null
from public.users u
where u.id = a.id
  and u.role = ''accommodation_manager''
  and u.status in (''rejected'',''reviewing'')
  and a.banned_until is not null;"}', 'rejected_managers_may_sign_in_to_fix', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260908193515', '{"update public.tickets set status = ''open'' where status = ''pending'';
update public.tickets set status = ''in_progress'' where status in (''assigned'', ''under_review'');

drop policy if exists \"ticket_messages_reporter_select\" on public.ticket_messages;
create policy \"ticket_messages_reporter_select\" on public.ticket_messages
  for select to authenticated
  using (
    is_internal = false
    and exists (
      select 1 from public.tickets t
      where t.id = ticket_messages.ticket_id
        and (
          t.student_id = auth.uid()
          or t.accommodation_manager_id = auth.uid()
          or t.lease_id in (select l.id from public.leases l where l.student_id = auth.uid())
        )
    )
  );

create or replace function public.trg_ticket_message_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.tickets%rowtype;
  preview text;
begin
  if new.is_internal then
    return new;
  end if;

  select * into t from public.tickets where id = new.ticket_id;
  if not found then
    return new;
  end if;

  preview := coalesce(t.subject, ''Your ticket'') || '': '' || left(new.body, 120);

  if new.author_role = ''agent'' then
    if t.student_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.student_id, ''OSAS replied to your ticket'', preview, ''ticket'', ''/student/support'');
    end if;
    if t.accommodation_manager_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.accommodation_manager_id, ''OSAS replied to your ticket'', preview, ''ticket'', ''/manager/osas-compliance'');
    end if;
  else
    perform public.notify_admins(
      ''New reply on a ticket'',
      preview,
      ''ticket'',
      ''/support-tickets?focus=ticket:'' || t.id::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ticket_message_notify on public.ticket_messages;
create trigger trg_ticket_message_notify
  after insert on public.ticket_messages
  for each row execute function public.trg_ticket_message_notify();"}', 'ticket_reply_channel', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260909044845', '{"-- ============================================================
-- 1. One review per lease, per direction.
--    TenantProfile reads the existing review with .maybeSingle(), which throws
--    on a second row; nothing previously stopped a double submit.
-- ============================================================
alter table public.accommodation_reviews
  add constraint accommodation_reviews_lease_id_key unique (lease_id);
alter table public.accommodation_manager_reviews
  add constraint accommodation_manager_reviews_lease_id_key unique (lease_id);
alter table public.tenant_reviews
  add constraint tenant_reviews_lease_id_key unique (lease_id);

-- ============================================================
-- 2. Anonymous read surface.
--    Reviews are mutually anonymous between students and managers. The name
--    cannot be hidden in the UI alone: the row carries the counterparty''s user
--    id and public.users is readable by every authenticated user, so an id is
--    always resolvable to a name. These views therefore expose no counterparty
--    id at all, and SELECT on the base tables is revoked below.
--    They are owner-executed (NOT security_invoker) on purpose: they bypass RLS,
--    so each WHERE clause below is the access control. Edit them with that in mind.
-- ============================================================

-- Reviews *received* by the caller. Manager: about them + about their
-- accommodations. Student: about them.
create or replace view public.review_inbox as
  select r.id,
         ''manager''::text as kind,
         r.rating,
         r.comment,
         r.created_at,
         null::uuid as accommodation_id,
         null::text as accommodation_name
    from public.accommodation_manager_reviews r
   where r.accommodation_manager_id = auth.uid()
  union all
  select r.id,
         ''accommodation''::text,
         r.rating,
         r.comment,
         r.created_at,
         a.id,
         a.name
    from public.accommodation_reviews r
    join public.accommodations a on a.id = r.accommodation_id
   where a.accommodation_manager_id = auth.uid()
  union all
  select r.id,
         ''tenant''::text,
         r.rating,
         r.comment,
         r.created_at,
         null::uuid,
         null::text
    from public.tenant_reviews r
   where r.student_id = auth.uid();

-- Reviews *written* by the caller: drives the \"already rated\" state and lets a
-- manager see the review they left on a tenant.
create or replace view public.review_written_leases as
  select r.lease_id, ''accommodation''::text as kind, r.rating, r.comment
    from public.accommodation_reviews r
   where r.student_id = auth.uid()
  union all
  select r.lease_id, ''manager''::text, r.rating, r.comment
    from public.accommodation_manager_reviews r
   where r.student_id = auth.uid()
  union all
  select r.lease_id, ''tenant''::text, r.rating, r.comment
    from public.tenant_reviews r
   where r.accommodation_manager_id = auth.uid();

-- Admin oversight: every review with both identities. Gated on is_admin, which
-- is the same helper the policies on accommodations, leases and tickets use.
create or replace view public.review_admin_feed as
  select r.id, ''manager''::text as kind, r.lease_id, r.rating, r.comment, r.created_at,
         r.student_id as author_id,
         r.accommodation_manager_id as subject_id,
         null::uuid as accommodation_id
    from public.accommodation_manager_reviews r
   where public.is_admin(auth.uid())
  union all
  select r.id, ''accommodation''::text, r.lease_id, r.rating, r.comment, r.created_at,
         r.student_id, null::uuid, r.accommodation_id
    from public.accommodation_reviews r
   where public.is_admin(auth.uid())
  union all
  select r.id, ''tenant''::text, r.lease_id, r.rating, r.comment, r.created_at,
         r.accommodation_manager_id, r.student_id, null::uuid
    from public.tenant_reviews r
   where public.is_admin(auth.uid());

-- Writes stay on the base tables (the existing RLS insert policies already check
-- lease ownership and an ended/terminated status). Only reading is closed off.
revoke select on public.accommodation_reviews          from authenticated, anon;
revoke select on public.accommodation_manager_reviews  from authenticated, anon;
revoke select on public.tenant_reviews                 from authenticated, anon;

grant select on public.review_inbox           to authenticated;
grant select on public.review_written_leases  to authenticated;
grant select on public.review_admin_feed      to authenticated;

-- ============================================================
-- 3. Keep accommodations.rating_avg / reviews_count in step.
--    accommo-web reads both columns in four places; nothing ever wrote them, so
--    every accommodation showed \"—\" and 0 reviews.
-- ============================================================
create or replace function public.refresh_accommodation_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid := coalesce(new.accommodation_id, old.accommodation_id);
begin
  update public.accommodations a
     set rating_avg = sub.avg_rating,
         reviews_count = sub.n
    from (
      select avg(rating)::numeric(3, 2) as avg_rating,
             count(*)::int as n
        from public.accommodation_reviews
       where accommodation_id = target
    ) sub
   where a.id = target;
  return null;
end;
$$;

drop trigger if exists accommodation_reviews_refresh_rating on public.accommodation_reviews;
create trigger accommodation_reviews_refresh_rating
after insert or update or delete on public.accommodation_reviews
for each row execute function public.refresh_accommodation_rating();

-- Backfill so the columns are true from today, not just for future writes.
update public.accommodations a
   set rating_avg = sub.avg_rating,
       reviews_count = sub.n
  from (
    select a2.id,
           (select avg(r.rating)::numeric(3, 2)
              from public.accommodation_reviews r
             where r.accommodation_id = a2.id) as avg_rating,
           (select count(*)::int
              from public.accommodation_reviews r
             where r.accommodation_id = a2.id) as n
      from public.accommodations a2
  ) sub
 where a.id = sub.id;

-- ============================================================
-- 4. Both student-side reviews in one transaction.
--    They were two sequential inserts from the client: if the second failed the
--    first was already committed, and the \"already reviewed\" check is the union
--    of both tables, so the student could never supply the missing half.
--    SECURITY INVOKER so the existing RLS insert policies still gate it.
-- ============================================================
create or replace function public.submit_student_review(
  p_lease_id uuid,
  p_accommodation_id uuid,
  p_accommodation_manager_id uuid,
  p_acc_rating int,
  p_acc_comment text,
  p_manager_rating int,
  p_manager_comment text
) returns void
language sql
security invoker
set search_path = public
as $$
  with acc as (
    insert into public.accommodation_reviews (lease_id, student_id, accommodation_id, rating, comment)
    values (p_lease_id, auth.uid(), p_accommodation_id, p_acc_rating, nullif(btrim(coalesce(p_acc_comment, '''')), ''''))
    returning 1
  )
  insert into public.accommodation_manager_reviews (lease_id, student_id, accommodation_manager_id, rating, comment)
  select p_lease_id, auth.uid(), p_accommodation_manager_id, p_manager_rating,
         nullif(btrim(coalesce(p_manager_comment, '''')), '''')
    from acc;
$$;

grant execute on function public.submit_student_review(uuid, uuid, uuid, int, text, int, text) to authenticated;"}', 'anonymous_reviews_and_rating_aggregates', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260909045439', '{"-- refresh_accommodation_rating is a trigger function; Postgres refuses a direct
-- call anyway, but it is SECURITY DEFINER and was exposed on /rest/v1/rpc by the
-- default grant. Nothing should be able to invoke it but the trigger.
revoke execute on function public.refresh_accommodation_rating() from anon, authenticated;"}', 'restrict_refresh_accommodation_rating_execute', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260909050420', '{"-- TenantProfile reads a tenant''s stay history, but boarding_history could only
-- be selected by the student themselves or an admin — so the manager''s \"past
-- stays\" list silently came back empty.
--
-- Scoped to the manager''s own accommodations, mirroring the existing
-- boarding_history_insert_manager policy. A manager sees the stays that
-- happened at their own places, not the student''s history elsewhere.
create policy boarding_history_select_manager
  on public.boarding_history
  for select
  to authenticated
  using (
    exists (
      select 1 from public.accommodations a
      where a.id = boarding_history.accommodation_id
        and a.accommodation_manager_id = (select auth.uid())
    )
  );"}', 'boarding_history_manager_select', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910132804', '{"ALTER TABLE public.users ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz;

GRANT SELECT ON public.policies TO anon;
DROP POLICY IF EXISTS \"policies_select_anon\" ON public.policies;
CREATE POLICY \"policies_select_anon\"
  ON public.policies FOR SELECT TO anon
  USING (NOT archived AND effective_date <= now());

DROP POLICY IF EXISTS \"policies_select_authenticated\" ON public.policies;
CREATE POLICY \"policies_select_authenticated\"
  ON public.policies FOR SELECT TO authenticated
  USING (
    NOT archived
    AND effective_date <= now()
    AND get_my_role() = ANY (ARRAY[''student'', ''accommodation_manager''])
  );"}', 'terms_and_policies', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910172628', '{"CREATE OR REPLACE FUNCTION public.notify_announcement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF new.published_at IS NULL OR new.archived THEN RETURN new; END IF;
  IF tg_op = ''UPDATE'' AND old.published_at IS NOT NULL THEN RETURN new; END IF;

  INSERT INTO public.notifications (user_id, title, body, type, link_url)
  SELECT u.id, new.title, left(new.body, 300), ''announcement'', NULL
  FROM public.users u
  WHERE u.status <> ''suspended''
    AND (
      (new.audience = ''all'' AND u.role IN (''student'', ''accommodation_manager''))
      OR (new.audience = ''students'' AND u.role = ''student'')
      OR (new.audience = ''accommodation_managers'' AND u.role = ''accommodation_manager'')
    );

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_announcement ON public.announcements;
CREATE TRIGGER trg_notify_announcement
  AFTER INSERT OR UPDATE OF published_at, archived ON public.announcements
  FOR EACH ROW EXECUTE FUNCTION public.notify_announcement();

CREATE OR REPLACE FUNCTION public.notify_policy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF new.archived OR new.effective_date > now() THEN RETURN new; END IF;
  IF tg_op = ''UPDATE'' AND NOT (old.archived OR old.effective_date > now()) THEN RETURN new; END IF;

  INSERT INTO public.notifications (user_id, title, body, type, link_url)
  SELECT
    u.id,
    new.title,
    coalesce(new.version || '' · '', '''')
      || ''In effect from '' || to_char(new.effective_date, ''Mon DD, YYYY'')
      || ''. Open Policies & guidelines to read and accept it.'',
    ''policy'',
    NULL
  FROM public.users u
  WHERE u.status <> ''suspended''
    AND u.role IN (''student'', ''accommodation_manager'');

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_policy ON public.policies;
CREATE TRIGGER trg_notify_policy
  AFTER INSERT OR UPDATE OF effective_date, archived ON public.policies
  FOR EACH ROW EXECUTE FUNCTION public.notify_policy();"}', 'notify_announcements_policies', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910180907', '{"ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS summary text,
  ADD COLUMN IF NOT EXISTS accommodation_id uuid REFERENCES public.accommodations(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS notified_at timestamptz;

CREATE INDEX IF NOT EXISTS announcements_accommodation_idx
  ON public.announcements (accommodation_id) WHERE accommodation_id IS NOT NULL;

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS ref_id uuid;
CREATE INDEX IF NOT EXISTS notifications_ref_idx ON public.notifications (ref_id) WHERE ref_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.my_accommodation_ids()
RETURNS TABLE (id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.accommodation_id
  FROM public.leases l
  JOIN public.rooms r ON r.id = l.room_id
  WHERE l.student_id = auth.uid() AND l.status = ''active''
  UNION
  SELECT a.id FROM public.accommodations a WHERE a.accommodation_manager_id = auth.uid();
$$;

DROP POLICY IF EXISTS \"announcements_select_audience\" ON public.announcements;
CREATE POLICY \"announcements_select_audience\"
  ON public.announcements FOR SELECT TO authenticated
  USING (
    published_at IS NOT NULL
    AND published_at <= now()
    AND NOT archived
    AND (expires_at IS NULL OR expires_at > now())
    AND (
      CASE WHEN accommodation_id IS NULL THEN
        audience = ''all''
        OR (audience = ''students'' AND get_my_role() = ''student'')
        OR (audience = ''accommodation_managers'' AND get_my_role() = ''accommodation_manager'')
      ELSE
        accommodation_id IN (SELECT id FROM public.my_accommodation_ids())
      END
    )
  );

DROP POLICY IF EXISTS \"announcements_select_public\" ON public.announcements;
CREATE POLICY \"announcements_select_public\"
  ON public.announcements FOR SELECT TO anon
  USING (
    audience = ''all'' AND accommodation_id IS NULL
    AND published_at IS NOT NULL AND published_at <= now()
    AND NOT archived
    AND (expires_at IS NULL OR expires_at > now())
  );

DROP POLICY IF EXISTS \"announcements_manager_own\" ON public.announcements;
CREATE POLICY \"announcements_manager_own\"
  ON public.announcements FOR ALL TO authenticated
  USING (
    author_id = auth.uid()
    AND accommodation_id IN (
      SELECT a.id FROM public.accommodations a WHERE a.accommodation_manager_id = auth.uid()
    )
  )
  WITH CHECK (
    author_id = auth.uid()
    AND accommodation_id IN (
      SELECT a.id FROM public.accommodations a WHERE a.accommodation_manager_id = auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION public.fanout_announcement(p_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE a public.announcements; sent integer;
BEGIN
  UPDATE public.announcements
     SET notified_at = now()
   WHERE id = p_id
     AND notified_at IS NULL
     AND archived = false
     AND published_at IS NOT NULL
     AND published_at <= now()
     AND (expires_at IS NULL OR expires_at > now())
  RETURNING * INTO a;

  IF a.id IS NULL THEN RETURN 0; END IF;

  INSERT INTO public.notifications (user_id, title, body, type, link_url, ref_id)
  SELECT u.id, a.title, coalesce(nullif(a.summary, ''''), left(a.body, 300)), ''announcement'', NULL, a.id
  FROM public.users u
  WHERE u.status <> ''suspended''
    AND u.id <> a.author_id
    AND (
      CASE WHEN a.accommodation_id IS NULL THEN
        (a.audience = ''all'' AND u.role IN (''student'', ''accommodation_manager''))
        OR (a.audience = ''students'' AND u.role = ''student'')
        OR (a.audience = ''accommodation_managers'' AND u.role = ''accommodation_manager'')
      ELSE
        u.id IN (
          SELECT l.student_id FROM public.leases l
          JOIN public.rooms r ON r.id = l.room_id
          WHERE r.accommodation_id = a.accommodation_id AND l.status = ''active''
        )
      END
    );

  GET DIAGNOSTICS sent = ROW_COUNT;
  RETURN sent;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_announcement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF new.published_at IS NULL OR new.published_at > now() OR new.archived THEN
    RETURN new;
  END IF;
  PERFORM public.fanout_announcement(new.id);
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_announcement ON public.announcements;
CREATE TRIGGER trg_notify_announcement
  AFTER INSERT OR UPDATE OF published_at, archived ON public.announcements
  FOR EACH ROW EXECUTE FUNCTION public.notify_announcement();

CREATE OR REPLACE FUNCTION public.announce_due()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r record; total integer := 0;
BEGIN
  FOR r IN
    SELECT id FROM public.announcements
    WHERE notified_at IS NULL AND archived = false
      AND published_at IS NOT NULL AND published_at <= now()
      AND (expires_at IS NULL OR expires_at > now())
  LOOP
    total := total + public.fanout_announcement(r.id);
  END LOOP;
  RETURN total;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_expired_announcements()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE n integer;
BEGIN
  UPDATE public.announcements
     SET archived = true
   WHERE archived = false AND expires_at IS NOT NULL AND expires_at < now();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

CREATE OR REPLACE FUNCTION public.announcement_reach(p_id uuid)
RETURNS TABLE (sent integer, seen integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() <> ''admin'' THEN
    RAISE EXCEPTION ''admins only'';
  END IF;
  RETURN QUERY
    SELECT count(*)::int, count(*) FILTER (WHERE read_at IS NOT NULL)::int
    FROM public.notifications
    WHERE ref_id = p_id AND type = ''announcement'';
END;
$$;

GRANT EXECUTE ON FUNCTION public.announcement_reach(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_accommodation_ids() TO authenticated;"}', 'announcements_v2', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910183927', '{"ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS source text;

CREATE OR REPLACE FUNCTION public.fanout_announcement(p_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE a public.announcements; sent integer; sender text;
BEGIN
  UPDATE public.announcements
     SET notified_at = now()
   WHERE id = p_id
     AND notified_at IS NULL
     AND archived = false
     AND published_at IS NOT NULL
     AND published_at <= now()
     AND (expires_at IS NULL OR expires_at > now())
  RETURNING * INTO a;

  IF a.id IS NULL THEN RETURN 0; END IF;

  -- Who it reads as: a house notice is from the house, everything else is the
  -- platform speaking. Individual OSAS staff names mean nothing to a student.
  SELECT CASE
           WHEN a.accommodation_id IS NULL THEN ''System Admin''
           ELSE coalesce((SELECT name FROM public.accommodations WHERE id = a.accommodation_id), ''Your accommodation'')
         END
    INTO sender;

  INSERT INTO public.notifications (user_id, title, body, type, link_url, ref_id, source)
  SELECT u.id, a.title, coalesce(nullif(a.summary, ''''), left(a.body, 300)), ''announcement'', NULL, a.id, sender
  FROM public.users u
  WHERE u.status <> ''suspended''
    AND u.id <> a.author_id
    AND (
      CASE WHEN a.accommodation_id IS NULL THEN
        (a.audience = ''all'' AND u.role IN (''student'', ''accommodation_manager''))
        OR (a.audience = ''students'' AND u.role = ''student'')
        OR (a.audience = ''accommodation_managers'' AND u.role = ''accommodation_manager'')
      ELSE
        u.id IN (
          SELECT l.student_id FROM public.leases l
          JOIN public.rooms r ON r.id = l.room_id
          WHERE r.accommodation_id = a.accommodation_id AND l.status = ''active''
        )
      END
    );

  GET DIAGNOSTICS sent = ROW_COUNT;
  RETURN sent;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_policy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF new.archived OR new.effective_date > now() THEN RETURN new; END IF;
  IF tg_op = ''UPDATE'' AND NOT (old.archived OR old.effective_date > now()) THEN RETURN new; END IF;

  INSERT INTO public.notifications (user_id, title, body, type, link_url, ref_id, source)
  SELECT
    u.id,
    new.title,
    coalesce(new.version || '' · '', '''')
      || ''In effect from '' || to_char(new.effective_date AT TIME ZONE ''Asia/Manila'', ''Mon DD, YYYY'')
      || ''. Open Policies & guidelines to read and accept it.'',
    ''policy'',
    NULL,
    new.id,
    ''System Admin''
  FROM public.users u
  WHERE u.status <> ''suspended''
    AND u.role IN (''student'', ''accommodation_manager'');

  RETURN new;
END;
$$;

UPDATE public.notifications SET source = ''System Admin''
 WHERE source IS NULL AND type IN (''announcement'', ''policy'');"}', 'notification_source', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910190702', '{"ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS event_at timestamptz,
  ADD COLUMN IF NOT EXISTS event_end timestamptz,
  ADD COLUMN IF NOT EXISTS deadline_at timestamptz,
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS image_url text;

COMMENT ON COLUMN public.announcements.event_at IS
  ''What the notice is about, not when it is shown: the start of the thing happening. published_at/expires_at remain display windows.'';
COMMENT ON COLUMN public.announcements.deadline_at IS
  ''When the reader has to have acted by.'';"}', 'announcement_facts', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910193138', '{"CREATE OR REPLACE FUNCTION public.handle_auth_user_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> ''provider'', ''email'');
  v_picture text := coalesce(new.raw_user_meta_data ->> ''avatar_url'', new.raw_user_meta_data ->> ''picture'');
begin
  if tg_op = ''INSERT'' then
    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, avatar_url, sex,
      email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      v_picture,
      coalesce((new.raw_user_meta_data ->> ''sex'')::text, ''M''),
      case when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          avatar_url = coalesce(public.users.avatar_url, excluded.avatar_url),
          sex = excluded.sex,
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone),
        -- A photo the provider supplies is the only copy anyone but its owner
        -- can read; coalesce so an uploaded avatar is never clobbered by it.
        avatar_url = coalesce(public.users.avatar_url, v_picture),
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;

UPDATE public.users u
   SET avatar_url = coalesce(au.raw_user_meta_data ->> ''avatar_url'', au.raw_user_meta_data ->> ''picture'')
  FROM auth.users au
 WHERE au.id = u.id
   AND u.avatar_url IS NULL
   AND coalesce(au.raw_user_meta_data ->> ''avatar_url'', au.raw_user_meta_data ->> ''picture'') IS NOT NULL;"}', 'sync_avatar_from_auth', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910193252', '{"-- 1. Every student profile carries a rotatable token; the QR stops carrying the
--    student number itself.
ALTER TABLE public.student_profiles
  ALTER COLUMN qr_code_token SET DEFAULT gen_random_uuid()::text;

UPDATE public.student_profiles
   SET qr_code_token = gen_random_uuid()::text
 WHERE qr_code_token IS NULL;

-- 2. Every scan is recorded: oversight for OSAS, a \"who checked my ID\" trail
--    for the student, and the thing that makes rate limiting possible.
CREATE TABLE IF NOT EXISTS public.qr_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scanner_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  student_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  method text NOT NULL DEFAULT ''qr'',
  result text NOT NULL,
  scanned_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS qr_scans_scanner_idx ON public.qr_scans (scanner_id, scanned_at DESC);
CREATE INDEX IF NOT EXISTS qr_scans_student_idx ON public.qr_scans (student_id, scanned_at DESC);

ALTER TABLE public.qr_scans ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.qr_scans TO authenticated;

DROP POLICY IF EXISTS qr_scans_select_own ON public.qr_scans;
CREATE POLICY qr_scans_select_own ON public.qr_scans FOR SELECT TO authenticated
  USING (scanner_id = auth.uid() OR student_id = auth.uid() OR is_admin(auth.uid()));

-- 3. The lookup. SECURITY DEFINER so a manager can confirm ANY verified
--    student — the whole point is checking someone who is not yet a tenant —
--    while tenancy details stay behind the lease relationship.
CREATE OR REPLACE FUNCTION public.verify_student_qr(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid := auth.uid();
  recent integer;
  sp record;
  u record;
  is_mine boolean;
  v_method text := ''qr'';
  v_result text;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION ''Not signed in'';
  END IF;

  -- Rate limit: the manual field is a brute-force surface over a guessable ID
  -- space, so cap attempts per scanner per minute regardless of method.
  SELECT count(*) INTO recent
    FROM public.qr_scans
   WHERE scanner_id = me AND scanned_at > now() - interval ''1 minute'';
  IF recent >= 12 THEN
    RAISE EXCEPTION ''Too many scans in a row. Wait a minute and try again.'';
  END IF;

  SELECT * INTO sp FROM public.student_profiles WHERE qr_code_token = p_code;
  IF sp.user_id IS NULL THEN
    -- Not a token: treat it as a typed student number.
    v_method := ''manual'';
    SELECT * INTO sp FROM public.student_profiles WHERE student_id = p_code;
  END IF;

  IF sp.user_id IS NULL THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, NULL, v_method, ''not_found'');
    RETURN jsonb_build_object(''found'', false, ''reason'', ''not_found'');
  END IF;

  SELECT * INTO u FROM public.users WHERE id = sp.user_id;

  SELECT EXISTS (
    SELECT 1 FROM public.leases l
     WHERE l.student_id = sp.user_id AND l.accommodation_manager_id = me
  ) INTO is_mine;

  v_result := CASE WHEN sp.osas_verified_at IS NOT NULL THEN ''verified'' ELSE ''unverified'' END;
  INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
  VALUES (me, sp.user_id, v_method, v_result);

  RETURN jsonb_build_object(
    ''found'', true,
    ''user_id'', sp.user_id,
    ''student_id'', sp.student_id,
    ''full_name'', u.full_name,
    ''initials'', u.initials,
    ''avatar_url'', u.avatar_url,
    ''program'', sp.program,
    ''college'', sp.college,
    ''year_level'', sp.year_level,
    ''osas_verified'', sp.osas_verified_at IS NOT NULL,
    ''verified_at'', sp.osas_verified_at,
    ''account_status'', u.status,
    ''is_my_tenant'', is_mine,
    ''method'', v_method
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_student_qr(text) TO authenticated;

-- 4. A student can burn a leaked code.
CREATE OR REPLACE FUNCTION public.rotate_qr_token()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE fresh text := gen_random_uuid()::text;
BEGIN
  UPDATE public.student_profiles SET qr_code_token = fresh WHERE user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION ''No student profile for this account''; END IF;
  RETURN fresh;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rotate_qr_token() TO authenticated;"}', 'qr_verification', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910194124', '{"ALTER TABLE public.student_profiles
  ADD COLUMN IF NOT EXISTS qr_token_rotated_at timestamptz;

-- Replacing a code invalidates the one a manager may be about to scan, so it
-- is a deliberate act, not something a stuck finger should do ten times. The
-- cooldown is short: a leaked code is urgent, and rotating only ever affects
-- the student''s own record.
CREATE OR REPLACE FUNCTION public.rotate_qr_token()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  fresh text := gen_random_uuid()::text;
  last_at timestamptz;
  wait_s integer;
BEGIN
  SELECT qr_token_rotated_at INTO last_at
    FROM public.student_profiles WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION ''No student profile for this account'';
  END IF;

  IF last_at IS NOT NULL AND last_at > now() - interval ''60 seconds'' THEN
    wait_s := ceil(extract(epoch FROM (last_at + interval ''60 seconds'' - now())));
    RAISE EXCEPTION ''You just replaced your code. Try again in % second(s).'', wait_s
      USING ERRCODE = ''53400'';
  END IF;

  UPDATE public.student_profiles
     SET qr_code_token = fresh, qr_token_rotated_at = now()
   WHERE user_id = auth.uid();

  RETURN fresh;
END;
$$;"}', 'rotate_qr_token_cooldown', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260910194453', '{"ALTER TABLE public.student_profiles
  ADD COLUMN IF NOT EXISTS qr_token_expires_at timestamptz;

-- Existing tokens get a normal hour of life rather than dying on deploy.
UPDATE public.student_profiles
   SET qr_token_expires_at = now() + interval ''1 hour''
 WHERE qr_token_expires_at IS NULL;

-- The student''s screen asks for its code through this: it hands back the live
-- one, or mints a fresh hour when the last has run out. Rotation is therefore
-- automatic and lazy — no cron writing 110 rows an hour, and no code going
-- stale in someone''s hand while they hold up the screen.
--
-- Deliberately does NOT stamp qr_token_rotated_at: that column tracks manual
-- replacements only, or an automatic refresh would trip the manual cooldown.
CREATE OR REPLACE FUNCTION public.current_qr_token()
RETURNS TABLE (token text, expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE sp record;
BEGIN
  SELECT qr_code_token, qr_token_expires_at INTO sp
    FROM public.student_profiles WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION ''No student profile for this account'';
  END IF;

  IF sp.qr_code_token IS NULL
     OR sp.qr_token_expires_at IS NULL
     OR sp.qr_token_expires_at <= now() THEN
    UPDATE public.student_profiles
       SET qr_code_token = gen_random_uuid()::text,
           qr_token_expires_at = now() + interval ''1 hour''
     WHERE user_id = auth.uid()
     RETURNING qr_code_token, qr_token_expires_at INTO sp;
  END IF;

  token := sp.qr_code_token;
  expires_at := sp.qr_token_expires_at;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.current_qr_token() TO authenticated;

-- A manual replace also starts a fresh hour.
CREATE OR REPLACE FUNCTION public.rotate_qr_token()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  fresh text := gen_random_uuid()::text;
  last_at timestamptz;
  wait_s integer;
BEGIN
  SELECT qr_token_rotated_at INTO last_at
    FROM public.student_profiles WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION ''No student profile for this account'';
  END IF;

  IF last_at IS NOT NULL AND last_at > now() - interval ''60 seconds'' THEN
    wait_s := ceil(extract(epoch FROM (last_at + interval ''60 seconds'' - now())));
    RAISE EXCEPTION ''You just replaced your code. Try again in % second(s).'', wait_s
      USING ERRCODE = ''53400'';
  END IF;

  UPDATE public.student_profiles
     SET qr_code_token = fresh,
         qr_token_rotated_at = now(),
         qr_token_expires_at = now() + interval ''1 hour''
   WHERE user_id = auth.uid();

  RETURN fresh;
END;
$$;

-- An expired code is refused outright: that is the whole point of a screenshot
-- having a shelf life. The attempt is still logged, so a manager showing up
-- with stale codes is visible.
CREATE OR REPLACE FUNCTION public.verify_student_qr(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid := auth.uid();
  recent integer;
  sp record;
  u record;
  is_mine boolean;
  v_method text := ''qr'';
  v_result text;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION ''Not signed in'';
  END IF;

  SELECT count(*) INTO recent
    FROM public.qr_scans
   WHERE scanner_id = me AND scanned_at > now() - interval ''1 minute'';
  IF recent >= 12 THEN
    RAISE EXCEPTION ''Too many scans in a row. Wait a minute and try again.'';
  END IF;

  SELECT * INTO sp FROM public.student_profiles WHERE qr_code_token = p_code;

  IF sp.user_id IS NOT NULL
     AND sp.qr_token_expires_at IS NOT NULL
     AND sp.qr_token_expires_at <= now() THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, sp.user_id, ''qr'', ''expired'');
    RETURN jsonb_build_object(''found'', false, ''reason'', ''expired'');
  END IF;

  IF sp.user_id IS NULL THEN
    v_method := ''manual'';
    SELECT * INTO sp FROM public.student_profiles WHERE student_id = p_code;
  END IF;

  IF sp.user_id IS NULL THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, NULL, v_method, ''not_found'');
    RETURN jsonb_build_object(''found'', false, ''reason'', ''not_found'');
  END IF;

  SELECT * INTO u FROM public.users WHERE id = sp.user_id;

  SELECT EXISTS (
    SELECT 1 FROM public.leases l
     WHERE l.student_id = sp.user_id AND l.accommodation_manager_id = me
  ) INTO is_mine;

  v_result := CASE WHEN sp.osas_verified_at IS NOT NULL THEN ''verified'' ELSE ''unverified'' END;
  INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
  VALUES (me, sp.user_id, v_method, v_result);

  RETURN jsonb_build_object(
    ''found'', true,
    ''user_id'', sp.user_id,
    ''student_id'', sp.student_id,
    ''full_name'', u.full_name,
    ''initials'', u.initials,
    ''avatar_url'', u.avatar_url,
    ''program'', sp.program,
    ''college'', sp.college,
    ''year_level'', sp.year_level,
    ''osas_verified'', sp.osas_verified_at IS NOT NULL,
    ''verified_at'', sp.osas_verified_at,
    ''account_status'', u.status,
    ''is_my_tenant'', is_mine,
    ''method'', v_method
  );
END;
$$;"}', 'qr_token_expiry', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913143433', '{"-- Manager-issued application forms. See
-- accommo-mobile/supabase/migrations/20260913000000_application_invite.sql for the
-- full rationale; this is that file''s DDL.

alter table public.conversations
  add column if not exists inquiry_room_id uuid references public.rooms(id) on delete set null,
  add column if not exists invited_room_id uuid references public.rooms(id) on delete set null,
  add column if not exists invited_at timestamptz;

alter table public.leases add column if not exists decision_reason text;

create or replace function public.invite_application(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room uuid;
begin
  if v_me is null then
    raise exception ''Not signed in'';
  end if;

  select c.inquiry_room_id into v_room
  from public.conversations c
  where c.id = p_conversation
    and (c.user_a_id = v_me or c.user_b_id = v_me);

  if not found then
    raise exception ''Conversation not found'';
  end if;

  if (select u.role::text from public.users u where u.id = v_me) <> ''accommodation_manager'' then
    raise exception ''Only the accommodation manager can send an application form'';
  end if;

  if v_room is null then
    raise exception ''This student has not asked about a room yet'';
  end if;

  if not exists (
    select 1
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
    where r.id = v_room
      and a.accommodation_manager_id = v_me
      and r.status = ''available''
  ) then
    raise exception ''That room is not yours, or is no longer available'';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $$;

revoke all on function public.invite_application(uuid) from public;
grant execute on function public.invite_application(uuid) to authenticated;

alter policy leases_insert_student_application on public.leases
with check (
  (student_id = (select auth.uid()))
  and (status = ''pending''::lease_status)
  and exists (
    select 1 from rooms r join accommodations a on a.id = r.accommodation_id
    where r.id = leases.room_id and a.accommodation_manager_id = leases.accommodation_manager_id
  )
  and exists (
    select 1 from student_profiles sp
    where sp.user_id = leases.student_id and sp.osas_verified_at is not null
  )
  and exists (
    select 1 from conversations c
    where c.invited_room_id = leases.room_id
      and (
        (c.user_a_id = leases.student_id and c.user_b_id = leases.accommodation_manager_id)
        or (c.user_b_id = leases.student_id and c.user_a_id = leases.accommodation_manager_id)
      )
  )
);"}', 'application_invite', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913150453', '{"-- A form must not be issued to a student who already holds a lease.
--
-- leases_one_current_per_student is a UNIQUE index on student_id over
-- (''pending'',''active'',''leave_requested''), so a second application fails at
-- INSERT with a raw 23505 -- surfacing to the student as a 409 Conflict after
-- they had already filled the form in. Refuse at the point the form is issued
-- instead, so the manager never hands out one that cannot be used.

create or replace function public.invite_application(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room uuid;
  v_student uuid;
begin
  if v_me is null then
    raise exception ''Not signed in'';
  end if;

  select c.inquiry_room_id,
         case when c.user_a_id = v_me then c.user_b_id else c.user_a_id end
    into v_room, v_student
  from public.conversations c
  where c.id = p_conversation
    and (c.user_a_id = v_me or c.user_b_id = v_me);

  if not found then
    raise exception ''Conversation not found'';
  end if;

  if (select u.role::text from public.users u where u.id = v_me) <> ''accommodation_manager'' then
    raise exception ''Only the accommodation manager can send an application form'';
  end if;

  if v_room is null then
    raise exception ''This student has not asked about a room yet'';
  end if;

  if not exists (
    select 1
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
    where r.id = v_room
      and a.accommodation_manager_id = v_me
      and r.status = ''available''
  ) then
    raise exception ''That room is not yours, or is no longer available'';
  end if;

  if exists (
    select 1 from public.leases l
    where l.student_id = v_student
      and l.status in (''pending'', ''active'', ''leave_requested'')
  ) then
    raise exception ''This student already has a current application or stay'';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $$;

revoke all on function public.invite_application(uuid) from public;
grant execute on function public.invite_application(uuid) to authenticated;"}', 'invite_requires_no_current_lease', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260914092838', '{"alter table public.policies drop column doc_type;
revoke select on public.policies from anon;"}', 'policies_are_osas_only', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913150953', '{"-- Leaving resets the thread: the student must ask again.
--
-- conversations.inquiry_room_id was stamped once, when the student first tapped
-- \"Ask about this room\", and never cleared. So after a tenancy ended the thread
-- still claimed the student was asking about that room, and the manager''s
-- \"Send application form\" button stayed live -- letting them re-issue a form to
-- a former tenant who never asked for one, possibly for a room that had since
-- been taken.
--
-- Done as a trigger rather than in the client because every way a tenancy can
-- close routes through this one status change: leave approved (TenantProfile
-- sets ''ended'' with ended_reason ''leave_approved''), termination, and anything
-- added later.
--
-- Only closure clears it. A DECLINED application deliberately does not: the two
-- are still talking, and making the student walk back to the room page to retry
-- a different move-in date would be friction for no gain.

create or replace function public.tg_lease_closed_clears_inquiry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations c
     set inquiry_room_id = null,
         invited_room_id = null,
         invited_at = null
   where (c.user_a_id = NEW.student_id and c.user_b_id = NEW.accommodation_manager_id)
      or (c.user_b_id = NEW.student_id and c.user_a_id = NEW.accommodation_manager_id);
  return NEW;
end $$;

drop trigger if exists trg_lease_closed_clears_inquiry on public.leases;
create trigger trg_lease_closed_clears_inquiry
  after update of status on public.leases
  for each row
  when (NEW.status in (''ended'', ''terminated'') and OLD.status is distinct from NEW.status)
  execute function public.tg_lease_closed_clears_inquiry();"}', 'closing_a_lease_clears_the_inquiry', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913161905', '{"-- One conversation per pair, enforced rather than hoped for.
--
-- findOrCreate() in src/stores/messages.ts was read-then-insert with nothing in
-- the database behind it, so two entry points opening the same thread at once
-- (a listing''s \"Ask\" and the messages tab, or a double tap) both found nothing
-- and both inserted. Three pairs ended up with two rows each, splitting their
-- history between them.
--
-- The client now resolves the losing side of that race by re-reading the row the
-- winner created -- but that only works because of the index below, which is
-- what actually makes the second insert fail instead of succeed.

-- The one duplicate that carried history: move its message to the survivor.
update public.messages
   set conversation_id = ''425c09c8-628c-4f86-824d-78acf47e0a74''
 where conversation_id = ''b2106250-f558-4675-8d73-3f2b45447efd'';

update public.conversations c
   set unread_b = c.unread_b + coalesce(
         (select unread_b from public.conversations
           where id = ''b2106250-f558-4675-8d73-3f2b45447efd''), 0)
 where c.id = ''425c09c8-628c-4f86-824d-78acf47e0a74'';

-- Restate the preview from the messages that now belong to the survivor.
update public.conversations c
   set last_message = m.body, last_time = m.sent_at
  from (select body, sent_at from public.messages
         where conversation_id = ''425c09c8-628c-4f86-824d-78acf47e0a74''
         order by sent_at desc limit 1) m
 where c.id = ''425c09c8-628c-4f86-824d-78acf47e0a74'';

-- The other two duplicates held no messages at all.
delete from public.conversations
 where id in (
   ''f3602484-14a7-48b1-a867-928d7c11bef7'',
   ''8d3a81d8-7dcd-4885-ab26-37fbbeb61aa1'',
   ''b2106250-f558-4675-8d73-3f2b45447efd''
 );

-- least/greatest normalises the pair, since either user can be user_a.
create unique index if not exists conversations_unique_pair
  on public.conversations (least(user_a_id, user_b_id), greatest(user_a_id, user_b_id));"}', 'one_conversation_per_pair', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913161925', '{"-- Two rooms carried 500 and 5000 months of advance/deposit -- 41 and 416 years.
-- rooms.advance_months / deposit_months had `min` on the input but no `max` and
-- no clamp on save, so a mistyped value went straight in. Both accommodations
-- are accredited, so students were seeing these, and the student application
-- summary multiplies them by the rent: room 101 quoted ~PHP 1,333,333 due on
-- move-in.
--
-- The client now clamps to 0-12 on blur and again in the save payload
-- (AccommodationDetail.vue). This repairs the rows that predate that.
--
-- One month advance and one month deposit is the ordinary arrangement locally;
-- these were plainly typos rather than a real figure to preserve.

update public.rooms
   set advance_months = 1,
       deposit_months = 1
 where id in (
   ''ca7aa4f0-b65b-42c3-9b46-de4a159a65dc'',
   ''232a1648-0e40-4121-8d8b-cbf50d584e77''
 );"}', 'correct_absurd_advance_deposit_months', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913170414', '{"-- A photo with no caption left the thread list saying \"No messages yet\".
--
-- tg_message_after_insert copied new.body straight into conversations.last_message,
-- and a photo-only message has an empty body -- so the inbox row for a perfectly
-- real conversation read as empty. Fixed here rather than in the client because
-- last_message is written in exactly one place and read by every surface.
--
-- Precedence: a caption always wins, so \"look at this\" + a photo still previews
-- as \"look at this\"; only a genuinely empty body falls back to the marker.

create or replace function public.tg_message_after_insert()
returns trigger
language plpgsql
security definer
set search_path to ''public''
as $function$
begin
  update conversations c
     set last_message = coalesce(
           nullif(trim(new.body), ''''),
           case when new.attachment_url is not null then ''📷 Photo'' else '''' end
         ),
         last_time    = new.sent_at,
         unread_a = case when c.user_a_id <> new.sender_id then c.unread_a + 1 else c.unread_a end,
         unread_b = case when c.user_b_id <> new.sender_id then c.unread_b + 1 else c.unread_b end
   where c.id = new.conversation_id;
  return new;
end;
$function$;

-- Repair the threads whose newest message is an uncaptioned photo. Threads with
-- no messages at all keep a blank preview -- \"No messages yet\" is true for them.
update public.conversations c
   set last_message = ''📷 Photo''
  from (
    select distinct on (conversation_id) conversation_id, body, attachment_url
      from public.messages
     order by conversation_id, sent_at desc
  ) newest
 where newest.conversation_id = c.id
   and coalesce(trim(c.last_message), '''') = ''''
   and coalesce(trim(newest.body), '''') = ''''
   and newest.attachment_url is not null;"}', 'photo_messages_get_a_thread_preview', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913171120', '{"-- \"You sent a photo\" vs \"Maria sent a photo\" depends on who is READING, and
-- last_message is one string shared by both participants -- so the wording
-- cannot be decided here. Record who sent it instead and let each client phrase
-- it for its own viewer. The 📷 marker from the previous migration is dropped.
--
-- No \"was it a photo\" flag is needed: send() refuses a message with neither a
-- body nor a file, so an empty body implies an attachment. The client reads
--   last_sender_id is null -> no messages yet
--   last_message is empty  -> a photo, phrased for the viewer
--   otherwise              -> the text itself

alter table public.conversations
  add column if not exists last_sender_id uuid references public.users(id) on delete set null;

create or replace function public.tg_message_after_insert()
returns trigger
language plpgsql
security definer
set search_path to ''public''
as $function$
begin
  update conversations c
     set last_message   = coalesce(trim(new.body), ''''),
         last_sender_id = new.sender_id,
         last_time      = new.sent_at,
         unread_a = case when c.user_a_id <> new.sender_id then c.unread_a + 1 else c.unread_a end,
         unread_b = case when c.user_b_id <> new.sender_id then c.unread_b + 1 else c.unread_b end
   where c.id = new.conversation_id;
  return new;
end;
$function$;

-- Backfill from each thread''s newest message, and undo the 📷 marker.
update public.conversations c
   set last_sender_id = newest.sender_id,
       last_message   = coalesce(trim(newest.body), '''')
  from (
    select distinct on (conversation_id) conversation_id, sender_id, body
      from public.messages
     order by conversation_id, sent_at desc
  ) newest
 where newest.conversation_id = c.id;"}', 'thread_preview_knows_its_sender', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913182105', '{"-- Every path that checks a PIN must count against the same lockout.
--
-- 20260913180214_pin_lock throttled verify_pin() but not set_pin() or
-- clear_pin(), both of which also compare the current PIN. That left two
-- unthrottled brute-force surfaces: \"Turn off PIN\" would accept guesses all day
-- without ever incrementing attempts, so the 15-minute lockout could simply be
-- walked around. Verified before this migration: six wrong guesses through
-- clear_pin/set_pin left attempts at 0.
--
-- One private helper now owns comparing, counting, locking and notifying, and
-- all three callers go through it.

create or replace function public.pin_attempt(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid(); v_row public.user_pins; v_ok boolean;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  select * into v_row from public.user_pins where user_id = v_me;
  if v_row.user_id is null then
    raise exception ''No PIN is set on this account'';
  end if;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    raise exception ''Too many attempts. Try again after %'',
      to_char(v_row.locked_until at time zone ''Asia/Manila'', ''HH12:MI AM'');
  end if;

  v_ok := v_row.pin_hash = extensions.crypt(p_pin, v_row.pin_hash);

  if v_ok then
    update public.user_pins set attempts = 0, locked_until = null where user_id = v_me;
    return true;
  end if;

  update public.user_pins
     set attempts = attempts + 1,
         locked_until = case when attempts + 1 >= 5 then now() + interval ''15 minutes'' end
   where user_id = v_me
  returning * into v_row;

  if v_row.locked_until is not null then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (
      v_me, ''security'', ''Incorrect PIN attempts'',
      ''Someone entered the wrong PIN 5 times on your account. If that was not you, change your password.'',
      null
    );
  end if;

  return false;
end $$;

-- Internal: the three functions below call it as the definer. Nothing gains by
-- exposing a bare \"is this the PIN\" endpoint to clients.
revoke all on function public.pin_attempt(text) from public, anon, authenticated;

create or replace function public.verify_pin(p_pin text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  return public.pin_attempt(p_pin);
end $$;

create or replace function public.set_pin(p_pin text, p_current text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  if p_pin !~ ''^[0-9]{6}$'' then
    raise exception ''A PIN must be exactly 6 digits'';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is not null then
    -- Counts against the lockout, exactly like entering it on the pad.
    if p_current is null or not public.pin_attempt(p_current) then
      raise exception ''That is not your current PIN'';
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt(''bf'')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
end $$;

create or replace function public.clear_pin(p_current text)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is null then return; end if;
  if not public.pin_attempt(p_current) then
    raise exception ''That is not your current PIN'';
  end if;
  delete from public.user_pins where user_id = v_me;
end $$;

revoke all on function public.verify_pin(text) from public;
revoke all on function public.set_pin(text, text) from public;
revoke all on function public.clear_pin(text) from public;
grant execute on function public.verify_pin(text) to authenticated;
grant execute on function public.set_pin(text, text) to authenticated;
grant execute on function public.clear_pin(text) to authenticated;"}', 'throttle_every_pin_check', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913182141', '{"-- A PIN check cannot both count the attempt and raise about it.
--
-- The previous migration routed set_pin/clear_pin through pin_attempt() so a
-- wrong guess would be tallied -- but both then raised ''That is not your current
-- PIN'', and a raise aborts the transaction, discarding the very increment that
-- was just made. PostgREST gives each RPC its own transaction, so every wrong
-- guess silently undid its own tally and the lockout never arrived. verify_pin
-- escaped it only because it RETURNS false rather than raising.
--
-- So the wrong-PIN answer is now a return value, not an exception. Exceptions
-- are kept only for cases with no state to preserve: not signed in, a malformed
-- PIN, or an account already locked (the lock was committed by the attempt that
-- set it). Both functions change return type, hence the drops.

drop function if exists public.set_pin(text, text);
drop function if exists public.clear_pin(text);

create function public.set_pin(p_pin text, p_current text default null)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  if p_pin !~ ''^[0-9]{6}$'' then
    raise exception ''A PIN must be exactly 6 digits'';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is not null then
    -- false, not an exception: the increment inside pin_attempt has to commit.
    if p_current is null or not public.pin_attempt(p_current) then
      return false;
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt(''bf'')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
  return true;
end $$;

create function public.clear_pin(p_current text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is null then return true; end if;
  if not public.pin_attempt(p_current) then
    return false;
  end if;
  delete from public.user_pins where user_id = v_me;
  return true;
end $$;

revoke all on function public.set_pin(text, text) from public;
revoke all on function public.clear_pin(text) from public;
grant execute on function public.set_pin(text, text) to authenticated;
grant execute on function public.clear_pin(text) to authenticated;"}', 'pin_throttle_must_survive_the_answer', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913182851', '{"-- Changing an existing PIN now needs proof of the mailbox as well as the old PIN.
--
-- Knowing the current PIN was the only barrier, so anyone who watched it being
-- typed -- or guessed it inside the five allowed attempts -- could quietly
-- replace it and lock the owner out of their own money and tenancy actions. A
-- PIN is meant to survive exactly that kind of shoulder-surfing.
--
-- The proof is the same one reset_pin() already uses: a JWT minted in the last
-- five minutes, which is what verifying an e-mail code produces. No new mail
-- plumbing -- registration''s sendEmailOtp/verifyEmailOtp already deliver it.
--
-- Setting the FIRST PIN is deliberately exempt: the account was just created or
-- the owner is already signed in and holds nothing to protect yet, and demanding
-- an e-mail round trip there would only push people to skip it.

create or replace function public.set_pin(p_pin text, p_current text default null)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text; v_iat bigint;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  if p_pin !~ ''^[0-9]{6}$'' then
    raise exception ''A PIN must be exactly 6 digits'';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;

  if v_hash is not null then
    -- Changing: the mailbox first, so a wrong-PIN answer never reveals whether
    -- the e-mail step would have passed.
    v_iat := nullif(auth.jwt() ->> ''iat'', '''')::bigint;
    if v_iat is null or v_iat < extract(epoch from now()) - 300 then
      raise exception ''Confirm the code sent to your e-mail first'';
    end if;

    -- false, not an exception: the increment inside pin_attempt has to commit.
    if p_current is null or not public.pin_attempt(p_current) then
      return false;
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt(''bf'')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
  return true;
end $$;

revoke all on function public.set_pin(text, text) from public;
grant execute on function public.set_pin(text, text) to authenticated;"}', 'changing_a_pin_needs_the_mailbox_too', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913183134', '{"-- One way to change a PIN: confirm the mailbox, choose a new one.
--
-- Requiring the old PIN *as well* looked like a second factor but was not one:
-- reset_pin() already accepted a new PIN on the strength of a fresh e-mail
-- confirmation alone, so anyone who could pass the old-PIN check could simply
-- have taken the easier path. Two rows in Settings, one strictly cheaper, same
-- outcome -- the extra field only slowed down the legitimate owner.
--
-- The mailbox is therefore the root of trust for changing a PIN, which is the
-- ordinary shape of account recovery and should be described that way rather
-- than as two independent factors. set_pin() keeps p_current purely so existing
-- callers do not break; it is ignored.
--
-- What the old PIN still genuinely guards is clear_pin(): turning protection OFF
-- asks for it, and that check is thrown against the same lockout ledger.

create or replace function public.set_pin(p_pin text, p_current text default null)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text; v_iat bigint;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  if p_pin !~ ''^[0-9]{6}$'' then
    raise exception ''A PIN must be exactly 6 digits'';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;

  -- Replacing an existing PIN needs a session minted in the last five minutes,
  -- which is what confirming an e-mail code produces. Setting the FIRST PIN is
  -- exempt: the owner is already signed in and has nothing yet to protect, and
  -- an e-mail round trip there would only push people to skip it.
  if v_hash is not null then
    v_iat := nullif(auth.jwt() ->> ''iat'', '''')::bigint;
    if v_iat is null or v_iat < extract(epoch from now()) - 300 then
      raise exception ''Confirm the code sent to your e-mail first'';
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt(''bf'')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
  return true;
end $$;

-- reset_pin() is now exactly set_pin() for an existing PIN. Kept as a thin alias
-- so nothing that already calls it breaks, rather than leaving two copies of the
-- same rule to drift apart.
create or replace function public.reset_pin(p_new text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.set_pin(p_new);
end $$;

revoke all on function public.set_pin(text, text) from public;
revoke all on function public.reset_pin(text) from public;
grant execute on function public.set_pin(text, text) to authenticated;
grant execute on function public.reset_pin(text) to authenticated;"}', 'one_way_to_change_a_pin', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260914093605', '{"alter table public.users add column privacy_accepted_at timestamptz;
grant select, insert, update (privacy_accepted_at) on public.users to authenticated;"}', 'separate_privacy_consent', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913183307', '{"-- Two leftovers from when changing a PIN and resetting a forgotten one were
-- separate flows.
--
-- reset_pin() became a one-line alias for set_pin() once both hung on the same
-- proof (a JWT minted in the last five minutes). Nothing calls it, and a second
-- public name for one rule is a second thing to audit.
--
-- set_pin''s p_current stopped being read at the same time, but stayed in the
-- signature -- an argument the server silently ignores is worse than one that
-- is not there, because a caller can believe it is being checked.

drop function if exists public.reset_pin(text);
drop function if exists public.set_pin(text, text);

create function public.set_pin(p_pin text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_hash text; v_iat bigint;
begin
  if v_me is null then raise exception ''Not signed in''; end if;
  if p_pin !~ ''^[0-9]{6}$'' then
    raise exception ''A PIN must be exactly 6 digits'';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;

  -- Replacing an existing PIN needs a session minted in the last five minutes,
  -- which is what confirming an e-mail code produces. The old PIN is NOT asked
  -- for: it is exactly what someone who has forgotten it cannot supply, and
  -- demanding it as well guarded nothing once the mailbox alone could reset.
  -- Setting the FIRST PIN is exempt -- the owner is already signed in and has
  -- nothing yet to protect, and a round trip there only makes people skip it.
  if v_hash is not null then
    v_iat := nullif(auth.jwt() ->> ''iat'', '''')::bigint;
    if v_iat is null or v_iat < extract(epoch from now()) - 300 then
      raise exception ''Confirm the code sent to your e-mail first'';
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt(''bf'')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
  return true;
end $$;

revoke all on function public.set_pin(text) from public;
grant execute on function public.set_pin(text) to authenticated;"}', 'drop_the_leftovers_of_the_old_pin_change', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913195728', '{"DROP POLICY IF EXISTS \"Authenticated users can view public profile info\" ON public.users;

CREATE POLICY users_select_related ON public.users
FOR SELECT
TO authenticated
USING (
  public.can_notify(id)
  OR EXISTS (
    SELECT 1 FROM public.accommodations a
    WHERE a.accommodation_manager_id = users.id
      AND a.status = ''accredited''
  )
);

CREATE OR REPLACE FUNCTION public.tg_payment_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''public''
AS $function$
declare
  v_student uuid;
  v_manager uuid;
begin
  select l.student_id, l.accommodation_manager_id
    into v_student, v_manager
    from public.leases l
   where l.id = new.lease_id;

  if auth.uid() is distinct from v_student or auth.uid() = v_manager then
    return new;
  end if;

  if tg_op = ''INSERT'' then
    if new.status <> ''pending_verification''
    or new.paid_at          is not null
    or new.verified_by      is not null
    or new.rejection_reason is not null then
      raise exception ''a student may only submit a payment for verification'';
    end if;
  else
    if new.status           is distinct from old.status
    or new.amount           is distinct from old.amount
    or new.month            is distinct from old.month
    or new.lease_id         is distinct from old.lease_id
    or new.paid_at          is distinct from old.paid_at
    or new.verified_by      is distinct from old.verified_by
    or new.rejection_reason is distinct from old.rejection_reason then
      raise exception ''a student may not verify or alter a submitted payment'';
    end if;
  end if;

  return new;
end;
$function$;

DROP TRIGGER IF EXISTS payment_guard ON public.payments;
CREATE TRIGGER payment_guard
  BEFORE INSERT OR UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.tg_payment_guard();

ALTER TABLE public.payments
  ADD CONSTRAINT payments_amount_positive CHECK (amount > 0);

DROP POLICY IF EXISTS payments_delete_involved ON public.payments;

CREATE POLICY payments_delete_manager ON public.payments
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.leases l
    WHERE l.id = payments.lease_id
      AND l.accommodation_manager_id = auth.uid()
  )
);

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;

GRANT EXECUTE ON FUNCTION public.is_admin(uuid)            TO anon;
GRANT EXECUTE ON FUNCTION public.can_notify(uuid)          TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_role()             TO anon;
GRANT EXECUTE ON FUNCTION public.my_accommodation_ids()    TO anon;
GRANT EXECUTE ON FUNCTION public.current_is_superadmin()   TO anon;

REVOKE EXECUTE ON FUNCTION public.check_student_id_exists(text) FROM anon, authenticated;

REVOKE INSERT, UPDATE, DELETE ON public.qr_scans           FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.concerns           FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.tickets            FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.ticket_messages    FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.review_inbox           FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.review_admin_feed      FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.review_written_leases  FROM anon;

CREATE OR REPLACE FUNCTION public.verify_student_qr(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''public''
AS $function$
DECLARE
  me uuid := auth.uid();
  recent integer;
  sp record;
  u record;
  is_mine boolean;
  v_method text := ''qr'';
  v_result text;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION ''Not signed in'';
  END IF;

  SELECT count(*) INTO recent
    FROM public.qr_scans
   WHERE scanner_id = me AND scanned_at > now() - interval ''1 minute'';
  IF recent >= 12 THEN
    RAISE EXCEPTION ''Too many scans in a row. Wait a minute and try again.'';
  END IF;

  SELECT * INTO sp FROM public.student_profiles WHERE qr_code_token = p_code;

  IF sp.user_id IS NOT NULL
     AND (sp.qr_token_expires_at IS NULL OR sp.qr_token_expires_at <= now()) THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, sp.user_id, ''qr'', ''expired'');
    RETURN jsonb_build_object(''found'', false, ''reason'', ''expired'');
  END IF;

  IF sp.user_id IS NULL THEN
    IF public.get_my_role() IN (''accommodation_manager'', ''admin'') THEN
      v_method := ''manual'';
      SELECT * INTO sp FROM public.student_profiles WHERE student_id = p_code;
    END IF;
  END IF;

  IF sp.user_id IS NULL THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, NULL, v_method, ''not_found'');
    RETURN jsonb_build_object(''found'', false, ''reason'', ''not_found'');
  END IF;

  SELECT * INTO u FROM public.users WHERE id = sp.user_id;

  SELECT EXISTS (
    SELECT 1 FROM public.leases l
     WHERE l.student_id = sp.user_id AND l.accommodation_manager_id = me
  ) INTO is_mine;

  v_result := CASE WHEN sp.osas_verified_at IS NOT NULL THEN ''verified'' ELSE ''unverified'' END;
  INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
  VALUES (me, sp.user_id, v_method, v_result);

  RETURN jsonb_build_object(
    ''found'', true,
    ''user_id'', sp.user_id,
    ''student_id'', sp.student_id,
    ''full_name'', u.full_name,
    ''initials'', u.initials,
    ''avatar_url'', u.avatar_url,
    ''program'', sp.program,
    ''college'', sp.college,
    ''year_level'', sp.year_level,
    ''osas_verified'', sp.osas_verified_at IS NOT NULL,
    ''verified_at'', sp.osas_verified_at,
    ''account_status'', u.status,
    ''is_my_tenant'', is_mine,
    ''method'', v_method
  );
END;
$function$;"}', 'server_side_enforcement', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913195759', '{"REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

GRANT EXECUTE ON FUNCTION public.is_admin(uuid)          TO anon;
GRANT EXECUTE ON FUNCTION public.can_notify(uuid)        TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_role()           TO anon;
GRANT EXECUTE ON FUNCTION public.my_accommodation_ids()  TO anon;
GRANT EXECUTE ON FUNCTION public.current_is_superadmin() TO anon;

REVOKE EXECUTE ON FUNCTION public.check_student_id_exists(text) FROM PUBLIC, anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;"}', 'lock_anon_rpc_for_real', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913201235', '{"REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;

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

GRANT EXECUTE ON FUNCTION public.is_admin(uuid)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_notify(uuid)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_accommodation_ids()  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_is_superadmin() TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM authenticated;

ALTER VIEW public.review_inbox          SET (security_invoker = true);
ALTER VIEW public.review_written_leases SET (security_invoker = true);
DROP VIEW IF EXISTS public.review_admin_feed;

DROP POLICY IF EXISTS users_select_own ON public.users;
DROP POLICY IF EXISTS \"Users can read their own profile\" ON public.users;
DROP POLICY IF EXISTS accommodation_managers_read_lease_tenant_users ON public.users;

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
create index if not exists idx_verification_requests_reviewed_by on verification_requests (reviewed_by);"}', 'lock_authenticated_rpc_and_views', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913201302', '{"GRANT SELECT ON public.accommodation_reviews         TO authenticated;
GRANT SELECT ON public.accommodation_manager_reviews TO authenticated;
GRANT SELECT ON public.tenant_reviews                TO authenticated;

REVOKE ALL ON public.review_inbox          FROM anon;
REVOKE ALL ON public.review_written_leases FROM anon;"}', 'review_tables_need_select', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260913201333', '{"CREATE OR REPLACE FUNCTION public.ticket_touch()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''public''
AS $function$
begin
  new.updated_at = now();
  if new.status = ''resolved'' and old.status is distinct from ''resolved'' then
    new.resolved_at = now();
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.validate_accommodation_facility_room()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''public''
AS $function$
BEGIN
  IF NEW.room_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.rooms
    WHERE id = NEW.room_id
      AND accommodation_id = NEW.accommodation_id
  ) THEN
    RAISE EXCEPTION ''Private facility room must belong to its accommodation'';
  END IF;
  RETURN NEW;
END;
$function$;"}', 'pin_trigger_search_paths', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260914062435', '{"-- The manager''s ticket-reply notification linked to /manager/osas-compliance,
-- which is not a route this app has. resolveNotifLink() rejects any path
-- missing from its ROUTES set, so the link silently degraded to the BY_TYPE
-- fallback -- which lands on /manager/osas anyway, just by accident rather
-- than on purpose. Name the real route.
--
-- Body is otherwise identical to 20260909000000_ticket_reply_channel.sql.

create or replace function public.trg_ticket_message_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.tickets%rowtype;
  preview text;
begin
  if new.is_internal then
    return new;
  end if;

  select * into t from public.tickets where id = new.ticket_id;
  if not found then
    return new;
  end if;

  preview := coalesce(t.subject, ''Your ticket'') || '': '' || left(new.body, 120);

  if new.author_role = ''agent'' then
    if t.student_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.student_id, ''OSAS replied to your ticket'', preview, ''ticket'', ''/student/support'');
    end if;
    if t.accommodation_manager_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.accommodation_manager_id, ''OSAS replied to your ticket'', preview, ''ticket'', ''/manager/osas'');
    end if;
  else
    perform public.notify_admins(
      ''New reply on a ticket'',
      preview,
      ''ticket'',
      ''/support-tickets?focus=ticket:'' || t.id::text
    );
  end if;

  return new;
end;
$$;

-- Existing rows still carry the dead path; they resolve through the same
-- fallback, so this only has to stop new ones being written.
update public.notifications
   set link_url = ''/manager/osas''
 where link_url = ''/manager/osas-compliance'';"}', 'ticket_notify_manager_link', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260914063937', '{"alter table public.accommodations
  add column if not exists gender_policy text;

alter table public.accommodations
  drop constraint if exists accommodations_gender_policy_check;

alter table public.accommodations
  add constraint accommodations_gender_policy_check
  check (gender_policy in (''male'', ''female'', ''co_ed''));"}', 'accommodation_gender_policy', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260914090829', '{"alter table public.policies
  add column doc_type text not null default ''guideline''
    check (doc_type in (''tos'', ''privacy'', ''guideline''));"}', 'policy_doc_types', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915091850', '{"create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> ''provider'', ''email'');
  v_domain text;
  -- The twin of ALLOWED_EMAIL_DOMAINS in accommo-mobile/src/utils/config.ts.
  v_allowed text[] := array[''gmail.com'', ''isu.edu.ph''];
begin
  if tg_op = ''INSERT'' then
    v_domain := lower(split_part(coalesce(new.email, ''''), ''@'', 2));
    if v_domain <> all (v_allowed) then
      raise exception using
        errcode = ''check_violation'',
        message = format(''accommo: e-mail domain %L is not accepted'', v_domain),
        hint = ''Accommo accounts must use @gmail.com or @isu.edu.ph.'';
    end if;

    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      coalesce((new.raw_user_meta_data ->> ''sex'')::text, ''M''),
      case when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone),
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;

drop trigger if exists sync_public_users_from_auth on auth.users;
create trigger sync_public_users_from_auth
  after insert or delete or update on auth.users
  for each row execute function public.handle_auth_user_sync();"}', 'restrict_email_domains', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915104815', '{"create or replace function public.complete_registration()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception ''Not signed in.'';
  end if;

  perform set_config(''app.completing_registration'', ''true'', true);

  update public.users
     set registered_at       = coalesce(registered_at, now()),
         terms_accepted_at   = coalesce(terms_accepted_at, now()),
         privacy_accepted_at = coalesce(privacy_accepted_at, now()),
         updated_at          = now()
   where id = v_uid
     and email_verified_at is not null;

  if not found then
    raise exception ''Confirm your e-mail address before completing registration.''
      using errcode = ''check_violation'';
  end if;
end;
$$;

revoke all on function public.complete_registration() from public;
grant execute on function public.complete_registration() to authenticated;

create or replace function public.lock_user_privileges()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  allow_resubmit boolean := coalesce(current_setting(''app.resubmitting'', true), ''false'') = ''true'';
  allow_email boolean := coalesce(current_setting(''app.confirming_email'', true), ''false'') = ''true'';
  allow_complete boolean := coalesce(current_setting(''app.completing_registration'', true), ''false'') = ''true'';
  allow_sync boolean := coalesce(current_setting(''app.syncing_auth'', true), ''false'') = ''true'';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = ''INSERT'' then
    if new.role = ''admin'' and not public.is_admin(auth.uid()) then
      raise exception ''Insufficient privileges to assign the admin role.'';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      if not (old.registered_at is null
              and new.role in (''student'',''accommodation_manager'')
              and old.role <> ''admin'') then
        raise exception ''You are not allowed to change your own role.'';
      end if;
    end if;
    if new.email_verified_at is distinct from old.email_verified_at
       and not (allow_email or allow_sync) then
      raise exception ''You are not allowed to change your own e-mail verification.'';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = ''pending'' and old.status in (''rejected'',''unverified'') then
        return new;
      end if;
      raise exception ''You are not allowed to change your own account status.'';
    end if;
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception ''Registration is already complete.'';
    end if;

    if not allow_complete then
      if new.registered_at is distinct from old.registered_at then
        raise exception ''Registration is completed by the server, not the client.'';
      end if;
      if new.terms_accepted_at is distinct from old.terms_accepted_at
         or new.privacy_accepted_at is distinct from old.privacy_accepted_at then
        raise exception ''Consent timestamps are recorded by the server, not the client.'';
      end if;
    end if;

    if new.email is distinct from old.email and not allow_sync then
      raise exception ''Change your e-mail address through your account settings.'';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> ''provider'', ''email'');
  v_domain text;
  v_allowed text[] := array[''gmail.com'', ''isu.edu.ph''];
begin
  if tg_op = ''INSERT'' then
    v_domain := lower(split_part(coalesce(new.email, ''''), ''@'', 2));
    if v_domain <> all (v_allowed) then
      raise exception using
        errcode = ''check_violation'',
        message = format(''accommo: e-mail domain %L is not accepted'', v_domain),
        hint = ''Accommo accounts must use @gmail.com or @isu.edu.ph.'';
    end if;

    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      coalesce((new.raw_user_meta_data ->> ''sex'')::text, ''M''),
      case when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    perform set_config(''app.syncing_auth'', ''true'', true);
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone),
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;"}', 'lock_registration_columns', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915105210', '{"create or replace function public.reap_unverified_signups(p_older_than interval default ''72 hours'')
returns integer
language plpgsql security definer set search_path = public, auth
as $$
declare
  v_count integer;
begin
  with doomed as (
    delete from auth.users a
     where a.created_at < now() - p_older_than
       and exists (
         select 1
           from public.users u
          where u.id = a.id
            and u.email_verified_at is null
            and u.registered_at is null
            and u.role <> ''admin''
            and u.is_superadmin = false
       )
    returning a.id
  )
  select count(*) into v_count from doomed;
  return v_count;
end;
$$;

revoke all on function public.reap_unverified_signups(interval) from public;

do $$
begin
  perform cron.unschedule(''reap-unverified-signups'');
exception when others then
  null;
end $$;

select cron.schedule(
  ''reap-unverified-signups'',
  ''23 3 * * *'',
  $$select public.reap_unverified_signups()$$
);"}', 'reap_unverified_signups', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915105412', '{"-- The reaper was exposed on the REST API.
--
-- `revoke all ... from public` does not remove the EXECUTE that Supabase grants
-- directly to `anon` and `authenticated` through default privileges, so the
-- function was reachable at /rest/v1/rpc/reap_unverified_signups by anyone
-- holding the anon key — and it takes an interval, so `''0 seconds''` would have
-- deleted every unverified, unfinished account in one call.
revoke all on function public.reap_unverified_signups(interval) from anon, authenticated, public;

-- complete_registration is meant for signed-in users only. It already raises
-- ''Not signed in.'' when auth.uid() is null, so anon could do no harm, but an
-- endpoint that exists only to be refused should not exist.
revoke all on function public.complete_registration() from anon;

-- Belt and braces, so a future default-privilege grant cannot quietly re-expose
-- this. pg_cron and service_role both run without a JWT, so a null auth.uid()
-- is exactly the caller this is for; anything with a user behind it is not.
create or replace function public.reap_unverified_signups(p_older_than interval default ''72 hours'')
returns integer
language plpgsql security definer set search_path = public, auth
as $$
declare
  v_count integer;
begin
  if auth.uid() is not null then
    raise exception ''reap_unverified_signups is not callable by a client.'';
  end if;

  with doomed as (
    delete from auth.users a
     where a.created_at < now() - p_older_than
       and exists (
         select 1
           from public.users u
          where u.id = a.id
            and u.email_verified_at is null
            and u.registered_at is null
            and u.role <> ''admin''
            and u.is_superadmin = false
       )
    returning a.id
  )
  select count(*) into v_count from doomed;
  return v_count;
end;
$$;

revoke all on function public.reap_unverified_signups(interval) from anon, authenticated, public;"}', 'restrict_reaper_to_scheduler', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915113217', '{"DROP POLICY IF EXISTS audit_logs_insert_admin ON public.audit_logs;

CREATE POLICY audit_logs_insert_admin ON public.audit_logs
FOR INSERT
TO authenticated
WITH CHECK (
  public.is_admin(auth.uid())
  AND actor_id = auth.uid()
);

DROP POLICY IF EXISTS notifications_insert_admin ON public.notifications;

CREATE POLICY notifications_insert_admin ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS tenant_reviews_select_admin ON public.tenant_reviews;
CREATE POLICY tenant_reviews_select_admin ON public.tenant_reviews
FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS accommodation_manager_reviews_select_admin ON public.accommodation_manager_reviews;
CREATE POLICY accommodation_manager_reviews_select_admin ON public.accommodation_manager_reviews
FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS accommodation_reviews_select_admin ON public.accommodation_reviews;
CREATE POLICY accommodation_reviews_select_admin ON public.accommodation_reviews
FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

DROP VIEW IF EXISTS public.review_admin_feed;

CREATE VIEW public.review_admin_feed
WITH (security_invoker = true)
AS
  SELECT
    tr.id,
    ''tenant''::text                  AS kind,
    tr.student_id                   AS subject_id,
    tr.accommodation_manager_id     AS author_id,
    tr.rating,
    tr.comment,
    tr.created_at,
    tr.lease_id,
    NULL::uuid                      AS accommodation_id
  FROM public.tenant_reviews tr

  UNION ALL

  SELECT
    amr.id,
    ''manager''::text                 AS kind,
    amr.accommodation_manager_id    AS subject_id,
    amr.student_id                  AS author_id,
    amr.rating,
    amr.comment,
    amr.created_at,
    amr.lease_id,
    NULL::uuid                      AS accommodation_id
  FROM public.accommodation_manager_reviews amr

  UNION ALL

  SELECT
    ar.id,
    ''accommodation''::text           AS kind,
    ar.accommodation_id             AS subject_id,
    ar.student_id                   AS author_id,
    ar.rating,
    ar.comment,
    ar.created_at,
    ar.lease_id,
    ar.accommodation_id
  FROM public.accommodation_reviews ar;

REVOKE ALL ON public.review_admin_feed FROM anon;
GRANT SELECT ON public.review_admin_feed TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = ''supabase_realtime''
      AND schemaname = ''public''
      AND tablename = ''audit_logs''
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_logs;
  END IF;
END
$$;"}', 'web_console_can_record_its_decisions', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915182826', '{"alter table public.users
  add column if not exists date_of_birth date;

comment on column public.users.date_of_birth is
  ''Self-declared birth date, collected at registration. Nullable: accounts created before this column exists have none.'';

alter table public.users
  drop constraint if exists users_date_of_birth_plausible;
alter table public.users
  add constraint users_date_of_birth_plausible
  check (date_of_birth is null or (date_of_birth > date ''1900-01-01'' and date_of_birth <= current_date));

create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql security definer set search_path = public
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> ''provider'', ''email'');
  v_domain text;
  v_allowed text[] := array[''gmail.com'', ''isu.edu.ph''];
  v_dob date;
begin
  begin
    v_dob := nullif(new.raw_user_meta_data ->> ''date_of_birth'', '''')::date;
  exception when others then
    v_dob := null;
  end;

  if tg_op = ''INSERT'' then
    v_domain := lower(split_part(coalesce(new.email, ''''), ''@'', 2));
    if v_domain <> all (v_allowed) then
      raise exception using
        errcode = ''check_violation'',
        message = format(''accommo: e-mail domain %L is not accepted'', v_domain),
        hint = ''Accommo accounts must use @gmail.com or @isu.edu.ph.'';
    end if;

    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      date_of_birth, email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      coalesce((new.raw_user_meta_data ->> ''sex'')::text, ''M''),
      v_dob,
      case when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = excluded.sex,
          date_of_birth = coalesce(excluded.date_of_birth, public.users.date_of_birth),
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    perform set_config(''app.syncing_auth'', ''true'', true);
    update public.users
    set email = new.email,
        phone = coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone),
        date_of_birth = coalesce(v_dob, public.users.date_of_birth),
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;"}', 'record_date_of_birth', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915194954', '{"alter table public.users
  add column if not exists reviewing_by uuid references public.users(id) on delete set null,
  add column if not exists reviewing_at timestamptz;

alter table public.accommodations
  add column if not exists reviewing_by uuid references public.users(id) on delete set null,
  add column if not exists reviewing_at timestamptz;

comment on column public.users.reviewing_by is
  ''Admin who currently has this verification request open. Null when nobody does.'';
comment on column public.users.reviewing_at is
  ''When the current review claim was taken. Used to age out an abandoned lock.'';
comment on column public.accommodations.reviewing_by is
  ''Admin who currently has this accreditation request open. Null when nobody does.'';
comment on column public.accommodations.reviewing_at is
  ''When the current review claim was taken. Used to age out an abandoned lock.'';

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
  left join public.verification_documents d on d.user_id = u.id and d.status = ''pending''
  where public.is_admin(auth.uid())
    and u.status::text in (''pending'',''reviewing'')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$$;

revoke all on function public.get_verification_queue() from public;
grant execute on function public.get_verification_queue() to authenticated;"}', 'review_lock_ownership', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915201052', '{"alter type public.accommodation_status add value if not exists ''expired'';
alter type public.accommodation_status add value if not exists ''suspended'';
alter type public.accommodation_status add value if not exists ''needs_revision'';"}', 'property_status_values', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915201104', '{"create or replace function public.sweep_expired_permits() returns void
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  with latest as (
    select distinct on (d.accommodation_id, d.doc_type)
           d.accommodation_id, d.doc_type, d.expires_at
    from public.accommodation_documents d
    order by d.accommodation_id, d.doc_type, d.version desc
  ),
  lapsed as (
    select distinct accommodation_id from latest
    where expires_at is not null and expires_at < now()
  )
  update public.accommodations a
  set status = ''expired''
  where a.status = ''accredited''
    and a.id in (select accommodation_id from lapsed);
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      ''Accreditation expired'',
      n || '' accommodation(s) have a permit that has expired and are no longer listed.'',
      ''verification'', ''/verifications'');
  end if;
end $$;

revoke all on function public.sweep_expired_permits() from public, anon, authenticated;

create or replace function public.sweep_expired_accreditations() returns void
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  update public.accommodations a
  set status = ''expired''
  where a.status = ''accredited''
    and a.accreditation_expires_at is not null
    and a.accreditation_expires_at < now();
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      ''Accreditation term ended'',
      n || '' accommodation(s) reached the end of their accreditation term and are no longer listed.'',
      ''verification'', ''/verifications'');
  end if;
end $$;

revoke all on function public.sweep_expired_accreditations() from public, anon, authenticated;

select cron.unschedule(''sweep-expired-accreditations'')
where exists (select 1 from cron.job where jobname = ''sweep-expired-accreditations'');

select cron.schedule(''sweep-expired-accreditations'', ''30 18 * * *'',
                     $$select public.sweep_expired_accreditations();$$);

create or replace function public.tg_permit_needs_review() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config(''app.permit_review'', ''true'', true);
  update public.accommodations set status = ''pending''
  where id = new.accommodation_id
    and status in (''accredited'', ''expired'', ''needs_revision'', ''rejected'');
  perform set_config(''app.permit_review'', ''false'', true);
  return new;
end $$;

create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = ''student_profiles'' then
    if tg_op = ''INSERT'' then
      if new.osas_verified_at is not null then
        raise exception ''Only OSAS may set verification status.'';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception ''Only OSAS may change verification status.'';
    end if;
  end if;

  if tg_table_name = ''accommodations'' then
    if tg_op = ''INSERT'' then
      if new.status <> ''pending'' then
        raise exception ''A new accommodation must start as pending.'';
      end if;
    elsif new.status is distinct from old.status then
      if not (coalesce(current_setting(''app.permit_review'', true), ''false'') = ''true''
              and new.status = ''pending''
              and old.status in (''accredited'', ''expired'', ''needs_revision'', ''rejected'')) then
        raise exception ''Only OSAS may change accreditation status.'';
      end if;
    end if;
  end if;

  if tg_table_name = ''verification_documents'' then
    if new.status = ''approved'' then
      raise exception ''Only OSAS may approve a document.'';
    end if;
  end if;

  return new;
end $fn$;"}', 'property_status_writers', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915201435', '{"create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = ''student_profiles'' then
    if tg_op = ''INSERT'' then
      if new.osas_verified_at is not null then
        raise exception ''Only OSAS may set verification status.'';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception ''Only OSAS may change verification status.'';
    end if;
  end if;

  if tg_table_name = ''accommodations'' then
    if tg_op = ''INSERT'' then
      if new.status <> ''pending'' then
        raise exception ''A new accommodation must start as pending.'';
      end if;
    elsif new.status is distinct from old.status then
      if coalesce(current_setting(''app.permit_review'', true), ''false'') = ''true''
         and new.status = ''pending''
         and old.status in (''accredited'', ''expired'', ''needs_revision'', ''rejected'') then
        null;
      elsif auth.uid() = old.accommodation_manager_id
            and new.accommodation_manager_id = old.accommodation_manager_id
            and (
              (old.status = ''accredited'' and new.status = ''delisted'')
              or (old.status = ''delisted'' and new.status = ''accredited''
                  and (new.accreditation_expires_at is null
                       or new.accreditation_expires_at > now()))
            ) then
        null;
      else
        raise exception ''Only OSAS may change accreditation status.'';
      end if;
    end if;
  end if;

  if tg_table_name = ''verification_documents'' then
    if new.status = ''approved'' then
      raise exception ''Only OSAS may approve a document.'';
    end if;
  end if;

  return new;
end $fn$;"}', 'manager_may_delist', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915202240', '{"create policy accommodation_policies_select_admin on accommodation_policies
  for select to authenticated using (is_admin(auth.uid()));

create policy accommodation_amenities_select_admin on accommodation_amenities
  for select to authenticated using (is_admin(auth.uid()));"}', 'admin_reads_property_details', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260915203003', '{"drop function if exists public.get_verification_queue();

create function public.get_verification_queue()
returns table(
  user_id uuid, full_name text, email text, role text, user_status text,
  avatar_url text,
  created_at timestamp with time zone, reviewing_by uuid, reviewing_at timestamp with time zone,
  doc_id uuid, doc_type text, file_url text, filename text, doc_status text
)
language sql
security definer
set search_path to ''public''
as $function$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.avatar_url,
         u.created_at, u.reviewing_by, u.reviewing_at,
         d.id, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = ''pending''
  where public.is_admin(auth.uid())
    and u.status::text in (''pending'',''reviewing'')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$function$;

grant execute on function public.get_verification_queue() to anon, authenticated, service_role;"}', 'verification_queue_avatar', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260919064315', '{"create or replace function public.record_consent(p_documents text[])
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_unknown text[];
begin
  if v_uid is null then
    raise exception ''Not signed in.'';
  end if;

  if p_documents is null or cardinality(p_documents) = 0 then
    raise exception ''Name the document being accepted.''
      using errcode = ''check_violation'';
  end if;

  -- The column a name maps to is decided here, not by the caller, so the
  -- argument cannot reach any other column.
  select array_agg(d)
    into v_unknown
    from unnest(p_documents) as d
   where d not in (''terms'', ''privacy'');

  if v_unknown is not null then
    raise exception ''Unknown legal document: %'', array_to_string(v_unknown, '', '')
      using errcode = ''check_violation'';
  end if;

  perform set_config(''app.recording_consent'', ''true'', true);

  update public.users
     set terms_accepted_at = case
           when ''terms'' = any (p_documents) then now() else terms_accepted_at end,
         privacy_accepted_at = case
           when ''privacy'' = any (p_documents) then now() else privacy_accepted_at end,
         updated_at = now()
   where id = v_uid;

  if not found then
    raise exception ''Account not found.'';
  end if;
end;
$$;

revoke all on function public.record_consent(text[]) from public;
revoke all on function public.record_consent(text[]) from anon;
grant execute on function public.record_consent(text[]) to authenticated;

create or replace function public.lock_user_privileges()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  allow_resubmit boolean := coalesce(current_setting(''app.resubmitting'', true), ''false'') = ''true'';
  allow_email boolean := coalesce(current_setting(''app.confirming_email'', true), ''false'') = ''true'';
  allow_complete boolean := coalesce(current_setting(''app.completing_registration'', true), ''false'') = ''true'';
  allow_sync boolean := coalesce(current_setting(''app.syncing_auth'', true), ''false'') = ''true'';
  allow_consent boolean := coalesce(current_setting(''app.recording_consent'', true), ''false'') = ''true'';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = ''INSERT'' then
    if new.role = ''admin'' and not public.is_admin(auth.uid()) then
      raise exception ''Insufficient privileges to assign the admin role.'';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      -- Choosing student vs manager is part of onboarding, and only then.
      if not (old.registered_at is null
              and new.role in (''student'',''accommodation_manager'')
              and old.role <> ''admin'') then
        raise exception ''You are not allowed to change your own role.'';
      end if;
    end if;
    -- `allow_sync` joins `allow_email` here because the sync''s UPDATE branch
    -- stamps this column itself when an OAuth identity is linked later. In
    -- practice auth.uid() is null for a write driven by the auth server and this
    -- whole block is skipped, but that depends on how GoTrue happens to connect,
    -- which is not a thing to leave a security guard resting on.
    if new.email_verified_at is distinct from old.email_verified_at
       and not (allow_email or allow_sync) then
      raise exception ''You are not allowed to change your own e-mail verification.'';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = ''pending'' and old.status in (''rejected'',''unverified'') then
        return new;
      end if;
      raise exception ''You are not allowed to change your own account status.'';
    end if;
    -- Registration completes once; it cannot be un-set to re-open role changes.
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception ''Registration is already complete.'';
    end if;

    -- Completing a registration happens only through complete_registration().
    if new.registered_at is distinct from old.registered_at and not allow_complete then
      raise exception ''Registration is completed by the server, not the client.'';
    end if;

    -- Consent is stamped by complete_registration() the first time and by
    -- record_consent() when a document is revised. Never by the client.
    if (new.terms_accepted_at is distinct from old.terms_accepted_at
        or new.privacy_accepted_at is distinct from old.privacy_accepted_at)
       and not (allow_complete or allow_consent) then
      raise exception ''Consent timestamps are recorded by the server, not the client.'';
    end if;

    -- The address shown across both apps follows auth.users, and is only ever
    -- written by the sync trigger. Changing it directly let someone display an
    -- address they had never proved — on any domain, signup rule or not.
    if new.email is distinct from old.email and not allow_sync then
      raise exception ''Change your e-mail address through your account settings.'';
    end if;
  end if;
  return new;
end;
$$;"}', 'record_re_consent', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260919073413', '{"revoke execute on function public.get_verification_queue() from public, anon;
grant  execute on function public.get_verification_queue() to authenticated, service_role;"}', 'verification_queue_is_not_anon_reachable', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260919073527', '{"create or replace function public.tg_notification_attribution()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  sender_name text;
begin
  -- Addressed to yourself, or written by OSAS: nothing to attribute.
  if new.user_id = auth.uid() or public.is_admin(auth.uid()) then
    return new;
  end if;

  -- Service-role and trigger-driven writes have no auth.uid() at all; those are
  -- the backend''s own fan-outs and are equally not somebody''s peer.
  if auth.uid() is null then
    return new;
  end if;

  select u.full_name into sender_name from public.users u where u.id = auth.uid();
  new.source := coalesce(nullif(trim(sender_name), ''''), ''Another user'');

  -- The types a conversation peer has any business sending. Anything else --
  -- ''verification'', ''policy'', ''announcement'', ''system'' -- is OSAS''s voice, so it
  -- is demoted rather than rejected: a refused insert would fail the message
  -- send that carried it.
  if new.type is null or new.type not in (''message'', ''application'', ''lease'', ''leave'', ''payment'', ''concern'', ''review'') then
    new.type := ''message'';
  end if;

  return new;
end;
$fn$;

revoke all on function public.tg_notification_attribution() from anon, authenticated;

drop trigger if exists notification_attribution on public.notifications;
create trigger notification_attribution
  before insert on public.notifications
  for each row execute function public.tg_notification_attribution();"}', 'peer_notifications_cannot_impersonate', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260919073540', '{"create or replace function public.lock_document_ref() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  public_id text;
begin
  -- No JWT: service_role, a migration, or the SQL console. Same carve-out the
  -- sibling lock_verification_columns() trigger makes.
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  -- Unchanged on an update, or not a signed reference: nothing to pin.
  if new.file_url is null or new.file_url not like ''cld:%'' then return new; end if;
  if tg_op = ''UPDATE'' and new.file_url is not distinct from old.file_url then return new; end if;

  -- cld:<resource_type>:<type>:<format>:<public_id>, and a public_id may itself
  -- contain '':'' -- so take everything from the fifth field on, not just it.
  public_id := substr(new.file_url, length(split_part(new.file_url, '':'', 1) || '':'' ||
                                           split_part(new.file_url, '':'', 2) || '':'' ||
                                           split_part(new.file_url, '':'', 3) || '':'' ||
                                           split_part(new.file_url, '':'', 4) || '':'') + 1);

  if public_id !~ (''^accommo/docs/'' || auth.uid()::text || ''/'') then
    raise exception ''A document may only reference a file you uploaded.'';
  end if;

  return new;
end $fn$;

revoke all on function public.lock_document_ref() from anon, authenticated;

drop trigger if exists trg_lock_document_ref on public.verification_documents;
create trigger trg_lock_document_ref before insert or update on public.verification_documents
  for each row execute function public.lock_document_ref();

drop trigger if exists trg_lock_document_ref on public.accommodation_documents;
create trigger trg_lock_document_ref before insert or update on public.accommodation_documents
  for each row execute function public.lock_document_ref();"}', 'documents_cannot_point_at_someone_elses_file', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260919073610', '{"create or replace function public.student_may_lease(p_student uuid)
returns boolean
language sql
stable
security definer
set search_path to ''public''
as $fn$
  select exists (
    select 1
      from public.users u
      join public.student_profiles sp on sp.user_id = u.id
     where u.id = p_student
       and u.role::text = ''student''
       and u.status::text = ''verified''
       and sp.osas_verified_at is not null
  );
$fn$;

revoke all on function public.student_may_lease(uuid) from public, anon;
grant execute on function public.student_may_lease(uuid) to authenticated, service_role;

alter policy leases_insert_manager on public.leases
  with check (
    accommodation_manager_id = (select auth.uid())
    and exists (
      select 1 from public.rooms r
        join public.accommodations a on a.id = r.accommodation_id
       where r.id = leases.room_id
         and a.accommodation_manager_id = (select auth.uid())
    )
    and public.student_may_lease(leases.student_id)
  );

alter policy leases_insert_student_application on public.leases
  with check (
    student_id = (select auth.uid())
    and status = ''pending''::lease_status
    and exists (
      select 1 from public.rooms r
        join public.accommodations a on a.id = r.accommodation_id
       where r.id = leases.room_id
         and a.accommodation_manager_id = leases.accommodation_manager_id
    )
    and public.student_may_lease(leases.student_id)
    and exists (
      select 1 from public.conversations c
       where c.invited_room_id = leases.room_id
         and ((c.user_a_id = leases.student_id and c.user_b_id = leases.accommodation_manager_id)
           or (c.user_b_id = leases.student_id and c.user_a_id = leases.accommodation_manager_id))
    )
  );

create or replace function public.invite_application(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path to ''public''
as $fn$
declare
  v_me uuid := auth.uid();
  v_room uuid;
  v_student uuid;
begin
  if v_me is null then
    raise exception ''Not signed in'';
  end if;

  select c.inquiry_room_id,
         case when c.user_a_id = v_me then c.user_b_id else c.user_a_id end
    into v_room, v_student
  from public.conversations c
  where c.id = p_conversation
    and (c.user_a_id = v_me or c.user_b_id = v_me);

  if not found then
    raise exception ''Conversation not found'';
  end if;

  if (select u.role::text from public.users u where u.id = v_me) <> ''accommodation_manager'' then
    raise exception ''Only the accommodation manager can send an application form'';
  end if;

  if v_room is null then
    raise exception ''This student has not asked about a room yet'';
  end if;

  if not exists (
    select 1
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
    where r.id = v_room
      and a.accommodation_manager_id = v_me
      and r.status = ''available''
  ) then
    raise exception ''That room is not yours, or is no longer available'';
  end if;

  if not public.student_may_lease(v_student) then
    raise exception ''OSAS has not verified this student yet, so they cannot be offered a room.'';
  end if;

  if exists (
    select 1 from public.leases l
    where l.student_id = v_student
      and l.status in (''pending'', ''active'', ''leave_requested'')
  ) then
    raise exception ''This student already has a current application or stay'';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $fn$;

create or replace function public.tg_lease_guard_student_update()
returns trigger
language plpgsql
security definer
set search_path to ''public''
as $fn$
begin
  if new.student_id is distinct from old.student_id
     and not public.is_admin(auth.uid()) then
    raise exception ''a lease cannot be reassigned to a different student'';
  end if;

  if auth.uid() = old.student_id and auth.uid() <> old.accommodation_manager_id then
    if new.room_id                   is distinct from old.room_id
    or new.student_id                is distinct from old.student_id
    or new.accommodation_manager_id  is distinct from old.accommodation_manager_id
    or new.monthly_rent              is distinct from old.monthly_rent
    or new.start_date                is distinct from old.start_date
    or new.end_date                  is distinct from old.end_date
    or new.deposit_paid              is distinct from old.deposit_paid
    or new.advance_paid              is distinct from old.advance_paid then
      raise exception ''a student may only request leave on their own lease'';
    end if;
  end if;
  return new;
end $fn$;

create or replace function public.tg_revoke_on_unverify()
returns trigger
language plpgsql
security definer
set search_path to ''public'', ''auth''
as $fn$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  awaiting_review boolean := new.role = ''accommodation_manager'' and new.status = ''pending'';
begin
  if new.status in (''rejected'',''suspended'') and new.status is distinct from old.status then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where accommodation_manager_id = new.id and status = ''accredited'';
  end if;

  if new.status = ''suspended'' and old.status is distinct from ''suspended'' then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if new.status in (''verified'',''rejected'',''reviewing'')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $fn$;"}', 'only_a_verified_student_may_hold_a_lease', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260919073958', '{"-- The two trigger functions added minutes ago were revoked from `anon,
-- authenticated` but not from PUBLIC, so they inherited the default PUBLIC grant
-- and showed up on the REST surface -- the same trap 20260914000001 documented
-- and 20260916000006 fell into, repeated here in the very migration whose
-- comment warned about it.
--
-- Calling either one over REST would fail anyway (\"trigger functions can only be
-- called as triggers\"), so nothing was exposed. It is the grant that is wrong,
-- and a wrong grant on a SECURITY DEFINER function is not worth leaving lying
-- around to be read as precedent.
revoke all on function public.lock_document_ref() from public, anon, authenticated;
revoke all on function public.tg_notification_attribution() from public, anon, authenticated;"}', 'trigger_functions_are_not_rpc_surface', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260920214842', '{"alter table public.verification_documents
  add column if not exists expires_at date;

comment on column public.verification_documents.expires_at is
  ''Expiry of the document itself, as entered by the uploader. Null for document types that do not expire (school_id, assessment_of_fees) and for rows predating the column.'';"}', 'verification_document_expiry', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260920215921', '{"delete from public.verification_documents vd
where exists (
  select 1
  from public.verification_documents newer
  where newer.user_id = vd.user_id
    and newer.doc_type = vd.doc_type
    and (newer.uploaded_at, newer.id) > (vd.uploaded_at, vd.id)
);

create unique index if not exists verification_documents_user_doc_type_key
  on public.verification_documents (user_id, doc_type);"}', 'verification_document_uniqueness', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260920225957', '{"alter table public.accommodation_policies
  drop column if exists smoking;"}', 'smoking_is_never_allowed', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260922033848', '{"-- Rename the `accommodation_manager` role to `landlord` across the schema.
-- Identifiers use the single ungendered token `landlord`; the UI renders
-- \"Landlord/Landlady\" over it. A person''s title is derived client-side from
-- users.sex. See accommo-mobile/supabase/migrations/20260922000000_*.sql.

-- 1. Enum values
alter type public.user_role     rename value ''accommodation_manager''  to ''landlord'';
alter type public.audience_type rename value ''accommodation_managers'' to ''landlords'';

-- 2. Tables
alter table public.accommodation_manager_profiles rename to landlord_profiles;
alter table public.accommodation_manager_reviews  rename to landlord_reviews;

-- 3. Columns
alter table public.accommodations   rename column accommodation_manager_id to landlord_id;
alter table public.leases           rename column accommodation_manager_id to landlord_id;
alter table public.tickets          rename column accommodation_manager_id to landlord_id;
alter table public.tenant_reviews   rename column accommodation_manager_id to landlord_id;
alter table public.landlord_reviews rename column accommodation_manager_id to landlord_id;

-- 4. Constraints
alter table public.landlord_profiles
  rename constraint accommodation_manager_profiles_pkey to landlord_profiles_pkey;
alter table public.landlord_profiles
  rename constraint accommodation_manager_profiles_user_id_fkey to landlord_profiles_user_id_fkey;
alter table public.landlord_reviews
  rename constraint accommodation_manager_reviews_pkey to landlord_reviews_pkey;
alter table public.landlord_reviews
  rename constraint accommodation_manager_reviews_accommodation_manager_id_fkey to landlord_reviews_landlord_id_fkey;
alter table public.landlord_reviews
  rename constraint accommodation_manager_reviews_lease_id_fkey to landlord_reviews_lease_id_fkey;
alter table public.landlord_reviews
  rename constraint accommodation_manager_reviews_lease_id_key to landlord_reviews_lease_id_key;
alter table public.landlord_reviews
  rename constraint accommodation_manager_reviews_rating_range to landlord_reviews_rating_range;
alter table public.landlord_reviews
  rename constraint accommodation_manager_reviews_student_id_fkey to landlord_reviews_student_id_fkey;
alter table public.accommodations
  rename constraint accommodations_accommodation_manager_id_fkey to accommodations_landlord_id_fkey;
alter table public.leases
  rename constraint leases_accommodation_manager_id_fkey to leases_landlord_id_fkey;
alter table public.tenant_reviews
  rename constraint tenant_reviews_accommodation_manager_id_fkey to tenant_reviews_landlord_id_fkey;
alter table public.tickets
  rename constraint tickets_accommodation_manager_id_fkey to tickets_landlord_id_fkey;

-- 5. Standalone indexes
alter index public.idx_accommodation_manager_reviews_accommodation_manager_id rename to idx_landlord_reviews_landlord_id;
alter index public.idx_accommodation_manager_reviews_student_id rename to idx_landlord_reviews_student_id;
alter index public.idx_accommodations_accommodation_manager_id rename to idx_accommodations_landlord_id;
alter index public.idx_leases_accommodation_manager_id rename to idx_leases_landlord_id;
alter index public.idx_tenant_reviews_accommodation_manager_id rename to idx_tenant_reviews_landlord_id;
alter index public.idx_tickets_accommodation_manager_id rename to idx_tickets_landlord_id;

-- 6. Trigger function whose own name carries the old term
alter function public.trg_new_accommodation_manager() rename to trg_new_landlord;

-- 7. Function bodies (all 16 have string bodies, so renames do not reach them)

create or replace function public.can_notify(target uuid)
 returns boolean language sql stable security definer set search_path to ''public''
as $function$
  select
    target = auth.uid()
    or exists (
      select 1 from public.leases l
      where (l.student_id = auth.uid() and l.landlord_id = target)
         or (l.landlord_id = auth.uid() and l.student_id = target))
    or exists (
      select 1 from public.conversations c
      where (c.user_a_id = auth.uid() and c.user_b_id = target)
         or (c.user_b_id = auth.uid() and c.user_a_id = target));
$function$;

create or replace function public.my_accommodation_ids()
 returns table(id uuid) language sql stable security definer set search_path to ''public''
as $function$
  SELECT r.accommodation_id
  FROM public.leases l
  JOIN public.rooms r ON r.id = l.room_id
  WHERE l.student_id = auth.uid() AND l.status = ''active''
  UNION
  SELECT a.id FROM public.accommodations a WHERE a.landlord_id = auth.uid();
$function$;

drop function if exists public.submit_student_review(uuid, uuid, uuid, integer, text, integer, text);

create function public.submit_student_review(p_lease_id uuid, p_accommodation_id uuid, p_landlord_id uuid, p_acc_rating integer, p_acc_comment text, p_manager_rating integer, p_manager_comment text)
 returns void language sql set search_path to ''public''
as $function$
  with acc as (
    insert into public.accommodation_reviews (lease_id, student_id, accommodation_id, rating, comment)
    values (p_lease_id, auth.uid(), p_accommodation_id, p_acc_rating, nullif(btrim(coalesce(p_acc_comment, '''')), ''''))
    returning 1
  )
  insert into public.landlord_reviews (lease_id, student_id, landlord_id, rating, comment)
  select p_lease_id, auth.uid(), p_landlord_id, p_manager_rating,
         nullif(btrim(coalesce(p_manager_comment, '''')), '''')
    from acc;
$function$;

create or replace function public.notify_policy()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
BEGIN
  IF new.archived OR new.effective_date > now() THEN RETURN new; END IF;
  IF tg_op = ''UPDATE'' AND NOT (old.archived OR old.effective_date > now()) THEN RETURN new; END IF;

  INSERT INTO public.notifications (user_id, title, body, type, link_url, ref_id, source)
  SELECT
    u.id,
    new.title,
    coalesce(new.version || '' · '', '''')
      || ''In effect from '' || to_char(new.effective_date AT TIME ZONE ''Asia/Manila'', ''Mon DD, YYYY'')
      || ''. Open Policies & guidelines to read and accept it.'',
    ''policy'',
    NULL,
    new.id,
    ''System Admin''
  FROM public.users u
  WHERE u.status <> ''suspended''
    AND u.role IN (''student'', ''landlord'');

  RETURN new;
END;
$function$;

create or replace function public.purge_unverified_accounts(p_older_than interval default ''30 days''::interval)
 returns integer language plpgsql security definer set search_path to ''public'', ''auth''
as $function$
declare
  n integer;
begin
  with doomed as (
    select u.id
    from public.users u
    where u.email_verified_at is null
      and u.status = ''pending''
      and u.created_at < now() - p_older_than
      and not exists (select 1 from public.verification_documents d where d.user_id = u.id)
      and not exists (select 1 from public.leases l where l.student_id = u.id or l.landlord_id = u.id)
      and not exists (select 1 from public.accommodations a where a.landlord_id = u.id)
      and not exists (select 1 from public.messages m where m.sender_id = u.id)
  )
  delete from auth.users a using doomed d where a.id = d.id;
  get diagnostics n = row_count;

  if n > 0 then
    insert into public.audit_logs (action, actor_id, entity_type, after_json)
    values (''auth.purge_unverified'', null, ''user'',
            jsonb_build_object(''deleted'', n, ''older_than'', p_older_than::text));
  end if;
  return n;
end $function$;

create or replace function public.tg_lease_closed_clears_inquiry()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
begin
  update public.conversations c
     set inquiry_room_id = null,
         invited_room_id = null,
         invited_at = null
   where (c.user_a_id = NEW.student_id and c.user_b_id = NEW.landlord_id)
      or (c.user_b_id = NEW.student_id and c.user_a_id = NEW.landlord_id);
  return NEW;
end $function$;

create or replace function public.tg_lease_guard_student_update()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
begin
  if new.student_id is distinct from old.student_id
     and not public.is_admin(auth.uid()) then
    raise exception ''a lease cannot be reassigned to a different student'';
  end if;

  if auth.uid() = old.student_id and auth.uid() <> old.landlord_id then
    if new.room_id      is distinct from old.room_id
    or new.student_id   is distinct from old.student_id
    or new.landlord_id  is distinct from old.landlord_id
    or new.monthly_rent is distinct from old.monthly_rent
    or new.start_date   is distinct from old.start_date
    or new.end_date     is distinct from old.end_date
    or new.deposit_paid is distinct from old.deposit_paid
    or new.advance_paid is distinct from old.advance_paid then
      raise exception ''a student may only request leave on their own lease'';
    end if;
  end if;
  return new;
end $function$;

create or replace function public.trg_new_landlord()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
begin
  if new.role = ''landlord'' then
    perform public.notify_admins(
      ''New landlord/landlady registered'',
      coalesce(new.full_name, new.email)
        || '' joined as a landlord/landlady and needs verification.'',
      ''verification'',
      ''/verifications?focus=verification:'' || new.id::text
    );
  end if;
  return new;
end;
$function$;

create or replace function public.fanout_announcement(p_id uuid)
 returns integer language plpgsql security definer set search_path to ''public''
as $function$
DECLARE a public.announcements; sent integer; sender text;
BEGIN
  UPDATE public.announcements
     SET notified_at = now()
   WHERE id = p_id
     AND notified_at IS NULL
     AND archived = false
     AND published_at IS NOT NULL
     AND published_at <= now()
     AND (expires_at IS NULL OR expires_at > now())
  RETURNING * INTO a;

  IF a.id IS NULL THEN RETURN 0; END IF;

  SELECT CASE
           WHEN a.accommodation_id IS NULL THEN ''System Admin''
           ELSE coalesce((SELECT name FROM public.accommodations WHERE id = a.accommodation_id), ''Your accommodation'')
         END
    INTO sender;

  INSERT INTO public.notifications (user_id, title, body, type, link_url, ref_id, source)
  SELECT u.id, a.title, coalesce(nullif(a.summary, ''''), left(a.body, 300)), ''announcement'', NULL, a.id, sender
  FROM public.users u
  WHERE u.status <> ''suspended''
    AND u.id <> a.author_id
    AND (
      CASE WHEN a.accommodation_id IS NULL THEN
        (a.audience = ''all'' AND u.role IN (''student'', ''landlord''))
        OR (a.audience = ''students'' AND u.role = ''student'')
        OR (a.audience = ''landlords'' AND u.role = ''landlord'')
      ELSE
        u.id IN (
          SELECT l.student_id FROM public.leases l
          JOIN public.rooms r ON r.id = l.room_id
          WHERE r.accommodation_id = a.accommodation_id AND l.status = ''active''
        )
      END
    );

  GET DIAGNOSTICS sent = ROW_COUNT;
  RETURN sent;
END;
$function$;

create or replace function public.invite_application(p_conversation uuid)
 returns void language plpgsql security definer set search_path to ''public''
as $function$
declare
  v_me uuid := auth.uid();
  v_room uuid;
  v_student uuid;
begin
  if v_me is null then
    raise exception ''Not signed in'';
  end if;

  select c.inquiry_room_id,
         case when c.user_a_id = v_me then c.user_b_id else c.user_a_id end
    into v_room, v_student
  from public.conversations c
  where c.id = p_conversation
    and (c.user_a_id = v_me or c.user_b_id = v_me);

  if not found then
    raise exception ''Conversation not found'';
  end if;

  if (select u.role::text from public.users u where u.id = v_me) <> ''landlord'' then
    raise exception ''Only the landlord/landlady can send an application form'';
  end if;

  if v_room is null then
    raise exception ''This student has not asked about a room yet'';
  end if;

  if not exists (
    select 1
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
    where r.id = v_room
      and a.landlord_id = v_me
      and r.status = ''available''
  ) then
    raise exception ''That room is not yours, or is no longer available'';
  end if;

  if not public.student_may_lease(v_student) then
    raise exception ''OSAS has not verified this student yet, so they cannot be offered a room.'';
  end if;

  if exists (
    select 1 from public.leases l
    where l.student_id = v_student
      and l.status in (''pending'', ''active'', ''leave_requested'')
  ) then
    raise exception ''This student already has a current application or stay'';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $function$;

create or replace function public.lock_user_privileges()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
declare
  allow_resubmit boolean := coalesce(current_setting(''app.resubmitting'', true), ''false'') = ''true'';
  allow_email boolean := coalesce(current_setting(''app.confirming_email'', true), ''false'') = ''true'';
  allow_complete boolean := coalesce(current_setting(''app.completing_registration'', true), ''false'') = ''true'';
  allow_sync boolean := coalesce(current_setting(''app.syncing_auth'', true), ''false'') = ''true'';
  allow_consent boolean := coalesce(current_setting(''app.recording_consent'', true), ''false'') = ''true'';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = ''INSERT'' then
    if new.role = ''admin'' and not public.is_admin(auth.uid()) then
      raise exception ''Insufficient privileges to assign the admin role.'';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      if not (old.registered_at is null
              and new.role in (''student'',''landlord'')
              and old.role <> ''admin'') then
        raise exception ''You are not allowed to change your own role.'';
      end if;
    end if;
    if new.email_verified_at is distinct from old.email_verified_at
       and not (allow_email or allow_sync) then
      raise exception ''You are not allowed to change your own e-mail verification.'';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = ''pending'' and old.status in (''rejected'',''unverified'') then
        return new;
      end if;
      raise exception ''You are not allowed to change your own account status.'';
    end if;
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception ''Registration is already complete.'';
    end if;
    if new.registered_at is distinct from old.registered_at and not allow_complete then
      raise exception ''Registration is completed by the server, not the client.'';
    end if;
    if (new.terms_accepted_at is distinct from old.terms_accepted_at
        or new.privacy_accepted_at is distinct from old.privacy_accepted_at)
       and not (allow_complete or allow_consent) then
      raise exception ''Consent timestamps are recorded by the server, not the client.'';
    end if;
    if new.email is distinct from old.email and not allow_sync then
      raise exception ''Change your e-mail address through your account settings.'';
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.lock_verification_columns()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = ''student_profiles'' then
    if tg_op = ''INSERT'' then
      if new.osas_verified_at is not null then
        raise exception ''Only OSAS may set verification status.'';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception ''Only OSAS may change verification status.'';
    end if;
  end if;

  if tg_table_name = ''accommodations'' then
    if tg_op = ''INSERT'' then
      if new.status <> ''pending'' then
        raise exception ''A new accommodation must start as pending.'';
      end if;
    elsif new.status is distinct from old.status then
      if coalesce(current_setting(''app.permit_review'', true), ''false'') = ''true''
         and new.status = ''pending''
         and old.status in (''accredited'', ''expired'', ''needs_revision'', ''rejected'') then
        null;
      elsif auth.uid() = old.landlord_id
            and new.landlord_id = old.landlord_id
            and (
              (old.status = ''accredited'' and new.status = ''delisted'')
              or (old.status = ''delisted'' and new.status = ''accredited''
                  and (new.accreditation_expires_at is null
                       or new.accreditation_expires_at > now()))
            ) then
        null;
      else
        raise exception ''Only OSAS may change accreditation status.'';
      end if;
    end if;
  end if;

  if tg_table_name = ''verification_documents'' then
    if new.status = ''approved'' then
      raise exception ''Only OSAS may approve a document.'';
    end if;
  end if;

  return new;
end $function$;

create or replace function public.tg_payment_guard()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
declare
  v_student uuid;
  v_landlord uuid;
begin
  select l.student_id, l.landlord_id
    into v_student, v_landlord
    from public.leases l
   where l.id = new.lease_id;

  if auth.uid() is distinct from v_student or auth.uid() = v_landlord then
    return new;
  end if;

  if tg_op = ''INSERT'' then
    if new.status <> ''pending_verification''
    or new.paid_at          is not null
    or new.verified_by      is not null
    or new.rejection_reason is not null then
      raise exception ''a student may only submit a payment for verification'';
    end if;
  else
    if new.status           is distinct from old.status
    or new.amount           is distinct from old.amount
    or new.month            is distinct from old.month
    or new.lease_id         is distinct from old.lease_id
    or new.paid_at          is distinct from old.paid_at
    or new.verified_by      is distinct from old.verified_by
    or new.rejection_reason is distinct from old.rejection_reason then
      raise exception ''a student may not verify or alter a submitted payment'';
    end if;
  end if;

  return new;
end;
$function$;

create or replace function public.tg_revoke_on_unverify()
 returns trigger language plpgsql security definer set search_path to ''public'', ''auth''
as $function$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  awaiting_review boolean := new.role = ''landlord'' and new.status = ''pending'';
begin
  if new.status in (''rejected'',''suspended'') and new.status is distinct from old.status then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where landlord_id = new.id and status = ''accredited'';
  end if;

  if new.status = ''suspended'' and old.status is distinct from ''suspended'' then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if new.status in (''verified'',''rejected'',''reviewing'')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $function$;

create or replace function public.trg_ticket_message_notify()
 returns trigger language plpgsql security definer set search_path to ''public''
as $function$
declare
  t public.tickets%rowtype;
  preview text;
begin
  if new.is_internal then
    return new;
  end if;

  select * into t from public.tickets where id = new.ticket_id;
  if not found then
    return new;
  end if;

  preview := coalesce(t.subject, ''Your ticket'') || '': '' || left(new.body, 120);

  if new.author_role = ''agent'' then
    if t.student_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.student_id, ''OSAS replied to your ticket'', preview, ''ticket'', ''/student/support'');
    end if;
    if t.landlord_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.landlord_id, ''OSAS replied to your ticket'', preview, ''ticket'', ''/manager/osas'');
    end if;
  else
    perform public.notify_admins(
      ''New reply on a ticket'',
      preview,
      ''ticket'',
      ''/support-tickets?focus=ticket:'' || t.id::text
    );
  end if;

  return new;
end;
$function$;

create or replace function public.verify_student_qr(p_code text)
 returns jsonb language plpgsql security definer set search_path to ''public''
as $function$
DECLARE
  me uuid := auth.uid();
  recent integer;
  sp record;
  u record;
  is_mine boolean;
  v_method text := ''qr'';
  v_result text;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION ''Not signed in'';
  END IF;

  SELECT count(*) INTO recent
    FROM public.qr_scans
   WHERE scanner_id = me AND scanned_at > now() - interval ''1 minute'';
  IF recent >= 12 THEN
    RAISE EXCEPTION ''Too many scans in a row. Wait a minute and try again.'';
  END IF;

  SELECT * INTO sp FROM public.student_profiles WHERE qr_code_token = p_code;

  IF sp.user_id IS NOT NULL
     AND (sp.qr_token_expires_at IS NULL OR sp.qr_token_expires_at <= now()) THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, sp.user_id, ''qr'', ''expired'');
    RETURN jsonb_build_object(''found'', false, ''reason'', ''expired'');
  END IF;

  IF sp.user_id IS NULL THEN
    IF public.get_my_role() IN (''landlord'', ''admin'') THEN
      v_method := ''manual'';
      SELECT * INTO sp FROM public.student_profiles WHERE student_id = p_code;
    END IF;
  END IF;

  IF sp.user_id IS NULL THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, NULL, v_method, ''not_found'');
    RETURN jsonb_build_object(''found'', false, ''reason'', ''not_found'');
  END IF;

  SELECT * INTO u FROM public.users WHERE id = sp.user_id;

  SELECT EXISTS (
    SELECT 1 FROM public.leases l
     WHERE l.student_id = sp.user_id AND l.landlord_id = me
  ) INTO is_mine;

  v_result := CASE WHEN sp.osas_verified_at IS NOT NULL THEN ''verified'' ELSE ''unverified'' END;
  INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
  VALUES (me, sp.user_id, v_method, v_result);

  RETURN jsonb_build_object(
    ''found'', true,
    ''user_id'', sp.user_id,
    ''student_id'', sp.student_id,
    ''full_name'', u.full_name,
    ''initials'', u.initials,
    ''avatar_url'', u.avatar_url,
    ''program'', sp.program,
    ''college'', sp.college,
    ''year_level'', sp.year_level,
    ''osas_verified'', sp.osas_verified_at IS NOT NULL,
    ''verified_at'', sp.osas_verified_at,
    ''account_status'', u.status,
    ''is_my_tenant'', is_mine,
    ''method'', v_method
  );
END;
$function$;"}', 'rename_accommodation_manager_to_landlord', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260922033923', '{"-- Two policies compare get_my_role(), which returns TEXT, against a string
-- literal. A text literal is not tracked by the enum''s OID, so ALTER TYPE ...
-- RENAME VALUE did not reach them and they were left matching a role that no
-- longer exists — denying landlords read access to policies and to
-- announcements addressed to them. They fail closed, so nothing was exposed.

drop policy if exists policies_select_authenticated on public.policies;
create policy policies_select_authenticated on public.policies
  for select to authenticated
  using (
    (not archived)
    and (effective_date <= now())
    and (public.get_my_role() = any (array[''student''::text, ''landlord''::text]))
  );

drop policy if exists announcements_select_audience on public.announcements;
create policy announcements_select_audience on public.announcements
  for select to authenticated
  using (
    (published_at is not null)
    and (published_at <= now())
    and (not archived)
    and ((expires_at is null) or (expires_at > now()))
    and case
      when (accommodation_id is null) then (
        (audience = ''all''::audience_type)
        or ((audience = ''students''::audience_type) and (public.get_my_role() = ''student''::text))
        or ((audience = ''landlords''::audience_type) and (public.get_my_role() = ''landlord''::text))
      )
      else (accommodation_id in (select id from public.my_accommodation_ids()))
    end
  );"}', 'fix_role_text_literals_after_landlord_rename', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260922034500', NULL, 'limit_accommodation_types', NULL, NULL, NULL),
	('20260922215003', '{"alter table public.accommodations
  add column if not exists hidden_from_listings boolean not null default false;

create or replace function public.guard_hidden_from_listings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.hidden_from_listings is distinct from old.hidden_from_listings
     and not is_admin(auth.uid()) then
    raise exception ''Only OSAS can change whether an accommodation is hidden from listings''
      using errcode = ''42501'';
  end if;
  return new;
end;
$$;

drop trigger if exists accommodations_guard_hidden_from_listings on public.accommodations;
create trigger accommodations_guard_hidden_from_listings
  before update of hidden_from_listings on public.accommodations
  for each row execute function public.guard_hidden_from_listings();"}', 'accommodation_hidden_from_listings', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260923100000', NULL, 'facility_rooms_and_status', NULL, NULL, NULL),
	('20260923110000', NULL, 'amenities_are_utilities', NULL, NULL, NULL),
	('20260923120000', NULL, 'payments_readable_by_osas', NULL, NULL, NULL),
	('20260923130000', NULL, 'sex_unknown_not_male', NULL, NULL, NULL),
	('20260923140000', NULL, 'report_settings', NULL, NULL, NULL),
	('20260923184828', '{"create table if not exists public.account_standing (
  user_id uuid primary key references public.users(id) on delete cascade,
  reason text,
  suspended_until timestamptz,
  restrictions text[] not null default ''{}''
    constraint account_standing_known_restrictions check (restrictions <@ array[''apply'', ''listings'']::text[]),
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.account_standing enable row level security;

drop policy if exists account_standing_select on public.account_standing;
create policy account_standing_select on public.account_standing
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin((select auth.uid())));

revoke all on public.account_standing from anon;
revoke insert, update, delete on public.account_standing from authenticated;
grant select on public.account_standing to authenticated;

drop trigger if exists trg_audit_account_standing on public.account_standing;
create trigger trg_audit_account_standing
  after insert or update or delete on public.account_standing
  for each row execute function public.fn_audit_log_change();

create or replace function public.student_may_lease(p_student uuid)
returns boolean
language sql
stable
security definer
set search_path to ''public''
as $fn$
  select exists (
    select 1
      from public.users u
      join public.student_profiles sp on sp.user_id = u.id
     where u.id = p_student
       and u.role::text = ''student''
       and u.status::text = ''verified''
       and sp.osas_verified_at is not null
       and not exists (
         select 1 from public.account_standing s
          where s.user_id = u.id and ''apply'' = any(s.restrictions)
       )
  );
$fn$;

revoke all on function public.student_may_lease(uuid) from public, anon;
grant execute on function public.student_may_lease(uuid) to authenticated, service_role;

create or replace function public.tg_revoke_on_unverify()
returns trigger
language plpgsql
security definer
set search_path to ''public'', ''auth''
as $function$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  awaiting_review boolean := new.role = ''landlord'' and new.status = ''pending'';
begin
  if new.status in (''rejected'',''suspended'') and new.status is distinct from old.status then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = ''delisted''
      where landlord_id = new.id and status = ''accredited'';
  end if;

  if new.status = ''suspended'' and old.status is distinct from ''suspended'' then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if new.status in (''verified'',''rejected'',''reviewing'')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  if new.status = ''verified'' and new.status is distinct from old.status
     and new.role = ''student'' then
    update public.student_profiles
       set osas_verified_at = coalesce(osas_verified_at, now())
     where user_id = new.id;
  end if;

  return new;
end $function$;

create or replace function public.admin_set_account_status(
  p_user uuid,
  p_status public.user_status,
  p_reason text default null,
  p_until timestamptz default null,
  p_restrictions text[] default null
)
returns void
language plpgsql
security definer
set search_path to ''public''
as $fn$
declare
  v_me uuid := auth.uid();
  v_user public.users;
  v_reason text := nullif(btrim(coalesce(p_reason, '''')), '''');
  v_old_restr text[];
  v_restr text[];
  v_added text[];
  v_removed text[];
  v_until_txt text;
begin
  if not public.is_admin(v_me) then
    raise exception ''Only OSAS can change an account''''s status.'' using errcode = ''42501'';
  end if;

  select * into v_user from public.users where id = p_user for update;
  if not found then
    raise exception ''That account no longer exists.'';
  end if;
  if v_user.role = ''admin'' or v_user.is_superadmin then
    raise exception ''Administrator accounts are managed under Settings.'';
  end if;

  select restrictions into v_old_restr from public.account_standing where user_id = p_user;
  v_old_restr := coalesce(v_old_restr, ''{}'');
  v_restr := coalesce(p_restrictions, v_old_restr);
  v_added := array(select unnest(v_restr) except select unnest(v_old_restr));
  v_removed := array(select unnest(v_old_restr) except select unnest(v_restr));

  if ''apply'' = any(v_added) and v_user.role <> ''student'' then
    raise exception ''Only a student can be stopped from applying for rooms.'';
  end if;
  if ''listings'' = any(v_added) and v_user.role <> ''landlord'' then
    raise exception ''Only a landlord/landlady has listings to hide.'';
  end if;

  if v_reason is null and (
       (p_status in (''suspended'', ''rejected'') and p_status is distinct from v_user.status)
       or cardinality(v_added) > 0
     ) then
    raise exception ''Give a reason — the person is told it.'';
  end if;

  if p_until is not null then
    if p_status <> ''suspended'' then
      raise exception ''An end date only applies to a suspension.'';
    end if;
    if p_until <= now() then
      raise exception ''The end date must be in the future.'';
    end if;
    if v_user.status not in (''verified'', ''suspended'') then
      raise exception ''Only a verified account can be suspended until a date.'';
    end if;
  end if;

  if p_status is distinct from v_user.status then
    update public.users set status = p_status, updated_at = now() where id = p_user;
  end if;

  insert into public.account_standing (user_id, reason, suspended_until, restrictions, updated_by, updated_at)
  values (
    p_user,
    v_reason,
    case when p_status = ''suspended'' then p_until end,
    v_restr,
    v_me,
    now()
  )
  on conflict (user_id) do update
    set reason = excluded.reason,
        suspended_until = excluded.suspended_until,
        restrictions = excluded.restrictions,
        updated_by = excluded.updated_by,
        updated_at = excluded.updated_at;

  if ''listings'' = any(v_added) then
    update public.accommodations set hidden_from_listings = true where landlord_id = p_user;
  elsif ''listings'' = any(v_removed) then
    update public.accommodations set hidden_from_listings = false where landlord_id = p_user;
  end if;

  if p_status is distinct from v_user.status and p_status in (''rejected'', ''verified'') then
    insert into public.verification_requests
      (entity_type, entity_id, type, status, reviewed_by, reviewed_at, decision_notes)
    values (
      ''user'',
      p_user,
      case when v_user.role = ''landlord'' then ''Landlord/Landlady Identity'' else ''Enrollment Form / COR'' end,
      case when p_status = ''rejected'' then ''resubmission_requested'' else ''approved'' end,
      v_me,
      now(),
      v_reason
    );
  end if;

  v_until_txt := case when p_until is not null
    then '' until '' || to_char(p_until at time zone ''Asia/Manila'', ''Mon FMDD, YYYY'')
    else '''' end;

  if p_status is distinct from v_user.status then
    insert into public.notifications (user_id, type, title, body, link_url)
    select p_user, ''verification'', t.title, t.body, ''/profile''
    from (values
      (case p_status
         when ''suspended'' then ''Account suspended''
         when ''rejected'' then ''Resubmission requested''
         when ''verified'' then case when v_user.status = ''suspended'' then ''Account reactivated'' else ''Verification approved'' end
       end,
       case p_status
         when ''suspended'' then ''OSAS suspended your account'' || v_until_txt || ''. Reason: '' || v_reason
         when ''rejected'' then ''OSAS needs new requirements from you. Note: '' || v_reason
         when ''verified'' then case when v_user.status = ''suspended''
           then ''Your account is active again.'' || coalesce('' Note: '' || v_reason, '''')
           else ''Your account has been verified.'' end
       end)
    ) as t(title, body)
    where t.title is not null;
  end if;

  if ''apply'' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, ''system'', ''Room applications paused'',
            ''OSAS has paused your room applications. Reason: '' || v_reason, ''/profile'');
  end if;
  if ''apply'' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, ''system'', ''Room applications restored'', ''You can apply for rooms again.'', ''/profile'');
  end if;
  if ''listings'' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, ''system'', ''Listings hidden'',
            ''OSAS has hidden your accommodations from students. Reason: '' || v_reason, ''/profile'');
  end if;
  if ''listings'' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, ''system'', ''Listings visible again'', ''Students can see your accommodations again.'', ''/profile'');
  end if;
end $fn$;

revoke all on function public.admin_set_account_status(uuid, public.user_status, text, timestamptz, text[]) from public, anon;
grant execute on function public.admin_set_account_status(uuid, public.user_status, text, timestamptz, text[]) to authenticated;

create or replace function public.lift_expired_suspensions()
returns integer
language plpgsql
security definer
set search_path to ''public''
as $fn$
declare
  v_count integer;
begin
  if auth.uid() is not null then
    raise exception ''lift_expired_suspensions is not callable by a client.'';
  end if;

  with due as (
    select s.user_id
      from public.account_standing s
      join public.users u on u.id = s.user_id
     where u.status = ''suspended''
       and s.suspended_until is not null
       and s.suspended_until <= now()
  ), lifted as (
    update public.users u set status = ''verified'', updated_at = now()
      from due where u.id = due.user_id
    returning u.id
  ), cleared as (
    update public.account_standing s
       set suspended_until = null, reason = null, updated_by = null, updated_at = now()
      from lifted where s.user_id = lifted.id
    returning s.user_id
  )
  insert into public.notifications (user_id, type, title, body, link_url)
  select user_id, ''verification'', ''Account reactivated'', ''Your suspension has ended. You can sign in again.'', ''/profile''
    from cleared;

  get diagnostics v_count = row_count;
  return v_count;
end $fn$;

revoke all on function public.lift_expired_suspensions() from public, anon, authenticated;

do $$
begin
  perform cron.unschedule(''lift-expired-suspensions'')
    where exists (select 1 from cron.job where jobname = ''lift-expired-suspensions'');
  perform cron.schedule(''lift-expired-suspensions'', ''*/15 * * * *'', ''select public.lift_expired_suspensions()'');
end $$;

create table if not exists public.account_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  author_id uuid references public.users(id) on delete set null default auth.uid(),
  body text not null constraint account_notes_body_size check (length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists account_notes_user_created on public.account_notes (user_id, created_at desc);

alter table public.account_notes enable row level security;

drop policy if exists account_notes_select_admin on public.account_notes;
create policy account_notes_select_admin on public.account_notes
  for select to authenticated using (public.is_admin((select auth.uid())));

drop policy if exists account_notes_insert_admin on public.account_notes;
create policy account_notes_insert_admin on public.account_notes
  for insert to authenticated
  with check (public.is_admin((select auth.uid())) and author_id = (select auth.uid()));

drop policy if exists account_notes_delete_author on public.account_notes;
create policy account_notes_delete_author on public.account_notes
  for delete to authenticated
  using (author_id = (select auth.uid()) and public.is_admin((select auth.uid())));

revoke all on public.account_notes from anon;
grant select, insert, delete on public.account_notes to authenticated;"}', 'account_status_controls', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260923190739', '{"create or replace function public.handle_auth_user_sync()
returns trigger
language plpgsql
security definer
set search_path to ''public''
as $function$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> ''provider'', ''email'');
  v_domain text;
  v_allowed text[] := array[''gmail.com'', ''isu.edu.ph''];
  v_dob date;
begin
  begin
    v_dob := nullif(new.raw_user_meta_data ->> ''date_of_birth'', '''')::date;
  exception when others then
    v_dob := null;
  end;

  if tg_op = ''INSERT'' then
    v_domain := lower(split_part(coalesce(new.email, ''''), ''@'', 2));
    if v_domain <> all (v_allowed) then
      raise exception using
        errcode = ''check_violation'',
        message = format(''accommo: e-mail domain %L is not accepted'', v_domain),
        hint = ''Accommo accounts must use @gmail.com or @isu.edu.ph.'';
    end if;

    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      date_of_birth, email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, ''+639000000000''),
      coalesce((new.raw_user_meta_data ->> ''role'')::text, ''student'')::user_role,
      ''pending''::user_status,
      coalesce(new.raw_user_meta_data ->> ''full_name'', ''Demo User''),
      coalesce(new.raw_user_meta_data ->> ''initials'', ''DU''),
      coalesce((new.raw_user_meta_data ->> ''avatar_color''), ''blue''),
      nullif(new.raw_user_meta_data ->> ''sex'', ''''),
      v_dob,
      case when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), null
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = coalesce(excluded.sex, public.users.sex),
          date_of_birth = coalesce(excluded.date_of_birth, public.users.date_of_birth),
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = ''UPDATE'' then
    perform set_config(''app.syncing_auth'', ''true'', true);
    update public.users
    set email = new.email,
        phone = case
          when new.phone is distinct from old.phone
            or (new.raw_user_meta_data ->> ''phone'') is distinct from (old.raw_user_meta_data ->> ''phone'')
          then coalesce(new.phone, (new.raw_user_meta_data ->> ''phone'')::text, phone)
          else phone
        end,
        date_of_birth = case
          when (new.raw_user_meta_data ->> ''date_of_birth'') is distinct from (old.raw_user_meta_data ->> ''date_of_birth'')
          then coalesce(v_dob, public.users.date_of_birth)
          else public.users.date_of_birth
        end,
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> ''email'' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = ''DELETE'' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$function$;

create or replace function public.assert_admin_over(p_user uuid)
returns void
language plpgsql
stable
security definer
set search_path to ''public''
as $fn$
begin
  if not public.is_admin(auth.uid()) then
    raise exception ''Only OSAS can do this.'' using errcode = ''42501'';
  end if;
  if not exists (select 1 from public.users where id = p_user and role in (''student'', ''landlord'') and not is_superadmin) then
    raise exception ''This only applies to student and landlord/landlady accounts.'';
  end if;
end $fn$;

revoke all on function public.assert_admin_over(uuid) from public, anon;
grant execute on function public.assert_admin_over(uuid) to authenticated;

create or replace function public.admin_sign_in_methods(p_user uuid)
returns table (has_password boolean, has_google boolean, last_sign_in_at timestamptz)
language plpgsql
stable
security definer
set search_path to ''public'', ''auth''
as $fn$
begin
  perform public.assert_admin_over(p_user);
  return query
    select coalesce(a.encrypted_password, '''') <> '''',
           exists (select 1 from auth.identities i where i.user_id = a.id and i.provider = ''google''),
           a.last_sign_in_at
      from auth.users a
     where a.id = p_user;
end $fn$;

create or replace function public.admin_sign_out_everywhere(p_user uuid)
returns integer
language plpgsql
security definer
set search_path to ''public'', ''auth''
as $fn$
declare
  v_count integer;
begin
  perform public.assert_admin_over(p_user);
  delete from auth.sessions where user_id = p_user;
  get diagnostics v_count = row_count;
  delete from auth.refresh_tokens where user_id = p_user::text;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), ''account.sign_out_everywhere'', ''users'', p_user::text, jsonb_build_object(''sessions'', v_count), now());
  return v_count;
end $fn$;

create or replace function public.admin_disconnect_google(p_user uuid)
returns void
language plpgsql
security definer
set search_path to ''public'', ''auth''
as $fn$
begin
  perform public.assert_admin_over(p_user);
  if not exists (select 1 from auth.identities where user_id = p_user and provider = ''google'') then
    raise exception ''This account has no Google account connected.'';
  end if;
  if (select coalesce(encrypted_password, '''') = '''' from auth.users where id = p_user) then
    raise exception ''Set a temporary password first — without Google they would have no way to sign in.'';
  end if;

  delete from auth.identities where user_id = p_user and provider = ''google'';
  update auth.users
     set raw_app_meta_data = jsonb_set(
           jsonb_set(coalesce(raw_app_meta_data, ''{}''), ''{provider}'', ''\"email\"''),
           ''{providers}'',
           coalesce((select jsonb_agg(p) from jsonb_array_elements_text(raw_app_meta_data -> ''providers'') p where p <> ''google''), ''[\"email\"]'')
         )
   where id = p_user;
  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), ''account.disconnect_google'', ''users'', p_user::text, ''{}''::jsonb, now());
end $fn$;

revoke all on function public.admin_sign_in_methods(uuid) from public, anon;
revoke all on function public.admin_sign_out_everywhere(uuid) from public, anon;
revoke all on function public.admin_disconnect_google(uuid) from public, anon;
grant execute on function public.admin_sign_in_methods(uuid) to authenticated;
grant execute on function public.admin_sign_out_everywhere(uuid) to authenticated;
grant execute on function public.admin_disconnect_google(uuid) to authenticated;"}', 'admin_account_recovery', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260923192143', '{"alter table public.users add column if not exists closed_at timestamptz;

create or replace function public.admin_change_role(p_user uuid, p_role public.user_role, p_reason text)
returns void
language plpgsql
security definer
set search_path to ''public'', ''auth''
as $fn$
declare
  v_user public.users;
  v_reason text := nullif(btrim(coalesce(p_reason, '''')), '''');
begin
  perform public.assert_admin_over(p_user);
  if p_role not in (''student'', ''landlord'') then
    raise exception ''An account can only become a student or a landlord/landlady here.'';
  end if;
  if v_reason is null then
    raise exception ''Give a reason — the person is told it.'';
  end if;

  select * into v_user from public.users where id = p_user for update;
  if v_user.role = p_role then
    raise exception ''They already have that role.'';
  end if;
  if v_user.closed_at is not null then
    raise exception ''This account is closed.'';
  end if;
  if exists (select 1 from public.leases
              where (student_id = p_user or landlord_id = p_user)
                and status in (''active'', ''pending'', ''leave_requested'')) then
    raise exception ''They have a current stay or application. It has to end first.'';
  end if;
  if exists (select 1 from public.accommodations where landlord_id = p_user) then
    raise exception ''They still own accommodations. Those have to be removed or transferred first.'';
  end if;

  update public.users
     set role = p_role,
         status = ''pending'',
         registered_at = null,
         updated_at = now()
   where id = p_user;
  update public.student_profiles set osas_verified_at = null where user_id = p_user;

  insert into public.account_standing (user_id, reason, restrictions, updated_by, updated_at)
  values (p_user, v_reason, ''{}'', auth.uid(), now())
  on conflict (user_id) do update
    set reason = excluded.reason, suspended_until = null, restrictions = ''{}'',
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;

  insert into public.notifications (user_id, type, title, body, link_url)
  values (p_user, ''verification'', ''Your account role was changed'',
          ''OSAS changed your account to '' || case when p_role = ''student'' then ''a student'' else ''a landlord/landlady'' end
          || ''. Sign in again to finish registering. Reason: '' || v_reason, ''/profile'');
end $fn$;

create or replace function public.admin_close_account(p_user uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path to ''public'', ''auth''
as $fn$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '''')), '''');
begin
  perform public.assert_admin_over(p_user);
  if not public.current_is_superadmin() then
    raise exception ''Only the main admin can close an account.'' using errcode = ''42501'';
  end if;
  if v_reason is null then
    raise exception ''Give a reason for closing the account.'';
  end if;
  if (select closed_at from public.users where id = p_user) is not null then
    raise exception ''This account is already closed.'';
  end if;
  if exists (select 1 from public.leases
              where (student_id = p_user or landlord_id = p_user)
                and status in (''active'', ''pending'', ''leave_requested'')) then
    raise exception ''They have a current stay or application. It has to end first.'';
  end if;
  if exists (select 1 from public.accommodations where landlord_id = p_user and status = ''accredited'') then
    raise exception ''They have accredited accommodations. Delist them first.'';
  end if;

  delete from auth.identities where user_id = p_user;
  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;
  update auth.users
     set email = ''closed+'' || p_user::text || ''@accommo.invalid'',
         phone = null,
         encrypted_password = '''',
         raw_user_meta_data = ''{}''::jsonb,
         banned_until = now() + interval ''100 years''
   where id = p_user;

  update public.users
     set full_name = ''Closed account'',
         initials = ''CA'',
         phone = ''+639000000000'',
         sex = null,
         date_of_birth = null,
         avatar_url = null,
         status = ''suspended'',
         closed_at = now(),
         updated_at = now()
   where id = p_user;
  update public.student_profiles
     set student_id = null, school_id_url = null, assessment_of_fees_url = null,
         emergency_contact_json = null, extracted_name = null, extracted_school_id = null,
         qr_code_token = null, osas_verified_at = null
   where user_id = p_user;
  update public.landlord_profiles
     set government_id_url = null, extracted_name = null, extracted_gov_id = null
   where user_id = p_user;
  delete from public.verification_documents where user_id = p_user;
  delete from public.notifications where user_id = p_user;
  delete from public.user_pins where user_id = p_user;

  insert into public.account_standing (user_id, reason, restrictions, updated_by, updated_at)
  values (p_user, v_reason, ''{}'', auth.uid(), now())
  on conflict (user_id) do update
    set reason = excluded.reason, suspended_until = null, restrictions = ''{}'',
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  update public.audit_logs
     set before_json = before_json - array[
           ''email'', ''phone'', ''full_name'', ''initials'', ''date_of_birth'', ''avatar_url'', ''sex'',
           ''student_id'', ''school_id_url'', ''assessment_of_fees_url'', ''emergency_contact_json'',
           ''extracted_name'', ''extracted_school_id'', ''qr_code_token'',
           ''government_id_url'', ''extracted_gov_id'', ''file_url'', ''filename''],
         after_json = after_json - array[
           ''email'', ''phone'', ''full_name'', ''initials'', ''date_of_birth'', ''avatar_url'', ''sex'',
           ''student_id'', ''school_id_url'', ''assessment_of_fees_url'', ''emergency_contact_json'',
           ''extracted_name'', ''extracted_school_id'', ''qr_code_token'',
           ''government_id_url'', ''extracted_gov_id'', ''file_url'', ''filename'']
   where entity_type in (''users'', ''student_profiles'', ''landlord_profiles'', ''verification_documents'')
     and (entity_id = p_user::text
          or before_json ->> ''user_id'' = p_user::text
          or after_json ->> ''user_id'' = p_user::text);

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), ''account.closed'', ''users'', p_user::text, jsonb_build_object(''reason'', v_reason), now());
end $fn$;

revoke all on function public.admin_change_role(uuid, public.user_role, text) from public, anon;
revoke all on function public.admin_close_account(uuid, text) from public, anon;
grant execute on function public.admin_change_role(uuid, public.user_role, text) to authenticated;
grant execute on function public.admin_close_account(uuid, text) to authenticated;"}', 'admin_role_change_and_closure', 'titusplaza1202@gmail.com', NULL, NULL),
	('20260924024301', '{"create or replace function public.is_verified_landlord(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = uid and u.role = ''landlord'' and u.status = ''verified''
  );
$$;

revoke all on function public.is_verified_landlord(uuid) from public;
grant execute on function public.is_verified_landlord(uuid) to authenticated;

drop policy if exists accommodations_insert_verified on public.accommodations;
create policy accommodations_insert_verified on public.accommodations
  as restrictive
  for insert
  to authenticated
  with check (public.is_verified_landlord(auth.uid()) or public.is_admin(auth.uid()));

drop policy if exists rooms_insert_verified on public.rooms;
create policy rooms_insert_verified on public.rooms
  as restrictive
  for insert
  to authenticated
  with check (public.is_verified_landlord(auth.uid()) or public.is_admin(auth.uid()));

drop policy if exists accommodation_facilities_insert_verified on public.accommodation_facilities;
create policy accommodation_facilities_insert_verified on public.accommodation_facilities
  as restrictive
  for insert
  to authenticated
  with check (public.is_verified_landlord(auth.uid()) or public.is_admin(auth.uid()));"}', 'unverified_landlord_no_inventory', 'titusplaza1202@gmail.com', NULL, NULL);


--
-- PostgreSQL database dump complete
--

-- \unrestrict VlGLV72KO2ONmNHSEtT07eXgBK3EPWPgvwkvtPDMmXzVqOFabdxhjnJlJniVYDN

RESET ALL;
