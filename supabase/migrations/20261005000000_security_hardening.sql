-- Security hardening from the 2026-10-05 review. Most of these are "update own
-- row" or insert policies that checked whose row it was and nothing about the
-- other columns.
--
--  1. A landlord/landlady could read a tenant's (or a walk-in's) QR token off
--     student_profiles and accept_added_student() without ever scanning it.
--  2. Identity a person was verified on (student number, ID files, extracted
--     names) stayed editable after OSAS verified it.
--  3. Columns that are the database's to write, not the client's: a listing's
--     rating, who a review is about, where a message lives, a conversation's
--     participants and preview, a permit's version and upload time.
--  4. Anyone could open a conversation with anyone, and a conversation is what
--     unlocks the other person's whole users row (can_notify) and lets you push
--     notifications at them. A student could also issue themselves the
--     application form (invited_room_id) and name their own rent.
--  5. A lease could be moved into another landlord/landlady's room, and a
--     closed lease reopened (e.g. ended -> write a tenant review -> active).
--  6. Permit expiry was whatever the landlord/landlady typed on an upload, even
--     one OSAS sent back, so sweep_expired_permits never fired.
--  7. A file column took any plain URL, which doc-access then handed to OSAS
--     as the "document". Only signed cld: refs are accepted from clients now.
--  8. Paid payments could be deleted; either side could delete a conversation.
--  9. Tickets could name any lease, landlord/landlady or concern.
--
-- Guards that only stop the signed-in client use `current_user = 'authenticated'`:
-- the security-definer RPCs and triggers that legitimately write these columns
-- (invite_application, mark_conversation_read, refresh_accommodation_rating,
-- current_qr_token, ...) run as their owner and pass straight through, so none
-- of them needed a bypass flag. OSAS is exempt throughout.

-- 1 ---------------------------------------------------------------------------
-- The QR token is a live credential; only current_qr_token()/rotate_qr_token()
-- (security definer) read or write it. Column grants rather than a policy,
-- because RLS can hide rows but not columns. A column added to student_profiles
-- later has to be granted here too, or clients cannot see it.
revoke select, insert, update on public.student_profiles from authenticated;
grant select (user_id, student_id, program, year_level, college, school_id_url, assessment_of_fees_url,
              osas_verified_at, emergency_contact_json, extracted_name, extracted_school_id),
      insert (user_id, student_id, program, year_level, college, school_id_url, assessment_of_fees_url,
              osas_verified_at, emergency_contact_json, extracted_name, extracted_school_id),
      update (user_id, student_id, program, year_level, college, school_id_url, assessment_of_fees_url,
              osas_verified_at, emergency_contact_json, extracted_name, extracted_school_id)
   on public.student_profiles to authenticated;

-- 2 ---------------------------------------------------------------------------
-- Free while the account is being set up or OSAS has asked for resubmission;
-- fixed once OSAS has verified it. College, program and year level stay
-- editable: they change every year and OSAS did not verify them.
create or replace function public.lock_verified_identity() returns trigger
language plpgsql set search_path = public as $$
declare
  c text;
begin
  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;
  if not exists (select 1 from public.users u
                  where u.id = old.user_id and u.status in ('verified', 'suspended')) then
    return new;
  end if;
  foreach c in array tg_argv loop
    if (to_jsonb(new) -> c) is distinct from (to_jsonb(old) -> c) then
      raise exception 'OSAS verified your %. Ask OSAS to change it.', replace(c, '_', ' ')
        using errcode = '42501';
    end if;
  end loop;
  return new;
end $$;

drop trigger if exists lock_verified_identity on public.student_profiles;
create trigger lock_verified_identity before update on public.student_profiles
  for each row execute function public.lock_verified_identity(
    'student_id', 'school_id_url', 'assessment_of_fees_url', 'extracted_name', 'extracted_school_id');

drop trigger if exists lock_verified_identity on public.landlord_profiles;
create trigger lock_verified_identity before update on public.landlord_profiles
  for each row execute function public.lock_verified_identity(
    'government_id_url', 'extracted_name', 'extracted_gov_id');

-- 3 ---------------------------------------------------------------------------
-- The named columns are never the signed-in client's to change.
create or replace function public.lock_columns() returns trigger
language plpgsql set search_path = public as $$
declare
  c text;
