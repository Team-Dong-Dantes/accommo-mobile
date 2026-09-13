-- Verification-workflow hardening (students, accommodation managers, accommodations).
--
-- Closes the applicant-side bypasses of the OSAS gates, gives the review flow
-- the write access it never had, and makes a decision actually revoke something.
-- Audit findings #1 #2 #3 #5 #8 #9 #10 #11 #12 #13 #14 #16 #18 #22.

-- ── #12  One definition of "admin" ──────────────────────────────────────────
-- Two competed: is_admin() read admin_profiles (accommodations, documents),
-- get_my_role() read users.role (user status, lock_user_privileges). An account
-- with one and not the other got a split set of powers. users.role wins — it is
-- what the privilege trigger and notify_admins already trust.
--
create or replace function public.is_admin(p_uid uuid) returns boolean
language sql stable security definer set search_path = public set row_security = off as $$
  select exists (
    select 1 from public.users
    where id = p_uid and (role = 'admin' or is_superadmin = true)
  );
$$;

-- lock_user_privileges had no service-role escape: auth.uid() is null for
-- service_role, the SQL console and migrations, so get_my_role() came back null
-- and the trigger read every such write as a user escalating themselves. It
-- blocked this migration's own demote below. Same null-JWT exemption as the new
-- guard, and it now shares the one is_admin() definition.
create or replace function public.lock_user_privileges() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  allow_resubmit boolean := coalesce(current_setting('app.resubmitting', true), 'false') = 'true';
begin
  if auth.uid() is null then return new; end if;

  if tg_op = 'INSERT' then
    if new.role = 'admin' and not public.is_admin(auth.uid()) then
      raise exception 'Insufficient privileges to assign the admin role.';
    end if;
    return new;
  end if;

  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role then
      raise exception 'You are not allowed to change your own role.';
    end if;
    if new.status is distinct from old.status then
      -- Only the resubmit RPC, and only rejected/unverified -> pending.
      if allow_resubmit and new.status = 'pending' and old.status in ('rejected','unverified') then
        return new;
      end if;
      raise exception 'You are not allowed to change your own account status.';
    end if;
  end if;
  return new;
end $$;

update public.users set role = 'student'
where id = 'bbbb0001-0000-4000-8000-000000000001' and role = 'admin';

-- Repoint every policy that inlined admin_profiles, so all of them now agree.
drop policy if exists admin_select_all_users on public.users;
create policy admin_select_all_users on public.users
  for select to authenticated using (public.is_admin(auth.uid()));

drop policy if exists "Admins can update user statuses" on public.users;
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

-- The legacy owner/admin policy did its own users.role lookup; is_admin() now
-- covers the admin half and the owner-scoped policies cover the rest.
drop policy if exists "Verification documents visible to owner/admin" on public.verification_documents;

-- ── #16  The policy the approval flow was always missing ────────────────────
-- accommo-web runs on the anon key with the admin's own session, so RLS applies
-- to its writes. student_profiles had no admin UPDATE policy at all, so the
-- osas_verified_at stamp in useVerifications matched zero rows for every
-- student and never errored. The 94 live stamps all came from a data backfill.
drop policy if exists admin_select_all_student_profiles on public.student_profiles;
create policy admin_all_student_profiles on public.student_profiles
  for all to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- ── #1 #2 #13  Column guards on the three gate columns ─────────────────────
-- Same shape as the existing lock_user_privileges trigger on users. INSERT is
-- covered too: the owner-scoped insert policies never constrained these values.
create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- No JWT means service_role, the SQL console or a migration.
  -- ponytail: leans on anon holding no INSERT/UPDATE policy on these tables;
  -- revisit if any policy here is ever widened to anon or public.
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = 'student_profiles' then
    if tg_op = 'INSERT' then
      if new.osas_verified_at is not null then
        raise exception 'Only OSAS may set verification status.';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception 'Only OSAS may change verification status.';
    end if;
  end if;

  if tg_table_name = 'accommodations' then
    if tg_op = 'INSERT' then
      if new.status <> 'pending' then
        raise exception 'A new accommodation must start as pending.';
      end if;
    elsif new.status is distinct from old.status then
      -- tg_permit_needs_review below sends an accredited listing back to review
      -- on the manager's behalf; that one transition is allowed through.
      if not (coalesce(current_setting('app.permit_review', true), 'false') = 'true'
              and old.status = 'accredited' and new.status = 'reviewing') then
        raise exception 'Only OSAS may change accreditation status.';
      end if;
    end if;
  end if;

  -- 'approved' is the only doc status that grants anything, so guard just that
  -- and leave the owner's own resubmission (back to 'pending') working.
  if tg_table_name = 'verification_documents' and new.status = 'approved' then
    raise exception 'Only OSAS may approve a document.';
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

