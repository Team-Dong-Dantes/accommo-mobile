-- A landlord/landlady may add a student to a room by hand (a walk-in tenant),
-- but that tenancy only starts once they scan the student's QR code in person.
-- The scan is the student's consent, and a student QR exists only once OSAS
-- has verified them.
--
-- 1. leases.added_by_landlord marks a lease that did not come from the
--    student's own application.
-- 2. leases_insert_manager goes: it let a landlord/landlady insert any lease,
--    even straight as active, and no screen in either app used it.
-- 3. add_student_to_room(): the one way to add a student.
-- 4. accept_added_student(): the one way to accept an added student — only
--    with that student's current QR token, so a typed student ID never works.
-- 5. A trigger holds 4 true against a plain update through
--    leases_update_manager.

-- 1 ---------------------------------------------------------------------------
alter table public.leases
  add column if not exists added_by_landlord boolean not null default false;

-- 2 ---------------------------------------------------------------------------
drop policy if exists leases_insert_manager on public.leases;

-- 3 ---------------------------------------------------------------------------
create or replace function public.add_student_to_room(p_room uuid, p_student_no text, p_start date)
returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare
  v_me uuid := auth.uid();
  v_student uuid;
  v_rent numeric;
  v_id uuid;
begin
  if v_me is null then
    raise exception 'Not signed in';
  end if;
  if not public.is_verified_landlord(v_me) then
    raise exception 'Only a verified landlord/landlady can add students.';
  end if;

  select r.monthly_rent into v_rent
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
   where r.id = p_room and a.landlord_id = v_me and r.status = 'available';
  if not found then
    raise exception 'That room is not yours, or is no longer available.';
  end if;

  select sp.user_id into v_student
    from public.student_profiles sp
   where sp.student_id = trim(p_student_no);
  if v_student is null then
    raise exception 'No student has that student ID.';
  end if;

  if not public.student_may_lease(v_student) then
    raise exception 'OSAS has not verified this student yet, so they cannot be added to a room.';
  end if;

  if exists (
    select 1 from public.leases l
     where l.student_id = v_student and l.status in ('active', 'leave_requested', 'pending')
  ) then
    raise exception 'This student already has a stay or an application in progress.';
  end if;

  insert into public.leases
    (room_id, student_id, landlord_id, start_date, end_date, monthly_rent, status, added_by_landlord)
  values
    (p_room, v_student, v_me, coalesce(p_start, current_date),
     (coalesce(p_start, current_date) + interval '12 months')::date, v_rent, 'pending', true)
  returning id into v_id;

  return v_id;
end;
$$;

-- 4 ---------------------------------------------------------------------------
create or replace function public.accept_added_student(p_lease uuid, p_code text)
returns void
language plpgsql security definer set search_path to 'public' as $$
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
    select 1 from public.student_profiles sp
     where sp.user_id = v_student
       and sp.qr_code_token = trim(p_code)
       and sp.qr_token_expires_at > now()
  ) into v_ok;

  insert into public.qr_scans (scanner_id, student_id, method, result)
  values (v_me, v_student, 'qr', case when v_ok then 'verified' else 'mismatch' end);

  if not v_ok then
    raise exception 'That QR code is not this student''s, or it has expired. Ask them to open their QR screen again.';
  end if;

  perform set_config('app.qr_accept', 'true', true);
  update public.leases set status = 'active' where id = p_lease;
  perform set_config('app.qr_accept', 'false', true);
end;
$$;

revoke all on function public.add_student_to_room(uuid, text, date) from public, anon;
revoke all on function public.accept_added_student(uuid, text) from public, anon;
grant execute on function public.add_student_to_room(uuid, text, date) to authenticated;
grant execute on function public.accept_added_student(uuid, text) to authenticated;

-- 5 ---------------------------------------------------------------------------
create or replace function public.guard_added_lease() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  if new.added_by_landlord is distinct from old.added_by_landlord then
    raise exception 'How a lease was started cannot be changed.';
  end if;
  if old.added_by_landlord and old.status = 'pending' and new.status = 'active'
     and coalesce(current_setting('app.qr_accept', true), 'false') <> 'true' then
    raise exception 'Scan the student''s QR code to accept.';
  end if;
  return new;
end;
$$;

drop trigger if exists leases_guard_added on public.leases;
create trigger leases_guard_added
  before update on public.leases
  for each row execute function public.guard_added_lease();