begin
  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;
  foreach c in array tg_argv loop
    if (to_jsonb(new) -> c) is distinct from (to_jsonb(old) -> c) then
      raise exception '% is set by Accommo, not by the app.', c using errcode = '42501';
    end if;
  end loop;
  return new;
end $$;

do $$
declare r record;
begin
  for r in select * from (values
    ('accommodations',          array['rating_avg', 'reviews_count']),
    ('accommodation_reviews',   array['lease_id', 'student_id', 'accommodation_id']),
    ('landlord_reviews',        array['lease_id', 'student_id', 'landlord_id']),
    ('tenant_reviews',          array['lease_id', 'student_id', 'landlord_id']),
    ('messages',                array['conversation_id', 'sender_id', 'sent_at']),
    ('accommodation_documents', array['version', 'uploaded_at']),
    ('conversations',           array['user_a_id', 'user_b_id', 'last_message', 'last_sender_id',
                                      'last_time', 'unread_a', 'unread_b'])
  ) as t(tbl, cols)
  loop
    execute format('drop trigger if exists lock_columns on public.%I', r.tbl);
    execute format('create trigger lock_columns before update on public.%I for each row execute function public.lock_columns(%s)',
                   r.tbl, (select string_agg(quote_literal(c), ', ') from unnest(r.cols) c));
  end loop;
end $$;

-- A new permit version is numbered and timed by the database, so the upload
-- time OSAS's decisions are compared against (section 6, resubmit_accommodation)
-- cannot be backdated.
create or replace function public.stamp_document_version() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;
  new.uploaded_at := now();
  new.version := coalesce((select max(d.version) from public.accommodation_documents d
                            where d.accommodation_id = new.accommodation_id and d.doc_type = new.doc_type), 0) + 1;
  return new;
end $$;

drop trigger if exists stamp_document_version on public.accommodation_documents;
create trigger stamp_document_version before insert on public.accommodation_documents
  for each row execute function public.stamp_document_version();

-- 4 ---------------------------------------------------------------------------
-- Who may start a conversation with whom: a student asking a listed
-- landlord/landlady, either side of a lease, or a landlord/landlady who has
-- just scanned that student's QR in person. Everything else (student to
-- student, anyone to OSAS, cold contact by id) is refused.
create or replace function public.may_message(p_other uuid) returns boolean
language sql stable set search_path = public as $$
  select exists (select 1 from public.leases l
                  where (l.student_id = auth.uid() and l.landlord_id = p_other)
                     or (l.landlord_id = auth.uid() and l.student_id = p_other))
      or (public.get_my_role() = 'student'
          and exists (select 1 from public.accommodations a
                       where a.landlord_id = p_other and a.status = 'accredited'))
      or exists (select 1 from public.qr_scans s
                  where s.scanner_id = auth.uid() and s.student_id = p_other
                    and s.method = 'qr' and s.result in ('verified', 'unverified'));
$$;
revoke all on function public.may_message(uuid) from public, anon;
grant execute on function public.may_message(uuid) to authenticated;

drop policy if exists "conversations_insert_participant" on public.conversations;
create policy "conversations_insert_participant" on public.conversations
  for insert to authenticated
  with check (
    (select auth.uid()) in (user_a_id, user_b_id)
    and user_a_id <> user_b_id
    and invited_room_id is null and invited_at is null
    and ((select public.is_admin((select auth.uid())))
         or public.may_message(case when user_a_id = (select auth.uid()) then user_b_id else user_a_id end))
  );

-- The form is issued by invite_application() only, which checks the room is
-- the landlord/landlady's and available. Either side may still clear a used one.
create or replace function public.guard_conversation_invite() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;
  if (new.invited_room_id is distinct from old.invited_room_id and new.invited_room_id is not null)
     or (new.invited_at is distinct from old.invited_at and new.invited_at is not null) then
    raise exception 'Only the landlord/landlady can send an application form.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists guard_conversation_invite on public.conversations;
create trigger guard_conversation_invite before update on public.conversations
  for each row execute function public.guard_conversation_invite();