-- #13 cont. — a user may withdraw a submission still awaiting review, not erase
-- one that has already been decided.
drop policy if exists verification_documents_delete_own on public.verification_documents;
create policy verification_documents_delete_own on public.verification_documents
  for delete to authenticated
  using (user_id = (select auth.uid()) and status = 'pending');

-- ── #5  A decision has to revoke something ──────────────────────────────────
-- osas_verified_at, not users.status, is what gates lease applications, the QR
-- and chat-apply. Rejecting or suspending an already-verified account left all
-- three intact. In the database so it also covers the Users page, the SQL
-- console and any future caller.
create or replace function public.tg_revoke_on_unverify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('rejected','suspended') and old.status = 'verified' then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = 'delisted'
      where accommodation_manager_id = new.id and status = 'accredited';
  end if;
  return new;
end $$;

drop trigger if exists trg_revoke_on_unverify on public.users;
create trigger trg_revoke_on_unverify after update of status on public.users
  for each row execute function public.tg_revoke_on_unverify();

-- ── #11  Applications only to accredited accommodations ─────────────────────
-- The old policy checked the room/manager chain and osas_verified_at but never
-- the accommodation's own status, so a known room_id in a pending, rejected or
-- delisted listing was leasable.
drop policy if exists leases_insert_student_application on public.leases;
create policy leases_insert_student_application on public.leases
  for insert to authenticated with check (
    student_id = (select auth.uid())
    and status = 'pending'
    and exists (
      select 1 from public.rooms r
      join public.accommodations a on a.id = r.accommodation_id
      where r.id = leases.room_id
        and a.accommodation_manager_id = leases.accommodation_manager_id
        and a.status = 'accredited')
    and exists (
      select 1 from public.student_profiles sp
      where sp.user_id = leases.student_id and sp.osas_verified_at is not null)
  );

-- ── #3 #8  The queue is admin-only, and decided users leave it ──────────────
-- It was SECURITY DEFINER granted to every authenticated user with no admin
-- check, so any student could dump each applicant's name, email and document
-- URLs. The `or d.id is not null` arm also re-admitted users whose account was
-- already decided (16 of them live), because nothing ever wrote a document row
-- past 'pending'. Dropping that arm is safe now that the app calls
-- resubmit_verification(), which puts a resubmitting account back to 'pending'.
create or replace function public.get_verification_queue()
returns table (user_id uuid, full_name text, email text, role text, user_status text,
               created_at timestamptz, doc_type text, file_url text, filename text, doc_status text)
language sql security definer set search_path = public as $$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.created_at, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = 'pending'
  where public.is_admin(auth.uid())
    and u.status::text in ('pending','reviewing')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$$;

revoke all on function public.get_verification_queue() from public;
grant execute on function public.get_verification_queue() to authenticated;

-- ── #18  Transaction-local resubmit flag ────────────────────────────────────
-- set_config(..., false) is session-scoped: if the UPDATE raised, the flag
-- stayed set on that pooled PostgREST connection and later requests on the same
-- backend inherited the status-change exemption.
create or replace function public.resubmit_verification() returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select id, status into r from public.users where id = auth.uid();
  if r.id is null then raise exception 'Not signed in'; end if;
  if r.status in ('pending','reviewing','verified') then return; end if;
  if r.status = 'suspended' then raise exception 'Suspended accounts cannot resubmit.'; end if;
  perform set_config('app.resubmitting', 'true', true);
  update public.users set status = 'pending', updated_at = now() where id = r.id;
end $$;

