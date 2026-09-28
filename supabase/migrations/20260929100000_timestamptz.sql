-- Store every timestamp with its time zone.
--
-- These columns were `timestamp without time zone` holding UTC (the database
-- runs in UTC). PostgREST returned them with no offset, and both apps' browsers
-- read an offset-less time as local — so in Manila every "last active",
-- "submitted … ago", review SLA and near-midnight date was 8 hours off.
-- As timestamptz they come back as "…+00:00" and every client reads them right.
--
-- `at time zone 'UTC'` keeps each stored instant exactly as it was. The three
-- views, two announcement policies and one trigger that reference these columns
-- block the type change, so they are dropped and recreated verbatim.

-- Dependents ------------------------------------------------------------------
drop view if exists public.latest_accommodation_documents;
drop view if exists public.review_admin_feed;
drop view if exists public.review_inbox;
drop policy if exists "announcements_select_audience" on public.announcements;
drop policy if exists "announcements_select_public" on public.announcements;
drop trigger if exists trg_notify_announcement on public.announcements;

-- Columns ---------------------------------------------------------------------
alter table public.accommodation_documents  alter column uploaded_at        type timestamptz using uploaded_at at time zone 'UTC';
alter table public.accommodation_reviews    alter column created_at         type timestamptz using created_at at time zone 'UTC';
alter table public.announcements
  alter column published_at type timestamptz using published_at at time zone 'UTC',
  alter column expires_at   type timestamptz using expires_at at time zone 'UTC';
alter table public.audit_logs               alter column created_at         type timestamptz using created_at at time zone 'UTC';
alter table public.conversations            alter column last_time          type timestamptz using last_time at time zone 'UTC';
alter table public.landlord_reviews         alter column created_at         type timestamptz using created_at at time zone 'UTC';
alter table public.leases                   alter column leave_requested_at type timestamptz using leave_requested_at at time zone 'UTC';
alter table public.messages                 alter column sent_at            type timestamptz using sent_at at time zone 'UTC';
alter table public.notifications            alter column read_at            type timestamptz using read_at at time zone 'UTC';
alter table public.payments                 alter column paid_at            type timestamptz using paid_at at time zone 'UTC';
alter table public.student_profiles         alter column osas_verified_at   type timestamptz using osas_verified_at at time zone 'UTC';
alter table public.tenant_reviews           alter column created_at         type timestamptz using created_at at time zone 'UTC';
alter table public.users
  alter column created_at        type timestamptz using created_at at time zone 'UTC',
  alter column updated_at        type timestamptz using updated_at at time zone 'UTC',
  alter column last_login_at     type timestamptz using last_login_at at time zone 'UTC',
  alter column email_verified_at type timestamptz using email_verified_at at time zone 'UTC',
  alter column created_at        set default now(),
  alter column updated_at        set default now();
alter table public.verification_documents
  alter column uploaded_at type timestamptz using uploaded_at at time zone 'UTC',
  alter column verified_at type timestamptz using verified_at at time zone 'UTC';

-- Dependents, recreated as they were -----------------------------------------
create trigger trg_notify_announcement after insert or update of published_at, archived
  on public.announcements for each row execute function public.notify_announcement();

create policy "announcements_select_audience" on public.announcements
  for select to authenticated
  using (
    (published_at is not null) and (published_at <= now()) and (not archived)
    and ((expires_at is null) or (expires_at > now()))
    and case
      when (accommodation_id is null) then (
        (audience = 'all'::audience_type)
        or ((audience = 'students'::audience_type) and (get_my_role() = 'student'::text))
        or ((audience = 'landlords'::audience_type) and (get_my_role() = 'landlord'::text)))
      else (accommodation_id in (select my_accommodation_ids.id from my_accommodation_ids() my_accommodation_ids(id)))
    end
  );

create policy "announcements_select_public" on public.announcements
  for select to anon
  using (
    (audience = 'all'::audience_type) and (accommodation_id is null)
    and (published_at is not null) and (published_at <= now()) and (not archived)
    and ((expires_at is null) or (expires_at > now()))
  );

create view public.latest_accommodation_documents with (security_invoker = true) as
  select distinct on (accommodation_id, doc_type) accommodation_id,
    doc_type, version, file_url, issued_at, expires_at, uploaded_at
  from public.accommodation_documents pd
  order by accommodation_id, doc_type, version desc, uploaded_at desc;

create view public.review_admin_feed with (security_invoker = true) as
  select tr.id, 'tenant'::text as kind, tr.student_id as subject_id, tr.landlord_id as author_id,
         tr.rating, tr.comment, tr.created_at, tr.lease_id, null::uuid as accommodation_id
    from public.tenant_reviews tr
  union all
  select amr.id, 'manager'::text, amr.landlord_id, amr.student_id,
         amr.rating, amr.comment, amr.created_at, amr.lease_id, null::uuid
    from public.landlord_reviews amr
  union all
  select ar.id, 'accommodation'::text, ar.accommodation_id, ar.student_id,
         ar.rating, ar.comment, ar.created_at, ar.lease_id, ar.accommodation_id
    from public.accommodation_reviews ar;

create view public.review_inbox with (security_invoker = true) as
  select r.id, 'manager'::text as kind, r.rating, r.comment, r.created_at,
         null::uuid as accommodation_id, null::text as accommodation_name
    from public.landlord_reviews r
   where r.landlord_id = auth.uid()
  union all
  select r.id, 'accommodation'::text, r.rating, r.comment, r.created_at, a.id, a.name
    from public.accommodation_reviews r
    join public.accommodations a on a.id = r.accommodation_id
   where a.landlord_id = auth.uid()
  union all
  select r.id, 'tenant'::text, r.rating, r.comment, r.created_at, null::uuid, null::text
    from public.tenant_reviews r
   where r.student_id = auth.uid();

-- Same grants the views had.
revoke all on public.latest_accommodation_documents, public.review_admin_feed, public.review_inbox from anon, authenticated;
grant select on public.latest_accommodation_documents to anon;
grant select, insert, update, delete on public.latest_accommodation_documents to authenticated;
grant select, insert, update, delete, references, trigger on public.review_admin_feed, public.review_inbox to authenticated;
grant all on public.latest_accommodation_documents, public.review_admin_feed, public.review_inbox to service_role;