-- 5 ---------------------------------------------------------------------------
-- A student's application takes its terms from the room, the way
-- ApplicationCard.vue works them out: per-person rent as is, a whole-room rent
-- split across capacity. Direct inserts are students only (leases_insert_manager
-- is gone; add_student_to_room runs as its owner).
create or replace function public.guard_lease_writes() returns trigger
language plpgsql set search_path = public as $$
declare
  r public.rooms;
begin
  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;

  if tg_op = 'INSERT' then
    select * into r from public.rooms where id = new.room_id;
    if r.id is null then
      raise exception 'That room is not open for applications.' using errcode = '42501';
    end if;
    new.monthly_rent := case when r.rent_basis = 'person' then r.monthly_rent
                             else r.monthly_rent / greatest(coalesce(r.capacity, 1), 1) end;
    new.added_by_landlord := false;
    new.advance_paid := null;
    new.deposit_paid := null;
    return new;
  end if;

  if (new.room_id, new.landlord_id) is distinct from (old.room_id, old.landlord_id) then
    raise exception 'A lease cannot be moved to another room or landlord/landlady.' using errcode = '42501';
  end if;
  if old.status in ('ended', 'terminated', 'rejected') and new.status is distinct from old.status then
    raise exception 'This lease is closed. Start a new one instead.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists guard_lease_writes on public.leases;
create trigger guard_lease_writes before insert or update on public.leases
  for each row execute function public.guard_lease_writes();

-- 6 ---------------------------------------------------------------------------
-- A permit counts toward expiry only once OSAS has approved something after it
-- was uploaded (any decision that looks at permits; a details change does not).
-- An upload OSAS has not passed, or sent back, leaves the previous version in
-- force, so a far-future expiry typed on a fresh upload no longer keeps the
-- listing up. Listings from before accreditation rounds have no approval to
-- compare with and keep the old rule (latest version).
create or replace function public.sweep_expired_permits() returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  n int;
begin
  with approved as (
    select r.accommodation_id, max(r.decided_at) as at
      from public.accreditation_rounds r
     where r.decision = 'approved' and r.kind <> 'change'
     group by r.accommodation_id
  ),
  latest as (
    select distinct on (d.accommodation_id, d.doc_type)
           d.accommodation_id, d.doc_type, d.expires_at
      from public.accommodation_documents d
      left join approved ap on ap.accommodation_id = d.accommodation_id
     where ap.at is null or d.uploaded_at <= ap.at
     order by d.accommodation_id, d.doc_type, d.version desc
  ),
  lapsed as (
    select distinct accommodation_id from latest
     where expires_at is not null and expires_at < now()
  )
  update public.accommodations a
     set status = 'expired'
   where a.status = 'accredited'
     and a.id in (select accommodation_id from lapsed);
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      'Accreditation expired',
      n || ' accommodation(s) have a permit that has expired and are no longer listed.',
      'verification', '/verifications');
  end if;
end $$;

-- An upload while another round is open used to open nothing and tell no one.
-- There can be only one open round, so OSAS is told and looks at the permit
-- alongside what it is already reviewing.
-- ponytail: a permit uploaded during a 'change' round is not passed by that
-- round's approval (section above); the landlord/landlady re-uploads it once
-- the change is decided. A queue of rounds per listing is the upgrade.
create or replace function public.tg_permit_needs_review() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
begin
  select * into a from public.accommodations where id = new.accommodation_id;
  if a.status::text in ('accredited', 'delisted') then
    if not exists (select 1 from public.accreditation_rounds
                    where accommodation_id = a.id and decided_at is null) then
      perform public.open_accreditation_round(a.id, 'permit_update');
    end if;
    perform public.notify_admins(
      'Permit updated',
      coalesce(a.name, 'An accommodation') || ' uploaded a new ' || public.permit_label(new.doc_type) || '.',
      'accommodation',
      '/verifications?focus=verification:' || a.id::text
    );
  end if;
  return new;
end $$;

