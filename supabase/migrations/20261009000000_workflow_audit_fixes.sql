-- Fixes from the 2026-10-08 workflow review of both apps.
--
--  1. A landlord/landlady OSAS rejected or sent back could put their own
--     delisted listing back up, and kept taking tenants: invite, accept and
--     walk-in add never asked whether they were still verified, or whether the
--     listing was still accredited and visible.
--  2. The student QR is for verified landlords/landladies only. Anyone signed in
--     could scan one and open the student's school ID and assessment of fees,
--     look students up by number, and message them forever after.
--  3. A stay could only end through the student's leave request. The
--     landlord/landlady can now end it (or terminate it) with a reason, the
--     student is told, and the stay goes into their history either way.
--  4. Men could apply to a female-only boarding house and vice versa. Nothing
--     compared gender_policy with the student's sex, and the student could
--     change their sex at will.
--  5. Utility bills could be posted on any lease, for any month, and changed or
--     deleted after they were paid — and a bill on an ended stay blocks the
--     student from renting anywhere (past_stay_balance).
--  6. Payments: a student could swap the receipt on a submitted or confirmed
--     payment; one receipt could cover two submissions within 24 hours; a
--     landlord/landlady could delete a student's pending submission.
--  7. A verified account could swap its approved ID documents.
--  8. Smaller ones: application terms the student wrote themselves, a due date
--     made stricter after the fact, an application form usable twice, OSAS
--     notified of every payment, any verified landlord/landlady reading any
--     student's debt, hidden listings still served by the API, a suspension
--     reason the landlord/landlady never saw, tenants of a suspended or expired
--     listing losing sight of their own room.

create or replace function pg_temp.patch_fn(p_fn regproc, p_old text, p_new text)
returns void
language plpgsql
as $$
declare
  d text := pg_get_functiondef(p_fn);
begin
  if position(p_old in d) = 0 then
    raise exception 'patch_fn: % does not contain: %', p_fn, p_old;
  end if;
  execute replace(d, p_old, p_new);
end $$;

-- ---- Helpers ------------------------------------------------------------------

-- Who a listing accepts against the student's sex on record. 'U' (not given)
-- and null only fit a co-ed place.
create or replace function public.assert_gender_fits(p_student uuid, p_room uuid)
returns void
language plpgsql stable security definer set search_path = public as $$
declare
  v_policy text;
  v_sex text;
begin
  select a.gender_policy into v_policy
    from public.rooms r join public.accommodations a on a.id = r.accommodation_id
   where r.id = p_room;
  select upper(btrim(coalesce(u.sex, ''))) into v_sex from public.users u where u.id = p_student;
  if v_policy = 'male' and v_sex is distinct from 'M' then
    raise exception 'This accommodation only takes male students.' using errcode = '42501';
  end if;
  if v_policy = 'female' and v_sex is distinct from 'F' then
    raise exception 'This accommodation only takes female students.' using errcode = '42501';
  end if;
end $$;
revoke all on function public.assert_gender_fits(uuid, uuid) from public, anon;
-- guard_lease_writes runs as the signed-in student.
grant execute on function public.assert_gender_fits(uuid, uuid) to authenticated;

-- What a student owes on stays that have ended, for the checks that keep them
-- from starting a new one. Unchecked, so only the functions below call it;
-- past_stay_balance() is the question clients may ask, about themselves.
create or replace function public.owed_on_past_stays(p_student uuid)
returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(sum(r.balance), 0)
    from public.leases l cross join lateral public.ledger_rows(l.id) r
   where l.student_id = p_student and l.status::text in ('ended', 'terminated') and r.kind in ('rent', 'bill');
$$;
revoke all on function public.owed_on_past_stays(uuid) from public, anon, authenticated;

-- Any verified landlord/landlady could ask this about any student.
create or replace function public.past_stay_balance(p_student uuid)
returns numeric
language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null or auth.uid() = p_student or public.is_admin(auth.uid())
              then public.owed_on_past_stays(p_student) else 0 end;
$$;

-- A tenant's own place stays readable whatever OSAS does to the listing:
-- suspending or expiring it used to blank the room and accommodation out of
-- the student's My Stay and History, because every read policy said
-- "accredited".
create or replace function public.tenant_of_accommodation(p_accommodation uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.leases l join public.rooms r on r.id = l.room_id
                  where r.accommodation_id = p_accommodation and l.student_id = auth.uid());
