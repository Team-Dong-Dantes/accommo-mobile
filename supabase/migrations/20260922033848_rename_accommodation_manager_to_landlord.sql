-- Rename the `accommodation_manager` role to `landlord` across the schema.
--
-- The apps now call this role "Landlord/Landlady". Identifiers cannot carry the
-- slash — a table named "landlord/landlady_profiles" would need double quotes in
-- every query forever, and the Supabase client would have to carry the quoted
-- name into every .from() call — so the schema uses the single ungendered token
-- `landlord` and the UI renders "Landlord/Landlady" over it. No user ever sees
-- an enum value.
--
-- A person's title (Landlord vs Landlady) is derived in the client from
-- users.sex, falling back to "Landlord/Landlady". Nothing about that is stored.
--
-- BREAKING. Any already-installed APK sends `role=eq.accommodation_manager` and
-- will get `400 invalid input value for enum user_role` on its next role query.
-- The web deploy and a new mobile build must ship together with this migration.
--
-- Note on what does NOT need touching: the 68 RLS policies store parsed
-- expression trees keyed by OID, and ALTER TYPE ... RENAME VALUE keeps the
-- label's OID, so policies follow all of these renames automatically. The 16
-- functions are the exception — every one has a string body (prosqlbody is
-- null), which is re-parsed at runtime, so each is replaced below.

begin;

-- 1. Enum values --------------------------------------------------------------

alter type public.user_role     rename value 'accommodation_manager'  to 'landlord';
alter type public.audience_type rename value 'accommodation_managers' to 'landlords';

-- 2. Tables -------------------------------------------------------------------

alter table public.accommodation_manager_profiles rename to landlord_profiles;
alter table public.accommodation_manager_reviews  rename to landlord_reviews;

-- 3. Columns ------------------------------------------------------------------

alter table public.accommodations   rename column accommodation_manager_id to landlord_id;
alter table public.leases           rename column accommodation_manager_id to landlord_id;
alter table public.tickets          rename column accommodation_manager_id to landlord_id;
alter table public.tenant_reviews   rename column accommodation_manager_id to landlord_id;
alter table public.landlord_reviews rename column accommodation_manager_id to landlord_id;

-- 4. Constraints (a constraint-backed index is renamed with its constraint) ----

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

-- 5. Standalone indexes -------------------------------------------------------

alter index public.idx_accommodation_manager_reviews_accommodation_manager_id
  rename to idx_landlord_reviews_landlord_id;
alter index public.idx_accommodation_manager_reviews_student_id
  rename to idx_landlord_reviews_student_id;
alter index public.idx_accommodations_accommodation_manager_id
  rename to idx_accommodations_landlord_id;
alter index public.idx_leases_accommodation_manager_id
  rename to idx_leases_landlord_id;
alter index public.idx_tenant_reviews_accommodation_manager_id
  rename to idx_tenant_reviews_landlord_id;
alter index public.idx_tickets_accommodation_manager_id
  rename to idx_tickets_landlord_id;

-- 6. Trigger function whose own name carries the old term ---------------------
-- Triggers reference their function by OID, so the rename does not disturb them.

alter function public.trg_new_accommodation_manager() rename to trg_new_landlord;

-- 7. Function bodies ----------------------------------------------------------
-- Every one of these has a string body, so the renames above do not reach into
-- them. Replaced verbatim apart from the renamed identifiers and the user-facing
-- wording.

