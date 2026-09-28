-- Baseline: the whole live schema as of 2026-09-25, taken with
-- `supabase db dump --linked`. Everything before this lives in
-- ../migrations_archive/ for history only — it never rebuilt the database,
-- because the four original *_remote.sql files were empty.
--
-- New changes go in new migrations after this one, as before.




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."accommodation_status" AS ENUM (
    'pending',
    'reviewing',
    'accredited',
    'rejected',
    'delisted',
    'expired',
    'suspended',
    'needs_revision'
);


ALTER TYPE "public"."accommodation_status" OWNER TO "postgres";


CREATE TYPE "public"."amenity" AS ENUM (
    'wifi',
    'water',
    'electric',
    'aircon',
    'parking',
    'kitchen',
    'laundry',
    'cctv'
);


ALTER TYPE "public"."amenity" OWNER TO "postgres";


CREATE TYPE "public"."audience_type" AS ENUM (
    'all',
    'students',
    'landlords'
);


ALTER TYPE "public"."audience_type" OWNER TO "postgres";


CREATE TYPE "public"."doc_status" AS ENUM (
    'pending',
    'approved',
    'rejected'
);


ALTER TYPE "public"."doc_status" OWNER TO "postgres";


CREATE TYPE "public"."lease_status" AS ENUM (
    'active',
    'ended',
    'terminated',
    'leave_requested',
    'pending',
    'rejected'
);


ALTER TYPE "public"."lease_status" OWNER TO "postgres";


CREATE TYPE "public"."msg_status" AS ENUM (
    'sent',
    'delivered',
    'read'
);


ALTER TYPE "public"."msg_status" OWNER TO "postgres";


CREATE TYPE "public"."office" AS ENUM (
    'osas',
    'registrar',
    'housing'
);


ALTER TYPE "public"."office" OWNER TO "postgres";


CREATE TYPE "public"."payment_method" AS ENUM (
    'gcash',
    'maya',
    'bank',
    'cash',
    'others'
);


ALTER TYPE "public"."payment_method" OWNER TO "postgres";


CREATE TYPE "public"."payment_status" AS ENUM (
    'due',
    'paid',
    'overdue',
    'pending_verification',
    'rejected'
);


ALTER TYPE "public"."payment_status" OWNER TO "postgres";


CREATE TYPE "public"."room_status" AS ENUM (
    'available',
    'occupied',
    'maintenance'
);


ALTER TYPE "public"."room_status" OWNER TO "postgres";


CREATE TYPE "public"."room_type" AS ENUM (
    'solo',
    'duo',
    'triple',
    'bedspace',
    'studio'
);


ALTER TYPE "public"."room_type" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'student',
    'landlord',
    'admin'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "public"."user_status" AS ENUM (
    'unverified',
    'pending',
    'reviewing',
    'verified',
    'rejected',
    'suspended'
);


ALTER TYPE "public"."user_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_change_role"("p_user" "uuid", "p_role" "public"."user_role", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  v_user public.users;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform public.assert_admin_over(p_user);
  if p_role not in ('student', 'landlord') then
    raise exception 'An account can only become a student or a landlord/landlady here.';
  end if;
  if v_reason is null then
    raise exception 'Give a reason — the person is told it.';
  end if;

  select * into v_user from public.users where id = p_user for update;
  if v_user.role = p_role then
    raise exception 'They already have that role.';
  end if;
  if v_user.closed_at is not null then
    raise exception 'This account is closed.';
  end if;
  if exists (select 1 from public.leases
              where (student_id = p_user or landlord_id = p_user)
                and status in ('active', 'pending', 'leave_requested')) then
    raise exception 'They have a current stay or application. It has to end first.';
  end if;
  if exists (select 1 from public.accommodations where landlord_id = p_user) then
    raise exception 'They still own accommodations. Those have to be removed or transferred first.';
  end if;

  update public.users
     set role = p_role,
         status = 'pending',
         registered_at = null,
         updated_at = now()
   where id = p_user;
  update public.student_profiles set osas_verified_at = null where user_id = p_user;

  insert into public.account_standing (user_id, reason, restrictions, updated_by, updated_at)
  values (p_user, v_reason, '{}', auth.uid(), now())
  on conflict (user_id) do update
    set reason = excluded.reason, suspended_until = null, restrictions = '{}',
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;

  insert into public.notifications (user_id, type, title, body, link_url)
  values (p_user, 'verification', 'Your account role was changed',
          'OSAS changed your account to ' || case when p_role = 'student' then 'a student' else 'a landlord/landlady' end
          || '. Sign in again to finish registering. Reason: ' || v_reason, '/profile');
end $$;


ALTER FUNCTION "public"."admin_change_role"("p_user" "uuid", "p_role" "public"."user_role", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_close_account"("p_user" "uuid", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform public.assert_admin_over(p_user);
  if not public.current_is_superadmin() then
    raise exception 'Only the main admin can close an account.' using errcode = '42501';
  end if;
  if v_reason is null then
    raise exception 'Give a reason for closing the account.';
  end if;
  if (select closed_at from public.users where id = p_user) is not null then
    raise exception 'This account is already closed.';
  end if;
  if exists (select 1 from public.leases
              where (student_id = p_user or landlord_id = p_user)
                and status in ('active', 'pending', 'leave_requested')) then
    raise exception 'They have a current stay or application. It has to end first.';
  end if;
  if exists (select 1 from public.accommodations where landlord_id = p_user and status = 'accredited') then
    raise exception 'They have accredited accommodations. Delist them first.';
  end if;

  delete from auth.identities where user_id = p_user;
  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;
  update auth.users
     set email = 'closed+' || p_user::text || '@accommo.invalid',
         phone = null,
         encrypted_password = '',
         raw_user_meta_data = '{}'::jsonb,
         banned_until = now() + interval '100 years'
   where id = p_user;

  update public.users
     set full_name = 'Closed account',
         initials = 'CA',
         phone = '+639000000000',
         sex = null,
         date_of_birth = null,
         avatar_url = null,
         status = 'suspended',
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
  values (p_user, v_reason, '{}', auth.uid(), now())
  on conflict (user_id) do update
    set reason = excluded.reason, suspended_until = null, restrictions = '{}',
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  update public.audit_logs
     set before_json = before_json - array[
           'email', 'phone', 'full_name', 'initials', 'date_of_birth', 'avatar_url', 'sex',
           'student_id', 'school_id_url', 'assessment_of_fees_url', 'emergency_contact_json',
           'extracted_name', 'extracted_school_id', 'qr_code_token',
           'government_id_url', 'extracted_gov_id', 'file_url', 'filename'],
         after_json = after_json - array[
           'email', 'phone', 'full_name', 'initials', 'date_of_birth', 'avatar_url', 'sex',
           'student_id', 'school_id_url', 'assessment_of_fees_url', 'emergency_contact_json',
           'extracted_name', 'extracted_school_id', 'qr_code_token',
           'government_id_url', 'extracted_gov_id', 'file_url', 'filename']
   where entity_type in ('users', 'student_profiles', 'landlord_profiles', 'verification_documents')
     and (entity_id = p_user::text
          or before_json ->> 'user_id' = p_user::text
          or after_json ->> 'user_id' = p_user::text);

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), 'account.closed', 'users', p_user::text, jsonb_build_object('reason', v_reason), now());
end $$;


ALTER FUNCTION "public"."admin_close_account"("p_user" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_disconnect_google"("p_user" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
begin
  perform public.assert_admin_over(p_user);
  if not exists (select 1 from auth.identities where user_id = p_user and provider = 'google') then
    raise exception 'This account has no Google account connected.';
  end if;
  if (select coalesce(encrypted_password, '') = '' from auth.users where id = p_user) then
    raise exception 'Set a temporary password first — without Google they would have no way to sign in.';
  end if;

  delete from auth.identities where user_id = p_user and provider = 'google';
  update auth.users
     set raw_app_meta_data = jsonb_set(
           jsonb_set(coalesce(raw_app_meta_data, '{}'), '{provider}', '"email"'),
           '{providers}',
           coalesce((select jsonb_agg(p) from jsonb_array_elements_text(raw_app_meta_data -> 'providers') p where p <> 'google'), '["email"]')
         )
   where id = p_user;
  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), 'account.disconnect_google', 'users', p_user::text, '{}'::jsonb, now());
end $$;