$$;
create or replace function public.tenant_of_room(p_room uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.leases l where l.room_id = p_room and l.student_id = auth.uid());
$$;
revoke all on function public.tenant_of_accommodation(uuid), public.tenant_of_room(uuid) from public, anon;
grant execute on function public.tenant_of_accommodation(uuid), public.tenant_of_room(uuid) to authenticated;

create policy accommodations_select_tenant on public.accommodations
  for select to authenticated using (public.tenant_of_accommodation(id));
create policy rooms_select_tenant on public.rooms
  for select to authenticated using (public.tenant_of_room(id));
create policy accommodation_images_select_tenant on public.accommodation_images
  for select to authenticated using (public.tenant_of_accommodation(accommodation_id));
create policy accommodation_amenities_select_tenant on public.accommodation_amenities
  for select to authenticated using (public.tenant_of_accommodation(accommodation_id));
create policy accommodation_policies_select_tenant on public.accommodation_policies
  for select to authenticated using (public.tenant_of_accommodation(accommodation_id));
create policy room_images_select_tenant on public.room_images
  for select to authenticated using (public.tenant_of_room(room_id));

-- ---- 1. Only a verified landlord/landlady relists or takes tenants ------------

select pg_temp.patch_fn('public.lock_verification_columns',
  $p$        elsif auth.uid() = old.landlord_id
              and new.landlord_id = old.landlord_id$p$,
  $p$        elsif auth.uid() = old.landlord_id
              and new.landlord_id = old.landlord_id
              -- Rejecting or sending a landlord/landlady back delists their
              -- listings (tg_revoke_on_unverify); this is what keeps them down.
              and public.is_verified_landlord(old.landlord_id)$p$);

-- "Hide their listings" covered only the listings that existed when OSAS said
-- so; one created afterwards went up in plain view.
select pg_temp.patch_fn('public.lock_verification_columns',
  $p$    if tg_op = 'INSERT' then
      if new.status::text not in ('pending', 'draft') then$p$,
  $p$    if tg_op = 'INSERT' then
      new.hidden_from_listings := exists (select 1 from public.account_standing s
                                           where s.user_id = new.landlord_id and 'listings' = any(s.restrictions));
      if new.status::text not in ('pending', 'draft') then$p$);

select pg_temp.patch_fn('public.invite_application',
  $p$  if (select u.role::text from public.users u where u.id = v_me) <> 'landlord' then
    raise exception 'Only the landlord/landlady can send an application form';
  end if;$p$,
  $p$  if not public.is_verified_landlord(v_me) then
    raise exception 'Only a landlord/landlady OSAS has verified can send an application form.';
  end if;$p$);
select pg_temp.patch_fn('public.invite_application',
  $p$      and r.status = 'available'
  ) then$p$,
  $p$      and r.status = 'available'
      and a.status = 'accredited' and not a.hidden_from_listings
  ) then$p$);
select pg_temp.patch_fn('public.invite_application',
  $p$    raise exception 'OSAS has not verified this student yet, so they cannot be offered a room.';
  end if;$p$,
  $p$    raise exception 'OSAS has not verified this student yet, so they cannot be offered a room.';
  end if;

  perform public.assert_gender_fits(v_student, v_room);$p$);
select pg_temp.patch_fn('public.invite_application',
  $p$public.past_stay_balance(v_student)$p$, $p$public.owed_on_past_stays(v_student)$p$);

select pg_temp.patch_fn('public.add_student_to_room',
  $p$where r.id = p_room and a.landlord_id = v_me and r.status = 'available';$p$,
  $p$where r.id = p_room and a.landlord_id = v_me and r.status = 'available'
     and a.status = 'accredited' and not a.hidden_from_listings;$p$);
select pg_temp.patch_fn('public.add_student_to_room',
  $p$    raise exception 'OSAS has not verified this student yet, so they cannot be added to a room.';
  end if;$p$,
  $p$    raise exception 'OSAS has not verified this student yet, so they cannot be added to a room.';
  end if;
  perform public.assert_gender_fits(v_student, p_room);$p$);