create or replace function public.can_notify(target uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
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
 returns table(id uuid)
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  SELECT r.accommodation_id
  FROM public.leases l
  JOIN public.rooms r ON r.id = l.room_id
  WHERE l.student_id = auth.uid() AND l.status = 'active'
  UNION
  SELECT a.id FROM public.accommodations a WHERE a.landlord_id = auth.uid();
$function$;

-- Parameter names are part of the call site for named-argument RPC, and
-- CREATE OR REPLACE refuses to rename an input parameter, so this one is
-- dropped and recreated. The mobile client calls it with named arguments.
drop function if exists public.submit_student_review(uuid, uuid, uuid, integer, text, integer, text);

create function public.submit_student_review(p_lease_id uuid, p_accommodation_id uuid, p_landlord_id uuid, p_acc_rating integer, p_acc_comment text, p_manager_rating integer, p_manager_comment text)
 returns void
 language sql
 set search_path to 'public'
as $function$
  with acc as (
    insert into public.accommodation_reviews (lease_id, student_id, accommodation_id, rating, comment)
    values (p_lease_id, auth.uid(), p_accommodation_id, p_acc_rating, nullif(btrim(coalesce(p_acc_comment, '')), ''))
    returning 1
  )
  insert into public.landlord_reviews (lease_id, student_id, landlord_id, rating, comment)
  select p_lease_id, auth.uid(), p_landlord_id, p_manager_rating,
         nullif(btrim(coalesce(p_manager_comment, '')), '')
    from acc;
$function$;

create or replace function public.notify_policy()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
BEGIN
  IF new.archived OR new.effective_date > now() THEN RETURN new; END IF;
  IF tg_op = 'UPDATE' AND NOT (old.archived OR old.effective_date > now()) THEN RETURN new; END IF;

  INSERT INTO public.notifications (user_id, title, body, type, link_url, ref_id, source)
  SELECT
    u.id,
    new.title,
    coalesce(new.version || ' · ', '')
      || 'In effect from ' || to_char(new.effective_date AT TIME ZONE 'Asia/Manila', 'Mon DD, YYYY')
      || '. Open Policies & guidelines to read and accept it.',
    'policy',
    NULL,
    new.id,
    'System Admin'
  FROM public.users u
  WHERE u.status <> 'suspended'
    AND u.role IN ('student', 'landlord');

  RETURN new;
END;
$function$;

create or replace function public.purge_unverified_accounts(p_older_than interval default '30 days'::interval)
 returns integer
 language plpgsql
 security definer
 set search_path to 'public', 'auth'
as $function$
declare
  n integer;
begin
  with doomed as (
    select u.id
    from public.users u
    where u.email_verified_at is null
      and u.status = 'pending'
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
    values ('auth.purge_unverified', null, 'user',
            jsonb_build_object('deleted', n, 'older_than', p_older_than::text));
  end if;
  return n;
end $function$;

create or replace function public.tg_lease_closed_clears_inquiry()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
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
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.student_id is distinct from old.student_id
     and not public.is_admin(auth.uid()) then
    raise exception 'a lease cannot be reassigned to a different student';
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
      raise exception 'a student may only request leave on their own lease';
    end if;
  end if;
  return new;
end $function$;

create or replace function public.trg_new_landlord()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.role = 'landlord' then
    perform public.notify_admins(
      'New landlord/landlady registered',
      coalesce(new.full_name, new.email)
        || ' joined as a landlord/landlady and needs verification.',
      'verification',
      '/verifications?focus=verification:' || new.id::text
    );
  end if;
  return new;
end;
$function$;

create or replace function public.fanout_announcement(p_id uuid)
 returns integer
 language plpgsql
 security definer
 set search_path to 'public'
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

  -- Who it reads as: a house notice is from the house, everything else is the
  -- platform speaking. Individual OSAS staff names mean nothing to a student.
  SELECT CASE
           WHEN a.accommodation_id IS NULL THEN 'System Admin'
           ELSE coalesce((SELECT name FROM public.accommodations WHERE id = a.accommodation_id), 'Your accommodation')
         END
    INTO sender;

  INSERT INTO public.notifications (user_id, title, body, type, link_url, ref_id, source)
  SELECT u.id, a.title, coalesce(nullif(a.summary, ''), left(a.body, 300)), 'announcement', NULL, a.id, sender
  FROM public.users u
  WHERE u.status <> 'suspended'
    AND u.id <> a.author_id
    AND (
      CASE WHEN a.accommodation_id IS NULL THEN
        (a.audience = 'all' AND u.role IN ('student', 'landlord'))
        OR (a.audience = 'students' AND u.role = 'student')
        OR (a.audience = 'landlords' AND u.role = 'landlord')
      ELSE
        u.id IN (
          SELECT l.student_id FROM public.leases l
          JOIN public.rooms r ON r.id = l.room_id
          WHERE r.accommodation_id = a.accommodation_id AND l.status = 'active'
        )
      END
    );

  GET DIAGNOSTICS sent = ROW_COUNT;
  RETURN sent;
END;
$function$;

create or replace function public.invite_application(p_conversation uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_me uuid := auth.uid();
  v_room uuid;
  v_student uuid;
begin
  if v_me is null then
    raise exception 'Not signed in';
  end if;

  select c.inquiry_room_id,
         case when c.user_a_id = v_me then c.user_b_id else c.user_a_id end
    into v_room, v_student
  from public.conversations c
  where c.id = p_conversation
    and (c.user_a_id = v_me or c.user_b_id = v_me);

  if not found then
    raise exception 'Conversation not found';
  end if;

  if (select u.role::text from public.users u where u.id = v_me) <> 'landlord' then
    raise exception 'Only the landlord/landlady can send an application form';
  end if;

  if v_room is null then
    raise exception 'This student has not asked about a room yet';
  end if;

  if not exists (
    select 1
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
    where r.id = v_room
      and a.landlord_id = v_me
      and r.status = 'available'
  ) then
    raise exception 'That room is not yours, or is no longer available';
  end if;

  if not public.student_may_lease(v_student) then
    raise exception 'OSAS has not verified this student yet, so they cannot be offered a room.';
  end if;

  if exists (
    select 1 from public.leases l
    where l.student_id = v_student
      and l.status in ('pending', 'active', 'leave_requested')
  ) then
    raise exception 'This student already has a current application or stay';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $function$;

create or replace function public.lock_user_privileges()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  allow_resubmit boolean := coalesce(current_setting('app.resubmitting', true), 'false') = 'true';
  allow_email boolean := coalesce(current_setting('app.confirming_email', true), 'false') = 'true';
  allow_complete boolean := coalesce(current_setting('app.completing_registration', true), 'false') = 'true';
  allow_sync boolean := coalesce(current_setting('app.syncing_auth', true), 'false') = 'true';
  allow_consent boolean := coalesce(current_setting('app.recording_consent', true), 'false') = 'true';
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
      -- Choosing student vs landlord/landlady is part of onboarding, and only then.
      if not (old.registered_at is null
              and new.role in ('student','landlord')
              and old.role <> 'admin') then
        raise exception 'You are not allowed to change your own role.';
      end if;
    end if;
    -- `allow_sync` joins `allow_email` here because the sync's UPDATE branch
    -- stamps this column itself when an OAuth identity is linked later. In
    -- practice auth.uid() is null for a write driven by the auth server and this
    -- whole block is skipped, but that depends on how GoTrue happens to connect,
    -- which is not a thing to leave a security guard resting on.
    if new.email_verified_at is distinct from old.email_verified_at
       and not (allow_email or allow_sync) then
      raise exception 'You are not allowed to change your own e-mail verification.';
    end if;
    if new.status is distinct from old.status then
      if allow_resubmit and new.status = 'pending' and old.status in ('rejected','unverified') then
        return new;
      end if;
      raise exception 'You are not allowed to change your own account status.';
    end if;
    -- Registration completes once; it cannot be un-set to re-open role changes.
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception 'Registration is already complete.';
    end if;

    -- Completing a registration happens only through complete_registration().
    if new.registered_at is distinct from old.registered_at and not allow_complete then
      raise exception 'Registration is completed by the server, not the client.';
    end if;

    -- Consent is stamped by complete_registration() the first time and by
    -- record_consent() when a document is revised. Never by the client.
    if (new.terms_accepted_at is distinct from old.terms_accepted_at
        or new.privacy_accepted_at is distinct from old.privacy_accepted_at)
       and not (allow_complete or allow_consent) then
      raise exception 'Consent timestamps are recorded by the server, not the client.';
    end if;

    -- The address shown across both apps follows auth.users, and is only ever
    -- written by the sync trigger. Changing it directly let someone display an
    -- address they had never proved — on any domain, signup rule or not.
    if new.email is distinct from old.email and not allow_sync then
      raise exception 'Change your e-mail address through your account settings.';
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.lock_verification_columns()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
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
      if coalesce(current_setting('app.permit_review', true), 'false') = 'true'
         and new.status = 'pending'
         and old.status in ('accredited', 'expired', 'needs_revision', 'rejected') then
        null;
      elsif auth.uid() = old.landlord_id
            and new.landlord_id = old.landlord_id
            and (
              (old.status = 'accredited' and new.status = 'delisted')
              or (old.status = 'delisted' and new.status = 'accredited'
                  and (new.accreditation_expires_at is null
                       or new.accreditation_expires_at > now()))
            ) then
        null;
      else
        raise exception 'Only OSAS may change accreditation status.';
      end if;
    end if;
  end if;

  if tg_table_name = 'verification_documents' then
    if new.status = 'approved' then
      raise exception 'Only OSAS may approve a document.';
    end if;
  end if;

  return new;
end $function$;

create or replace function public.tg_payment_guard()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
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

  if tg_op = 'INSERT' then
    if new.status <> 'pending_verification'
    or new.paid_at          is not null
    or new.verified_by      is not null
    or new.rejection_reason is not null then
      raise exception 'a student may only submit a payment for verification';
    end if;
  else
    if new.status           is distinct from old.status
    or new.amount           is distinct from old.amount
    or new.month            is distinct from old.month
    or new.lease_id         is distinct from old.lease_id
    or new.paid_at          is distinct from old.paid_at
    or new.verified_by      is distinct from old.verified_by
    or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'a student may not verify or alter a submitted payment';
    end if;
  end if;

  return new;
end;
$function$;

create or replace function public.tg_revoke_on_unverify()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public', 'auth'
as $function$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  awaiting_review boolean := new.role = 'landlord' and new.status = 'pending';
begin
  if new.status in ('rejected','suspended') and new.status is distinct from old.status then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = 'delisted'
      where landlord_id = new.id and status = 'accredited';
  end if;

  if new.status = 'suspended' and old.status is distinct from 'suspended' then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  if new.status in ('verified','rejected','reviewing')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $function$;

create or replace function public.trg_ticket_message_notify()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
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

  preview := coalesce(t.subject, 'Your ticket') || ': ' || left(new.body, 120);

  if new.author_role = 'agent' then
    if t.student_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.student_id, 'OSAS replied to your ticket', preview, 'ticket', '/student/support');
    end if;
    if t.landlord_id is not null then
      insert into public.notifications (user_id, title, body, type, link_url)
      values (t.landlord_id, 'OSAS replied to your ticket', preview, 'ticket', '/manager/osas');
    end if;
  else
    perform public.notify_admins(
      'New reply on a ticket',
      preview,
      'ticket',
      '/support-tickets?focus=ticket:' || t.id::text
    );
  end if;

  return new;
end;
$function$;

create or replace function public.verify_student_qr(p_code text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
DECLARE
  me uuid := auth.uid();
  recent integer;
  sp record;
  u record;
  is_mine boolean;
  v_method text := 'qr';
  v_result text;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;

  SELECT count(*) INTO recent
    FROM public.qr_scans
   WHERE scanner_id = me AND scanned_at > now() - interval '1 minute';
  IF recent >= 12 THEN
    RAISE EXCEPTION 'Too many scans in a row. Wait a minute and try again.';
  END IF;

  SELECT * INTO sp FROM public.student_profiles WHERE qr_code_token = p_code;

  IF sp.user_id IS NOT NULL
     AND (sp.qr_token_expires_at IS NULL OR sp.qr_token_expires_at <= now()) THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, sp.user_id, 'qr', 'expired');
    RETURN jsonb_build_object('found', false, 'reason', 'expired');
  END IF;

  IF sp.user_id IS NULL THEN
    IF public.get_my_role() IN ('landlord', 'admin') THEN
      v_method := 'manual';
      SELECT * INTO sp FROM public.student_profiles WHERE student_id = p_code;
    END IF;
  END IF;

  IF sp.user_id IS NULL THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, NULL, v_method, 'not_found');
    RETURN jsonb_build_object('found', false, 'reason', 'not_found');
  END IF;

  SELECT * INTO u FROM public.users WHERE id = sp.user_id;

  SELECT EXISTS (
    SELECT 1 FROM public.leases l
     WHERE l.student_id = sp.user_id AND l.landlord_id = me
  ) INTO is_mine;

  v_result := CASE WHEN sp.osas_verified_at IS NOT NULL THEN 'verified' ELSE 'unverified' END;
  INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
  VALUES (me, sp.user_id, v_method, v_result);

  RETURN jsonb_build_object(
    'found', true,
    'user_id', sp.user_id,
    'student_id', sp.student_id,
    'full_name', u.full_name,
    'initials', u.initials,
    'avatar_url', u.avatar_url,
    'program', sp.program,
    'college', sp.college,
    'year_level', sp.year_level,
    'osas_verified', sp.osas_verified_at IS NOT NULL,
    'verified_at', sp.osas_verified_at,
    'account_status', u.status,
    'is_my_tenant', is_mine,
    'method', v_method
  );
END;
$function$;

commit;

-- Post-migration check: all four should return 0.
--
--   select count(*) from pg_policies
--    where schemaname='public'
--      and (qual::text like '%accommodation_manager%' or with_check::text like '%accommodation_manager%');
--   select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--    where n.nspname='public' and p.prosrc like '%accommodation_manager%';
--   select count(*) from information_schema.columns
--    where table_schema='public' and column_name like '%accommodation_manager%';
--   select count(*) from information_schema.tables
--    where table_schema='public' and table_name like '%accommodation_manager%';