-- ── #9  Notify OSAS on resubmissions, not only first upload ─────────────────
-- The trigger was AFTER INSERT only, and a resubmission is an UPDATE of the
-- same row, so swapping the file behind a decided verification told nobody.
create or replace function public.trg_new_verification() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if new.status = 'pending' and new.user_id is not null
     and (tg_op = 'INSERT' or new.file_url is distinct from old.file_url) then
    select coalesce(full_name, email) into v_name from public.users where id = new.user_id;
    perform public.notify_admins(
      'New verification request',
      coalesce(v_name, 'A user') || ' submitted '
        || coalesce(new.doc_type, 'documents') || ' for review.',
      'verification',
      '/verifications?focus=verification:' || new.user_id::text);
  end if;
  return new;
end $$;

drop trigger if exists trg_new_verification on public.verification_documents;
create trigger trg_new_verification after insert or update on public.verification_documents
  for each row execute function public.trg_new_verification();

-- ── #10  A new permit version reopens the accreditation ─────────────────────
-- expires_at was read only by three mobile manager screens: no admin surface,
-- nothing lapsed, and a renewal was never reviewed.
create or replace function public.tg_permit_needs_review() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.permit_review', 'true', true);
  update public.accommodations set status = 'reviewing'
  where id = new.accommodation_id and status = 'accredited';
  perform set_config('app.permit_review', 'false', true);
  return new;
end $$;

drop trigger if exists trg_permit_needs_review on public.accommodation_documents;
create trigger trg_permit_needs_review after insert on public.accommodation_documents
  for each row execute function public.tg_permit_needs_review();

-- ── #14  A decision trail the applicant can actually read back ──────────────
-- useVerifications has always inserted into verification_requests, but the
-- table does not exist, so every one of those writes fell into its catch block
-- and the only surviving record of a reason was the notification body — which
-- the mobile app read back by string-matching the notification *title*.
create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('user','accommodation')),
  entity_id uuid not null,
  type text,
  status text not null check (status in ('approved','rejected','resubmission_requested')),
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

-- The subject reads their own decisions: directly for a user, through ownership
-- for an accommodation.
drop policy if exists verification_requests_select_subject on public.verification_requests;
create policy verification_requests_select_subject on public.verification_requests
  for select to authenticated using (
    (entity_type = 'user' and entity_id = auth.uid())
    or (entity_type = 'accommodation' and exists (
      select 1 from public.accommodations a
      where a.id = verification_requests.entity_id
        and a.accommodation_manager_id = auth.uid()))
  );

-- ── #22  Least privilege on the over-granted tables ─────────────────────────
-- Seven tables handed anon the full DML set including TRUNCATE, which is not
-- subject to RLS. Not reachable through PostgREST (no verb for it) and RLS
-- currently blocks the DML, so this is defence in depth: one policy widened to
-- anon or public would otherwise open permit and ticket tampering.
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

-- ── Backfill the state the old bugs left behind ─────────────────────────────
-- Documents belonging to an account that was already decided: close them so
-- they stop trailing the queue.
update public.verification_documents d
set status = (case when u.status = 'verified' then 'approved' else 'rejected' end)::doc_status,
    verified_at = coalesce(d.verified_at, now())
from public.users u
where u.id = d.user_id and d.status = 'pending'
  and u.status not in ('pending','reviewing');

-- Verified students the broken stamp write skipped.
insert into public.student_profiles (user_id, osas_verified_at)
select u.id, now() from public.users u
where u.role = 'student' and u.status = 'verified'
on conflict (user_id) do update
set osas_verified_at = coalesce(student_profiles.osas_verified_at, excluded.osas_verified_at);

-- Accredited listings that never met the bar: an unverified manager, or no
-- permits at all. Back to the queue rather than silently trusted.
update public.accommodations a set status = 'reviewing'
where a.status = 'accredited'
  and (exists (select 1 from public.users u
               where u.id = a.accommodation_manager_id and u.status <> 'verified')
   or not exists (select 1 from public.accommodation_documents d
                  where d.accommodation_id = a.id));

-- ── #22 cont.  Stop the next table inheriting the same over-grant ───────────
-- verification_requests above was created with the stock Supabase default ACL,
-- which hands anon the full DML set including TRUNCATE — the one privilege in
-- that set RLS does not backstop. Narrow only TRUNCATE; SELECT/INSERT/UPDATE/
-- DELETE stay as Supabase expects them, gated by RLS.
revoke truncate, references, trigger on public.verification_requests from anon, authenticated;
revoke insert, update, delete on public.verification_requests from anon;
alter default privileges in schema public revoke truncate on tables from anon, authenticated;