select pg_temp.patch_fn('public.add_student_to_room',
  $p$public.past_stay_balance(v_student)$p$, $p$public.owed_on_past_stays(v_student)$p$);

-- ---- 2. The QR scanner is for verified landlords/landladies -------------------

select pg_temp.patch_fn('public.verify_student_qr',
  $p$  if me is null then
    raise exception 'Not signed in';
  end if;$p$,
  $p$  if me is null then
    raise exception 'Not signed in';
  end if;
  if not public.is_verified_landlord(me) then
    raise exception 'Only a landlord/landlady OSAS has verified can scan student QR codes.' using errcode = '42501';
  end if;$p$);
select pg_temp.patch_fn('public.verify_student_qr',
  $p$  elsif public.get_my_role() in ('landlord', 'admin') then$p$,
  $p$  else$p$);

-- Seeing the school ID and assessment of fees is how the landlord/landlady
-- checks the person in front of them is really enrolled at ISU.
select pg_temp.patch_fn('public.scanned_student_docs',
  $p$begin
  if not exists ($p$,
  $p$begin
  if not public.is_verified_landlord(auth.uid()) then
    return null;
  end if;
  if not exists ($p$);

select pg_temp.patch_fn('public.accept_added_student',
  $p$  if v_me is null then
    raise exception 'Not signed in';
  end if;$p$,
  $p$  if v_me is null then
    raise exception 'Not signed in';
  end if;
  if not public.is_verified_landlord(v_me) then
    raise exception 'Only a landlord/landlady OSAS has verified can accept a student.' using errcode = '42501';
  end if;$p$);

create or replace function public.may_message(p_other uuid) returns boolean
language sql stable set search_path = public as $$
  select exists (select 1 from public.leases l
                  where (l.student_id = auth.uid() and l.landlord_id = p_other)
                     or (l.landlord_id = auth.uid() and l.student_id = p_other))
      or (public.get_my_role() = 'student'
          and exists (select 1 from public.accommodations a
                       where a.landlord_id = p_other and a.status = 'accredited'))
      or (public.is_verified_landlord(auth.uid())
          and exists (select 1 from public.qr_scans s
                       where s.scanner_id = auth.uid() and s.student_id = p_other
                         and s.method = 'qr' and s.result in ('verified', 'unverified')));
$$;

-- ---- 3, 4, 8. Lease writes ----------------------------------------------------

create or replace function public.guard_lease_writes()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  r public.rooms;
  v_owed numeric;
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_start_day int;
begin
  -- A stay that closes ends no later than today in Manila. The apps sent the
  -- phone's UTC date, which is yesterday every morning before 8.
  if tg_op = 'UPDATE' and new.status in ('ended', 'terminated') and old.status is distinct from new.status then
    new.end_date := least(coalesce(old.end_date, v_today), v_today);
  end if;

  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;

  if tg_op = 'INSERT' then
    select * into r from public.rooms where id = new.room_id;
    if r.id is null then
      raise exception 'That room is not open for applications.' using errcode = '42501';
    end if;
    if not exists (select 1 from public.accommodations a
                    where a.id = r.accommodation_id and a.status = 'accredited' and not a.hidden_from_listings) then
      raise exception 'That accommodation is not taking applications right now.' using errcode = '42501';
    end if;
    perform public.assert_gender_fits(new.student_id, new.room_id);
    v_owed := public.past_stay_balance(new.student_id);
    if v_owed > 0.009 then
      raise exception 'You still owe ₱% on a past stay. Settle it with that landlord/landlady before applying.', to_char(v_owed, 'FM999,999,990.00');
    end if;
    if new.start_date < v_today then
      raise exception 'The move-in date can''t be in the past.';
    end if;
    if new.end_date <= new.start_date then
      raise exception 'A stay has to end after it starts.';
    end if;
    new.monthly_rent := round(case when r.rent_basis = 'person' then r.monthly_rent
                             else r.monthly_rent / greatest(coalesce(r.capacity, 1), 1) end, 2);
    new.added_by_landlord := false;
    new.advance_paid := null;
    new.deposit_paid := null;
    -- The landlord/landlady's to set, not the applicant's: back to the defaults.
    new.rent_due_day := null;
    new.grace_days := 3;
    new.allow_partial := true;
    new.partial_min_pct := 10;
    return new;
  end if;

  if (new.room_id, new.landlord_id) is distinct from (old.room_id, old.landlord_id) then
    raise exception 'A lease cannot be moved to another room or landlord/landlady.' using errcode = '42501';
  end if;
  if old.status in ('ended', 'terminated', 'rejected') and new.status is distinct from old.status then
    raise exception 'This lease is closed. Start a new one instead.' using errcode = '42501';
  end if;
  if old.status <> 'pending'
     and (new.monthly_rent, new.water_billing, new.water_flat_fee, new.electric_billing, new.electric_flat_fee,
          new.wifi_billing, new.wifi_flat_fee)
         is distinct from
         (old.monthly_rent, old.water_billing, old.water_flat_fee, old.electric_billing, old.electric_flat_fee,
          old.wifi_billing, old.wifi_flat_fee) then
    raise exception 'The rent and utility terms are fixed once a stay is accepted.' using errcode = '42501';
  end if;

  -- Moving the due day earlier or cutting the grace turned months that were
  -- fine yesterday overdue today. Once a stay runs, only the lenient way.
  if old.status <> 'pending' then
    v_start_day := least(extract(day from old.start_date)::int, 28);
    if coalesce(new.rent_due_day, v_start_day) < coalesce(old.rent_due_day, v_start_day)
       or new.grace_days < old.grace_days then
      raise exception 'Once a stay is running, rent can only fall due later or get more grace, not less.' using errcode = '42501';
    end if;
  end if;

  -- Accepting an application asks again what offering the form asked: things
  -- change while it sits there.
  if old.status = 'pending' and new.status = 'active' then
    if not public.is_verified_landlord(auth.uid()) then
      raise exception 'Only a landlord/landlady OSAS has verified can accept a tenant.' using errcode = '42501';
    end if;
    if not exists (select 1 from public.rooms rm join public.accommodations a on a.id = rm.accommodation_id
                    where rm.id = new.room_id and a.status = 'accredited' and not a.hidden_from_listings) then
      raise exception 'This accommodation is not accredited and listed right now, so it can''t take tenants.' using errcode = '42501';
    end if;
    if not public.student_may_lease(new.student_id) then
      raise exception 'OSAS has not verified this student, or has paused their applications.' using errcode = '42501';
    end if;
    perform public.assert_gender_fits(new.student_id, new.room_id);
  end if;

  -- The landlord/landlady ending a stay the student did not ask to leave says why.
  if old.status = 'active' and new.status in ('ended', 'terminated')
     and nullif(btrim(coalesce(new.decision_reason, '')), '') is null then
    raise exception 'Give a reason for ending this stay — the student is told it.';
  end if;
  return new;
end $$;

-- A form is good for one application; the app cleared it, a direct insert did not.
create or replace function public.tg_lease_uses_invite() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.conversations c
     set invited_room_id = null, invited_at = null
   where c.invited_room_id = new.room_id
     and ((c.user_a_id = new.student_id and c.user_b_id = new.landlord_id)
       or (c.user_b_id = new.student_id and c.user_a_id = new.landlord_id));
  return null;
end $$;
revoke all on function public.tg_lease_uses_invite() from public, anon, authenticated;
create trigger trg_lease_uses_invite after insert on public.leases
  for each row when (new.status = 'pending' and not new.added_by_landlord)
  execute function public.tg_lease_uses_invite();

-- Every closed stay goes into the student's history, which is what rating it
-- hangs off. The app wrote this after a leave approval, as a second request
-- that could fail on its own.
create or replace function public.tg_lease_history() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.boarding_history (student_id, accommodation_id, accommodation_name, room_type, period_start, period_end, end_reason)
  select new.student_id, a.id, a.name, r.room_type::text, new.start_date, new.end_date,
         coalesce(new.ended_reason, new.status::text)
    from public.rooms r join public.accommodations a on a.id = r.accommodation_id
   where r.id = new.room_id;
  return null;
end $$;
revoke all on function public.tg_lease_history() from public, anon, authenticated;
create trigger trg_lease_history after update of status on public.leases
  for each row when (new.status in ('ended', 'terminated') and old.status is distinct from new.status)
  execute function public.tg_lease_history();

create or replace function public.tg_lease_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_room text := public.room_display(new.room_id);
  v_why text := coalesce(' Reason: ' || nullif(trim(new.decision_reason), ''), '');
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' and new.added_by_landlord then
      perform public.notify_peer(new.student_id, 'lease', 'Added to a room',
        'Your ' || public.landlord_title(new.landlord_id) || ' added you to ' || v_room || '. Show them your student QR to confirm.',
        '/student/profile/qr', new.landlord_id);
    elsif new.status = 'pending' then
      perform public.notify_peer(new.landlord_id, 'lease', 'New application',
        'Applied for ' || v_room, '/manager/messages?to=' || new.student_id, new.student_id);
    end if;
    return null;
  end if;

  if new.status is not distinct from old.status then return null; end if;

  if old.status = 'pending' and new.status = 'active' then
    if new.added_by_landlord then
      perform public.notify_peer(new.student_id, 'lease', 'Stay confirmed',
        'Your stay at ' || v_room || ' is confirmed.', '/student/stay', new.landlord_id);
    else
      perform public.notify_peer(new.student_id, 'lease', 'Application accepted',
        'You''re in! Your application for ' || v_room || ' was accepted.', '/student/stay', new.landlord_id);
    end if;
  elsif old.status = 'pending' and new.status = 'rejected' then
    perform public.notify_peer(new.student_id, 'lease', 'Application declined',
      'Your application for ' || v_room || ' was declined.' || v_why,
      '/student/profile', new.landlord_id);
  elsif new.status = 'leave_requested' then
    perform public.notify_peer(new.landlord_id, 'lease', 'Leave request',
      'A tenant requested to leave '
        || coalesce((select a.name from public.rooms r join public.accommodations a on a.id = r.accommodation_id
                      where r.id = new.room_id), 'their room') || '.',
      '/manager/tenant/' || new.id, new.student_id);
  elsif old.status = 'leave_requested' and new.status = 'ended' then
    perform public.notify_peer(new.student_id, 'lease', 'Leave request approved',
      'Your move-out from ' || v_room || ' was approved. You can now rate your stay.',
      '/student/profile/history', new.landlord_id);
  elsif old.status = 'leave_requested' and new.status = 'active' then
    perform public.notify_peer(new.student_id, 'lease', 'Leave request declined',
      'Your request to leave ' || v_room || ' was declined.' || v_why,
      '/student/stay', new.landlord_id);
  elsif new.status = 'terminated' then
    perform public.notify_peer(new.student_id, 'lease', 'Stay terminated',
      'Your ' || public.landlord_title(new.landlord_id) || ' terminated your stay at ' || v_room || '.' || v_why,
      '/student/profile/history', new.landlord_id);
  elsif new.status = 'ended' then
    perform public.notify_peer(new.student_id, 'lease', 'Stay ended',
      'Your ' || public.landlord_title(new.landlord_id) || ' ended your stay at ' || v_room || '.' || v_why
        || ' You can now rate your stay.',
      '/student/profile/history', new.landlord_id);
  end if;
  return null;
end $$;

-- Withdrawing an application deletes it, which told the landlord/landlady nothing.
create or replace function public.tg_lease_withdrawn() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Gone with the account itself (a cascade): nobody left to tell.
  if not exists (select 1 from public.users where id = old.landlord_id) then return null; end if;
  perform public.notify_peer(old.landlord_id, 'lease',
    case when old.added_by_landlord then 'Student declined the room' else 'Application withdrawn' end,
    coalesce((select full_name from public.users where id = old.student_id), 'A student')
      || case when old.added_by_landlord then ' declined being added to ' else ' withdrew their application for ' end
      || public.room_display(old.room_id) || '.',
    '/manager/messages?to=' || old.student_id, old.student_id);
  return null;
end $$;
revoke all on function public.tg_lease_withdrawn() from public, anon, authenticated;
create trigger trg_lease_withdrawn after delete on public.leases
  for each row when (old.status = 'pending')
  execute function public.tg_lease_withdrawn();

-- Not every leave request is early.
select pg_temp.patch_fn('public.trg_lease_leave',
  $p$        || ' early.',$p$,
  $p$        || case when new.end_date > (now() at time zone 'Asia/Manila')::date then ' early.' else '.' end,$p$);

-- The student's sex is what OSAS verified against their ID, and now decides
-- which boarding houses take them. Set at registration, corrected by OSAS.
select pg_temp.patch_fn('public.lock_user_privileges',
  $p$    if new.email is distinct from old.email and not allow_sync then
      raise exception 'Change your e-mail address through your account settings.';
    end if;$p$,
  $p$    if new.email is distinct from old.email and not allow_sync then
      raise exception 'Change your e-mail address through your account settings.';
    end if;
    if old.registered_at is not null and new.sex is distinct from old.sex then
      raise exception 'Your sex on record is set at registration. Ask OSAS to correct it.';
    end if;$p$);

-- ---- 5. Utility bills ---------------------------------------------------------

create or replace function public.guard_utility_bills() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  l public.leases;
  v_billing text;
  v_today date := (now() at time zone 'Asia/Manila')::date;
begin
  if auth.uid() is null or public.is_admin(auth.uid()) then return coalesce(new, old); end if;

  if tg_op <> 'INSERT'
     and (tg_op = 'DELETE' or (new.lease_id, new.utility, new.month, new.amount) is distinct from (old.lease_id, old.utility, old.month, old.amount))
     and exists (select 1 from public.payments p where p.bill_id = old.id and p.status::text not in ('rejected', 'withdrawn')) then
    raise exception 'This bill has payments against it, so it can''t be changed or removed. Forgive what is left instead.';
  end if;
  if tg_op = 'DELETE' then return old; end if;

  select * into l from public.leases where id = new.lease_id;
  if l.status::text in ('pending', 'rejected') then
    raise exception 'Bills go on an accepted stay.';
  end if;
  v_billing := case new.utility when 'water' then l.water_billing::text
                                when 'electric' then l.electric_billing::text
                                else l.wifi_billing::text end;
  if v_billing is distinct from 'own_meter' and v_billing is distinct from 'split' then
    raise exception 'This stay''s terms don''t bill that utility monthly.';
  end if;
  if date_trunc('month', new.month) < date_trunc('month', l.start_date)
     or date_trunc('month', new.month) > date_trunc('month', l.end_date) then
    raise exception 'That month is outside this stay.';
  end if;
  -- The last month's meter reading arrives after move-out; a month is enough.
  if l.status::text in ('ended', 'terminated') and v_today > l.end_date + 30 then
    raise exception 'This stay ended more than 30 days ago, so no more bills can go on it.';
  end if;
  return new;
end $$;
revoke all on function public.guard_utility_bills() from public, anon, authenticated;
create trigger guard_utility_bills before insert or update or delete on public.utility_bills
  for each row execute function public.guard_utility_bills();

-- ---- 6. Payments --------------------------------------------------------------

select pg_temp.patch_fn('public.tg_payment_rules',
  $p$    if new.amount is distinct from old.amount then$p$,
  $p$    -- The receipt is the evidence a confirmation rests on. It was editable
    -- after submission, and after confirmation.
    if (new.method, new.txn_reference, new.proof_url, new.proof_hash, new.description, new.note, new.promise_date, new.batch_id)
       is distinct from
       (old.method, old.txn_reference, old.proof_url, old.proof_hash, old.description, old.note, old.promise_date, old.batch_id) then
      raise exception 'A payment''s details and receipt can''t be changed once it is submitted. Withdraw it and submit again.';
    end if;
    if new.amount is distinct from old.amount then$p$);

-- One transfer split over several months (record_payment/record_payments)
-- shares its reference and receipt; that, not "same lease within a day", is
-- the exception. The old one let one receipt pay for two submissions.
select pg_temp.patch_fn('public.tg_payment_rules',
  $p$not (p.lease_id = new.lease_id and p.created_at > now() - interval '24 hours')$p$,
  $p$not (new.batch_id is not null and p.batch_id = new.batch_id)$p$);

-- A submission the landlord/landlady doubts is rejected with a reason, not
-- deleted; deleting a forgiven balance brought it back silently.
drop policy if exists payments_delete_manager on public.payments;

-- OSAS does not verify payments; every admin got one notice per row.
drop trigger if exists trg_payment_flag on public.payments;
drop function if exists public.trg_payment_flag();

-- ---- 7. Verified documents stay as OSAS approved them -------------------------

create or replace function public.guard_verified_documents() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return coalesce(new, old); end if;
  if exists (select 1 from public.users u
              where u.id = coalesce(new.user_id, old.user_id)
                and u.status in ('reviewing', 'verified', 'suspended')) then
    raise exception 'OSAS is reviewing or has verified your documents. Ask OSAS to change them.' using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;
create trigger guard_verified_documents before insert or update or delete on public.verification_documents
  for each row execute function public.guard_verified_documents();

-- ---- 8. OSAS's side -----------------------------------------------------------

-- A decision releases the review claim, as decide_accreditation does; the
-- console now decides accounts through this function instead of five writes.
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$update public.users set status = p_status, updated_at = now() where id = p_user;$p$,
  $p$update public.users set status = p_status, reviewing_by = null, reviewing_at = null, updated_at = now() where id = p_user;$p$);

-- Hidden listings were filtered by the app alone; the API served them.
drop policy if exists accommodations_select_accredited on public.accommodations;
create policy accommodations_select_accredited on public.accommodations
  for select using (status = 'accredited' and not hidden_from_listings);

-- Why OSAS suspended a listing. The console said the reason was shown to the
-- landlord/landlady; it only ever reached the audit log.
alter table public.accommodations add column if not exists status_note text;
drop trigger if exists lock_columns on public.accommodations;
create trigger lock_columns before update on public.accommodations
  for each row execute function public.lock_columns('rating_avg', 'reviews_count', 'status_note');

create or replace function public.tg_accreditation_status_change() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_name text := coalesce(nullif(trim(new.name), ''), 'Your boarding house');
  v_student uuid;
begin
  if new.status is not distinct from old.status then return new; end if;

  -- Restoring a suspension does not outlast the accreditation term.
  if old.status = 'suspended' and new.status = 'accredited'
     and new.accreditation_expires_at is not null and new.accreditation_expires_at <= now() then
    raise exception 'Its accreditation term ended while it was suspended. The landlord/landlady has to renew it instead.';
  end if;

  -- A decision written straight to the row (an accommodo-web build from before
  -- decide_accreditation) still closes the round it answered, so the queue
  -- does not keep a request nobody will ever look at again.
  if old.status::text in ('pending', 'reviewing')
     and new.status::text in ('accredited', 'needs_revision', 'rejected') then
    update public.accreditation_rounds
       set decided_at = now(), decided_by = auth.uid(),
           decision = case new.status::text when 'accredited' then 'approved' when 'needs_revision' then 'returned' else 'rejected' end
     where accommodation_id = new.id and decided_at is null and kind in ('new', 'resubmission', 'appeal');
  end if;

  if old.status = 'suspended' and new.status = 'accredited' then
    perform public.notify_system(new.landlord_id, 'verification', 'Accreditation restored',
      v_name || ' is accredited again and visible to students.', '/manager/properties/' || new.id::text);
  end if;

  if new.status::text in ('suspended', 'expired') then
    perform public.notify_system(
      new.landlord_id, 'verification',
      case new.status::text when 'suspended' then 'Accreditation suspended' else 'Accreditation ended' end,
      case new.status::text
        when 'suspended' then v_name || ' is suspended by OSAS and hidden from students.'
          || coalesce(' Reason: ' || nullif(trim(new.status_note), ''), ' Check OSAS for the reason.')
        else v_name || '''s accreditation has ended and it is hidden from students. Renew it from the listing.'
      end,
      '/manager/properties/' || new.id::text
    );
    for v_student in
      select distinct l.student_id
        from public.leases l join public.rooms r on r.id = l.room_id
       where r.accommodation_id = new.id and l.status in ('active', 'leave_requested')
    loop
      perform public.notify_system(
        v_student, 'lease',
        case new.status::text when 'suspended' then 'Your boarding house was suspended' else 'Your boarding house is no longer accredited' end,
        v_name || ' is no longer accredited by OSAS'
          || case new.status::text when 'suspended' then ' while it is suspended' else '' end
          || '. Your stay is not ended by this. Contact OSAS from Support if you have concerns.',
        '/student/stay'
      );
    end loop;
  end if;
  return new;
end $$;