-- 7 ---------------------------------------------------------------------------
-- Every private upload in both apps goes through doc-access and stores a cld:
-- ref. A plain URL from a client was only ever a way to point OSAS at a page of
-- someone's choosing. Rows written before the move keep their URLs: an update
-- that leaves the column alone is not checked.
create or replace function public.lock_document_ref() returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare
  public_id text;
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if new.file_url is null then return new; end if;
  if tg_op = 'UPDATE' and new.file_url is not distinct from old.file_url then return new; end if;
  if new.file_url not like 'cld:%' then
    raise exception 'Upload the file through the app.' using errcode = '42501';
  end if;

  -- cld:<resource_type>:<type>:<format>:<public_id>, and a public_id may itself
  -- contain ':' -- so take everything from the fifth field on, not just it.
  public_id := substr(new.file_url, length(split_part(new.file_url, ':', 1) || ':' ||
                                           split_part(new.file_url, ':', 2) || ':' ||
                                           split_part(new.file_url, ':', 3) || ':' ||
                                           split_part(new.file_url, ':', 4) || ':') + 1);

  if public_id !~ ('^accommo/docs/' || auth.uid()::text || '/') then
    raise exception 'A document may only reference a file you uploaded.';
  end if;

  return new;
end $$;

create or replace function public.lock_private_ref() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  col text := tg_argv[0];
  v jsonb := to_jsonb(new) -> col;
  refs text[];
  r text;
begin
  if auth.uid() is null or public.is_admin(auth.uid()) then return new; end if;
  if tg_op = 'UPDATE' and v is not distinct from (to_jsonb(old) -> col) then return new; end if;

  refs := case jsonb_typeof(v)
            when 'array'  then array(select jsonb_array_elements_text(v))
            when 'string' then array[v #>> '{}']
            else '{}'::text[] end;

  foreach r in array refs loop
    -- '' is how the apps say "no file".
    continue when r = '';
    if r not like 'cld:%' then
      raise exception 'Upload the file through the app.' using errcode = '42501';
    end if;
    -- cld:<resource_type>:<type>:<format>:<public_id>
    if substr(r, length(split_part(r, ':', 1) || ':' || split_part(r, ':', 2) || ':' ||
                        split_part(r, ':', 3) || ':' || split_part(r, ':', 4) || ':') + 1)
       !~ ('^accommo/docs/' || auth.uid()::text || '/') then
      raise exception 'A file may only reference something you uploaded.';
    end if;
  end loop;
  return new;
end $$;

-- 8 ---------------------------------------------------------------------------
-- A wrong entry can still be removed; a settled payment is a record.
drop policy if exists "payments_delete_manager" on public.payments;
create policy "payments_delete_manager" on public.payments
  for delete to authenticated
  using (status <> 'paid'
         and exists (select 1 from public.leases l
                      where l.id = payments.lease_id and l.landlord_id = (select auth.uid())));

-- Neither app deletes a conversation, and it is the other person's record too.
drop policy if exists "conversations_delete_participant" on public.conversations;

-- 9 ---------------------------------------------------------------------------
-- Same shape as before (20260928120000), plus: everything a ticket points at
-- has to be the reporter's own.
drop policy if exists "tickets_reporter_insert" on public.tickets;
create policy "tickets_reporter_insert" on public.tickets
  for insert to authenticated
  with check (
    (select public.is_admin((select auth.uid())))
    or (
      status = 'open' and priority = 'medium' and assignee_id is null
      and (
        (landlord_id = (select auth.uid())
          and (student_id is null or exists (select 1 from public.leases l
                where l.landlord_id = (select auth.uid()) and l.student_id = tickets.student_id))
          and (lease_id is null or exists (select 1 from public.leases l
                where l.id = tickets.lease_id and l.landlord_id = (select auth.uid())))
          and (accommodation_id is null or exists (select 1 from public.accommodations a
                where a.id = tickets.accommodation_id and a.landlord_id = (select auth.uid())))
          and (concern_id is null or exists (select 1 from public.concerns c join public.leases l on l.id = c.lease_id
                where c.id = tickets.concern_id and l.landlord_id = (select auth.uid()))))
        or
        (student_id = (select auth.uid())
          and (landlord_id is null or exists (select 1 from public.leases l
                where l.student_id = (select auth.uid()) and l.landlord_id = tickets.landlord_id))
          and (lease_id is null or exists (select 1 from public.leases l
                where l.id = tickets.lease_id and l.student_id = (select auth.uid())))
          and concern_id is null)
      )
    )
  );