ALTER FUNCTION "public"."admin_disconnect_google"("p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_account_status"("p_user" "uuid", "p_status" "public"."user_status", "p_reason" "text" DEFAULT NULL::"text", "p_until" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_restrictions" "text"[] DEFAULT NULL::"text"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_me uuid := auth.uid();
  v_user public.users;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_old_restr text[];
  v_restr text[];
  v_added text[];
  v_removed text[];
  v_until_txt text;
begin
  if not public.is_admin(v_me) then
    raise exception 'Only OSAS can change an account''s status.' using errcode = '42501';
  end if;

  select * into v_user from public.users where id = p_user for update;
  if not found then
    raise exception 'That account no longer exists.';
  end if;
  if v_user.role = 'admin' or v_user.is_superadmin then
    raise exception 'Administrator accounts are managed under Settings.';
  end if;

  select restrictions into v_old_restr from public.account_standing where user_id = p_user;
  v_old_restr := coalesce(v_old_restr, '{}');
  v_restr := coalesce(p_restrictions, v_old_restr);
  v_added := array(select unnest(v_restr) except select unnest(v_old_restr));
  v_removed := array(select unnest(v_old_restr) except select unnest(v_restr));

  if 'apply' = any(v_added) and v_user.role <> 'student' then
    raise exception 'Only a student can be stopped from applying for rooms.';
  end if;
  if 'listings' = any(v_added) and v_user.role <> 'landlord' then
    raise exception 'Only a landlord/landlady has listings to hide.';
  end if;

  if v_reason is null and (
       (p_status in ('suspended', 'rejected') and p_status is distinct from v_user.status)
       or cardinality(v_added) > 0
     ) then
    raise exception 'Give a reason — the person is told it.';
  end if;

  if p_until is not null then
    if p_status <> 'suspended' then
      raise exception 'An end date only applies to a suspension.';
    end if;
    if p_until <= now() then
      raise exception 'The end date must be in the future.';
    end if;
    if v_user.status not in ('verified', 'suspended') then
      raise exception 'Only a verified account can be suspended until a date.';
    end if;
  end if;

  if p_status is distinct from v_user.status then
    update public.users set status = p_status, updated_at = now() where id = p_user;
  end if;

  insert into public.account_standing (user_id, reason, suspended_until, restrictions, updated_by, updated_at)
  values (
    p_user,
    v_reason,
    case when p_status = 'suspended' then p_until end,
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

  if 'listings' = any(v_added) then
    update public.accommodations set hidden_from_listings = true where landlord_id = p_user;
  elsif 'listings' = any(v_removed) then
    update public.accommodations set hidden_from_listings = false where landlord_id = p_user;
  end if;

  if p_status is distinct from v_user.status and p_status in ('rejected', 'verified') then
    insert into public.verification_requests
      (entity_type, entity_id, type, status, reviewed_by, reviewed_at, decision_notes)
    values (
      'user',
      p_user,
      case when v_user.role = 'landlord' then 'Landlord/Landlady Identity' else 'Enrollment Form / COR' end,
      case when p_status = 'rejected' then 'resubmission_requested' else 'approved' end,
      v_me,
      now(),
      v_reason
    );
  end if;

  v_until_txt := case when p_until is not null
    then ' until ' || to_char(p_until at time zone 'Asia/Manila', 'Mon FMDD, YYYY')
    else '' end;

  if p_status is distinct from v_user.status then
    insert into public.notifications (user_id, type, title, body, link_url)
    select p_user, 'verification', t.title, t.body, '/profile'
    from (values
      (case p_status
         when 'suspended' then 'Account suspended'
         when 'rejected' then 'Resubmission requested'
         when 'verified' then case when v_user.status = 'suspended' then 'Account reactivated' else 'Verification approved' end
       end,
       case p_status
         when 'suspended' then 'OSAS suspended your account' || v_until_txt || '. Reason: ' || v_reason
         when 'rejected' then 'OSAS needs new requirements from you. Note: ' || v_reason
         when 'verified' then case when v_user.status = 'suspended'
           then 'Your account is active again.' || coalesce(' Note: ' || v_reason, '')
           else 'Your account has been verified.' end
       end)
    ) as t(title, body)
    where t.title is not null;
  end if;

  if 'apply' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Room applications paused',
            'OSAS has paused your room applications. Reason: ' || v_reason, '/profile');
  end if;
  if 'apply' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Room applications restored', 'You can apply for rooms again.', '/profile');
  end if;
  if 'listings' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Listings hidden',
            'OSAS has hidden your accommodations from students. Reason: ' || v_reason, '/profile');
  end if;
  if 'listings' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Listings visible again', 'Students can see your accommodations again.', '/profile');
  end if;
end $$;


ALTER FUNCTION "public"."admin_set_account_status"("p_user" "uuid", "p_status" "public"."user_status", "p_reason" "text", "p_until" timestamp with time zone, "p_restrictions" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_sign_in_methods"("p_user" "uuid") RETURNS TABLE("has_password" boolean, "has_google" boolean, "last_sign_in_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
begin
  perform public.assert_admin_over(p_user);
  return query
    select coalesce(a.encrypted_password, '') <> '',
           exists (select 1 from auth.identities i where i.user_id = a.id and i.provider = 'google'),
           a.last_sign_in_at
      from auth.users a
     where a.id = p_user;
end $$;


ALTER FUNCTION "public"."admin_sign_in_methods"("p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_sign_out_everywhere"("p_user" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  v_count integer;
begin
  perform public.assert_admin_over(p_user);
  delete from auth.sessions where user_id = p_user;
  get diagnostics v_count = row_count;
  delete from auth.refresh_tokens where user_id = p_user::text;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), 'account.sign_out_everywhere', 'users', p_user::text, jsonb_build_object('sessions', v_count), now());
  return v_count;
end $$;


ALTER FUNCTION "public"."admin_sign_out_everywhere"("p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."announce_due"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."announce_due"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."announcement_reach"("p_id" "uuid") RETURNS TABLE("sent" integer, "seen" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF get_my_role() <> 'admin' THEN
    RAISE EXCEPTION 'admins only';
  END IF;
  RETURN QUERY
    SELECT count(*)::int, count(*) FILTER (WHERE read_at IS NOT NULL)::int
    FROM public.notifications
    WHERE ref_id = p_id AND type = 'announcement';
END;
$$;


ALTER FUNCTION "public"."announcement_reach"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_expired_announcements"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."archive_expired_announcements"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assert_admin_over"("p_user" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Only OSAS can do this.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.users where id = p_user and role in ('student', 'landlord') and not is_superadmin) then
    raise exception 'This only applies to student and landlord/landlady accounts.';
  end if;
end $$;


ALTER FUNCTION "public"."assert_admin_over"("p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_notify"("target" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."can_notify"("target" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_student_id_exists"("p_student_id" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.student_profiles
    where student_id = p_student_id
  );
$$;


ALTER FUNCTION "public"."check_student_id_exists"("p_student_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clear_pin"("p_current" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_me uuid := auth.uid(); v_hash text;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  select pin_hash into v_hash from public.user_pins where user_id = v_me;
  if v_hash is null then return true; end if;
  if not public.pin_attempt(p_current) then
    return false;
  end if;
  delete from public.user_pins where user_id = v_me;
  return true;
end $$;


ALTER FUNCTION "public"."clear_pin"("p_current" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_registration"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in.';
  end if;

  perform set_config('app.completing_registration', 'true', true);

  update public.users
     set registered_at       = coalesce(registered_at, now()),
         terms_accepted_at   = coalesce(terms_accepted_at, now()),
         privacy_accepted_at = coalesce(privacy_accepted_at, now()),
         updated_at          = now()
   where id = v_uid
     and email_verified_at is not null;

  if not found then
    raise exception 'Confirm your e-mail address before completing registration.'
      using errcode = 'check_violation';
  end if;
end;
$$;


ALTER FUNCTION "public"."complete_registration"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirm_email_ownership"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  methods jsonb := coalesce(auth.jwt() -> 'amr', '[]'::jsonb);
  provider text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  select raw_app_meta_data ->> 'provider' into provider from auth.users where id = auth.uid();

  if not (
    exists (
      select 1 from jsonb_array_elements(methods) m
      where m ->> 'method' in ('otp', 'magiclink', 'email', 'oauth')
    )
    or coalesce(provider, 'email') <> 'email'
  ) then
    raise exception 'Verify your e-mail with the code first.';
  end if;

  perform set_config('app.confirming_email', 'true', true);
  update public.users set email_verified_at = now(), updated_at = now()
  where id = auth.uid() and email_verified_at is null;
  return true;
end $$;


ALTER FUNCTION "public"."confirm_email_ownership"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_is_superadmin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce((select is_superadmin from public.users where id = auth.uid()), false);
$$;


ALTER FUNCTION "public"."current_is_superadmin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_qr_token"() RETURNS TABLE("token" "text", "expires_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE sp record;
BEGIN
  SELECT qr_code_token, qr_token_expires_at INTO sp
    FROM public.student_profiles WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No student profile for this account';
  END IF;

  IF sp.qr_code_token IS NULL
     OR sp.qr_token_expires_at IS NULL
     OR sp.qr_token_expires_at <= now() THEN
    UPDATE public.student_profiles
       SET qr_code_token = gen_random_uuid()::text,
           qr_token_expires_at = now() + interval '1 hour'
     WHERE user_id = auth.uid()
     RETURNING qr_code_token, qr_token_expires_at INTO sp;
  END IF;

  token := sp.qr_code_token;
  expires_at := sp.qr_token_expires_at;
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."current_qr_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_room_capacity"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  cap int;
  taken int;
begin
  if new.status not in ('active', 'leave_requested') then
    return new;
  end if;
  select r.capacity into cap from public.rooms r where r.id = new.room_id;
  if cap is null then
    return new;
  end if;
  select count(*) into taken
  from public.leases l
  where l.room_id = new.room_id
    and l.status in ('active', 'leave_requested')
    and l.id <> new.id;
  if taken >= cap then
    raise exception 'Room is already full (%/% beds occupied).', taken, cap
      using errcode = '23514';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_room_capacity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fanout_announcement"("p_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
$$;


ALTER FUNCTION "public"."fanout_announcement"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_audit_log_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
    v_action     text;
    v_entity_id  text;
    v_before     jsonb;
    v_after      jsonb;
    v_actor      uuid := auth.uid();
    v_pk         text;
    row_json     jsonb;
begin
    case TG_OP
        when 'INSERT' then v_action := 'CREATE';
        when 'DELETE' then v_action := 'DELETE';
        else               v_action := 'UPDATE';
    end case;

    if TG_OP in ('INSERT', 'UPDATE') then
        v_after := to_jsonb(NEW);
        row_json := v_after;
    else
        row_json := to_jsonb(OLD);
    end if;
    if TG_OP in ('UPDATE', 'DELETE') then
        v_before := to_jsonb(OLD);
    end if;

    -- Resolve the primary key column name for THIS table, then read its value
    -- off the row JSON (handles uuid and varchar/text/numeric PKs alike).
    select a.attname into v_pk
    from pg_index i
    join pg_attribute a
         on a.attrelid = i.indrelid
        and a.attnum  = any(i.indkey)
    where i.indrelid = TG_RELID
      and i.indisprimary
    limit 1;

    v_entity_id := coalesce(row_json ->> v_pk, '');

    insert into public.audit_logs (
        actor_id,
        action,
        entity_type,
        entity_id,
        before_json,
        after_json,
        created_at,
        ip_address,
        user_agent
    ) values (
        v_actor,
        v_action,
        TG_TABLE_NAME,
        v_entity_id,
        v_before,
        v_after,
        now(),
        nullif(nullif(current_setting('audit.ip_address', true), ''), null),
        nullif(nullif(current_setting('audit.user_agent', true), ''), null)
    );

    return coalesce(NEW, OLD);
end;
$$;


ALTER FUNCTION "public"."fn_audit_log_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT u.role::text
  FROM public.users u
  WHERE u.id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_verification_queue"() RETURNS TABLE("user_id" "uuid", "full_name" "text", "email" "text", "role" "text", "user_status" "text", "avatar_url" "text", "created_at" timestamp with time zone, "reviewing_by" "uuid", "reviewing_at" timestamp with time zone, "doc_id" "uuid", "doc_type" "text", "file_url" "text", "filename" "text", "doc_status" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select u.id, u.full_name, u.email, u.role::text, u.status::text,
         u.avatar_url,
         u.created_at, u.reviewing_by, u.reviewing_at,
         d.id, d.doc_type, d.file_url, d.filename, d.status::text
  from public.users u
  left join public.verification_documents d on d.user_id = u.id and d.status = 'pending'
  where public.is_admin(auth.uid())
    and u.status::text in ('pending','reviewing')
  order by (d.id is not null) desc, d.uploaded_at desc nulls last, u.created_at desc nulls last;
$$;


ALTER FUNCTION "public"."get_verification_queue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_facility_room_link"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (
    select 1
    from accommodation_facilities f
    join rooms r on r.accommodation_id = f.accommodation_id
    where f.id = new.facility_id
      and r.id = new.room_id
      and f.access_scope = 'shared'
  ) then
    raise exception 'A room can only be linked to a shared facility of its own accommodation'
      using errcode = '23514';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."guard_facility_room_link"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_hidden_from_listings"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.hidden_from_listings is distinct from old.hidden_from_listings
     and not is_admin(auth.uid()) then
    raise exception 'Only OSAS can change whether an accommodation is hidden from listings'
      using errcode = '42501';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."guard_hidden_from_listings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_auth_user_sync"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_domain text;
  v_allowed text[] := array['gmail.com', 'isu.edu.ph'];
  v_dob date;
begin
  begin
    v_dob := nullif(new.raw_user_meta_data ->> 'date_of_birth', '')::date;
  exception when others then
    v_dob := null;
  end;

  if tg_op = 'INSERT' then
    v_domain := lower(split_part(coalesce(new.email, ''), '@', 2));
    if v_domain <> all (v_allowed) then
      raise exception using
        errcode = 'check_violation',
        message = format('accommo: e-mail domain %L is not accepted', v_domain),
        hint = 'Accommo accounts must use @gmail.com or @isu.edu.ph.';
    end if;

    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      date_of_birth, email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, '+639000000000'),
      coalesce((new.raw_user_meta_data ->> 'role')::text, 'student')::user_role,
      'pending'::user_status,
      coalesce(new.raw_user_meta_data ->> 'full_name', 'Demo User'),
      coalesce(new.raw_user_meta_data ->> 'initials', 'DU'),
      coalesce((new.raw_user_meta_data ->> 'avatar_color'), 'blue'),
      nullif(new.raw_user_meta_data ->> 'sex', ''),
      v_dob,
      case when v_provider <> 'email' then coalesce(new.email_confirmed_at, now()) else null end,
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

  elsif tg_op = 'UPDATE' then
    perform set_config('app.syncing_auth', 'true', true);
    update public.users
    set email = new.email,
        phone = case
          when new.phone is distinct from old.phone
            or (new.raw_user_meta_data ->> 'phone') is distinct from (old.raw_user_meta_data ->> 'phone')
          then coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, phone)
          else phone
        end,
        date_of_birth = case
          when (new.raw_user_meta_data ->> 'date_of_birth') is distinct from (old.raw_user_meta_data ->> 'date_of_birth')
          then coalesce(v_dob, public.users.date_of_birth)
          else public.users.date_of_birth
        end,
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> 'email' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = 'DELETE' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$$;


ALTER FUNCTION "public"."handle_auth_user_sync"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_pin"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.user_pins where user_id = auth.uid());
$$;


ALTER FUNCTION "public"."has_pin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invite_application"("p_conversation" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
end $$;


ALTER FUNCTION "public"."invite_application"("p_conversation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"("p_uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
  select exists (
    select 1 from public.users
    where id = p_uid and (role = 'admin' or is_superadmin = true)
  );
$$;


ALTER FUNCTION "public"."is_admin"("p_uid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_verified_landlord"("uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.users u
    where u.id = uid and u.role = 'landlord' and u.status = 'verified'
  );
$$;


ALTER FUNCTION "public"."is_verified_landlord"("uid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."lift_expired_suspensions"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_count integer;
begin
  if auth.uid() is not null then
    raise exception 'lift_expired_suspensions is not callable by a client.';
  end if;

  with due as (
    select s.user_id
      from public.account_standing s
      join public.users u on u.id = s.user_id
     where u.status = 'suspended'
       and s.suspended_until is not null
       and s.suspended_until <= now()
  ), lifted as (
    update public.users u set status = 'verified', updated_at = now()
      from due where u.id = due.user_id
    returning u.id
  ), cleared as (
    update public.account_standing s
       set suspended_until = null, reason = null, updated_by = null, updated_at = now()
      from lifted where s.user_id = lifted.id
    returning s.user_id
  )
  insert into public.notifications (user_id, type, title, body, link_url)
  select user_id, 'verification', 'Account reactivated', 'Your suspension has ended. You can sign in again.', '/profile'
    from cleared;

  get diagnostics v_count = row_count;
  return v_count;
end $$;


ALTER FUNCTION "public"."lift_expired_suspensions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."lock_document_ref"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  public_id text;
begin
  -- No JWT: service_role, a migration, or the SQL console. Same carve-out the
  -- sibling lock_verification_columns() trigger makes.
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  -- Unchanged on an update, or not a signed reference: nothing to pin.
  if new.file_url is null or new.file_url not like 'cld:%' then return new; end if;
  if tg_op = 'UPDATE' and new.file_url is not distinct from old.file_url then return new; end if;

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


ALTER FUNCTION "public"."lock_document_ref"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."lock_user_privileges"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
      if not (old.registered_at is null
              and new.role in ('student','landlord')
              and old.role <> 'admin') then
        raise exception 'You are not allowed to change your own role.';
      end if;
    end if;
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
    if old.registered_at is not null and new.registered_at is distinct from old.registered_at then
      raise exception 'Registration is already complete.';
    end if;
    if new.registered_at is distinct from old.registered_at and not allow_complete then
      raise exception 'Registration is completed by the server, not the client.';
    end if;
    if (new.terms_accepted_at is distinct from old.terms_accepted_at
        or new.privacy_accepted_at is distinct from old.privacy_accepted_at)
       and not (allow_complete or allow_consent) then
      raise exception 'Consent timestamps are recorded by the server, not the client.';
    end if;
    if new.email is distinct from old.email and not allow_sync then
      raise exception 'Change your e-mail address through your account settings.';
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."lock_user_privileges"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."lock_verification_columns"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
end $$;


ALTER FUNCTION "public"."lock_verification_columns"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_conversation_read"("p_conversation" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_is_participant boolean;
begin
  select exists (
    select 1 from conversations c
     where c.id = p_conversation
       and (c.user_a_id = v_uid or c.user_b_id = v_uid)
  ) into v_is_participant;

  if not v_is_participant then
    raise exception 'not a participant of this conversation';
  end if;

  update conversations c
     set unread_a = case when c.user_a_id = v_uid then 0 else c.unread_a end,
         unread_b = case when c.user_b_id = v_uid then 0 else c.unread_b end
   where c.id = p_conversation;

  update messages m
     set status = 'read'
   where m.conversation_id = p_conversation
     and m.sender_id <> v_uid
     and m.status <> 'read';
end;
$$;


ALTER FUNCTION "public"."mark_conversation_read"("p_conversation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_accommodation_ids"() RETURNS TABLE("id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT r.accommodation_id
  FROM public.leases l
  JOIN public.rooms r ON r.id = l.room_id
  WHERE l.student_id = auth.uid() AND l.status = 'active'
  UNION
  SELECT a.id FROM public.accommodations a WHERE a.landlord_id = auth.uid();
$$;


ALTER FUNCTION "public"."my_accommodation_ids"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_admins"("p_title" "text", "p_body" "text", "p_type" "text", "p_link_url" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.notifications (user_id, title, body, type, link_url)
  select u.id, p_title, p_body, p_type, p_link_url
  from public.users u
  where u.role = 'admin' or u.is_superadmin = true;
end;
$$;


ALTER FUNCTION "public"."notify_admins"("p_title" "text", "p_body" "text", "p_type" "text", "p_link_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_announcement"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF new.published_at IS NULL OR new.published_at > now() OR new.archived THEN
    RETURN new;
  END IF;
  PERFORM public.fanout_announcement(new.id);
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."notify_announcement"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_policy"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."notify_policy"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pin_attempt"("p_pin" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_me uuid := auth.uid(); v_row public.user_pins; v_ok boolean;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  select * into v_row from public.user_pins where user_id = v_me;
  if v_row.user_id is null then
    raise exception 'No PIN is set on this account';
  end if;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    raise exception 'Too many attempts. Try again after %',
      to_char(v_row.locked_until at time zone 'Asia/Manila', 'HH12:MI AM');
  end if;

  v_ok := v_row.pin_hash = extensions.crypt(p_pin, v_row.pin_hash);

  if v_ok then
    update public.user_pins set attempts = 0, locked_until = null where user_id = v_me;
    return true;
  end if;

  update public.user_pins
     set attempts = attempts + 1,
         locked_until = case when attempts + 1 >= 5 then now() + interval '15 minutes' end
   where user_id = v_me
  returning * into v_row;

  if v_row.locked_until is not null then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (
      v_me, 'security', 'Incorrect PIN attempts',
      'Someone entered the wrong PIN 5 times on your account. If that was not you, change your password.',
      null
    );
  end if;

  return false;
end $$;


ALTER FUNCTION "public"."pin_attempt"("p_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_non_superadmin_escalation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' then
    if new.role = 'admin' and not public.current_is_superadmin() then
      raise exception 'Only the main admin can create administrator accounts.';
    end if;
    if new.is_superadmin and not public.current_is_superadmin() then
      raise exception 'Only the main admin can grant superadmin privileges.';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.role = 'admin' and old.role <> 'admin' and not public.current_is_superadmin() then
      raise exception 'Only the main admin can assign the administrator role.';
    end if;
    if new.is_superadmin is distinct from old.is_superadmin and not public.current_is_superadmin() then
      raise exception 'Only the main admin can change superadmin privileges.';
    end if;
    return new;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."prevent_non_superadmin_escalation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_unverified_accounts"("p_older_than" interval DEFAULT '30 days'::interval) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
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
end $$;


ALTER FUNCTION "public"."purge_unverified_accounts"("p_older_than" interval) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reap_unverified_signups"("p_older_than" interval DEFAULT '72:00:00'::interval) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  v_count integer;
begin
  if auth.uid() is not null then
    raise exception 'reap_unverified_signups is not callable by a client.';
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
            and u.role <> 'admin'
            and u.is_superadmin = false
       )
    returning a.id
  )
  select count(*) into v_count from doomed;
  return v_count;
end;
$$;


ALTER FUNCTION "public"."reap_unverified_signups"("p_older_than" interval) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_room_occupancy"("p_room_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_active_count integer;
  v_capacity integer;
  v_status room_status;
begin
  select count(*) into v_active_count from leases where room_id = p_room_id and status in ('active', 'leave_requested');
  select capacity, status into v_capacity, v_status from rooms where id = p_room_id;
  if v_capacity is null then
    return;
  end if;

  update rooms
  set current_pax = v_active_count,
      status = case
        when v_active_count >= v_capacity then 'occupied'::room_status
        when v_status = 'maintenance' then 'maintenance'::room_status
        else 'available'::room_status
      end
  where id = p_room_id;
end;
$$;


ALTER FUNCTION "public"."recompute_room_occupancy"("p_room_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_consent"("p_documents" "text"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_unknown text[];
begin
  if v_uid is null then
    raise exception 'Not signed in.';
  end if;

  if p_documents is null or cardinality(p_documents) = 0 then
    raise exception 'Name the document being accepted.'
      using errcode = 'check_violation';
  end if;

  -- The column a name maps to is decided here, not by the caller, so the
  -- argument cannot reach any other column.
  select array_agg(d)
    into v_unknown
    from unnest(p_documents) as d
   where d not in ('terms', 'privacy');

  if v_unknown is not null then
    raise exception 'Unknown legal document: %', array_to_string(v_unknown, ', ')
      using errcode = 'check_violation';
  end if;

  perform set_config('app.recording_consent', 'true', true);

  update public.users
     set terms_accepted_at = case
           when 'terms' = any (p_documents) then now() else terms_accepted_at end,
         privacy_accepted_at = case
           when 'privacy' = any (p_documents) then now() else privacy_accepted_at end,
         updated_at = now()
   where id = v_uid;

  if not found then
    raise exception 'Account not found.';
  end if;
end;
$$;


ALTER FUNCTION "public"."record_consent"("p_documents" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_accommodation_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."refresh_accommodation_rating"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resubmit_verification"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare r record;
begin
  select id, status into r from public.users where id = auth.uid();
  if r.id is null then raise exception 'Not signed in'; end if;
  if r.status in ('pending','reviewing','verified') then return; end if;
  if r.status = 'suspended' then raise exception 'Suspended accounts cannot resubmit.'; end if;
  perform set_config('app.resubmitting', 'true', true);
  update public.users set status = 'pending', updated_at = now() where id = r.id;
end $$;


ALTER FUNCTION "public"."resubmit_verification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rotate_qr_token"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  fresh text := gen_random_uuid()::text;
  last_at timestamptz;
  wait_s integer;
BEGIN
  SELECT qr_token_rotated_at INTO last_at
    FROM public.student_profiles WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No student profile for this account';
  END IF;

  IF last_at IS NOT NULL AND last_at > now() - interval '60 seconds' THEN
    wait_s := ceil(extract(epoch FROM (last_at + interval '60 seconds' - now())));
    RAISE EXCEPTION 'You just replaced your code. Try again in % second(s).', wait_s
      USING ERRCODE = '53400';
  END IF;

  UPDATE public.student_profiles
     SET qr_code_token = fresh,
         qr_token_rotated_at = now(),
         qr_token_expires_at = now() + interval '1 hour'
   WHERE user_id = auth.uid();

  RETURN fresh;
END;
$$;


ALTER FUNCTION "public"."rotate_qr_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_audit_context"("p_user_agent" "text" DEFAULT NULL::"text", "p_ip_address" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
    perform set_config('audit.user_agent', coalesce(p_user_agent, ''), true);
    perform set_config('audit.ip_address', coalesce(p_ip_address, ''), true);
end;
$$;


ALTER FUNCTION "public"."set_audit_context"("p_user_agent" "text", "p_ip_address" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_pin"("p_pin" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare v_me uuid := auth.uid(); v_hash text; v_iat bigint;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'A PIN must be exactly 6 digits';
  end if;

  select pin_hash into v_hash from public.user_pins where user_id = v_me;

  -- Replacing an existing PIN needs a session minted in the last five minutes,
  -- which is what confirming an e-mail code produces. The old PIN is NOT asked
  -- for: it is exactly what someone who has forgotten it cannot supply, and
  -- demanding it as well guarded nothing once the mailbox alone could reset.
  -- Setting the FIRST PIN is exempt -- the owner is already signed in and has
  -- nothing yet to protect, and a round trip there only makes people skip it.
  if v_hash is not null then
    v_iat := nullif(auth.jwt() ->> 'iat', '')::bigint;
    if v_iat is null or v_iat < extract(epoch from now()) - 300 then
      raise exception 'Confirm the code sent to your e-mail first';
    end if;
  end if;

  insert into public.user_pins (user_id, pin_hash, attempts, locked_until, updated_at)
  values (v_me, extensions.crypt(p_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, attempts = 0, locked_until = null, updated_at = now();
  return true;
end $_$;


ALTER FUNCTION "public"."set_pin"("p_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."student_may_lease"("p_student" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
      from public.users u
      join public.student_profiles sp on sp.user_id = u.id
     where u.id = p_student
       and u.role::text = 'student'
       and u.status::text = 'verified'
       and sp.osas_verified_at is not null
       and not exists (
         select 1 from public.account_standing s
          where s.user_id = u.id and 'apply' = any(s.restrictions)
       )
  );
$$;


ALTER FUNCTION "public"."student_may_lease"("p_student" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_student_review"("p_lease_id" "uuid", "p_accommodation_id" "uuid", "p_landlord_id" "uuid", "p_acc_rating" integer, "p_acc_comment" "text", "p_manager_rating" integer, "p_manager_comment" "text") RETURNS "void"
    LANGUAGE "sql"
    SET "search_path" TO 'public'
    AS $$
  with acc as (
    insert into public.accommodation_reviews (lease_id, student_id, accommodation_id, rating, comment)
    values (p_lease_id, auth.uid(), p_accommodation_id, p_acc_rating, nullif(btrim(coalesce(p_acc_comment, '')), ''))
    returning 1
  )
  insert into public.landlord_reviews (lease_id, student_id, landlord_id, rating, comment)
  select p_lease_id, auth.uid(), p_landlord_id, p_manager_rating,
         nullif(btrim(coalesce(p_manager_comment, '')), '')
    from acc;
$$;


ALTER FUNCTION "public"."submit_student_review"("p_lease_id" "uuid", "p_accommodation_id" "uuid", "p_landlord_id" "uuid", "p_acc_rating" integer, "p_acc_comment" "text", "p_manager_rating" integer, "p_manager_comment" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sweep_expired_accreditations"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  n int;
begin
  update public.accommodations a
  set status = 'expired'
  where a.status = 'accredited'
    and a.accreditation_expires_at is not null
    and a.accreditation_expires_at < now();
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      'Accreditation term ended',
      n || ' accommodation(s) reached the end of their accreditation term and are no longer listed.',
      'verification', '/verifications');
  end if;
end $$;


ALTER FUNCTION "public"."sweep_expired_accreditations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sweep_expired_permits"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."sweep_expired_permits"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_room_occupancy"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.recompute_room_occupancy(new.room_id);
  if tg_op = 'UPDATE' and old.room_id is distinct from new.room_id then
    perform public.recompute_room_occupancy(old.room_id);
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."sync_room_occupancy"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_lease_closed_clears_inquiry"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  update public.conversations c
     set inquiry_room_id = null,
         invited_room_id = null,
         invited_at = null
   where (c.user_a_id = NEW.student_id and c.user_b_id = NEW.landlord_id)
      or (c.user_b_id = NEW.student_id and c.user_a_id = NEW.landlord_id);
  return NEW;
end $$;


ALTER FUNCTION "public"."tg_lease_closed_clears_inquiry"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_lease_guard_student_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
end $$;


ALTER FUNCTION "public"."tg_lease_guard_student_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_message_after_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  update conversations c
     set last_message   = coalesce(trim(new.body), ''),
         last_sender_id = new.sender_id,
         last_time      = new.sent_at,
         unread_a = case when c.user_a_id <> new.sender_id then c.unread_a + 1 else c.unread_a end,
         unread_b = case when c.user_b_id <> new.sender_id then c.unread_b + 1 else c.unread_b end
   where c.id = new.conversation_id;
  return new;
end;
$$;


ALTER FUNCTION "public"."tg_message_after_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_notification_attribution"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  sender_name text;
begin
  -- Addressed to yourself, or written by OSAS: nothing to attribute.
  if new.user_id = auth.uid() or public.is_admin(auth.uid()) then
    return new;
  end if;

  -- Service-role and trigger-driven writes have no auth.uid() at all; those are
  -- the backend's own fan-outs and are equally not somebody's peer.
  if auth.uid() is null then
    return new;
  end if;

  select u.full_name into sender_name from public.users u where u.id = auth.uid();
  new.source := coalesce(nullif(trim(sender_name), ''), 'Another user');

  -- The types a conversation peer has any business sending. Anything else --
  -- 'verification', 'policy', 'announcement', 'system' -- is OSAS's voice, so it
  -- is demoted rather than rejected: a refused insert would fail the message
  -- send that carried it.
  if new.type is null or new.type not in ('message', 'application', 'lease', 'leave', 'payment', 'concern', 'review') then
    new.type := 'message';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."tg_notification_attribution"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_payment_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."tg_payment_guard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_permit_needs_review"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform set_config('app.permit_review', 'true', true);
  update public.accommodations set status = 'pending'
  where id = new.accommodation_id
    and status in ('accredited', 'expired', 'needs_revision', 'rejected');
  perform set_config('app.permit_review', 'false', true);
  return new;
end $$;


ALTER FUNCTION "public"."tg_permit_needs_review"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_revoke_on_unverify"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
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

  if new.status = 'verified' and new.status is distinct from old.status
     and new.role = 'student' then
    update public.student_profiles
       set osas_verified_at = coalesce(osas_verified_at, now())
     where user_id = new.id;
  end if;

  return new;
end $$;


ALTER FUNCTION "public"."tg_revoke_on_unverify"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ticket_touch"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.updated_at = now();
  if new.status = 'resolved' and old.status is distinct from 'resolved' then
    new.resolved_at = now();
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."ticket_touch"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_lease_leave"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.status = 'leave_requested'
     and old.status is distinct from 'leave_requested' then
    perform public.notify_admins(
      'Lease leave request',
      'A student requested to leave their lease early.',
      'lease',
      '/room-hub?room=' || new.room_id::text
    );
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_lease_leave"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_new_accommodation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.status = 'pending' then
    perform public.notify_admins(
      'New accommodation for accreditation',
      coalesce(new.name, 'An accommodation') || ' was submitted for accreditation.',
      'accommodation',
      '/verifications?focus=verification:' || new.id::text
    );
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_new_accommodation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_new_landlord"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."trg_new_landlord"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_new_ticket"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.status = 'open' then
    perform public.notify_admins(
      case when new.priority = 'urgent' or new.category = 'security'
           then 'Urgent: ' || coalesce(new.category, 'support') || ' ticket'
           else 'New support ticket' end,
      coalesce(new.subject, 'A ticket') || ' was reported (' || coalesce(new.category, 'other') || ').',
      'ticket',
      '/support-tickets?focus=ticket:' || new.id::text
    );
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_new_ticket"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_new_verification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."trg_new_verification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_payment_flag"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.status in ('overdue', 'pending_verification') then
    perform public.notify_admins(
      case when new.status = 'overdue'
           then 'Payment overdue' else 'Payment awaiting verification' end,
      'A payment of ₱' || new.amount || ' (' || new.month::text || ') is '
        || case when new.status = 'overdue'
                then 'overdue.' else 'pending verification.' end,
      'payment',
      '/room-hub?room=' || coalesce((select room_id::text from public.leases where id = new.lease_id), '')
    );
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_payment_flag"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_ticket_message_notify"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."trg_ticket_message_notify"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_accommodation_facility_room"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.room_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.rooms
    WHERE id = NEW.room_id
      AND accommodation_id = NEW.accommodation_id
  ) THEN
    RAISE EXCEPTION 'Private facility room must belong to its accommodation';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_accommodation_facility_room"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_pin"("p_pin" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return public.pin_attempt(p_pin);
end $$;


ALTER FUNCTION "public"."verify_pin"("p_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_student_qr"("p_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."verify_student_qr"("p_code" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."accommodation_amenities" (
    "accommodation_id" "uuid" NOT NULL,
    "amenity" "public"."amenity" NOT NULL,
    CONSTRAINT "accommodation_amenities_utilities_only" CHECK ((("amenity")::"text" = ANY (ARRAY['wifi'::"text", 'water'::"text", 'electric'::"text", 'cctv'::"text"])))
);


ALTER TABLE "public"."accommodation_amenities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "accommodation_id" "uuid" NOT NULL,
    "doc_type" "text" NOT NULL,
    "file_url" "text" NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    "issued_at" "date",
    "expires_at" "date",
    "uploaded_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accommodation_documents_doc_type_check" CHECK (("doc_type" = ANY (ARRAY['sanitary_permit'::"text", 'fire_safety'::"text", 'business_permit'::"text", 'building_permit'::"text"]))),
    CONSTRAINT "accommodation_documents_version_check" CHECK (("version" >= 1))
);


ALTER TABLE "public"."accommodation_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_facilities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "accommodation_id" "uuid" NOT NULL,
    "room_id" "uuid",
    "facility_type" "text" NOT NULL,
    "access_scope" "text" NOT NULL,
    "label" "text",
    "description" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "floor" integer,
    "status" "text" DEFAULT 'available'::"text" NOT NULL,
    CONSTRAINT "accommodation_facilities_scope_check" CHECK (("access_scope" = ANY (ARRAY['shared'::"text", 'private'::"text"]))),
    CONSTRAINT "accommodation_facilities_scope_room_check" CHECK (((("access_scope" = 'shared'::"text") AND ("room_id" IS NULL)) OR (("access_scope" = 'private'::"text") AND ("room_id" IS NOT NULL)))),
    CONSTRAINT "accommodation_facilities_status_check" CHECK (("status" = ANY (ARRAY['available'::"text", 'under_repair'::"text"]))),
    CONSTRAINT "accommodation_facilities_type_check" CHECK (("facility_type" = ANY (ARRAY['bathroom'::"text", 'kitchen'::"text", 'laundry'::"text", 'balcony'::"text", 'common_area'::"text", 'study_area'::"text", 'parking'::"text", 'aircon'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."accommodation_facilities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_facility_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "facility_id" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."accommodation_facility_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_facility_rooms" (
    "facility_id" "uuid" NOT NULL,
    "room_id" "uuid" NOT NULL
);


ALTER TABLE "public"."accommodation_facility_rooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_floors" (
    "accommodation_id" "uuid" NOT NULL,
    "floor_number" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."accommodation_floors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "accommodation_id" "uuid" NOT NULL,
    "url" character varying NOT NULL,
    "sort_order" integer
);


ALTER TABLE "public"."accommodation_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_policies" (
    "accommodation_id" "uuid" NOT NULL,
    "advance_months" integer,
    "deposit_months" integer,
    "min_stay" integer,
    "contract_type" character varying,
    "quiet_hours" character varying,
    "visitor_policy" character varying,
    "curfew_time" character varying,
    "cooking" boolean,
    "laundry" boolean,
    "pets" boolean,
    "house_rules_json" "jsonb"
);


ALTER TABLE "public"."accommodation_policies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lease_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "accommodation_id" "uuid" NOT NULL,
    "rating" integer NOT NULL,
    "comment" "text",
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accommodation_reviews_rating_range" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."accommodation_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "landlord_id" "uuid" NOT NULL,
    "name" character varying NOT NULL,
    "accommodation_type" character varying,
    "room_type" "public"."room_type",
    "address" character varying,
    "barangay" character varying,
    "city" character varying,
    "lat" numeric,
    "lng" numeric,
    "total_floors" integer,
    "total_rooms" integer,
    "capacity" integer,
    "description" "text",
    "status" "public"."accommodation_status" NOT NULL,
    "rating_avg" numeric,
    "reviews_count" integer,
    "business_name" "text",
    "accreditation_status" character varying,
    "accredited_at" timestamp with time zone,
    "accreditation_expires_at" timestamp with time zone,
    "gender_policy" "text",
    "reviewing_by" "uuid",
    "reviewing_at" timestamp with time zone,
    "hidden_from_listings" boolean DEFAULT false NOT NULL,
    CONSTRAINT "accommodations_accommodation_type_check" CHECK ((("accommodation_type")::"text" = ANY ((ARRAY['boarding_house'::character varying, 'residence'::character varying, 'dormitory'::character varying])::"text"[]))),
    CONSTRAINT "accommodations_gender_policy_check" CHECK (("gender_policy" = ANY (ARRAY['male'::"text", 'female'::"text", 'co_ed'::"text"])))
);


ALTER TABLE "public"."accommodations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."accommodations"."reviewing_by" IS 'Admin who currently has this accreditation request open. Null when nobody does.';



COMMENT ON COLUMN "public"."accommodations"."reviewing_at" IS 'When the current review claim was taken. Used to age out an abandoned lock.';



CREATE TABLE IF NOT EXISTS "public"."account_notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "author_id" "uuid" DEFAULT "auth"."uid"(),
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "account_notes_body_size" CHECK ((("length"("btrim"("body")) >= 1) AND ("length"("btrim"("body")) <= 4000)))
);


ALTER TABLE "public"."account_notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."account_standing" (
    "user_id" "uuid" NOT NULL,
    "reason" "text",
    "suspended_until" timestamp with time zone,
    "restrictions" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "updated_by" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "account_standing_known_restrictions" CHECK (("restrictions" <@ ARRAY['apply'::"text", 'listings'::"text"]))
);


ALTER TABLE "public"."account_standing" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_profiles" (
    "user_id" "uuid" NOT NULL,
    "office" "public"."office" NOT NULL,
    "position" character varying,
    "employee_id" character varying
);


ALTER TABLE "public"."admin_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "author_id" "uuid" NOT NULL,
    "title" character varying NOT NULL,
    "body" "text" NOT NULL,
    "audience" "public"."audience_type" DEFAULT 'all'::"public"."audience_type" NOT NULL,
    "published_at" timestamp without time zone,
    "expires_at" timestamp without time zone,
    "archived" boolean DEFAULT false NOT NULL,
    "summary" "text",
    "accommodation_id" "uuid",
    "notified_at" timestamp with time zone,
    "event_at" timestamp with time zone,
    "event_end" timestamp with time zone,
    "deadline_at" timestamp with time zone,
    "location" "text",
    "image_url" "text"
);


ALTER TABLE "public"."announcements" OWNER TO "postgres";


COMMENT ON COLUMN "public"."announcements"."event_at" IS 'What the notice is about, not when it is shown: the start of the thing happening. published_at/expires_at remain display windows.';



COMMENT ON COLUMN "public"."announcements"."deadline_at" IS 'When the reader has to have acted by.';



CREATE TABLE IF NOT EXISTS "public"."app_release" (
    "id" integer DEFAULT 1 NOT NULL,
    "latest_version_code" integer NOT NULL,
    "latest_version_name" "text" NOT NULL,
    "min_supported_version_code" integer DEFAULT 1 NOT NULL,
    "apk_url" "text" NOT NULL,
    "release_notes" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "app_release_id_check" CHECK (("id" = 1))
);


ALTER TABLE "public"."app_release" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "actor_id" "uuid",
    "action" character varying NOT NULL,
    "entity_type" character varying NOT NULL,
    "entity_id" character varying NOT NULL,
    "before_json" "jsonb",
    "after_json" "jsonb",
    "ip_address" character varying,
    "user_agent" character varying,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."boarding_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "accommodation_id" "uuid" NOT NULL,
    "accommodation_name" character varying,
    "room_type" character varying,
    "period_start" "date" NOT NULL,
    "period_end" "date" NOT NULL,
    "end_reason" "text"
);


ALTER TABLE "public"."boarding_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."concerns" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lease_id" "uuid" NOT NULL,
    "category" "text" NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "reported_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resolved_at" timestamp with time zone,
    "acknowledged_at" timestamp with time zone,
    "manager_response" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "in_progress_at" timestamp with time zone,
    "photo_url" "text"
);


ALTER TABLE "public"."concerns" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_a_id" "uuid" NOT NULL,
    "user_b_id" "uuid" NOT NULL,
    "last_message" "text",
    "last_time" timestamp without time zone,
    "unread_a" integer DEFAULT 0 NOT NULL,
    "unread_b" integer DEFAULT 0 NOT NULL,
    "inquiry_room_id" "uuid",
    "invited_room_id" "uuid",
    "invited_at" timestamp with time zone,
    "last_sender_id" "uuid"
);

ALTER TABLE ONLY "public"."conversations" REPLICA IDENTITY FULL;


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."landlord_profiles" (
    "user_id" "uuid" NOT NULL,
    "government_id_url" character varying,
    "response_rate" integer,
    "avg_response_minutes" integer,
    "extracted_name" "text",
    "extracted_gov_id" "text"
);


ALTER TABLE "public"."landlord_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."landlord_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lease_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "landlord_id" "uuid" NOT NULL,
    "rating" integer NOT NULL,
    "comment" "text",
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "landlord_reviews_rating_range" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."landlord_reviews" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."latest_accommodation_documents" WITH ("security_invoker"='true') AS
 SELECT DISTINCT ON ("accommodation_id", "doc_type") "accommodation_id",
    "doc_type",
    "version",
    "file_url",
    "issued_at",
    "expires_at",
    "uploaded_at"
   FROM "public"."accommodation_documents" "pd"
  ORDER BY "accommodation_id", "doc_type", "version" DESC, "uploaded_at" DESC;


ALTER VIEW "public"."latest_accommodation_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."leases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "room_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "landlord_id" "uuid" NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "monthly_rent" numeric,
    "advance_paid" numeric,
    "deposit_paid" numeric,
    "status" "public"."lease_status" DEFAULT 'active'::"public"."lease_status" NOT NULL,
    "leave_requested_at" timestamp without time zone,
    "ended_reason" "text",
    "decision_reason" "text"
);


ALTER TABLE "public"."leases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "status" "public"."msg_status" DEFAULT 'sent'::"public"."msg_status" NOT NULL,
    "sent_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "attachment_url" "text"
);

ALTER TABLE ONLY "public"."messages" REPLICA IDENTITY FULL;


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" character varying NOT NULL,
    "title" character varying NOT NULL,
    "body" character varying NOT NULL,
    "link_url" character varying,
    "read_at" timestamp without time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ref_id" "uuid",
    "source" "text"
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lease_id" "uuid" NOT NULL,
    "month" "date" NOT NULL,
    "description" "text",
    "amount" numeric NOT NULL,
    "status" "public"."payment_status" DEFAULT 'due'::"public"."payment_status" NOT NULL,
    "method" "public"."payment_method" NOT NULL,
    "txn_reference" character varying,
    "proof_url" character varying,
    "paid_at" timestamp without time zone,
    "verified_by" "uuid",
    "rejection_reason" "text",
    CONSTRAINT "payments_amount_positive" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."policies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" character varying NOT NULL,
    "body" "text" NOT NULL,
    "effective_date" "date" NOT NULL,
    "version" character varying,
    "created_by" "uuid" NOT NULL,
    "archived" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."policies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."qr_scans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "scanner_id" "uuid" NOT NULL,
    "student_id" "uuid",
    "method" "text" DEFAULT 'qr'::"text" NOT NULL,
    "result" "text" NOT NULL,
    "scanned_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."qr_scans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."report_settings" (
    "id" boolean DEFAULT true NOT NULL,
    "noted_by_name" "text",
    "noted_by_position" "text",
    "approved_by_name" "text",
    "approved_by_position" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_by" "uuid",
    CONSTRAINT "report_settings_id_check" CHECK ("id")
);


ALTER TABLE "public"."report_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tenant_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lease_id" "uuid" NOT NULL,
    "landlord_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "rating" integer NOT NULL,
    "comment" "text",
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "tenant_reviews_rating_range" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."tenant_reviews" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."review_admin_feed" WITH ("security_invoker"='true') AS
 SELECT "tr"."id",
    'tenant'::"text" AS "kind",
    "tr"."student_id" AS "subject_id",
    "tr"."landlord_id" AS "author_id",
    "tr"."rating",
    "tr"."comment",
    "tr"."created_at",
    "tr"."lease_id",
    NULL::"uuid" AS "accommodation_id"
   FROM "public"."tenant_reviews" "tr"
UNION ALL
 SELECT "amr"."id",
    'manager'::"text" AS "kind",
    "amr"."landlord_id" AS "subject_id",
    "amr"."student_id" AS "author_id",
    "amr"."rating",
    "amr"."comment",
    "amr"."created_at",
    "amr"."lease_id",
    NULL::"uuid" AS "accommodation_id"
   FROM "public"."landlord_reviews" "amr"
UNION ALL
 SELECT "ar"."id",
    'accommodation'::"text" AS "kind",
    "ar"."accommodation_id" AS "subject_id",
    "ar"."student_id" AS "author_id",
    "ar"."rating",
    "ar"."comment",
    "ar"."created_at",
    "ar"."lease_id",
    "ar"."accommodation_id"
   FROM "public"."accommodation_reviews" "ar";


ALTER VIEW "public"."review_admin_feed" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."review_inbox" WITH ("security_invoker"='true') AS
 SELECT "r"."id",
    'manager'::"text" AS "kind",
    "r"."rating",
    "r"."comment",
    "r"."created_at",
    NULL::"uuid" AS "accommodation_id",
    NULL::"text" AS "accommodation_name"
   FROM "public"."landlord_reviews" "r"
  WHERE ("r"."landlord_id" = "auth"."uid"())
UNION ALL
 SELECT "r"."id",
    'accommodation'::"text" AS "kind",
    "r"."rating",
    "r"."comment",
    "r"."created_at",
    "a"."id" AS "accommodation_id",
    "a"."name" AS "accommodation_name"
   FROM ("public"."accommodation_reviews" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE ("a"."landlord_id" = "auth"."uid"())
UNION ALL
 SELECT "r"."id",
    'tenant'::"text" AS "kind",
    "r"."rating",
    "r"."comment",
    "r"."created_at",
    NULL::"uuid" AS "accommodation_id",
    NULL::"text" AS "accommodation_name"
   FROM "public"."tenant_reviews" "r"
  WHERE ("r"."student_id" = "auth"."uid"());


ALTER VIEW "public"."review_inbox" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."review_written_leases" WITH ("security_invoker"='true') AS
 SELECT "r"."lease_id",
    'accommodation'::"text" AS "kind",
    "r"."rating",
    "r"."comment"
   FROM "public"."accommodation_reviews" "r"
  WHERE ("r"."student_id" = "auth"."uid"())
UNION ALL
 SELECT "r"."lease_id",
    'manager'::"text" AS "kind",
    "r"."rating",
    "r"."comment"
   FROM "public"."landlord_reviews" "r"
  WHERE ("r"."student_id" = "auth"."uid"())
UNION ALL
 SELECT "r"."lease_id",
    'tenant'::"text" AS "kind",
    "r"."rating",
    "r"."comment"
   FROM "public"."tenant_reviews" "r"
  WHERE ("r"."landlord_id" = "auth"."uid"());


ALTER VIEW "public"."review_written_leases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."room_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "room_id" "uuid" NOT NULL,
    "url" character varying NOT NULL,
    "sort_order" integer
);


ALTER TABLE "public"."room_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "accommodation_id" "uuid" NOT NULL,
    "label" character varying,
    "room_number" character varying,
    "floor" integer,
    "capacity" integer,
    "current_pax" integer,
    "monthly_rent" numeric,
    "status" "public"."room_status" NOT NULL,
    "room_type" "text",
    "custom_room_type" "text",
    "advance_months" integer,
    "deposit_months" integer,
    "rent_basis" "text" DEFAULT 'room'::"text" NOT NULL,
    CONSTRAINT "rooms_custom_room_type_check" CHECK (((("room_type" <> 'custom'::"text") AND ("custom_room_type" IS NULL)) OR (("room_type" = 'custom'::"text") AND (NULLIF(TRIM(BOTH FROM "custom_room_type"), ''::"text") IS NOT NULL)) OR ("room_type" IS NULL))),
    CONSTRAINT "rooms_rent_basis_check" CHECK (("rent_basis" = ANY (ARRAY['room'::"text", 'person'::"text"]))),
    CONSTRAINT "rooms_room_type_check" CHECK ((("room_type" IS NULL) OR ("room_type" = ANY (ARRAY['solo'::"text", 'duo'::"text", 'triple'::"text", 'bedspace'::"text", 'studio'::"text", 'custom'::"text"]))))
);


ALTER TABLE "public"."rooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."student_profiles" (
    "user_id" "uuid" NOT NULL,
    "student_id" character varying,
    "program" character varying,
    "year_level" integer,
    "college" character varying,
    "school_id_url" character varying,
    "assessment_of_fees_url" character varying,
    "qr_code_token" character varying DEFAULT ("gen_random_uuid"())::"text",
    "osas_verified_at" timestamp without time zone,
    "emergency_contact_json" "jsonb",
    "extracted_name" "text",
    "extracted_school_id" "text",
    "qr_token_rotated_at" timestamp with time zone,
    "qr_token_expires_at" timestamp with time zone
);


ALTER TABLE "public"."student_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ticket_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ticket_id" "uuid" NOT NULL,
    "author_id" "uuid",
    "author_role" "text" DEFAULT 'student'::"text" NOT NULL,
    "body" "text" NOT NULL,
    "is_internal" boolean DEFAULT false NOT NULL,
    "attachment_urls" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ticket_messages_author_role_check" CHECK (("author_role" = ANY (ARRAY['student'::"text", 'agent'::"text"])))
);


ALTER TABLE "public"."ticket_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tickets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lease_id" "uuid",
    "subject" "text",
    "description" "text",
    "category" "text",
    "photo_urls" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "priority" "text" DEFAULT 'medium'::"text" NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "assignee_id" "uuid",
    "reported_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resolved_at" timestamp with time zone,
    "student_id" "uuid",
    "landlord_id" "uuid",
    "accommodation_id" "uuid",
    "reporter_name" "text",
    CONSTRAINT "tickets_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "tickets_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'in_progress'::"text", 'resolved'::"text", 'closed'::"text", 'pending'::"text", 'assigned'::"text", 'under_review'::"text"])))
);


ALTER TABLE "public"."tickets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_pins" (
    "user_id" "uuid" NOT NULL,
    "pin_hash" "text" NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "locked_until" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_pins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "email" character varying NOT NULL,
    "phone" character varying NOT NULL,
    "role" "public"."user_role" NOT NULL,
    "status" "public"."user_status" DEFAULT 'pending'::"public"."user_status" NOT NULL,
    "full_name" character varying NOT NULL,
    "initials" character varying(2) NOT NULL,
    "avatar_color" character varying,
    "sex" character(1),
    "email_verified_at" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp without time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "last_login_at" timestamp without time zone,
    "is_superadmin" boolean DEFAULT false NOT NULL,
    "onboarding_complete" boolean DEFAULT false NOT NULL,
    "notification_prefs" "jsonb" DEFAULT '{"push": true, "email": true}'::"jsonb" NOT NULL,
    "avatar_url" "text",
    "registered_at" timestamp with time zone,
    "terms_accepted_at" timestamp with time zone,
    "privacy_accepted_at" timestamp with time zone,
    "date_of_birth" "date",
    "reviewing_by" "uuid",
    "reviewing_at" timestamp with time zone,
    "closed_at" timestamp with time zone,
    CONSTRAINT "users_date_of_birth_plausible" CHECK ((("date_of_birth" IS NULL) OR (("date_of_birth" > '1900-01-01'::"date") AND ("date_of_birth" <= CURRENT_DATE))))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."registered_at" IS 'When the owner completed registration. Null means an account exists (e.g. created by an OAuth sign-in) but onboarding was never finished; the app routes these to /register/role.';



COMMENT ON COLUMN "public"."users"."date_of_birth" IS 'Self-declared birth date, collected at registration. Nullable: accounts created before this column exists have none.';



COMMENT ON COLUMN "public"."users"."reviewing_by" IS 'Admin who currently has this verification request open. Null when nobody does.';



COMMENT ON COLUMN "public"."users"."reviewing_at" IS 'When the current review claim was taken. Used to age out an abandoned lock.';



CREATE TABLE IF NOT EXISTS "public"."verification_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "doc_type" character varying,
    "filename" character varying,
    "file_url" character varying,
    "uploaded_at" timestamp without time zone DEFAULT "now"(),
    "verified_at" timestamp without time zone,
    "verified_by" "uuid",
    "status" "public"."doc_status" DEFAULT 'pending'::"public"."doc_status" NOT NULL,
    "expires_at" "date"
);


ALTER TABLE "public"."verification_documents" OWNER TO "postgres";


COMMENT ON COLUMN "public"."verification_documents"."expires_at" IS 'Expiry of the document itself, as entered by the uploader. Null for document types that do not expire (school_id, assessment_of_fees) and for rows predating the column.';



CREATE TABLE IF NOT EXISTS "public"."verification_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "type" "text",
    "status" "text" NOT NULL,
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rejection_reasons" "text"[],
    "decision_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "verification_requests_entity_type_check" CHECK (("entity_type" = ANY (ARRAY['user'::"text", 'accommodation'::"text"]))),
    CONSTRAINT "verification_requests_status_check" CHECK (("status" = ANY (ARRAY['approved'::"text", 'rejected'::"text", 'resubmission_requested'::"text"])))
);


ALTER TABLE "public"."verification_requests" OWNER TO "postgres";


ALTER TABLE ONLY "public"."accommodation_amenities"
    ADD CONSTRAINT "accommodation_amenities_pkey" PRIMARY KEY ("accommodation_id", "amenity");



ALTER TABLE ONLY "public"."accommodation_documents"
    ADD CONSTRAINT "accommodation_documents_accommodation_id_doc_type_version_key" UNIQUE ("accommodation_id", "doc_type", "version");



ALTER TABLE ONLY "public"."accommodation_documents"
    ADD CONSTRAINT "accommodation_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodation_facilities"
    ADD CONSTRAINT "accommodation_facilities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodation_facility_images"
    ADD CONSTRAINT "accommodation_facility_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodation_facility_rooms"
    ADD CONSTRAINT "accommodation_facility_rooms_pkey" PRIMARY KEY ("facility_id", "room_id");



ALTER TABLE ONLY "public"."accommodation_floors"
    ADD CONSTRAINT "accommodation_floors_pkey" PRIMARY KEY ("accommodation_id", "floor_number");



ALTER TABLE ONLY "public"."accommodation_images"
    ADD CONSTRAINT "accommodation_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodation_policies"
    ADD CONSTRAINT "accommodation_policies_pkey" PRIMARY KEY ("accommodation_id");



ALTER TABLE ONLY "public"."accommodation_reviews"
    ADD CONSTRAINT "accommodation_reviews_lease_id_key" UNIQUE ("lease_id");



ALTER TABLE ONLY "public"."accommodation_reviews"
    ADD CONSTRAINT "accommodation_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodations"
    ADD CONSTRAINT "accommodations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."account_notes"
    ADD CONSTRAINT "account_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."account_standing"
    ADD CONSTRAINT "account_standing_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_employee_id_key" UNIQUE ("employee_id");



ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_release"
    ADD CONSTRAINT "app_release_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."boarding_history"
    ADD CONSTRAINT "boarding_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."concerns"
    ADD CONSTRAINT "concerns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."landlord_profiles"
    ADD CONSTRAINT "landlord_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."landlord_reviews"
    ADD CONSTRAINT "landlord_reviews_lease_id_key" UNIQUE ("lease_id");



ALTER TABLE ONLY "public"."landlord_reviews"
    ADD CONSTRAINT "landlord_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."leases"
    ADD CONSTRAINT "leases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."policies"
    ADD CONSTRAINT "policies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."qr_scans"
    ADD CONSTRAINT "qr_scans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."report_settings"
    ADD CONSTRAINT "report_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."room_images"
    ADD CONSTRAINT "room_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."student_profiles"
    ADD CONSTRAINT "student_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."student_profiles"
    ADD CONSTRAINT "student_profiles_qr_code_token_key" UNIQUE ("qr_code_token");



ALTER TABLE ONLY "public"."student_profiles"
    ADD CONSTRAINT "student_profiles_student_id_key" UNIQUE ("student_id");



ALTER TABLE ONLY "public"."tenant_reviews"
    ADD CONSTRAINT "tenant_reviews_lease_id_key" UNIQUE ("lease_id");



ALTER TABLE ONLY "public"."tenant_reviews"
    ADD CONSTRAINT "tenant_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ticket_messages"
    ADD CONSTRAINT "ticket_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tickets"
    ADD CONSTRAINT "tickets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_pins"
    ADD CONSTRAINT "user_pins_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verification_requests"
    ADD CONSTRAINT "verification_requests_pkey" PRIMARY KEY ("id");



CREATE INDEX "accommodation_documents_accommodation_id_idx" ON "public"."accommodation_documents" USING "btree" ("accommodation_id");



CREATE INDEX "accommodation_documents_doc_type_idx" ON "public"."accommodation_documents" USING "btree" ("doc_type");



CREATE INDEX "accommodation_documents_uploaded_at_idx" ON "public"."accommodation_documents" USING "btree" ("uploaded_at");



CREATE INDEX "account_notes_user_created" ON "public"."account_notes" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "announcements_accommodation_idx" ON "public"."announcements" USING "btree" ("accommodation_id") WHERE ("accommodation_id" IS NOT NULL);



CREATE INDEX "concerns_lease_id_idx" ON "public"."concerns" USING "btree" ("lease_id");



CREATE UNIQUE INDEX "conversations_unique_pair" ON "public"."conversations" USING "btree" (LEAST("user_a_id", "user_b_id"), GREATEST("user_a_id", "user_b_id"));



CREATE INDEX "idx_accommodation_facilities_accommodation_id" ON "public"."accommodation_facilities" USING "btree" ("accommodation_id");



CREATE INDEX "idx_accommodation_facilities_room_id" ON "public"."accommodation_facilities" USING "btree" ("room_id");



CREATE INDEX "idx_accommodation_facility_images_facility_id" ON "public"."accommodation_facility_images" USING "btree" ("facility_id");



CREATE INDEX "idx_accommodation_facility_rooms_room_id" ON "public"."accommodation_facility_rooms" USING "btree" ("room_id");



CREATE INDEX "idx_accommodation_images_accommodation_id" ON "public"."accommodation_images" USING "btree" ("accommodation_id");



CREATE INDEX "idx_accommodation_reviews_accommodation_id" ON "public"."accommodation_reviews" USING "btree" ("accommodation_id");



CREATE INDEX "idx_accommodation_reviews_student_id" ON "public"."accommodation_reviews" USING "btree" ("student_id");



CREATE INDEX "idx_accommodations_landlord_id" ON "public"."accommodations" USING "btree" ("landlord_id");



CREATE INDEX "idx_announcements_author_id" ON "public"."announcements" USING "btree" ("author_id");



CREATE INDEX "idx_audit_logs_actor_id" ON "public"."audit_logs" USING "btree" ("actor_id");



CREATE INDEX "idx_boarding_history_accommodation_id" ON "public"."boarding_history" USING "btree" ("accommodation_id");



CREATE INDEX "idx_boarding_history_student_id" ON "public"."boarding_history" USING "btree" ("student_id");



CREATE INDEX "idx_conversations_inquiry_room_id" ON "public"."conversations" USING "btree" ("inquiry_room_id");



CREATE INDEX "idx_conversations_invited_room_id" ON "public"."conversations" USING "btree" ("invited_room_id");



CREATE INDEX "idx_conversations_last_sender_id" ON "public"."conversations" USING "btree" ("last_sender_id");



CREATE INDEX "idx_conversations_user_a_id" ON "public"."conversations" USING "btree" ("user_a_id");



CREATE INDEX "idx_conversations_user_b_id" ON "public"."conversations" USING "btree" ("user_b_id");



CREATE INDEX "idx_landlord_reviews_landlord_id" ON "public"."landlord_reviews" USING "btree" ("landlord_id");



CREATE INDEX "idx_landlord_reviews_student_id" ON "public"."landlord_reviews" USING "btree" ("student_id");



CREATE INDEX "idx_leases_landlord_id" ON "public"."leases" USING "btree" ("landlord_id");



CREATE INDEX "idx_leases_room_id" ON "public"."leases" USING "btree" ("room_id");



CREATE INDEX "idx_messages_conversation_id" ON "public"."messages" USING "btree" ("conversation_id");



CREATE INDEX "idx_messages_sender_id" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "idx_notifications_user_id" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "idx_payments_lease_id" ON "public"."payments" USING "btree" ("lease_id");



CREATE INDEX "idx_payments_verified_by" ON "public"."payments" USING "btree" ("verified_by");



CREATE INDEX "idx_policies_created_by" ON "public"."policies" USING "btree" ("created_by");



CREATE INDEX "idx_room_images_room_id" ON "public"."room_images" USING "btree" ("room_id");



CREATE INDEX "idx_rooms_accommodation_id" ON "public"."rooms" USING "btree" ("accommodation_id");



CREATE INDEX "idx_tenant_reviews_landlord_id" ON "public"."tenant_reviews" USING "btree" ("landlord_id");



CREATE INDEX "idx_tenant_reviews_student_id" ON "public"."tenant_reviews" USING "btree" ("student_id");



CREATE INDEX "idx_ticket_messages_author_id" ON "public"."ticket_messages" USING "btree" ("author_id");



CREATE INDEX "idx_tickets_accommodation_id" ON "public"."tickets" USING "btree" ("accommodation_id");



CREATE INDEX "idx_tickets_assignee_id" ON "public"."tickets" USING "btree" ("assignee_id");



CREATE INDEX "idx_tickets_landlord_id" ON "public"."tickets" USING "btree" ("landlord_id");



CREATE INDEX "idx_tickets_lease_id" ON "public"."tickets" USING "btree" ("lease_id");



CREATE INDEX "idx_tickets_student_id" ON "public"."tickets" USING "btree" ("student_id");



CREATE INDEX "idx_verification_documents_user_id" ON "public"."verification_documents" USING "btree" ("user_id");



CREATE INDEX "idx_verification_documents_verified_by" ON "public"."verification_documents" USING "btree" ("verified_by");



CREATE INDEX "idx_verification_requests_reviewed_by" ON "public"."verification_requests" USING "btree" ("reviewed_by");



CREATE UNIQUE INDEX "leases_one_current_per_student" ON "public"."leases" USING "btree" ("student_id") WHERE ("status" = ANY (ARRAY['active'::"public"."lease_status", 'leave_requested'::"public"."lease_status", 'pending'::"public"."lease_status"]));



CREATE INDEX "notifications_ref_idx" ON "public"."notifications" USING "btree" ("ref_id") WHERE ("ref_id" IS NOT NULL);



CREATE INDEX "qr_scans_scanner_idx" ON "public"."qr_scans" USING "btree" ("scanner_id", "scanned_at" DESC);



CREATE INDEX "qr_scans_student_idx" ON "public"."qr_scans" USING "btree" ("student_id", "scanned_at" DESC);



CREATE INDEX "ticket_messages_ticket_idx" ON "public"."ticket_messages" USING "btree" ("ticket_id", "created_at");



CREATE UNIQUE INDEX "verification_documents_user_doc_type_key" ON "public"."verification_documents" USING "btree" ("user_id", "doc_type");



CREATE INDEX "verification_requests_entity_idx" ON "public"."verification_requests" USING "btree" ("entity_type", "entity_id", "reviewed_at" DESC);



CREATE OR REPLACE TRIGGER "accommodation_facilities_validate_room" BEFORE INSERT OR UPDATE ON "public"."accommodation_facilities" FOR EACH ROW EXECUTE FUNCTION "public"."validate_accommodation_facility_room"();



CREATE OR REPLACE TRIGGER "accommodation_facility_rooms_guard" BEFORE INSERT OR UPDATE ON "public"."accommodation_facility_rooms" FOR EACH ROW EXECUTE FUNCTION "public"."guard_facility_room_link"();



CREATE OR REPLACE TRIGGER "accommodation_reviews_refresh_rating" AFTER INSERT OR DELETE OR UPDATE ON "public"."accommodation_reviews" FOR EACH ROW EXECUTE FUNCTION "public"."refresh_accommodation_rating"();



CREATE OR REPLACE TRIGGER "accommodations_guard_hidden_from_listings" BEFORE UPDATE OF "hidden_from_listings" ON "public"."accommodations" FOR EACH ROW EXECUTE FUNCTION "public"."guard_hidden_from_listings"();



CREATE OR REPLACE TRIGGER "leases_guard_student_update" BEFORE UPDATE ON "public"."leases" FOR EACH ROW EXECUTE FUNCTION "public"."tg_lease_guard_student_update"();



CREATE OR REPLACE TRIGGER "messages_after_insert" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."tg_message_after_insert"();



CREATE OR REPLACE TRIGGER "notification_attribution" BEFORE INSERT ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."tg_notification_attribution"();



CREATE OR REPLACE TRIGGER "payment_guard" BEFORE INSERT OR UPDATE ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."tg_payment_guard"();



CREATE OR REPLACE TRIGGER "ticket_touch_trg" BEFORE UPDATE ON "public"."tickets" FOR EACH ROW EXECUTE FUNCTION "public"."ticket_touch"();



CREATE OR REPLACE TRIGGER "trg_audit_accommodation_manager_profiles" AFTER INSERT OR DELETE OR UPDATE ON "public"."landlord_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_accommodations" AFTER INSERT OR DELETE OR UPDATE ON "public"."accommodations" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_account_standing" AFTER INSERT OR DELETE OR UPDATE ON "public"."account_standing" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_admin_profiles" AFTER INSERT OR DELETE OR UPDATE ON "public"."admin_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_announcements" AFTER INSERT OR DELETE OR UPDATE ON "public"."announcements" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_leases" AFTER INSERT OR DELETE OR UPDATE ON "public"."leases" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_payments" AFTER INSERT OR DELETE OR UPDATE ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_policies" AFTER INSERT OR DELETE OR UPDATE ON "public"."policies" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_rooms" AFTER INSERT OR DELETE OR UPDATE ON "public"."rooms" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_student_profiles" AFTER INSERT OR DELETE OR UPDATE ON "public"."student_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_tickets" AFTER INSERT OR DELETE OR UPDATE ON "public"."tickets" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_users" AFTER INSERT OR DELETE OR UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_audit_verification_documents" AFTER INSERT OR DELETE OR UPDATE ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."fn_audit_log_change"();



CREATE OR REPLACE TRIGGER "trg_enforce_room_capacity" BEFORE INSERT OR UPDATE OF "status", "room_id" ON "public"."leases" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_room_capacity"();



CREATE OR REPLACE TRIGGER "trg_lease_closed_clears_inquiry" AFTER UPDATE OF "status" ON "public"."leases" FOR EACH ROW WHEN ((("new"."status" = ANY (ARRAY['ended'::"public"."lease_status", 'terminated'::"public"."lease_status"])) AND ("old"."status" IS DISTINCT FROM "new"."status"))) EXECUTE FUNCTION "public"."tg_lease_closed_clears_inquiry"();



CREATE OR REPLACE TRIGGER "trg_lease_leave" AFTER UPDATE ON "public"."leases" FOR EACH ROW EXECUTE FUNCTION "public"."trg_lease_leave"();



CREATE OR REPLACE TRIGGER "trg_lock_accreditation" BEFORE INSERT OR UPDATE ON "public"."accommodations" FOR EACH ROW EXECUTE FUNCTION "public"."lock_verification_columns"();



CREATE OR REPLACE TRIGGER "trg_lock_doc_review" BEFORE INSERT OR UPDATE ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."lock_verification_columns"();



CREATE OR REPLACE TRIGGER "trg_lock_document_ref" BEFORE INSERT OR UPDATE ON "public"."accommodation_documents" FOR EACH ROW EXECUTE FUNCTION "public"."lock_document_ref"();



CREATE OR REPLACE TRIGGER "trg_lock_document_ref" BEFORE INSERT OR UPDATE ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."lock_document_ref"();



CREATE OR REPLACE TRIGGER "trg_lock_osas" BEFORE INSERT OR UPDATE ON "public"."student_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."lock_verification_columns"();



CREATE OR REPLACE TRIGGER "trg_lock_user_privileges" BEFORE INSERT OR UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."lock_user_privileges"();



CREATE OR REPLACE TRIGGER "trg_new_accommodation" AFTER INSERT ON "public"."accommodations" FOR EACH ROW EXECUTE FUNCTION "public"."trg_new_accommodation"();



CREATE OR REPLACE TRIGGER "trg_new_accommodation_manager" AFTER INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."trg_new_landlord"();



CREATE OR REPLACE TRIGGER "trg_new_ticket" AFTER INSERT ON "public"."tickets" FOR EACH ROW EXECUTE FUNCTION "public"."trg_new_ticket"();



CREATE OR REPLACE TRIGGER "trg_new_verification" AFTER INSERT OR UPDATE ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."trg_new_verification"();



CREATE OR REPLACE TRIGGER "trg_notify_announcement" AFTER INSERT OR UPDATE OF "published_at", "archived" ON "public"."announcements" FOR EACH ROW EXECUTE FUNCTION "public"."notify_announcement"();



CREATE OR REPLACE TRIGGER "trg_notify_policy" AFTER INSERT OR UPDATE OF "effective_date", "archived" ON "public"."policies" FOR EACH ROW EXECUTE FUNCTION "public"."notify_policy"();



CREATE OR REPLACE TRIGGER "trg_payment_flag" AFTER INSERT ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."trg_payment_flag"();



CREATE OR REPLACE TRIGGER "trg_permit_needs_review" AFTER INSERT ON "public"."accommodation_documents" FOR EACH ROW EXECUTE FUNCTION "public"."tg_permit_needs_review"();



CREATE OR REPLACE TRIGGER "trg_revoke_on_unverify" AFTER UPDATE OF "status", "registered_at" ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."tg_revoke_on_unverify"();



CREATE OR REPLACE TRIGGER "trg_superadmin_privileges" BEFORE INSERT OR UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_non_superadmin_escalation"();



CREATE OR REPLACE TRIGGER "trg_sync_room_occupancy" AFTER INSERT OR UPDATE OF "status", "room_id" ON "public"."leases" FOR EACH ROW EXECUTE FUNCTION "public"."sync_room_occupancy"();



CREATE OR REPLACE TRIGGER "trg_ticket_message_notify" AFTER INSERT ON "public"."ticket_messages" FOR EACH ROW EXECUTE FUNCTION "public"."trg_ticket_message_notify"();



ALTER TABLE ONLY "public"."accommodation_amenities"
    ADD CONSTRAINT "accommodation_amenities_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_documents"
    ADD CONSTRAINT "accommodation_documents_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_facilities"
    ADD CONSTRAINT "accommodation_facilities_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_facilities"
    ADD CONSTRAINT "accommodation_facilities_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."rooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_facility_images"
    ADD CONSTRAINT "accommodation_facility_images_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "public"."accommodation_facilities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_facility_rooms"
    ADD CONSTRAINT "accommodation_facility_rooms_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "public"."accommodation_facilities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_facility_rooms"
    ADD CONSTRAINT "accommodation_facility_rooms_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."rooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_floors"
    ADD CONSTRAINT "accommodation_floors_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_images"
    ADD CONSTRAINT "accommodation_images_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_policies"
    ADD CONSTRAINT "accommodation_policies_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_reviews"
    ADD CONSTRAINT "accommodation_reviews_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_reviews"
    ADD CONSTRAINT "accommodation_reviews_lease_id_fkey" FOREIGN KEY ("lease_id") REFERENCES "public"."leases"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_reviews"
    ADD CONSTRAINT "accommodation_reviews_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodations"
    ADD CONSTRAINT "accommodations_landlord_id_fkey" FOREIGN KEY ("landlord_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodations"
    ADD CONSTRAINT "accommodations_reviewing_by_fkey" FOREIGN KEY ("reviewing_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."account_notes"
    ADD CONSTRAINT "account_notes_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."account_notes"
    ADD CONSTRAINT "account_notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."account_standing"
    ADD CONSTRAINT "account_standing_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."account_standing"
    ADD CONSTRAINT "account_standing_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."boarding_history"
    ADD CONSTRAINT "boarding_history_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boarding_history"
    ADD CONSTRAINT "boarding_history_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."concerns"
    ADD CONSTRAINT "concerns_lease_id_fkey" FOREIGN KEY ("lease_id") REFERENCES "public"."leases"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_inquiry_room_id_fkey" FOREIGN KEY ("inquiry_room_id") REFERENCES "public"."rooms"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_invited_room_id_fkey" FOREIGN KEY ("invited_room_id") REFERENCES "public"."rooms"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_last_sender_id_fkey" FOREIGN KEY ("last_sender_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_user_a_id_fkey" FOREIGN KEY ("user_a_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_user_b_id_fkey" FOREIGN KEY ("user_b_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."landlord_profiles"
    ADD CONSTRAINT "landlord_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."landlord_reviews"
    ADD CONSTRAINT "landlord_reviews_landlord_id_fkey" FOREIGN KEY ("landlord_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."landlord_reviews"
    ADD CONSTRAINT "landlord_reviews_lease_id_fkey" FOREIGN KEY ("lease_id") REFERENCES "public"."leases"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."landlord_reviews"
    ADD CONSTRAINT "landlord_reviews_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leases"
    ADD CONSTRAINT "leases_landlord_id_fkey" FOREIGN KEY ("landlord_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leases"
    ADD CONSTRAINT "leases_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."rooms"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."leases"
    ADD CONSTRAINT "leases_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_lease_id_fkey" FOREIGN KEY ("lease_id") REFERENCES "public"."leases"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."policies"
    ADD CONSTRAINT "policies_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_scans"
    ADD CONSTRAINT "qr_scans_scanner_id_fkey" FOREIGN KEY ("scanner_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_scans"
    ADD CONSTRAINT "qr_scans_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."report_settings"
    ADD CONSTRAINT "report_settings_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."room_images"
    ADD CONSTRAINT "room_images_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."rooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."student_profiles"
    ADD CONSTRAINT "student_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenant_reviews"
    ADD CONSTRAINT "tenant_reviews_landlord_id_fkey" FOREIGN KEY ("landlord_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenant_reviews"
    ADD CONSTRAINT "tenant_reviews_lease_id_fkey" FOREIGN KEY ("lease_id") REFERENCES "public"."leases"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenant_reviews"
    ADD CONSTRAINT "tenant_reviews_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ticket_messages"
    ADD CONSTRAINT "ticket_messages_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ticket_messages"
    ADD CONSTRAINT "ticket_messages_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "public"."tickets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tickets"
    ADD CONSTRAINT "tickets_accommodation_id_fkey" FOREIGN KEY ("accommodation_id") REFERENCES "public"."accommodations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tickets"
    ADD CONSTRAINT "tickets_assignee_id_fkey" FOREIGN KEY ("assignee_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tickets"
    ADD CONSTRAINT "tickets_landlord_id_fkey" FOREIGN KEY ("landlord_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tickets"
    ADD CONSTRAINT "tickets_lease_id_fkey" FOREIGN KEY ("lease_id") REFERENCES "public"."leases"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tickets"
    ADD CONSTRAINT "tickets_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_pins"
    ADD CONSTRAINT "user_pins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_reviewing_by_fkey" FOREIGN KEY ("reviewing_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."verification_requests"
    ADD CONSTRAINT "verification_requests_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



CREATE POLICY "Accommodation facilities manager manage" ON "public"."accommodation_facilities" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations"
  WHERE (("accommodations"."id" = "accommodation_facilities"."accommodation_id") AND ("accommodations"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations"
  WHERE (("accommodations"."id" = "accommodation_facilities"."accommodation_id") AND ("accommodations"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "Accommodation facilities visible with accommodation" ON "public"."accommodation_facilities" FOR SELECT TO "authenticated", "anon" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations"
  WHERE (("accommodations"."id" = "accommodation_facilities"."accommodation_id") AND (("accommodations"."status" = 'accredited'::"public"."accommodation_status") OR ("accommodations"."landlord_id" = "auth"."uid"()))))));



CREATE POLICY "Accommodation facility images manager manage" ON "public"."accommodation_facility_images" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_facilities" "facility"
     JOIN "public"."accommodations" "accommodation" ON (("accommodation"."id" = "facility"."accommodation_id")))
  WHERE (("facility"."id" = "accommodation_facility_images"."facility_id") AND ("accommodation"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_facilities" "facility"
     JOIN "public"."accommodations" "accommodation" ON (("accommodation"."id" = "facility"."accommodation_id")))
  WHERE (("facility"."id" = "accommodation_facility_images"."facility_id") AND ("accommodation"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "Accommodation facility images visible with facility" ON "public"."accommodation_facility_images" FOR SELECT TO "authenticated", "anon" USING ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_facilities" "facility"
     JOIN "public"."accommodations" "accommodation" ON (("accommodation"."id" = "facility"."accommodation_id")))
  WHERE (("facility"."id" = "accommodation_facility_images"."facility_id") AND (("accommodation"."status" = 'accredited'::"public"."accommodation_status") OR ("accommodation"."landlord_id" = "auth"."uid"()))))));



CREATE POLICY "Admins can update accommodation statuses" ON "public"."accommodations" FOR UPDATE TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "Users can insert their own profile" ON "public"."users" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can update their own profile" ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."accommodation_amenities" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_amenities_delete_own" ON "public"."accommodation_amenities" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_amenities"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_amenities_insert_own" ON "public"."accommodation_amenities" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_amenities"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_amenities_select_admin" ON "public"."accommodation_amenities" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodation_amenities_select_own" ON "public"."accommodation_amenities" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_amenities"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_amenities_select_public" ON "public"."accommodation_amenities" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_amenities"."accommodation_id") AND ("a"."status" = 'accredited'::"public"."accommodation_status")))));



CREATE POLICY "accommodation_amenities_update_own" ON "public"."accommodation_amenities" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_amenities"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_amenities"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."accommodation_documents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_documents_delete_admin" ON "public"."accommodation_documents" FOR DELETE TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodation_documents_delete_manager" ON "public"."accommodation_documents" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_documents"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_documents_insert_manager" ON "public"."accommodation_documents" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_documents"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_documents_select_admin" ON "public"."accommodation_documents" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodation_documents_select_manager" ON "public"."accommodation_documents" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_documents"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_documents_update_admin" ON "public"."accommodation_documents" FOR UPDATE TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodation_documents_update_manager" ON "public"."accommodation_documents" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_documents"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_documents"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."accommodation_facilities" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_facilities_insert_verified" ON "public"."accommodation_facilities" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (("public"."is_verified_landlord"("auth"."uid"()) OR "public"."is_admin"("auth"."uid"())));



ALTER TABLE "public"."accommodation_facility_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."accommodation_facility_rooms" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_facility_rooms_select" ON "public"."accommodation_facility_rooms" FOR SELECT TO "authenticated", "anon" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodation_facilities" "f"
  WHERE ("f"."id" = "accommodation_facility_rooms"."facility_id"))));



CREATE POLICY "accommodation_facility_rooms_write_own" ON "public"."accommodation_facility_rooms" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_facilities" "f"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "f"."accommodation_id")))
  WHERE (("f"."id" = "accommodation_facility_rooms"."facility_id") AND ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_facilities" "f"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "f"."accommodation_id")))
  WHERE (("f"."id" = "accommodation_facility_rooms"."facility_id") AND ("a"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."accommodation_floors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_floors_delete_own" ON "public"."accommodation_floors" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_floors"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_floors_insert_own" ON "public"."accommodation_floors" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_floors"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_floors_select_own" ON "public"."accommodation_floors" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_floors"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."accommodation_images" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_images_delete_own" ON "public"."accommodation_images" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_images"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_images_insert_own" ON "public"."accommodation_images" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_images"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_images_select_own" ON "public"."accommodation_images" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_images"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_images_select_public" ON "public"."accommodation_images" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_images"."accommodation_id") AND ("a"."status" = 'accredited'::"public"."accommodation_status")))));



CREATE POLICY "accommodation_images_update_own" ON "public"."accommodation_images" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_images"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_images"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_manager_profiles_delete_own" ON "public"."landlord_profiles" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "accommodation_manager_profiles_insert_own" ON "public"."landlord_profiles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "accommodation_manager_profiles_select_own" ON "public"."landlord_profiles" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "accommodation_manager_profiles_update_own" ON "public"."landlord_profiles" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "accommodation_manager_reviews_delete_own_student" ON "public"."landlord_reviews" FOR DELETE TO "authenticated" USING (("student_id" = "auth"."uid"()));



CREATE POLICY "accommodation_manager_reviews_insert_own_student" ON "public"."landlord_reviews" FOR INSERT TO "authenticated" WITH CHECK ((("student_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "landlord_reviews"."lease_id") AND ("l"."student_id" = "auth"."uid"()) AND ("l"."status" = ANY (ARRAY['ended'::"public"."lease_status", 'terminated'::"public"."lease_status"])) AND ("l"."landlord_id" = "landlord_reviews"."landlord_id"))))));



CREATE POLICY "accommodation_manager_reviews_select_admin" ON "public"."landlord_reviews" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodation_manager_reviews_select_involved" ON "public"."landlord_reviews" FOR SELECT TO "authenticated" USING ((("landlord_id" = "auth"."uid"()) OR ("student_id" = "auth"."uid"())));



CREATE POLICY "accommodation_manager_reviews_update_own_student" ON "public"."landlord_reviews" FOR UPDATE TO "authenticated" USING (("student_id" = "auth"."uid"())) WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "accommodation_managers_read_lease_student_profiles" ON "public"."student_profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."student_id" = "student_profiles"."user_id") AND ("l"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."accommodation_policies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_policies_delete_own" ON "public"."accommodation_policies" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_policies"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_policies_insert_own" ON "public"."accommodation_policies" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_policies"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_policies_select_admin" ON "public"."accommodation_policies" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodation_policies_select_own" ON "public"."accommodation_policies" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_policies"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "accommodation_policies_select_public" ON "public"."accommodation_policies" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_policies"."accommodation_id") AND ("a"."status" = 'accredited'::"public"."accommodation_status")))));



CREATE POLICY "accommodation_policies_update_own" ON "public"."accommodation_policies" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_policies"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_policies"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."accommodation_reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_reviews_delete_own_student" ON "public"."accommodation_reviews" FOR DELETE TO "authenticated" USING (("student_id" = "auth"."uid"()));



CREATE POLICY "accommodation_reviews_insert_own_student" ON "public"."accommodation_reviews" FOR INSERT TO "authenticated" WITH CHECK ((("student_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "accommodation_reviews"."lease_id") AND ("l"."student_id" = "auth"."uid"()) AND ("l"."status" = ANY (ARRAY['ended'::"public"."lease_status", 'terminated'::"public"."lease_status"])) AND (EXISTS ( SELECT 1
           FROM "public"."rooms" "r"
          WHERE (("r"."id" = "l"."room_id") AND ("r"."accommodation_id" = "accommodation_reviews"."accommodation_id")))))))));



CREATE POLICY "accommodation_reviews_select_admin" ON "public"."accommodation_reviews" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodation_reviews_select_involved" ON "public"."accommodation_reviews" FOR SELECT TO "authenticated" USING ((("student_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "accommodation_reviews"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"()))))));



CREATE POLICY "accommodation_reviews_update_own_student" ON "public"."accommodation_reviews" FOR UPDATE TO "authenticated" USING (("student_id" = "auth"."uid"())) WITH CHECK (("student_id" = "auth"."uid"()));



ALTER TABLE "public"."accommodations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodations_delete_own" ON "public"."accommodations" FOR DELETE TO "authenticated" USING (("landlord_id" = "auth"."uid"()));



CREATE POLICY "accommodations_delete_rejected_own" ON "public"."accommodations" FOR DELETE TO "authenticated" USING ((("landlord_id" = "auth"."uid"()) AND ("status" = 'rejected'::"public"."accommodation_status")));



CREATE POLICY "accommodations_insert_own" ON "public"."accommodations" FOR INSERT TO "authenticated" WITH CHECK (("landlord_id" = "auth"."uid"()));



CREATE POLICY "accommodations_insert_verified" ON "public"."accommodations" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (("public"."is_verified_landlord"("auth"."uid"()) OR "public"."is_admin"("auth"."uid"())));



CREATE POLICY "accommodations_select_accredited" ON "public"."accommodations" FOR SELECT USING (("status" = 'accredited'::"public"."accommodation_status"));



CREATE POLICY "accommodations_select_admin" ON "public"."accommodations" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "accommodations_select_own" ON "public"."accommodations" FOR SELECT TO "authenticated" USING (("landlord_id" = "auth"."uid"()));



CREATE POLICY "accommodations_update_own" ON "public"."accommodations" FOR UPDATE TO "authenticated" USING (("landlord_id" = "auth"."uid"())) WITH CHECK (("landlord_id" = "auth"."uid"()));



ALTER TABLE "public"."account_notes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "account_notes_delete_author" ON "public"."account_notes" FOR DELETE TO "authenticated" USING ((("author_id" = ( SELECT "auth"."uid"() AS "uid")) AND "public"."is_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "account_notes_insert_admin" ON "public"."account_notes" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_admin"(( SELECT "auth"."uid"() AS "uid")) AND ("author_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "account_notes_select_admin" ON "public"."account_notes" FOR SELECT TO "authenticated" USING ("public"."is_admin"(( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."account_standing" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "account_standing_select" ON "public"."account_standing" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "admin_all_student_profiles" ON "public"."student_profiles" TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "admin_all_verification_documents" ON "public"."verification_documents" TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



ALTER TABLE "public"."admin_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_profiles_delete_admin_only" ON "public"."admin_profiles" FOR DELETE USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "admin_profiles_insert_admin_only" ON "public"."admin_profiles" FOR INSERT WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "admin_profiles_select_own" ON "public"."admin_profiles" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "admin_profiles_update_admin_only" ON "public"."admin_profiles" FOR UPDATE USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "admin_select_all_accommodation_manager_profiles" ON "public"."landlord_profiles" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "admin_select_all_admin_profiles" ON "public"."admin_profiles" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "admin_select_all_users" ON "public"."users" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "announcements_delete_admin" ON "public"."announcements" FOR DELETE TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "announcements_insert_admin" ON "public"."announcements" FOR INSERT TO "authenticated" WITH CHECK (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "announcements_manager_own" ON "public"."announcements" TO "authenticated" USING ((("author_id" = "auth"."uid"()) AND ("accommodation_id" IN ( SELECT "a"."id"
   FROM "public"."accommodations" "a"
  WHERE ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((("author_id" = "auth"."uid"()) AND ("accommodation_id" IN ( SELECT "a"."id"
   FROM "public"."accommodations" "a"
  WHERE ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "announcements_select_admin" ON "public"."announcements" FOR SELECT TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "announcements_select_audience" ON "public"."announcements" FOR SELECT TO "authenticated" USING ((("published_at" IS NOT NULL) AND ("published_at" <= "now"()) AND (NOT "archived") AND (("expires_at" IS NULL) OR ("expires_at" > "now"())) AND
CASE
    WHEN ("accommodation_id" IS NULL) THEN (("audience" = 'all'::"public"."audience_type") OR (("audience" = 'students'::"public"."audience_type") AND ("public"."get_my_role"() = 'student'::"text")) OR (("audience" = 'landlords'::"public"."audience_type") AND ("public"."get_my_role"() = 'landlord'::"text")))
    ELSE ("accommodation_id" IN ( SELECT "my_accommodation_ids"."id"
       FROM "public"."my_accommodation_ids"() "my_accommodation_ids"("id")))
END));



CREATE POLICY "announcements_select_public" ON "public"."announcements" FOR SELECT TO "anon" USING ((("audience" = 'all'::"public"."audience_type") AND ("accommodation_id" IS NULL) AND ("published_at" IS NOT NULL) AND ("published_at" <= "now"()) AND (NOT "archived") AND (("expires_at" IS NULL) OR ("expires_at" > "now"()))));



CREATE POLICY "announcements_update_admin" ON "public"."announcements" FOR UPDATE TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text")) WITH CHECK (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "anon_name_read_accommodation_manager_profiles" ON "public"."landlord_profiles" FOR SELECT TO "anon" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."landlord_id" = "landlord_profiles"."user_id") AND ("a"."status" = 'accredited'::"public"."accommodation_status")))));



CREATE POLICY "anon_name_read_users" ON "public"."users" FOR SELECT TO "anon" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."landlord_id" = "users"."id") AND ("a"."status" = 'accredited'::"public"."accommodation_status")))));



ALTER TABLE "public"."app_release" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "app_release_read_all" ON "public"."app_release" FOR SELECT USING (true);



ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "audit_logs_insert_admin" ON "public"."audit_logs" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_admin"("auth"."uid"()) AND ("actor_id" = "auth"."uid"())));



CREATE POLICY "audit_logs_select_admin" ON "public"."audit_logs" FOR SELECT USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "audit_logs_select_own_actor" ON "public"."audit_logs" FOR SELECT TO "authenticated" USING (("actor_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."boarding_history" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "boarding_history_delete_own_student" ON "public"."boarding_history" FOR DELETE TO "authenticated" USING (("student_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "boarding_history_insert_manager" ON "public"."boarding_history" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "boarding_history"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "boarding_history_insert_own_student" ON "public"."boarding_history" FOR INSERT TO "authenticated" WITH CHECK (("student_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "boarding_history_select_admin" ON "public"."boarding_history" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "boarding_history_select_manager" ON "public"."boarding_history" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "boarding_history"."accommodation_id") AND ("a"."landlord_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "boarding_history_select_own_student" ON "public"."boarding_history" FOR SELECT TO "authenticated" USING (("student_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "boarding_history_update_own_student" ON "public"."boarding_history" FOR UPDATE TO "authenticated" USING (("student_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("student_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."concerns" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "concerns_manager_update" ON "public"."concerns" FOR UPDATE TO "authenticated" USING ((("lease_id" IN ( SELECT "leases"."id"
   FROM "public"."leases"
  WHERE ("leases"."landlord_id" = "auth"."uid"()))) OR "public"."is_admin"("auth"."uid"()))) WITH CHECK ((("lease_id" IN ( SELECT "leases"."id"
   FROM "public"."leases"
  WHERE ("leases"."landlord_id" = "auth"."uid"()))) OR "public"."is_admin"("auth"."uid"())));



CREATE POLICY "concerns_tenant_insert" ON "public"."concerns" FOR INSERT TO "authenticated" WITH CHECK ((("lease_id" IN ( SELECT "leases"."id"
   FROM "public"."leases"
  WHERE ("leases"."student_id" = "auth"."uid"()))) OR "public"."is_admin"("auth"."uid"())));



CREATE POLICY "concerns_tenant_manager_read" ON "public"."concerns" FOR SELECT TO "authenticated" USING ((("lease_id" IN ( SELECT "leases"."id"
   FROM "public"."leases"
  WHERE ("leases"."student_id" = "auth"."uid"()))) OR ("lease_id" IN ( SELECT "leases"."id"
   FROM "public"."leases"
  WHERE ("leases"."landlord_id" = "auth"."uid"()))) OR "public"."is_admin"("auth"."uid"())));



ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversations_delete_participant" ON "public"."conversations" FOR DELETE TO "authenticated" USING ((("user_a_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("user_b_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "conversations_insert_participant" ON "public"."conversations" FOR INSERT TO "authenticated" WITH CHECK ((("user_a_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("user_b_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "conversations_select_participant" ON "public"."conversations" FOR SELECT TO "authenticated" USING ((("user_a_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("user_b_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "conversations_update_participant" ON "public"."conversations" FOR UPDATE TO "authenticated" USING ((("user_a_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("user_b_id" = ( SELECT "auth"."uid"() AS "uid")))) WITH CHECK ((("user_a_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("user_b_id" = ( SELECT "auth"."uid"() AS "uid"))));



ALTER TABLE "public"."landlord_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."landlord_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."leases" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "leases_delete_own_pending" ON "public"."leases" FOR DELETE TO "authenticated" USING ((("student_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'pending'::"public"."lease_status")));



CREATE POLICY "leases_insert_manager" ON "public"."leases" FOR INSERT TO "authenticated" WITH CHECK ((("landlord_id" = ( SELECT "auth"."uid"() AS "uid")) AND (EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "leases"."room_id") AND ("a"."landlord_id" = ( SELECT "auth"."uid"() AS "uid"))))) AND "public"."student_may_lease"("student_id")));



CREATE POLICY "leases_insert_student_application" ON "public"."leases" FOR INSERT TO "authenticated" WITH CHECK ((("student_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'pending'::"public"."lease_status") AND (EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "leases"."room_id") AND ("a"."landlord_id" = "leases"."landlord_id")))) AND "public"."student_may_lease"("student_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."invited_room_id" = "leases"."room_id") AND ((("c"."user_a_id" = "leases"."student_id") AND ("c"."user_b_id" = "leases"."landlord_id")) OR (("c"."user_b_id" = "leases"."student_id") AND ("c"."user_a_id" = "leases"."landlord_id"))))))));



CREATE POLICY "leases_select_admin" ON "public"."leases" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "leases_select_involved" ON "public"."leases" FOR SELECT TO "authenticated" USING ((("student_id" = "auth"."uid"()) OR ("landlord_id" = "auth"."uid"())));



CREATE POLICY "leases_update_manager" ON "public"."leases" FOR UPDATE TO "authenticated" USING (("landlord_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("landlord_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "leases_update_student_leave" ON "public"."leases" FOR UPDATE TO "authenticated" USING ((("student_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'active'::"public"."lease_status"))) WITH CHECK ((("student_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'leave_requested'::"public"."lease_status")));



ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_delete_own" ON "public"."messages" FOR DELETE TO "authenticated" USING (("sender_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "messages_insert_participant" ON "public"."messages" FOR INSERT TO "authenticated" WITH CHECK ((("sender_id" = ( SELECT "auth"."uid"() AS "uid")) AND (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."user_a_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("c"."user_b_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "messages_select_participant" ON "public"."messages" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."user_a_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("c"."user_b_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "messages_update_own" ON "public"."messages" FOR UPDATE TO "authenticated" USING (("sender_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("sender_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_delete_own" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notifications_insert_admin" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "notifications_insert_counterparty" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_notify"("user_id"));



CREATE POLICY "notifications_insert_own" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payments_delete_manager" ON "public"."payments" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "payments"."lease_id") AND ("l"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "payments_insert_involved" ON "public"."payments" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "payments"."lease_id") AND (("l"."student_id" = "auth"."uid"()) OR ("l"."landlord_id" = "auth"."uid"()))))));



CREATE POLICY "payments_select_admin" ON "public"."payments" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "payments_select_involved" ON "public"."payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "payments"."lease_id") AND (("l"."student_id" = "auth"."uid"()) OR ("l"."landlord_id" = "auth"."uid"()))))));



CREATE POLICY "payments_update_involved" ON "public"."payments" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "payments"."lease_id") AND (("l"."student_id" = "auth"."uid"()) OR ("l"."landlord_id" = "auth"."uid"())))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "payments"."lease_id") AND (("l"."student_id" = "auth"."uid"()) OR ("l"."landlord_id" = "auth"."uid"()))))));



ALTER TABLE "public"."policies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "policies_delete_admin" ON "public"."policies" FOR DELETE TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "policies_insert_admin" ON "public"."policies" FOR INSERT TO "authenticated" WITH CHECK (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "policies_select_admin" ON "public"."policies" FOR SELECT TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "policies_select_anon" ON "public"."policies" FOR SELECT TO "anon" USING (((NOT "archived") AND ("effective_date" <= "now"())));



CREATE POLICY "policies_select_authenticated" ON "public"."policies" FOR SELECT TO "authenticated" USING (((NOT "archived") AND ("effective_date" <= "now"()) AND ("public"."get_my_role"() = ANY (ARRAY['student'::"text", 'landlord'::"text"]))));



CREATE POLICY "policies_update_admin" ON "public"."policies" FOR UPDATE TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text")) WITH CHECK (("public"."get_my_role"() = 'admin'::"text"));



ALTER TABLE "public"."qr_scans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "qr_scans_select_own" ON "public"."qr_scans" FOR SELECT TO "authenticated" USING ((("scanner_id" = "auth"."uid"()) OR ("student_id" = "auth"."uid"()) OR "public"."is_admin"("auth"."uid"())));



ALTER TABLE "public"."report_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "report_settings_admin_read" ON "public"."report_settings" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "report_settings_admin_update" ON "public"."report_settings" FOR UPDATE TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



ALTER TABLE "public"."room_images" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "room_images_delete_own" ON "public"."room_images" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "room_images"."room_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "room_images_insert_own" ON "public"."room_images" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "room_images"."room_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "room_images_select_own" ON "public"."room_images" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "room_images"."room_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "room_images_select_public" ON "public"."room_images" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "room_images"."room_id") AND ("a"."status" = 'accredited'::"public"."accommodation_status")))));



CREATE POLICY "room_images_update_own" ON "public"."room_images" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "room_images"."room_id") AND ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."rooms" "r"
     JOIN "public"."accommodations" "a" ON (("a"."id" = "r"."accommodation_id")))
  WHERE (("r"."id" = "room_images"."room_id") AND ("a"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."rooms" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "rooms_delete_own" ON "public"."rooms" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "rooms"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "rooms_insert_own" ON "public"."rooms" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "rooms"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "rooms_insert_verified" ON "public"."rooms" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (("public"."is_verified_landlord"("auth"."uid"()) OR "public"."is_admin"("auth"."uid"())));



CREATE POLICY "rooms_select_accredited" ON "public"."rooms" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "rooms"."accommodation_id") AND ("a"."status" = 'accredited'::"public"."accommodation_status")))));



CREATE POLICY "rooms_select_admin" ON "public"."rooms" FOR SELECT USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "rooms_select_own" ON "public"."rooms" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "rooms"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



CREATE POLICY "rooms_update_own" ON "public"."rooms" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "rooms"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "rooms"."accommodation_id") AND ("a"."landlord_id" = "auth"."uid"())))));



ALTER TABLE "public"."student_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "student_profiles_delete_own" ON "public"."student_profiles" FOR DELETE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "student_profiles_insert_own" ON "public"."student_profiles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "student_profiles_select_own" ON "public"."student_profiles" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "student_profiles_update_own" ON "public"."student_profiles" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."tenant_reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tenant_reviews_delete_own_manager" ON "public"."tenant_reviews" FOR DELETE TO "authenticated" USING (("landlord_id" = "auth"."uid"()));



CREATE POLICY "tenant_reviews_insert_own_manager" ON "public"."tenant_reviews" FOR INSERT TO "authenticated" WITH CHECK ((("landlord_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."leases" "l"
  WHERE (("l"."id" = "tenant_reviews"."lease_id") AND ("l"."landlord_id" = "auth"."uid"()) AND ("l"."status" = ANY (ARRAY['ended'::"public"."lease_status", 'terminated'::"public"."lease_status"])) AND ("l"."student_id" = "tenant_reviews"."student_id"))))));



CREATE POLICY "tenant_reviews_select_admin" ON "public"."tenant_reviews" FOR SELECT TO "authenticated" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "tenant_reviews_select_involved" ON "public"."tenant_reviews" FOR SELECT TO "authenticated" USING ((("student_id" = "auth"."uid"()) OR ("landlord_id" = "auth"."uid"())));



CREATE POLICY "tenant_reviews_update_own_manager" ON "public"."tenant_reviews" FOR UPDATE TO "authenticated" USING (("landlord_id" = "auth"."uid"())) WITH CHECK (("landlord_id" = "auth"."uid"()));



ALTER TABLE "public"."ticket_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ticket_messages_admin_all" ON "public"."ticket_messages" TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "ticket_messages_reporter_insert" ON "public"."ticket_messages" FOR INSERT TO "authenticated" WITH CHECK ((("is_internal" = false) AND (EXISTS ( SELECT 1
   FROM "public"."tickets" "t"
  WHERE (("t"."id" = "ticket_messages"."ticket_id") AND (("t"."student_id" = "auth"."uid"()) OR ("t"."landlord_id" = "auth"."uid"()) OR ("t"."lease_id" IN ( SELECT "leases"."id"
           FROM "public"."leases"
          WHERE ("leases"."student_id" = "auth"."uid"())))))))));



CREATE POLICY "ticket_messages_reporter_select" ON "public"."ticket_messages" FOR SELECT TO "authenticated" USING ((("is_internal" = false) AND (EXISTS ( SELECT 1
   FROM "public"."tickets" "t"
  WHERE (("t"."id" = "ticket_messages"."ticket_id") AND (("t"."student_id" = "auth"."uid"()) OR ("t"."landlord_id" = "auth"."uid"()) OR ("t"."lease_id" IN ( SELECT "l"."id"
           FROM "public"."leases" "l"
          WHERE ("l"."student_id" = "auth"."uid"())))))))));



ALTER TABLE "public"."tickets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tickets_admin_all" ON "public"."tickets" TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "tickets_reporter_insert" ON "public"."tickets" FOR INSERT TO "authenticated" WITH CHECK ((("student_id" = "auth"."uid"()) OR ("landlord_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'admin'::"public"."user_role"))))));



CREATE POLICY "tickets_reporter_select" ON "public"."tickets" FOR SELECT TO "authenticated" USING ((("student_id" = "auth"."uid"()) OR ("landlord_id" = "auth"."uid"()) OR ("lease_id" IN ( SELECT "l"."id"
   FROM "public"."leases" "l"
  WHERE ("l"."student_id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'admin'::"public"."user_role"))))));



CREATE POLICY "tickets_reporter_update" ON "public"."tickets" FOR UPDATE TO "authenticated" USING ((("student_id" = "auth"."uid"()) OR ("landlord_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'admin'::"public"."user_role")))))) WITH CHECK ((("student_id" = "auth"."uid"()) OR ("landlord_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'admin'::"public"."user_role"))))));



ALTER TABLE "public"."user_pins" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_select_related" ON "public"."users" FOR SELECT TO "authenticated" USING (("public"."can_notify"("id") OR (EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."landlord_id" = "users"."id") AND ("a"."status" = 'accredited'::"public"."accommodation_status"))))));



CREATE POLICY "users_update_admin" ON "public"."users" FOR UPDATE TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



ALTER TABLE "public"."verification_documents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_documents_delete_own" ON "public"."verification_documents" FOR DELETE TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'pending'::"public"."doc_status")));



CREATE POLICY "verification_documents_insert_own" ON "public"."verification_documents" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "verification_documents_select_own" ON "public"."verification_documents" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "verification_documents_update_own" ON "public"."verification_documents" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."verification_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_requests_admin_all" ON "public"."verification_requests" TO "authenticated" USING ("public"."is_admin"("auth"."uid"())) WITH CHECK ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "verification_requests_select_subject" ON "public"."verification_requests" FOR SELECT TO "authenticated" USING (((("entity_type" = 'user'::"text") AND ("entity_id" = "auth"."uid"())) OR (("entity_type" = 'accommodation'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."accommodations" "a"
  WHERE (("a"."id" = "verification_requests"."entity_id") AND ("a"."landlord_id" = "auth"."uid"())))))));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."announcements";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."audit_logs";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."concerns";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."conversations";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notifications";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































REVOKE ALL ON FUNCTION "public"."admin_change_role"("p_user" "uuid", "p_role" "public"."user_role", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_change_role"("p_user" "uuid", "p_role" "public"."user_role", "p_reason" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_change_role"("p_user" "uuid", "p_role" "public"."user_role", "p_reason" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_close_account"("p_user" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_close_account"("p_user" "uuid", "p_reason" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_close_account"("p_user" "uuid", "p_reason" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_disconnect_google"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_disconnect_google"("p_user" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_disconnect_google"("p_user" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_set_account_status"("p_user" "uuid", "p_status" "public"."user_status", "p_reason" "text", "p_until" timestamp with time zone, "p_restrictions" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_account_status"("p_user" "uuid", "p_status" "public"."user_status", "p_reason" "text", "p_until" timestamp with time zone, "p_restrictions" "text"[]) TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_set_account_status"("p_user" "uuid", "p_status" "public"."user_status", "p_reason" "text", "p_until" timestamp with time zone, "p_restrictions" "text"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_sign_in_methods"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_sign_in_methods"("p_user" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_sign_in_methods"("p_user" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_sign_out_everywhere"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_sign_out_everywhere"("p_user" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_sign_out_everywhere"("p_user" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."announce_due"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."announce_due"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."announcement_reach"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."announcement_reach"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."archive_expired_announcements"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."archive_expired_announcements"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."assert_admin_over"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."assert_admin_over"("p_user" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."assert_admin_over"("p_user" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."can_notify"("target" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_notify"("target" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."can_notify"("target" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_notify"("target" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."check_student_id_exists"("p_student_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_student_id_exists"("p_student_id" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."clear_pin"("p_current" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."clear_pin"("p_current" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."clear_pin"("p_current" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."complete_registration"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."complete_registration"() TO "service_role";
GRANT ALL ON FUNCTION "public"."complete_registration"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."confirm_email_ownership"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."confirm_email_ownership"() TO "service_role";
GRANT ALL ON FUNCTION "public"."confirm_email_ownership"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."current_is_superadmin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_is_superadmin"() TO "service_role";
GRANT ALL ON FUNCTION "public"."current_is_superadmin"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_is_superadmin"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."current_qr_token"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_qr_token"() TO "service_role";
GRANT ALL ON FUNCTION "public"."current_qr_token"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."enforce_room_capacity"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enforce_room_capacity"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."fanout_announcement"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fanout_announcement"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."fn_audit_log_change"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fn_audit_log_change"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_my_role"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_my_role"() TO "service_role";
GRANT ALL ON FUNCTION "public"."get_my_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_role"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_verification_queue"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_verification_queue"() TO "service_role";
GRANT ALL ON FUNCTION "public"."get_verification_queue"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."guard_facility_room_link"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guard_facility_room_link"() TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_hidden_from_listings"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_hidden_from_listings"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_auth_user_sync"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_auth_user_sync"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."has_pin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."has_pin"() TO "service_role";
GRANT ALL ON FUNCTION "public"."has_pin"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."invite_application"("p_conversation" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."invite_application"("p_conversation" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."invite_application"("p_conversation" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."is_admin"("p_uid" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_admin"("p_uid" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."is_admin"("p_uid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"("p_uid" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."is_verified_landlord"("uid" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_verified_landlord"("uid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_verified_landlord"("uid" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."is_verified_landlord"("uid" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."lift_expired_suspensions"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."lift_expired_suspensions"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."lock_document_ref"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."lock_document_ref"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."lock_user_privileges"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."lock_user_privileges"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."lock_verification_columns"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."lock_verification_columns"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_conversation_read"("p_conversation" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_conversation_read"("p_conversation" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."mark_conversation_read"("p_conversation" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."my_accommodation_ids"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_accommodation_ids"() TO "service_role";
GRANT ALL ON FUNCTION "public"."my_accommodation_ids"() TO "anon";
GRANT ALL ON FUNCTION "public"."my_accommodation_ids"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."notify_admins"("p_title" "text", "p_body" "text", "p_type" "text", "p_link_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_admins"("p_title" "text", "p_body" "text", "p_type" "text", "p_link_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_announcement"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_announcement"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_policy"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_policy"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."pin_attempt"("p_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pin_attempt"("p_pin" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."prevent_non_superadmin_escalation"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."prevent_non_superadmin_escalation"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_unverified_accounts"("p_older_than" interval) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_unverified_accounts"("p_older_than" interval) TO "service_role";



REVOKE ALL ON FUNCTION "public"."reap_unverified_signups"("p_older_than" interval) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."reap_unverified_signups"("p_older_than" interval) TO "service_role";



REVOKE ALL ON FUNCTION "public"."recompute_room_occupancy"("p_room_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."recompute_room_occupancy"("p_room_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."record_consent"("p_documents" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."record_consent"("p_documents" "text"[]) TO "service_role";
GRANT ALL ON FUNCTION "public"."record_consent"("p_documents" "text"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."refresh_accommodation_rating"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_accommodation_rating"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."resubmit_verification"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."resubmit_verification"() TO "service_role";
GRANT ALL ON FUNCTION "public"."resubmit_verification"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."rotate_qr_token"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rotate_qr_token"() TO "service_role";
GRANT ALL ON FUNCTION "public"."rotate_qr_token"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."set_audit_context"("p_user_agent" "text", "p_ip_address" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_audit_context"("p_user_agent" "text", "p_ip_address" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_pin"("p_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_pin"("p_pin" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."set_pin"("p_pin" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."student_may_lease"("p_student" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."student_may_lease"("p_student" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."student_may_lease"("p_student" "uuid") TO "authenticated";



GRANT ALL ON FUNCTION "public"."submit_student_review"("p_lease_id" "uuid", "p_accommodation_id" "uuid", "p_landlord_id" "uuid", "p_acc_rating" integer, "p_acc_comment" "text", "p_manager_rating" integer, "p_manager_comment" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_student_review"("p_lease_id" "uuid", "p_accommodation_id" "uuid", "p_landlord_id" "uuid", "p_acc_rating" integer, "p_acc_comment" "text", "p_manager_rating" integer, "p_manager_comment" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sweep_expired_accreditations"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sweep_expired_accreditations"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sweep_expired_permits"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sweep_expired_permits"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_room_occupancy"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_room_occupancy"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."tg_lease_closed_clears_inquiry"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."tg_lease_closed_clears_inquiry"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."tg_lease_guard_student_update"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."tg_lease_guard_student_update"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."tg_message_after_insert"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."tg_message_after_insert"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."tg_notification_attribution"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."tg_notification_attribution"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."tg_payment_guard"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."tg_payment_guard"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."tg_permit_needs_review"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."tg_permit_needs_review"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."tg_revoke_on_unverify"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."tg_revoke_on_unverify"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."ticket_touch"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ticket_touch"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_lease_leave"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_lease_leave"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_new_accommodation"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_new_accommodation"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_new_landlord"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_new_landlord"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_new_ticket"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_new_ticket"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_new_verification"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_new_verification"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_payment_flag"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_payment_flag"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_ticket_message_notify"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_ticket_message_notify"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validate_accommodation_facility_room"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validate_accommodation_facility_room"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."verify_pin"("p_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."verify_pin"("p_pin" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."verify_pin"("p_pin" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."verify_student_qr"("p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."verify_student_qr"("p_code" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."verify_student_qr"("p_code" "text") TO "authenticated";
























GRANT ALL ON TABLE "public"."accommodation_amenities" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."accommodation_amenities" TO "authenticated";



GRANT SELECT,MAINTAIN ON TABLE "public"."accommodation_documents" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."accommodation_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."accommodation_documents" TO "service_role";



GRANT SELECT,MAINTAIN ON TABLE "public"."accommodation_facilities" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."accommodation_facilities" TO "authenticated";
GRANT ALL ON TABLE "public"."accommodation_facilities" TO "service_role";



GRANT SELECT,MAINTAIN ON TABLE "public"."accommodation_facility_images" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."accommodation_facility_images" TO "authenticated";
GRANT ALL ON TABLE "public"."accommodation_facility_images" TO "service_role";



GRANT SELECT,MAINTAIN ON TABLE "public"."accommodation_facility_rooms" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."accommodation_facility_rooms" TO "authenticated";
GRANT ALL ON TABLE "public"."accommodation_facility_rooms" TO "service_role";



GRANT SELECT,MAINTAIN ON TABLE "public"."accommodation_floors" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."accommodation_floors" TO "authenticated";
GRANT ALL ON TABLE "public"."accommodation_floors" TO "service_role";



GRANT ALL ON TABLE "public"."accommodation_images" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."accommodation_images" TO "authenticated";
GRANT SELECT ON TABLE "public"."accommodation_images" TO "anon";



GRANT ALL ON TABLE "public"."accommodation_policies" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."accommodation_policies" TO "authenticated";



GRANT ALL ON TABLE "public"."accommodation_reviews" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."accommodation_reviews" TO "authenticated";



GRANT ALL ON TABLE "public"."accommodations" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."accommodations" TO "authenticated";
GRANT SELECT ON TABLE "public"."accommodations" TO "anon";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE "public"."account_notes" TO "authenticated";
GRANT ALL ON TABLE "public"."account_notes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE "public"."account_standing" TO "authenticated";
GRANT ALL ON TABLE "public"."account_standing" TO "service_role";



GRANT ALL ON TABLE "public"."admin_profiles" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."admin_profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."announcements" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."announcements" TO "authenticated";



GRANT ALL ON TABLE "public"."app_release" TO "service_role";
GRANT SELECT ON TABLE "public"."app_release" TO "anon";
GRANT SELECT ON TABLE "public"."app_release" TO "authenticated";



GRANT ALL ON TABLE "public"."audit_logs" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."audit_logs" TO "authenticated";



GRANT ALL ON TABLE "public"."boarding_history" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."boarding_history" TO "authenticated";



GRANT SELECT,MAINTAIN ON TABLE "public"."concerns" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."concerns" TO "authenticated";
GRANT ALL ON TABLE "public"."concerns" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."conversations" TO "authenticated";



GRANT ALL ON TABLE "public"."landlord_profiles" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."landlord_profiles" TO "authenticated";



GRANT SELECT("user_id") ON TABLE "public"."landlord_profiles" TO "anon";



GRANT ALL ON TABLE "public"."landlord_reviews" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."landlord_reviews" TO "authenticated";



GRANT SELECT,MAINTAIN ON TABLE "public"."latest_accommodation_documents" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."latest_accommodation_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."latest_accommodation_documents" TO "service_role";



GRANT ALL ON TABLE "public"."leases" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."leases" TO "authenticated";



GRANT ALL ON TABLE "public"."messages" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."messages" TO "authenticated";



GRANT ALL ON TABLE "public"."notifications" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."notifications" TO "authenticated";



GRANT ALL ON TABLE "public"."payments" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."payments" TO "authenticated";



GRANT ALL ON TABLE "public"."policies" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."policies" TO "authenticated";



GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE "public"."qr_scans" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE "public"."qr_scans" TO "authenticated";
GRANT ALL ON TABLE "public"."qr_scans" TO "service_role";



GRANT SELECT,MAINTAIN,UPDATE ON TABLE "public"."report_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."report_settings" TO "service_role";



GRANT ALL ON TABLE "public"."tenant_reviews" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."tenant_reviews" TO "authenticated";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE "public"."review_admin_feed" TO "authenticated";
GRANT ALL ON TABLE "public"."review_admin_feed" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE "public"."review_inbox" TO "authenticated";
GRANT ALL ON TABLE "public"."review_inbox" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE "public"."review_written_leases" TO "authenticated";
GRANT ALL ON TABLE "public"."review_written_leases" TO "service_role";



GRANT ALL ON TABLE "public"."room_images" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."room_images" TO "authenticated";



GRANT ALL ON TABLE "public"."rooms" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."rooms" TO "authenticated";
GRANT SELECT ON TABLE "public"."rooms" TO "anon";



GRANT ALL ON TABLE "public"."student_profiles" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."student_profiles" TO "authenticated";



GRANT SELECT,MAINTAIN ON TABLE "public"."ticket_messages" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."ticket_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."ticket_messages" TO "service_role";



GRANT SELECT,MAINTAIN ON TABLE "public"."tickets" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."tickets" TO "authenticated";
GRANT ALL ON TABLE "public"."tickets" TO "service_role";



GRANT ALL ON TABLE "public"."user_pins" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "service_role";
GRANT SELECT,INSERT,UPDATE ON TABLE "public"."users" TO "authenticated";



GRANT SELECT("id") ON TABLE "public"."users" TO "anon";



GRANT SELECT("full_name") ON TABLE "public"."users" TO "anon";



GRANT UPDATE("privacy_accepted_at") ON TABLE "public"."users" TO "authenticated";



GRANT ALL ON TABLE "public"."verification_documents" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."verification_documents" TO "authenticated";



GRANT SELECT,MAINTAIN ON TABLE "public"."verification_requests" TO "anon";
GRANT SELECT,INSERT,DELETE,MAINTAIN,UPDATE ON TABLE "public"."verification_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."verification_requests" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
































-- ── Outside `public`, so not in the dump above ──────────────────────────────

-- Keeps public.users in step with auth.users (signup, e-mail change, delete).
drop trigger if exists sync_public_users_from_auth on auth.users;
create trigger sync_public_users_from_auth
  after insert or update or delete on auth.users
  for each row execute function public.handle_auth_user_sync();

-- Scheduled jobs, copied from cron.job on the live project.
select cron.schedule('announce-due',                  '*/5 * * * *',  'select public.announce_due()');
select cron.schedule('archive-expired-announcements', '10 17 * * *',  'select public.archive_expired_announcements()');
select cron.schedule('lift-expired-suspensions',      '*/15 * * * *', 'select public.lift_expired_suspensions()');
select cron.schedule('reap-unverified-signups',       '23 3 * * *',   'select public.reap_unverified_signups()');
select cron.schedule('sweep-expired-accreditations',  '30 18 * * *',  'select public.sweep_expired_accreditations();');
select cron.schedule('sweep-expired-permits',         '0 18 * * *',   'select public.sweep_expired_permits();');

-- ── Privileges ──────────────────────────────────────────────────────────────
-- pg_dump omits REVOKEs that undo Supabase's default grants, so a fresh build
-- came out MORE open than live (anon could execute admin functions). This
-- block is `supabase db diff --linked` output that brings it back in line.

SET local check_function_bodies = off;

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."admin_change_role"(uuid, public.user_role, text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."admin_close_account"(uuid, text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."admin_disconnect_google"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."admin_set_account_status"(uuid, public.user_status, text, timestamp WITH time zone, text[]) FROM "anon";

REVOKE ALL ON FUNCTION "public"."admin_sign_in_methods"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."admin_sign_out_everywhere"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."announce_due"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."announce_due"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."announcement_reach"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."announcement_reach"(uuid) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."archive_expired_announcements"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."archive_expired_announcements"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."assert_admin_over"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."check_student_id_exists"(text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."check_student_id_exists"(text) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."clear_pin"(text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."complete_registration"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."confirm_email_ownership"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."current_qr_token"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."enforce_room_capacity"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."enforce_room_capacity"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."fanout_announcement"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."fanout_announcement"(uuid) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_audit_log_change"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."fn_audit_log_change"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."get_verification_queue"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."guard_facility_room_link"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."guard_facility_room_link"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."guard_hidden_from_listings"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."handle_auth_user_sync"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."handle_auth_user_sync"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."has_pin"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."invite_application"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."lift_expired_suspensions"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."lift_expired_suspensions"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."lock_document_ref"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."lock_document_ref"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."lock_user_privileges"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."lock_user_privileges"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."lock_verification_columns"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."lock_verification_columns"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."mark_conversation_read"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."notify_admins"(text, text, text, text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."notify_admins"(text, text, text, text) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."notify_announcement"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."notify_announcement"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."notify_policy"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."notify_policy"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."pin_attempt"(text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."pin_attempt"(text) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."prevent_non_superadmin_escalation"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."prevent_non_superadmin_escalation"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."purge_unverified_accounts"(interval) FROM "anon";

REVOKE ALL ON FUNCTION "public"."purge_unverified_accounts"(interval) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."reap_unverified_signups"(interval) FROM "anon";

REVOKE ALL ON FUNCTION "public"."reap_unverified_signups"(interval) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."recompute_room_occupancy"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."recompute_room_occupancy"(uuid) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."record_consent"(text[]) FROM "anon";

REVOKE ALL ON FUNCTION "public"."refresh_accommodation_rating"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."refresh_accommodation_rating"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."resubmit_verification"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."rotate_qr_token"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."set_audit_context"(text, text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."set_audit_context"(text, text) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."set_pin"(text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."student_may_lease"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."submit_student_review"(uuid, uuid, uuid, integer, text, integer, text) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."sweep_expired_accreditations"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."sweep_expired_accreditations"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."sweep_expired_permits"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."sweep_expired_permits"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."sync_room_occupancy"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."sync_room_occupancy"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."tg_lease_closed_clears_inquiry"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."tg_lease_closed_clears_inquiry"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."tg_lease_guard_student_update"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."tg_lease_guard_student_update"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."tg_message_after_insert"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."tg_message_after_insert"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."tg_notification_attribution"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."tg_notification_attribution"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."tg_payment_guard"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."tg_payment_guard"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."tg_permit_needs_review"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."tg_permit_needs_review"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."tg_revoke_on_unverify"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."tg_revoke_on_unverify"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."ticket_touch"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."ticket_touch"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."trg_lease_leave"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."trg_lease_leave"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."trg_new_accommodation"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."trg_new_accommodation"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."trg_new_landlord"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."trg_new_landlord"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."trg_new_ticket"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."trg_new_ticket"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."trg_new_verification"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."trg_new_verification"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."trg_payment_flag"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."trg_payment_flag"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."trg_ticket_message_notify"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."trg_ticket_message_notify"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."validate_accommodation_facility_room"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."validate_accommodation_facility_room"() FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."verify_pin"(text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."verify_student_qr"(text) FROM "anon";

REVOKE ALL ON TABLE "public"."accommodation_amenities" FROM "anon";

REVOKE ALL ON TABLE "public"."accommodation_policies" FROM "anon";

REVOKE ALL ON TABLE "public"."accommodation_reviews" FROM "anon";

REVOKE ALL ON TABLE "public"."account_notes" FROM "anon";

REVOKE ALL ON TABLE "public"."account_standing" FROM "anon";

REVOKE ALL ON TABLE "public"."admin_profiles" FROM "anon";

REVOKE ALL ON TABLE "public"."announcements" FROM "anon";

REVOKE ALL ON TABLE "public"."audit_logs" FROM "anon";

REVOKE ALL ON TABLE "public"."boarding_history" FROM "anon";

REVOKE ALL ON TABLE "public"."conversations" FROM "anon";

REVOKE ALL ON TABLE "public"."landlord_profiles" FROM "anon";

REVOKE ALL ON TABLE "public"."landlord_reviews" FROM "anon";

REVOKE ALL ON TABLE "public"."leases" FROM "anon";

REVOKE ALL ON TABLE "public"."messages" FROM "anon";

REVOKE ALL ON TABLE "public"."notifications" FROM "anon";

REVOKE ALL ON TABLE "public"."payments" FROM "anon";

REVOKE ALL ON TABLE "public"."policies" FROM "anon";

REVOKE ALL ON TABLE "public"."report_settings" FROM "anon";

REVOKE ALL ON TABLE "public"."room_images" FROM "anon";

REVOKE ALL ON TABLE "public"."student_profiles" FROM "anon";

REVOKE ALL ON TABLE "public"."tenant_reviews" FROM "anon";

REVOKE ALL ON TABLE "public"."user_pins" FROM "anon";

REVOKE ALL ON TABLE "public"."user_pins" FROM "authenticated";

REVOKE ALL ON TABLE "public"."users" FROM "anon";

REVOKE ALL ON TABLE "public"."verification_documents" FROM "anon";

REVOKE ALL ON TABLE "public"."review_admin_feed" FROM "anon";

REVOKE ALL ON TABLE "public"."review_inbox" FROM "anon";

REVOKE ALL ON TABLE "public"."review_written_leases" FROM "anon";

ALTER TABLE "public"."accommodations"
  DROP CONSTRAINT "accommodations_accommodation_type_check";

ALTER TABLE "public"."accommodations"
  ADD CONSTRAINT "accommodations_accommodation_type_check"
    CHECK (((accommodation_type)::text = ANY ((ARRAY['boarding_house'::character varying, 'residence'::character varying, 'dormitory'::character varying])::text[])));

REVOKE ALL ON TABLE "public"."accommodation_amenities" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."accommodation_amenities" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_documents" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."accommodation_documents" TO "anon";

REVOKE ALL ON TABLE "public"."accommodation_documents" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."accommodation_documents" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_facilities" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."accommodation_facilities" TO "anon";

REVOKE ALL ON TABLE "public"."accommodation_facilities" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."accommodation_facilities" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_facility_images" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."accommodation_facility_images" TO "anon";

REVOKE ALL ON TABLE "public"."accommodation_facility_images" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."accommodation_facility_images" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_facility_rooms" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."accommodation_facility_rooms" TO "anon";

REVOKE ALL ON TABLE "public"."accommodation_facility_rooms" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."accommodation_facility_rooms" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_floors" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."accommodation_floors" TO "anon";

REVOKE ALL ON TABLE "public"."accommodation_floors" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."accommodation_floors" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_images" FROM "anon";

GRANT SELECT ON TABLE "public"."accommodation_images" TO "anon";

REVOKE ALL ON TABLE "public"."accommodation_images" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."accommodation_images" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_policies" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."accommodation_policies" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodation_reviews" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."accommodation_reviews" TO "authenticated";

REVOKE ALL ON TABLE "public"."accommodations" FROM "anon";

GRANT SELECT ON TABLE "public"."accommodations" TO "anon";

REVOKE ALL ON TABLE "public"."accommodations" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."accommodations" TO "authenticated";

REVOKE ALL ON TABLE "public"."account_notes" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE "public"."account_notes" TO "authenticated";

REVOKE ALL ON TABLE "public"."account_standing" FROM "authenticated";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER ON TABLE "public"."account_standing" TO "authenticated";

REVOKE ALL ON TABLE "public"."admin_profiles" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."admin_profiles" TO "authenticated";

REVOKE ALL ON TABLE "public"."announcements" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."announcements" TO "authenticated";

REVOKE ALL ON TABLE "public"."app_release" FROM "anon";

GRANT SELECT ON TABLE "public"."app_release" TO "anon";

REVOKE ALL ON TABLE "public"."app_release" FROM "authenticated";

GRANT SELECT ON TABLE "public"."app_release" TO "authenticated";

REVOKE ALL ON TABLE "public"."audit_logs" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."audit_logs" TO "authenticated";

REVOKE ALL ON TABLE "public"."boarding_history" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."boarding_history" TO "authenticated";

REVOKE ALL ON TABLE "public"."concerns" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."concerns" TO "anon";

REVOKE ALL ON TABLE "public"."concerns" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."concerns" TO "authenticated";

REVOKE ALL ON TABLE "public"."conversations" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."conversations" TO "authenticated";

REVOKE ALL ON TABLE "public"."landlord_profiles" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."landlord_profiles" TO "authenticated";

REVOKE ALL ON TABLE "public"."landlord_reviews" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."landlord_reviews" TO "authenticated";

REVOKE ALL ON TABLE "public"."leases" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."leases" TO "authenticated";

REVOKE ALL ON TABLE "public"."messages" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."messages" TO "authenticated";

REVOKE ALL ON TABLE "public"."notifications" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."notifications" TO "authenticated";

REVOKE ALL ON TABLE "public"."payments" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."payments" TO "authenticated";

REVOKE ALL ON TABLE "public"."policies" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."policies" TO "authenticated";

REVOKE ALL ON TABLE "public"."qr_scans" FROM "anon";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER ON TABLE "public"."qr_scans" TO "anon";

REVOKE ALL ON TABLE "public"."qr_scans" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE "public"."qr_scans" TO "authenticated";

REVOKE ALL ON TABLE "public"."report_settings" FROM "authenticated";

GRANT MAINTAIN, SELECT, UPDATE ON TABLE "public"."report_settings" TO "authenticated";

REVOKE ALL ON TABLE "public"."room_images" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."room_images" TO "authenticated";

REVOKE ALL ON TABLE "public"."rooms" FROM "anon";

GRANT SELECT ON TABLE "public"."rooms" TO "anon";

REVOKE ALL ON TABLE "public"."rooms" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."rooms" TO "authenticated";

REVOKE ALL ON TABLE "public"."student_profiles" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."student_profiles" TO "authenticated";

REVOKE ALL ON TABLE "public"."tenant_reviews" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."tenant_reviews" TO "authenticated";

REVOKE ALL ON TABLE "public"."ticket_messages" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."ticket_messages" TO "anon";

REVOKE ALL ON TABLE "public"."ticket_messages" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."ticket_messages" TO "authenticated";

REVOKE ALL ON TABLE "public"."tickets" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."tickets" TO "anon";

REVOKE ALL ON TABLE "public"."tickets" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."tickets" TO "authenticated";

REVOKE ALL ON TABLE "public"."users" FROM "authenticated";

GRANT INSERT, SELECT, UPDATE ON TABLE "public"."users" TO "authenticated";

REVOKE ALL ON TABLE "public"."verification_documents" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."verification_documents" TO "authenticated";

REVOKE ALL ON TABLE "public"."verification_requests" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."verification_requests" TO "anon";

REVOKE ALL ON TABLE "public"."verification_requests" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."verification_requests" TO "authenticated";

REVOKE ALL ON TABLE "public"."latest_accommodation_documents" FROM "anon";

GRANT MAINTAIN, SELECT ON TABLE "public"."latest_accommodation_documents" TO "anon";

REVOKE ALL ON TABLE "public"."latest_accommodation_documents" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."latest_accommodation_documents" TO "authenticated";

REVOKE ALL ON TABLE "public"."review_admin_feed" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE "public"."review_admin_feed" TO "authenticated";

REVOKE ALL ON TABLE "public"."review_inbox" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE "public"."review_inbox" TO "authenticated";

REVOKE ALL ON TABLE "public"."review_written_leases" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE "public"."review_written_leases" TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLES TO "authenticated";

-- Column grants live has; the table-level REVOKE ALLs above wipe them.
GRANT SELECT ("user_id") ON TABLE "public"."landlord_profiles" TO "anon";
GRANT SELECT ("id", "full_name") ON TABLE "public"."users" TO "anon";
GRANT UPDATE ("privacy_accepted_at") ON TABLE "public"."users" TO "authenticated";
