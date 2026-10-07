-- 1. The student QR changes every 5 seconds.
--
-- Writing a fresh token every 5 seconds would put an audit row on
-- student_profiles each time. Instead the code is derived: an HMAC of the
-- 5-second slot, keyed by the student's qr_code_token, which now never leaves
-- the database. A screenshot is dead within seconds, and nothing is written.
--
-- Code shape: a1.<user_id>.<slot>.<mac>. A scan is accepted for the current
-- slot and the two before it (up to 15 s), which covers camera and network lag.

create or replace function public.qr_mac(p_user uuid, p_secret text, p_slot bigint)
returns text language sql immutable set search_path = public, extensions as $$
  select left(encode(extensions.hmac(p_user::text || ':' || p_slot, p_secret, 'sha256'), 'hex'), 24);
$$;
revoke all on function public.qr_mac(uuid, text, bigint) from public, anon, authenticated;

-- (user_id, 'ok' | 'expired') for a code with a genuine MAC; no row otherwise.
create or replace function public.qr_resolve(p_code text)
returns table (user_id uuid, status text)
language plpgsql stable security definer set search_path = public as $$
declare
  parts text[] := string_to_array(trim(p_code), '.');
  v_user uuid;
  v_slot bigint;
  v_now bigint := floor(extract(epoch from now()) / 5);
  v_secret text;
begin
  if array_length(parts, 1) <> 4 or parts[1] <> 'a1' then return; end if;
  begin
    v_user := parts[2]::uuid;
    v_slot := parts[3]::bigint;
  exception when others then return;
  end;

  select sp.qr_code_token into v_secret from public.student_profiles sp where sp.user_id = v_user;
  if v_secret is null or public.qr_mac(v_user, v_secret, v_slot) <> parts[4] then return; end if;

  user_id := v_user;
  status := case when v_slot between v_now - 2 and v_now then 'ok' else 'expired' end;
  return next;
end $$;
revoke all on function public.qr_resolve(text) from public, anon, authenticated;

-- The return shape changes (ttl_ms, so the phone's own clock never matters).
drop function if exists public.current_qr_token();
create function public.current_qr_token()
returns table (token text, expires_at timestamptz, ttl_ms integer)
language plpgsql security definer set search_path = public as $$
declare
  v_secret text;
  v_slot bigint := floor(extract(epoch from now()) / 5);
begin
  select sp.qr_code_token into v_secret from public.student_profiles sp where sp.user_id = auth.uid();
  if not found then
    raise exception 'No student profile for this account';
  end if;
  -- First use only: the key is long-lived now, so this writes once.
  if v_secret is null then
    update public.student_profiles set qr_code_token = gen_random_uuid()::text
     where student_profiles.user_id = auth.uid()
     returning qr_code_token into v_secret;
  end if;

  token := 'a1.' || auth.uid() || '.' || v_slot || '.' || public.qr_mac(auth.uid(), v_secret, v_slot);
  expires_at := to_timestamp((v_slot + 1) * 5);
  ttl_ms := greatest(0, round(extract(epoch from (expires_at - now())) * 1000))::integer;
  return next;
end $$;
revoke all on function public.current_qr_token() from public, anon;
grant execute on function public.current_qr_token() to authenticated;

create or replace function public.verify_student_qr(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  recent integer;
  r record;
  sp record;
  u record;
  is_mine boolean;
  v_method text := 'qr';
  v_result text;
begin
  if me is null then
    raise exception 'Not signed in';
  end if;

  select count(*) into recent
    from public.qr_scans
   where scanner_id = me and scanned_at > now() - interval '1 minute';
  if recent >= 12 then
    raise exception 'Too many scans in a row. Wait a minute and try again.';
  end if;

  select * into r from public.qr_resolve(p_code);

  if r.user_id is not null and r.status = 'expired' then
    insert into public.qr_scans (scanner_id, student_id, method, result)
    values (me, r.user_id, 'qr', 'expired');
    return jsonb_build_object('found', false, 'reason', 'expired');
  end if;

  if r.user_id is not null then
    select * into sp from public.student_profiles where user_id = r.user_id;
  elsif public.get_my_role() in ('landlord', 'admin') then
    v_method := 'manual';
    select * into sp from public.student_profiles where student_id = trim(p_code);
  end if;

  if sp.user_id is null then
    insert into public.qr_scans (scanner_id, student_id, method, result)
    values (me, null, v_method, 'not_found');
    return jsonb_build_object('found', false, 'reason', 'not_found');
  end if;

  select * into u from public.users where id = sp.user_id;

  select exists (
    select 1 from public.leases l
     where l.student_id = sp.user_id and l.landlord_id = me
  ) into is_mine;

  v_result := case when sp.osas_verified_at is not null then 'verified' else 'unverified' end;
  insert into public.qr_scans (scanner_id, student_id, method, result)
  values (me, sp.user_id, v_method, v_result);

  return jsonb_build_object(
    'found', true,
    'user_id', sp.user_id,
    'student_id', sp.student_id,
    'full_name', u.full_name,
    'initials', u.initials,
    'avatar_url', u.avatar_url,
    'program', sp.program,
    'college', sp.college,
    'year_level', sp.year_level,
    'osas_verified', sp.osas_verified_at is not null,
    'verified_at', sp.osas_verified_at,
    'account_status', u.status,
    'is_my_tenant', is_mine,
    'method', v_method
  );
end $$;

create or replace function public.accept_added_student(p_lease uuid, p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_student uuid;
  v_ok boolean;
begin
  if v_me is null then
    raise exception 'Not signed in';
  end if;

  select l.student_id into v_student
    from public.leases l
   where l.id = p_lease and l.landlord_id = v_me
     and l.status = 'pending' and l.added_by_landlord;
  if v_student is null then
    raise exception 'That is not a student you added, or they were already accepted.';
  end if;

  select exists (
    select 1 from public.qr_resolve(p_code) r
     where r.user_id = v_student and r.status = 'ok'
  ) into v_ok;

  insert into public.qr_scans (scanner_id, student_id, method, result)
  values (v_me, v_student, 'qr', case when v_ok then 'verified' else 'mismatch' end);

  if not v_ok then
    raise exception 'That QR code is not this student''s, or it has expired. Ask them to open their QR screen again.';
  end if;

  perform set_config('app.qr_accept', 'true', true);
  update public.leases set status = 'active' where id = p_lease;
  perform set_config('app.qr_accept', 'false', true);
end $$;

-- 2. A landlord/landlady who has just scanned a student's QR in person may see
-- that student's school ID and assessment of fees, for 30 minutes. Only a QR
-- scan counts: a typed student number proves nobody is standing there.
-- Returns the stored refs; doc-access signs them. The newest resubmission wins
-- over the file given at registration.
create or replace function public.scanned_student_docs(p_student uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  sp record;
begin
  if not exists (
    select 1 from public.qr_scans s
     where s.scanner_id = auth.uid() and s.student_id = p_student
       and s.method = 'qr' and s.result in ('verified', 'unverified')
       and s.scanned_at > now() - interval '30 minutes'
  ) then
    return null;
  end if;

  select school_id_url, assessment_of_fees_url into sp
    from public.student_profiles where user_id = p_student;

  return jsonb_build_object(
    'school_id', coalesce(
      (select d.file_url from public.verification_documents d
        where d.user_id = p_student and d.doc_type = 'school_id' and d.file_url is not null
        order by d.uploaded_at desc limit 1),
      sp.school_id_url),
    'assessment_of_fees', coalesce(
      (select d.file_url from public.verification_documents d
        where d.user_id = p_student and d.doc_type = 'assessment_of_fees' and d.file_url is not null
        order by d.uploaded_at desc limit 1),
      sp.assessment_of_fees_url)
  );
end $$;
revoke all on function public.scanned_student_docs(uuid) from public, anon;
grant execute on function public.scanned_student_docs(uuid) to authenticated;
