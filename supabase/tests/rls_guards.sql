-- The smallest thing that fails if 20260914000000 regresses.
--
-- Run it against any environment that has at least one active lease with a
-- payment on it:
--
--   supabase db execute --file supabase/tests/rls_guards.sql
--
-- or paste it into the SQL editor. On an empty local database (`supabase db
-- reset`), load tests/fixture.sql first — CI does exactly that. It impersonates a real student via
-- request.jwt.claims and asserts what that student cannot do. It writes
-- nothing: each write is rolled back by its own exception block.
--
-- Expected output:
--   A  <small number> of <total>   -- NOT "173 of 173"
--   B  PASS
--   C  PASS
--   D  PASS
--   M1-M3, R1-R2  PASS
--   V1-V2  PASS
--   S1-S8  PASS
--   U1-U3  PASS
--   F1-F3  PASS
--   P1-P2  PASS
--   T1-T4  PASS
--   PA1-PA5  PASS
--   AC1-AC7  PASS
--   H1-H22  PASS
--   AA1-AA8  PASS
--   PY1-PY18  PASS

create or replace function pg_temp.rls_check() returns table(test text, outcome text)
language plpgsql as $$
declare
  v_student uuid; v_total int; v_visible int; v_others int; v_payment uuid; v_msg text;
begin
  select l.student_id into v_student
    from public.leases l join public.payments p on p.lease_id = l.id
   where l.status = 'active' limit 1;
  if v_student is null then
    raise exception 'no active lease with a payment to test against';
  end if;

  select count(*) into v_total from public.users;
  select p.id into v_payment from public.payments p join public.leases l on l.id = p.lease_id
   where l.student_id = v_student limit 1;

  perform set_config('request.jwt.claims',
                     json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- A. A student must not be able to enumerate the user table. Before the
  -- migration this returned every row, email and phone included.
  select count(*) into v_visible from public.users;
  select count(*) into v_others  from public.users where id <> v_student;
  test := 'A: users rows visible to one student';
  outcome := v_visible || ' of ' || v_total || ' (others: ' || v_others || ')';
  return next;

  -- B. The payment verification workflow is the manager's, not the student's.
  begin
    update public.payments set status = 'paid', paid_at = now() where id = v_payment;
    outcome := 'FAIL - student marked own payment paid';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then 'FAIL - student marked own payment paid'
                    else 'PASS - ' || v_msg end;
  end;
  test := 'B: student sets own payment to paid'; return next;

  -- C. Nor by submitting one that claims to be paid already.
  begin
    insert into public.payments (lease_id, month, amount, method, status, paid_at)
    select p.lease_id, '2027-01-01', 1000, 'cash', 'paid', now()
      from public.payments p where p.id = v_payment;
    outcome := 'FAIL - pre-paid insert accepted';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then 'FAIL - pre-paid insert accepted'
                    else 'PASS - ' || v_msg end;
  end;
  test := 'C: student inserts an already-paid payment'; return next;

  -- D. Money invariant, enforced on the column rather than in each caller.
  begin
    insert into public.payments (lease_id, month, amount, method, status)
    select p.lease_id, '2027-02-01', -50, 'cash', 'pending_verification'
      from public.payments p where p.id = v_payment;
    outcome := 'FAIL - negative amount accepted';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then 'FAIL - negative amount accepted'
                    else 'PASS - ' || v_msg end;
  end;
  test := 'D: negative payment amount'; return next;

  reset role;
end $$;

-- The other half of the contract. A guard that blocks the student is only
-- correct if it still lets the manager verify, log and delete -- otherwise the
-- first check above passes while the app is broken.
create or replace function pg_temp.mgr_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_mgr uuid; v_payment uuid; v_msg text; v_lease uuid; v_month date; v_left numeric;
begin
  select l.landlord_id, p.id, l.id into v_mgr, v_payment, v_lease
    from public.leases l join public.payments p on p.lease_id = l.id
   where l.status = 'active' and p.status <> 'paid' limit 1;
  -- M2 logs against the first month still owed (20261006020000: months in order,
  -- never more than owed), worked out before switching roles.
  select m::date, public.payment_due(v_lease, 'rent', m::date) - c.confirmed - c.pending
    into v_month, v_left
    from generate_series((select date_trunc('month', start_date) from public.leases where id = v_lease),
                         date_trunc('month', now()) + interval '2 months', interval '1 month') m,
         lateral public.payment_covered(v_lease, 'rent', m::date, null, null) c
   where public.payment_due(v_lease, 'rent', m::date) - c.confirmed - c.pending > 0.009
   order by m limit 1;

  perform set_config('request.jwt.claims',
                     json_build_object('sub', v_mgr, 'role', 'authenticated')::text, true);
  set local role authenticated;

  begin
    update public.payments set status = 'paid', paid_at = now(), verified_by = v_mgr
     where id = v_payment;
    outcome := 'PASS';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then 'PASS'
                    else 'FAIL - manager blocked: ' || v_msg end;
  end;
  test := 'M1: manager verifies a payment'; return next;

  begin
    insert into public.payments (lease_id, month, amount, method, status, paid_at, verified_by)
    values (v_lease, v_month, least(v_left, 1500), 'cash', 'paid', now(), v_mgr);
    outcome := 'PASS';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then 'PASS'
                    else 'FAIL - manager blocked: ' || v_msg end;
  end;
  test := 'M2: manager logs a cash payment as paid'; return next;

  begin
    delete from public.payments where id = v_payment;
    outcome := 'PASS';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then 'PASS'
                    else 'FAIL - manager blocked: ' || v_msg end;
  end;
  test := 'M3: manager deletes a payment'; return next;

  reset role;
end $$;

-- The RPC surface. notify_admins() took a title, body and link and wrote them
-- into every admin's feed, with no caller check; it was reachable first without
-- a session at all, then with any session. Both are closed, and the 13 the apps
-- do call must keep working.
create or replace function pg_temp.rpc_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_student uuid; v_msg text;
begin
  select l.student_id into v_student from public.leases l where l.status='active' limit 1;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  set local role authenticated;

  begin
    perform public.notify_admins('x', 'x', 'system', null);
    outcome := 'FAIL - a signed-in user can spam every admin';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := 'PASS - ' || v_msg;
  end;
  test := 'R1: notify_admins from a student'; return next;

  reset role;
end $$;

-- The row the mobile update gate reads. Two things have to hold: a signed-out
-- client can read it (the "you must update" wall has to be able to appear on the
-- login screen, since a build old enough to be cut off may be too old to sign
-- in), and no client can write it -- the update floor locks every install out of
-- the app, so it must stay a service-role-only lever.
create or replace function pg_temp.release_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_student uuid; v_count int; v_msg text;
begin
  perform set_config('request.jwt.claims', '', true);
  set local role anon;
  begin
    select count(*) into v_count from public.app_release;
    outcome := case when v_count = 1 then 'PASS'
                    else 'FAIL - anon saw ' || v_count || ' rows, expected exactly 1' end;
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := 'FAIL - the login screen cannot read it: ' || v_msg;
  end;
  test := 'V1: signed-out client reads app_release'; return next;
  reset role;

  select l.student_id into v_student from public.leases l where l.status='active' limit 1;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    update public.app_release set min_supported_version_code = 999999 where id = 1;
    outcome := 'FAIL - a signed-in user can lock everyone out of the app';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then 'FAIL - a signed-in user can lock everyone out of the app'
                    else 'PASS - ' || v_msg end;
  end;
  test := 'V2: student raises the update floor'; return next;

  reset role;
end $$;


-- S. account_standing (20260923184828): OSAS's reasons and restrictions are
-- written only through admin_set_account_status(), read only by the person and
-- OSAS, and the `apply` restriction really does stop a lease.
create or replace function pg_temp.standing_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_student uuid; v_other uuid; v_admin uuid; v_msg text; v_count int; v_may boolean;
begin
  select u.id into v_student from public.users u join public.student_profiles sp on sp.user_id = u.id
   where u.role = 'student' and u.status = 'verified' and sp.osas_verified_at is not null limit 1;
  select id into v_other from public.users where role = 'student' and id <> v_student limit 1;
  select id into v_admin from public.users where is_superadmin limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into public.account_standing (user_id, restrictions) values (v_other, '{apply}');
    outcome := 'FAIL - a student wrote someone else''s standing';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then outcome else 'PASS - ' || v_msg end;
  end;
  test := 'S1: student writes account_standing directly'; return next;

  begin
    perform public.admin_set_account_status(v_other, 'suspended', 'test');
    outcome := 'FAIL - a student suspended another account';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := case when v_msg = 'rollback' then outcome else 'PASS - ' || v_msg end;
  end;
  test := 'S2: student calls admin_set_account_status'; return next;

  select count(*) into v_count from public.account_standing where user_id <> v_student;
  outcome := case when v_count = 0 then 'PASS' else 'FAIL - read ' || v_count || ' other people''s standing' end;
  test := 'S3: student reads others'' standing'; return next;
  reset role;

  -- S4/S5 change real rows, so both run inside one block that is rolled back.
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.admin_set_account_status(v_student, 'verified', 'test', null, '{apply}');
    v_may := public.student_may_lease(v_student);
    perform public.admin_set_account_status(v_student, 'suspended', 'test', null, '{}');
    perform public.admin_set_account_status(v_student, 'verified', null);
    reset role;
    raise exception 'rollback:%:%', v_may, public.student_may_lease(v_student);
  exception when others then
    get stacked diagnostics v_msg = message_text;
    reset role;
  end;
  outcome := case when v_msg like 'rollback:f:%' then 'PASS' else 'FAIL - ' || v_msg end;
  test := 'S4: `apply` restriction blocks student_may_lease'; return next;
  outcome := case when v_msg like 'rollback:%:t' then 'PASS' else 'FAIL - ' || v_msg end;
  test := 'S5: reactivation restores the verification stamp'; return next;

  -- S6 (20260923190739): a correction OSAS makes to a phone number survives
  -- the person's next sign-in, which rewrites auth.users.
  begin
    select id into v_other from public.users where role = 'student' limit 1;
    update public.users set phone = '+639000000001' where id = v_other;
    update auth.users set last_sign_in_at = now() where id = v_other;
    raise exception 'rollback:%', (select phone from public.users where id = v_other);
  exception when others then
    get stacked diagnostics v_msg = message_text;
  end;
  outcome := case when v_msg = 'rollback:+639000000001' then 'PASS' else 'FAIL - sign-in put back ' || v_msg end;
  test := 'S6: admin phone edit survives a sign-in'; return next;

  -- S7/S8 (20260923192143): a role change cannot pull someone out from under a
  -- live lease, and only the main admin can close an account.
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.admin_change_role((select student_id from public.leases where status = 'active' limit 1), 'landlord', 'test');
    v_msg := 'FAIL - changed the role of a student with an active lease';
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    reset role;
  end;
  outcome := case when v_msg = 'rollback' then 'FAIL - changed the role of a student with an active lease' else 'PASS - ' || v_msg end;
  test := 'S7: role change with a live lease'; return next;

  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.admin_close_account(v_other, 'test');
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    reset role;
  end;
  outcome := case when v_msg = 'rollback' then 'FAIL - a non-admin closed an account' else 'PASS - ' || v_msg end;
  test := 'S8: non-admin closes an account'; return next;
end $$;
create or replace function pg_temp.unverified_check() returns table(test text, outcome text)
language plpgsql as $$
declare
  v_pending uuid; v_verified uuid; v_acc uuid; v_msg text;
  v_student uuid; v_room uuid; v_landlord uuid; o4 text; o5 text; o6 text;
begin
  -- 20260924120000: an unverified landlord/landlady may sign in but may not add
  -- inventory. Skipped when there is no such account to impersonate.
  select id into v_pending from public.users where role = 'landlord' and status <> 'verified' limit 1;
  select a.landlord_id, a.id into v_verified, v_acc
    from public.accommodations a join public.users u on u.id = a.landlord_id
   where u.status = 'verified' limit 1;

  if v_pending is not null then
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', v_pending, 'role', 'authenticated')::text, true);
      set local role authenticated;
      insert into public.accommodations (landlord_id, name, status) values (v_pending, 'rls test', 'pending');
      raise exception 'rollback';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      reset role;
    end;
    outcome := case when v_msg = 'rollback' then 'FAIL - an unverified landlord/landlady added an accommodation' else 'PASS - ' || v_msg end;
    test := 'U1: unverified adds an accommodation'; return next;

    begin
      perform set_config('request.jwt.claims', json_build_object('sub', v_pending, 'role', 'authenticated')::text, true);
      set local role authenticated;
      insert into public.rooms (accommodation_id, label, status) values (v_acc, 'rls test', 'available');
      raise exception 'rollback';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      reset role;
    end;
    outcome := case when v_msg = 'rollback' then 'FAIL - an unverified landlord/landlady added a room' else 'PASS - ' || v_msg end;
    test := 'U2: unverified adds a room'; return next;
  end if;

  if v_verified is not null then
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', v_verified, 'role', 'authenticated')::text, true);
      set local role authenticated;
      insert into public.accommodations (landlord_id, name, status) values (v_verified, 'rls test', 'pending');
      raise exception 'rollback';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      reset role;
    end;
    outcome := case when v_msg = 'rollback' then 'PASS - verified landlord/landlady may add' else 'FAIL - ' || v_msg end;
    test := 'U3: verified adds an accommodation'; return next;

    -- 20261003000000: rooms and floors wait for accreditation, even for a
    -- verified landlord/landlady on their own listing.
    declare v_new uuid;
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', v_verified, 'role', 'authenticated')::text, true);
      set local role authenticated;
      insert into public.accommodations (landlord_id, name, status) values (v_verified, 'rls test', 'pending') returning id into v_new;
      insert into public.rooms (accommodation_id, label, status) values (v_new, 'rls test', 'available');
      raise exception 'rollback';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      reset role;
    end;
    outcome := case when v_msg = 'rollback' then 'FAIL - added a room to an unaccredited listing' else 'PASS - ' || v_msg end;
    test := 'U3b: room on an unaccredited listing'; return next;
  end if;

  -- U4-U6: a student OSAS has not verified may not apply for a room, and a
  -- landlord/landlady may not add them to one. U5 has OSAS verify the same
  -- student and retries, so U4 is known to fail on verification and nothing
  -- else. The room invite is set up first, as the app does before applying.
  -- Skipped when there is no such student or no available room.
  select u.id into v_student from public.users u join public.student_profiles sp on sp.user_id = u.id
   where u.role = 'student' and u.status = 'verified' and sp.osas_verified_at is null
     and not exists (select 1 from public.leases l where l.student_id = u.id
                      and l.status in ('pending', 'active', 'leave_requested'))
   limit 1;
  select r.id, a.landlord_id into v_room, v_landlord
    from public.rooms r join public.accommodations a on a.id = r.accommodation_id
   where r.status = 'available' limit 1;

  if v_student is not null and v_room is not null then
    begin
      insert into public.conversations (user_a_id, user_b_id, invited_room_id, invited_at)
      values (v_student, v_landlord, v_room, now());

      perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
      set local role authenticated;
      begin
        insert into public.leases (room_id, student_id, landlord_id, start_date, end_date, status)
        values (v_room, v_student, v_landlord, current_date, current_date + 365, 'pending');
        o4 := 'FAIL - an unverified student applied for a room';
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o4 := 'PASS - ' || v_msg;
      end;
      reset role;

      perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
      set local role authenticated;
      begin
        insert into public.leases (room_id, student_id, landlord_id, start_date, end_date, status)
        values (v_room, v_student, v_landlord, current_date, current_date + 365, 'pending');
        o6 := 'FAIL - a landlord/landlady added an unverified student to a room';
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o6 := 'PASS - ' || v_msg;
      end;
      reset role;

      -- No signed-in user, so trg_lock_osas lets the stamp through.
      perform set_config('request.jwt.claims', '', true);
      update public.student_profiles set osas_verified_at = now() where user_id = v_student;
      perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
      set local role authenticated;
      begin
        insert into public.leases (room_id, student_id, landlord_id, start_date, end_date, status)
        values (v_room, v_student, v_landlord, current_date, current_date + 365, 'pending');
        o5 := 'PASS - verified student may apply';
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o5 := 'FAIL - ' || v_msg;
      end;
      reset role;
      raise exception 'rollback';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      reset role;
      if v_msg <> 'rollback' then
        o4 := coalesce(o4, 'FAIL - ' || v_msg);
        o5 := coalesce(o5, 'FAIL - ' || v_msg);
        o6 := coalesce(o6, 'FAIL - ' || v_msg);
      end if;
    end;
    test := 'U4: unverified student applies for a room'; outcome := o4; return next;
    test := 'U5: same student, once verified, may apply'; outcome := o5; return next;
    test := 'U6: landlord/landlady adds an unverified student'; outcome := o6; return next;
  end if;
end $$;
-- F1-F3 (20260926000000): an admin with an authenticator app enrolled is only an
-- admin once the session has passed the code (aal2). Uses a throwaway factor
-- row that is rolled back with the rest of the block.
create or replace function pg_temp.mfa_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_admin uuid; v_aal1 boolean; v_aal2 boolean; v_role text; v_plain boolean; v_msg text;
begin
  select id into v_admin from public.users where is_superadmin limit 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated', 'aal', 'aal1')::text, true);
    v_plain := public.is_admin(v_admin);
    insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
    values (gen_random_uuid(), v_admin, 'rls test', 'totp', 'verified', now(), now());
    v_aal1 := public.is_admin(v_admin);
    v_role := public.get_my_role();
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    v_aal2 := public.is_admin(v_admin);
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
  end;
  outcome := case when v_msg <> 'rollback' then 'FAIL - ' || v_msg when v_plain then 'PASS' else 'FAIL - admin without MFA lost access' end;
  test := 'F1: admin without MFA is an admin'; return next;
  outcome := case when v_msg <> 'rollback' then 'FAIL - ' || v_msg when not v_aal1 and v_role is null then 'PASS' else 'FAIL - enrolled admin at aal1 still passes' end;
  test := 'F2: enrolled admin before the code'; return next;
  outcome := case when v_msg <> 'rollback' then 'FAIL - ' || v_msg when v_aal2 then 'PASS' else 'FAIL - enrolled admin at aal2 refused' end;
  test := 'F3: enrolled admin after the code'; return next;
end $$;
-- P1-P2 (20260926010000): a private file reference must point into the
-- writer's own upload folder, the same rule requirements already had.
create or replace function pg_temp.private_ref_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_student uuid; v_other uuid; v_msg text;
begin
  select l.student_id into v_student from public.leases l where l.status = 'active' limit 1;
  select id into v_other from public.users where id <> v_student limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into public.tickets (student_id, subject, description, photo_urls)
    values (v_student, 'rls test', 'rls test', array['cld:image:authenticated:jpg:accommo/docs/' || v_other || '/x']);
    raise exception 'rollback';
  exception when others then get stacked diagnostics v_msg = message_text;
  end;
  outcome := case when v_msg = 'rollback' then 'FAIL - pointed a ticket at someone else''s file' else 'PASS - ' || v_msg end;
  test := 'P1: ticket photo in another user''s folder'; return next;
  begin
    insert into public.tickets (student_id, subject, description, photo_urls)
    values (v_student, 'rls test', 'rls test', array['cld:image:authenticated:jpg:accommo/docs/' || v_student || '/x']);
    raise exception 'rollback';
  exception when others then get stacked diagnostics v_msg = message_text;
  end;
  outcome := case when v_msg = 'rollback' then 'PASS' else 'FAIL - ' || v_msg end;
  test := 'P2: ticket photo in own folder'; return next;
  reset role;
end $$;
-- T1-T4 (20260928120000): a reporter can't speak as OSAS, can't re-triage
-- their own ticket, and a reply on a resolved ticket reopens it. The fixture
-- ticket is created as postgres and everything is rolled back at the end;
-- outcomes are kept in variables because they are decided inside that block.
create or replace function pg_temp.ticket_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_student uuid; v_ticket uuid; v_msg text; v_n int; v_status text;
  o1 text; o2 text; o3 text; o4 text;
begin
  select l.student_id into v_student from public.leases l where l.status = 'active' limit 1;
  begin
    insert into public.tickets (student_id, subject, description, status)
    values (v_student, 'rls test', 'rls test', 'resolved') returning id into v_ticket;
    perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    set local role authenticated;

    begin
      insert into public.ticket_messages (ticket_id, author_id, author_role, body)
      values (v_ticket, v_student, 'agent', 'I am OSAS');
      o1 := 'FAIL - reporter posted as OSAS';
    exception when others then o1 := 'PASS';
    end;

    begin
      insert into public.tickets (student_id, subject, priority) values (v_student, 'rls test', 'urgent');
      o2 := 'FAIL - reporter filed an urgent ticket';
    exception when others then o2 := 'PASS';
    end;

    update public.tickets set priority = 'urgent' where id = v_ticket;
    get diagnostics v_n = row_count;
    o3 := case when v_n = 0 then 'PASS' else 'FAIL - reporter changed own ticket priority' end;

    insert into public.ticket_messages (ticket_id, author_id, author_role, body)
    values (v_ticket, v_student, 'student', 'still broken');
    select status into v_status from public.tickets where id = v_ticket;
    o4 := case when v_status = 'open' then 'PASS' else 'FAIL - status stayed ' || v_status end;

    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'rollback' then o4 := coalesce(o4, 'FAIL - ' || v_msg); end if;
  end;
  reset role;
  test := 'T1: reporter message as OSAS'; outcome := o1; return next;
  test := 'T2: reporter files an urgent ticket'; outcome := o2; return next;
  test := 'T3: reporter re-prioritises own ticket'; outcome := o3; return next;
  test := 'T4: reply reopens a resolved ticket'; outcome := o4; return next;
end $$;
create or replace function pg_temp.policy_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_student uuid := '00000000-0000-0000-0000-00000000b001';
  v_other uuid := '00000000-0000-0000-0000-00000000b002';
  v_admin uuid := '00000000-0000-0000-0000-00000000f001';
  v_live uuid; v_future uuid; v_n int; v_msg text;
  o1 text; o2 text; o3 text; o4 text; o5 text;
begin
  begin
    insert into public.policies (title, body, effective_date, created_by)
    values ('rls live', 'x', current_date, v_admin) returning id into v_live;
    insert into public.policies (title, body, effective_date, created_by)
    values ('rls future', 'x', current_date + 30, v_admin) returning id into v_future;
    insert into public.policy_acceptances (policy_id, user_id, revision) values (v_live, v_other, 1);

    perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    set local role authenticated;

    begin
      insert into public.policy_acceptances (policy_id, user_id, revision) values (v_live, v_student, 1);
      o1 := 'FAIL - direct acceptance insert allowed';
    exception when others then o1 := 'PASS';
    end;

    perform public.accept_policy(v_live);
    select count(*) into v_n from public.policy_acceptances where policy_id = v_live and user_id = v_student and revision = 1;
    o2 := case when v_n = 1 then 'PASS' else 'FAIL - accept_policy recorded nothing' end;

    begin
      perform public.accept_policy(v_future);
      o3 := 'FAIL - accepted a policy not yet in effect';
    exception when others then o3 := 'PASS';
    end;

    select count(*) into v_n from public.policy_acceptances where user_id <> v_student;
    o4 := case when v_n = 0 then 'PASS' else 'FAIL - saw ' || v_n || ' other acceptances' end;

    reset role;
    update public.policies set body = 'y', revision = 2 where id = v_live;
    update public.policies set body = 'z' where id = v_live;
    select count(*) into v_n from public.policy_versions where policy_id = v_live;
    o5 := case when v_n = 1 then 'PASS' else 'FAIL - ' || v_n || ' versions kept' end;

    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'rollback' then o5 := coalesce(o5, 'FAIL - ' || v_msg); end if;
  end;
  reset role;
  test := 'PA1: direct acceptance insert'; outcome := o1; return next;
  test := 'PA2: accept_policy records current revision'; outcome := o2; return next;
  test := 'PA3: accept a future policy'; outcome := o3; return next;
  test := 'PA4: read other users acceptances'; outcome := o4; return next;
  test := 'PA5: only a revision bump keeps a version'; outcome := o5; return next;
end $$;
-- L1-L6 (20260929120000): a landlord/landlady adds a walk-in student, and that
-- stay starts only with the student's own QR. Picks a verified landlord/landlady
-- with an available room, a student with no stay, and any other student whose
-- token must not work. The setup runs with no signed-in user (the lock triggers
-- let it through), and the whole block is rolled back.
create or replace function pg_temp.added_check() returns table(test text, outcome text)
language plpgsql as $$
declare
  v_landlord uuid; v_room uuid; v_student uuid; v_other uuid; v_lease uuid; v_status text; v_msg text;
  v_code_a text; v_code_b text; v_slot bigint := floor(extract(epoch from now()) / 5);
  o1 text; o2 text; o3 text; o4 text; o5 text; o6 text; o7 text;
begin
  select r.id, a.landlord_id into v_room, v_landlord
    from public.rooms r join public.accommodations a on a.id = r.accommodation_id
    join public.users u on u.id = a.landlord_id
   where r.status = 'available' and u.status = 'verified' limit 1;
  select sp.user_id into v_student from public.student_profiles sp
   where not exists (select 1 from public.leases l where l.student_id = sp.user_id
                      and l.status in ('active', 'leave_requested', 'pending'))
   limit 1;
  select sp.user_id into v_other from public.student_profiles sp where sp.user_id <> v_student limit 1;
  if v_room is null or v_student is null or v_other is null then return; end if;

  begin
    perform set_config('request.jwt.claims', '', true);
    update public.users set status = 'verified' where id = v_student;
    update public.student_profiles
       set student_id = 'rls-test-no', osas_verified_at = null,
           qr_code_token = 'rls-tok-a', qr_token_expires_at = now() + interval '1 hour'
     where user_id = v_student;
    update public.student_profiles
       set qr_code_token = 'rls-tok-b', qr_token_expires_at = now() + interval '1 hour'
     where user_id = v_other;
    -- What each student's QR screen shows right now (20261008000000): a
    -- 5-second code signed with the stored key, never the key itself.
    v_code_a := 'a1.' || v_student || '.' || v_slot || '.' || public.qr_mac(v_student, 'rls-tok-a', v_slot);
    v_code_b := 'a1.' || v_other || '.' || v_slot || '.' || public.qr_mac(v_other, 'rls-tok-b', v_slot);

    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;
    begin
      insert into public.leases (room_id, student_id, landlord_id, start_date, end_date, status)
      values (v_room, v_student, v_landlord, current_date, current_date + 365, 'active');
      o1 := 'FAIL - a landlord/landlady inserted a lease directly';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      o1 := 'PASS - ' || v_msg;
    end;
    begin
      perform public.add_student_to_room(v_room, 'rls-test-no', current_date);
      o2 := 'FAIL - added a student OSAS has not verified';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      o2 := 'PASS - ' || v_msg;
    end;
    reset role;

    perform set_config('request.jwt.claims', '', true);
    update public.student_profiles set osas_verified_at = now() where user_id = v_student;

    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;
    begin
      v_lease := public.add_student_to_room(v_room, 'rls-test-no', current_date);
      o3 := 'PASS - verified student added as pending';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      o3 := 'FAIL - ' || v_msg;
    end;
    if v_lease is not null then
      begin
        update public.leases set status = 'active' where id = v_lease;
        o4 := 'FAIL - an added student was accepted without a scan';
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o4 := 'PASS - ' || v_msg;
      end;
      begin
        perform public.accept_added_student(v_lease, v_code_b);
        o5 := 'FAIL - accepted with another student''s QR';
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o5 := 'PASS - ' || v_msg;
      end;
      begin
        perform public.accept_added_student(v_lease, 'rls-tok-a');
        o7 := 'FAIL - the stored key worked as a QR code';
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o7 := 'PASS - ' || v_msg;
      end;
      begin
        perform public.accept_added_student(v_lease, v_code_a);
        select status::text into v_status from public.leases where id = v_lease;
        o6 := case when v_status = 'active' then 'PASS' else 'FAIL - status is ' || v_status end;
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o6 := 'FAIL - ' || v_msg;
      end;
    end if;
    reset role;
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    reset role;
    if v_msg <> 'rollback' then o1 := coalesce(o1, 'FAIL - ' || v_msg); end if;
  end;
  test := 'L1: landlord/landlady inserts a lease directly'; outcome := o1; return next;
  test := 'L2: add a student OSAS has not verified'; outcome := o2; return next;
  test := 'L3: add a verified student'; outcome := o3; return next;
  test := 'L4: accept an added student without a scan'; outcome := coalesce(o4, 'FAIL - not reached'); return next;
  test := 'L5: accept with another student''s QR'; outcome := coalesce(o5, 'FAIL - not reached'); return next;
  test := 'L6: accept with their own QR'; outcome := coalesce(o6, 'FAIL - not reached'); return next;
  test := 'L7: accept with the raw stored QR key'; outcome := coalesce(o7, 'FAIL - not reached'); return next;
end $$;
-- AC1-AC7 (20261002120000): accreditation rounds. The location OSAS checked stays put
-- on a live listing, only OSAS decides, a sent-back listing cannot be
-- resubmitted with the flagged permit unreplaced, one appeal only, and one
-- landlord/landlady never sees another's history. Setup runs with no signed-in
-- user; the whole block is rolled back.
create or replace function pg_temp.accreditation_check() returns table(test text, outcome text)
language plpgsql as $$
declare
  v_acc uuid; v_landlord uuid; v_seen int; v_msg text;
  o1 text; o2 text; o3 text; o4 text; o5 text; o6 text; o7 text; o8 text; o9 text;
begin
  select a.id, a.landlord_id into v_acc, v_landlord
    from public.accommodations a where a.status = 'accredited' limit 1;
  if v_acc is null then return; end if;

  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;

    begin
      update public.accommodations set lat = coalesce(lat, 0) + 0.01 where id = v_acc;
      o1 := 'FAIL - moved an accredited listing directly';
    exception when others then
      get stacked diagnostics v_msg = message_text; o1 := 'PASS - ' || v_msg;
    end;

    begin
      update public.accommodations set accreditation_expires_at = now() + interval '10 years' where id = v_acc;
      o2 := 'FAIL - extended own accreditation';
    exception when others then
      get stacked diagnostics v_msg = message_text; o2 := 'PASS - ' || v_msg;
    end;

    begin
      perform public.decide_accreditation(v_acc, 'approved');
      o3 := 'FAIL - a landlord/landlady decided an accreditation';
    exception when others then
      get stacked diagnostics v_msg = message_text; o3 := 'PASS - ' || v_msg;
    end;

    begin
      insert into public.accreditation_rounds (accommodation_id, round, kind) values (v_acc, 99, 'new');
      o4 := 'FAIL - opened a round directly';
    exception when others then
      get stacked diagnostics v_msg = message_text; o4 := 'PASS - ' || v_msg;
    end;

    select count(*) into v_seen from public.accreditation_rounds r
      join public.accommodations a on a.id = r.accommodation_id
     where a.landlord_id <> v_landlord;
    o5 := case when v_seen = 0 then 'PASS' else 'FAIL - sees ' || v_seen || ' rounds of other listings' end;
    reset role;

    -- Sent back with the fire safety permit flagged a minute ago.
    perform set_config('request.jwt.claims', '', true);
    update public.accommodations set status = 'needs_revision' where id = v_acc;
    insert into public.accreditation_rounds (accommodation_id, round, kind, submitted_at, decided_at, decision, flagged_docs)
    values (v_acc, 900, 'new', now() - interval '2 minutes', now() - interval '1 minute', 'returned', array['fire_safety']);
    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;
    begin
      perform public.resubmit_accommodation(v_acc);
      o6 := 'FAIL - resubmitted without replacing the flagged permit';
    exception when others then
      get stacked diagnostics v_msg = message_text;
      o6 := case when v_msg like 'Replace the fire safety permit%' then 'PASS - ' || v_msg else 'FAIL - wrong refusal: ' || v_msg end;
    end;
    reset role;

    perform set_config('request.jwt.claims', '', true);
    update public.accommodations set status = 'rejected', appeal_used = true where id = v_acc;
    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;
    begin
      perform public.appeal_accommodation(v_acc, 'Please look again.');
      o7 := 'FAIL - appealed a second time';
    exception when others then
      get stacked diagnostics v_msg = message_text; o7 := 'PASS - ' || v_msg;
    end;
    reset role;

    -- 20261003010000: accredited again, with a sanitary permit good for a year.
    -- Unflagged and not near expiry, so it may be neither replaced nor edited.
    perform set_config('request.jwt.claims', '', true);
    update public.accommodations set status = 'accredited' where id = v_acc;
    insert into public.accommodation_documents (accommodation_id, doc_type, file_url, expires_at, version)
    values (v_acc, 'sanitary_permit', 'rls test', current_date + 365, 900);
    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;
    begin
      insert into public.accommodation_documents (accommodation_id, doc_type, file_url, expires_at, version)
      values (v_acc, 'sanitary_permit', 'cld:raw:authenticated:pdf:accommo/docs/' || v_landlord || '/rls2', current_date + 700, 901);
      o8 := 'FAIL - replaced a current permit on an accredited listing';
    exception when others then
      get stacked diagnostics v_msg = message_text; o8 := 'PASS - ' || v_msg;
    end;
    update public.accommodation_documents set expires_at = current_date + 3000 where accommodation_id = v_acc and version = 900;
    get diagnostics v_seen = row_count;
    o9 := case when v_seen = 0 then 'PASS - in-place edit refused' else 'FAIL - edited a permit on an accredited listing' end;
    reset role;
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    reset role;
    if v_msg <> 'rollback' then o1 := coalesce(o1, 'FAIL - ' || v_msg); end if;
  end;
  test := 'AC1: move an accredited listing directly'; outcome := o1; return next;
  test := 'AC2: extend own accreditation'; outcome := coalesce(o2, 'FAIL - not reached'); return next;
  test := 'AC3: landlord/landlady decides'; outcome := coalesce(o3, 'FAIL - not reached'); return next;
  test := 'AC4: open a round directly'; outcome := coalesce(o4, 'FAIL - not reached'); return next;
  test := 'AC5: read other listings'' rounds'; outcome := coalesce(o5, 'FAIL - not reached'); return next;
  test := 'AC6: resubmit with a flagged permit unreplaced'; outcome := coalesce(o6, 'FAIL - not reached'); return next;
  test := 'AC7: appeal twice'; outcome := coalesce(o7, 'FAIL - not reached'); return next;
  test := 'AC8: replace a current permit while accredited'; outcome := coalesce(o8, 'FAIL - not reached'); return next;
  test := 'AC9: edit a permit while accredited'; outcome := coalesce(o9, 'FAIL - not reached'); return next;
end $$;
-- H1-H22 (20261005000000, 20261005010000): the security hardening. Each guard is paired with
-- the honest write next to it, so a guard that also breaks the app shows up.
-- Uses the fixture's people by id; skipped on a database without it.
create or replace function pg_temp.hardening_check() returns table(test text, outcome text)
language plpgsql as $$
declare
  v_landlord uuid := '00000000-0000-0000-0000-00000000a001';
  v_tenant   uuid := '00000000-0000-0000-0000-00000000b001';
  v_other    uuid := '00000000-0000-0000-0000-00000000b002';
  v_acc      uuid := '00000000-0000-0000-0000-00000000c001';
  v_room     uuid := '00000000-0000-0000-0000-00000000d001';
  v_lease    uuid := '00000000-0000-0000-0000-00000000e001';
  v_conv uuid; v_conv2 uuid; v_message uuid;
  v_msg text; v_n int; v_num numeric; v_ver int; v_at timestamptz;
  names text[] := '{}'; results text[] := '{}';
begin
  if not exists (select 1 from public.leases where id = v_lease) then
    test := 'H: hardening'; outcome := 'SKIP - load tests/fixture.sql'; return next; return;
  end if;

  begin
    -- As the landlord/landlady.
    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;

    begin
      perform qr_code_token from public.student_profiles where user_id = v_tenant;
      v_msg := 'FAIL - read a tenant''s QR token';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H1: landlord reads a tenant''s QR token'::text; results := results || v_msg;

    begin
      select count(user_id) into v_n from public.student_profiles where user_id = v_tenant;
      v_msg := case when v_n = 1 then 'PASS' else 'FAIL - tenant''s profile not readable' end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg;
    end;
    names := names || 'H2: landlord still reads a tenant''s profile'::text; results := results || v_msg;

    begin
      update public.accommodations set rating_avg = 5, reviews_count = 99 where id = v_acc;
      v_msg := 'FAIL - set own listing''s rating';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H3: landlord sets own rating'::text; results := results || v_msg;

    begin
      insert into public.accommodation_documents (accommodation_id, doc_type, file_url, expires_at, version, uploaded_at)
      values (v_acc, 'fire_safety', 'cld:raw:authenticated:pdf:accommo/docs/' || v_landlord || '/h', current_date + 365, 50, '2000-01-01')
      returning version, uploaded_at into v_ver, v_at;
      v_msg := case when v_ver = 1 and v_at > now() - interval '1 minute' then 'PASS'
                    else 'FAIL - kept version ' || v_ver || ' / ' || v_at end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg;
    end;
    names := names || 'H4: permit version and upload time are the database''s'::text; results := results || v_msg;

    -- As a student with no lease.
    reset role;
    perform set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    set local role authenticated;

    begin
      insert into public.tickets (student_id, landlord_id, subject) values (v_other, v_landlord, 'h');
      v_msg := 'FAIL - filed a ticket against a stranger';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H5: ticket names a landlord/landlady you never leased from'::text; results := results || v_msg;

    begin
      insert into public.conversations (user_a_id, user_b_id) values (v_other, v_tenant);
      v_msg := 'FAIL - student opened a conversation with a stranger';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H6: student messages another student cold'::text; results := results || v_msg;

    begin
      insert into public.conversations (user_a_id, user_b_id) values (v_other, v_landlord) returning id into v_conv;
      v_msg := 'PASS';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg;
    end;
    names := names || 'H7: student asks a listed landlord/landlady'::text; results := results || v_msg;

    begin
      update public.conversations set invited_room_id = v_room, invited_at = now() where id = v_conv;
      v_msg := 'FAIL - student issued their own application form';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H8: student invites themselves'::text; results := results || v_msg;

    select count(*) into v_n from public.users_full where id = v_tenant;
    names := names || 'H18: student sees a stranger''s contact details'::text;
    results := results || case when v_n = 0 then 'PASS' else 'FAIL - row visible' end;

    delete from public.conversations where id = v_conv;
    get diagnostics v_n = row_count;
    names := names || 'H9: participant deletes a conversation'::text;
    results := results || case when v_n = 0 then 'PASS' else 'FAIL - deleted' end;

    -- Setup as the database: a second thread with a message in the first, the
    -- form issued, and this student verified so they may apply.
    reset role;
    perform set_config('request.jwt.claims', '', true);
    insert into public.conversations (user_a_id, user_b_id) values (v_other, v_tenant) returning id into v_conv2;
    insert into public.messages (conversation_id, sender_id, body) values (v_conv, v_other, 'h') returning id into v_message;
    update public.conversations set invited_room_id = v_room, invited_at = now() where id = v_conv;
    update public.student_profiles set osas_verified_at = now() where user_id = v_other;
    perform set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    set local role authenticated;

    begin
      update public.messages set conversation_id = v_conv2 where id = v_message;
      v_msg := 'FAIL - moved a message into another conversation';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H10: sender moves a message'::text; results := results || v_msg;

    begin
      insert into public.leases (room_id, student_id, landlord_id, start_date, end_date, status, monthly_rent)
      values (v_room, v_other, v_landlord, current_date, current_date + 365, 'pending', 1)
      returning monthly_rent into v_num;
      -- Fixture room: 2500 for the whole room, four beds.
      v_msg := case when v_num = 625 then 'PASS' else 'FAIL - rent ' || v_num end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg;
    end;
    names := names || 'H11: application rent comes from the room'::text; results := results || v_msg;

    begin
      insert into public.tickets (student_id, photo_urls, subject) values (v_other, array['https://example.com/x.html'], 'h');
      v_msg := 'FAIL - stored a plain URL as a file';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H12: plain URL in a file column'::text; results := results || v_msg;

    -- As the verified tenant.
    reset role;
    perform set_config('request.jwt.claims', json_build_object('sub', v_tenant, 'role', 'authenticated')::text, true);
    set local role authenticated;

    begin
      update public.student_profiles set student_id = 'h-swapped' where user_id = v_tenant;
      v_msg := 'FAIL - changed a verified student number';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H13: verified student changes their student number'::text; results := results || v_msg;

    begin
      update public.student_profiles set program = 'BSIT' where user_id = v_tenant;
      get diagnostics v_n = row_count;
      v_msg := case when v_n = 1 then 'PASS' else 'FAIL - no row updated' end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg;
    end;
    names := names || 'H14: verified student edits their program'::text; results := results || v_msg;

    begin
      perform email from public.users where id = v_landlord;
      v_msg := 'FAIL - read an e-mail straight off users';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H19: e-mail read from users'::text; results := results || v_msg;

    select count(*) into v_n from public.users_full where id = v_landlord and phone is not null;
    names := names || 'H20: tenant reads their landlord/landlady''s phone'::text;
    results := results || case when v_n = 1 then 'PASS' else 'FAIL - not visible' end;

    -- Back to the landlord/landlady: a closed lease stays closed, a paid payment stays.
    reset role;
    perform set_config('request.jwt.claims', '', true);
    update public.payments set status = 'paid', paid_at = now() where lease_id = v_lease;
    perform set_config('request.jwt.claims', json_build_object('sub', v_landlord, 'role', 'authenticated')::text, true);
    set local role authenticated;

    delete from public.payments where lease_id = v_lease and status = 'paid';
    get diagnostics v_n = row_count;
    names := names || 'H15: landlord deletes a paid payment'::text;
    results := results || case when v_n = 0 then 'PASS' else 'FAIL - deleted' end;

    begin
      update public.leases set status = 'ended', ended_reason = 'h' where id = v_lease;
      v_msg := 'PASS';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg;
    end;
    names := names || 'H16: landlord ends a lease'::text; results := results || v_msg;

    begin
      update public.leases set status = 'active' where id = v_lease;
      v_msg := 'FAIL - reopened an ended lease';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H17: landlord reopens an ended lease'::text; results := results || v_msg;

    reset role;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_landlord, 'role', 'authenticated', 'session_id', gen_random_uuid())::text, true);
    begin
      perform public.check_session();
      v_msg := 'FAIL - a session that does not exist was let through';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H21: token for an ended session'::text; results := results || v_msg;

    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    set local role anon;
    begin
      perform public.is_admin(v_landlord);
      v_msg := 'FAIL - anon asked whether an id is an admin';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'H22: anon calls is_admin()'::text; results := results || v_msg;

    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    reset role;
    if v_msg <> 'rollback' then
      names := names || 'H: hardening'::text; results := results || ('FAIL - ' || v_msg);
    end if;
  end;

  for i in 1 .. coalesce(array_length(names, 1), 0) loop
    test := names[i]; outcome := results[i]; return next;
  end loop;
end $$;
create or replace function pg_temp.rate_limit_check() returns table(test text, outcome text)
language plpgsql as $$
declare v_student uuid; v_msg text; v_n int := 0; o1 text; o2 text;
begin
  select l.student_id into v_student from public.leases l where l.status = 'active' limit 1;
  -- The checks before this one leave a signed-in user in the claims.
  perform set_config('request.jwt.claims', '', true);
  begin
    -- Rows the database writes itself (no signed-in user) are never capped.
    for i in 1..8 loop
      insert into public.tickets (student_id, subject) values (v_student, 'rate test');
    end loop;
    o2 := 'PASS';
    perform set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    set local role authenticated;
    begin
      for i in 1..6 loop
        insert into public.tickets (student_id, subject) values (v_student, 'rate test');
        v_n := i;
      end loop;
      o1 := 'FAIL - sixth ticket in an hour was accepted';
    exception when others then
      o1 := case when v_n = 5 then 'PASS' else 'FAIL - refused after ' || v_n || ' tickets' end;
    end;
    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'rollback' then o2 := coalesce(o2, 'FAIL - ' || v_msg); end if;
  end;
  reset role;
  test := 'RL1: sixth ticket in an hour is refused'; outcome := coalesce(o1, 'FAIL - not reached'); return next;
  test := 'RL2: database-written rows are not capped'; outcome := coalesce(o2, 'FAIL - not reached'); return next;
end $$;
-- Invited-admin access (20261006000000): a level per area, enforced in the
-- database. Student two is made a limited admin for the length of the block.
create or replace function pg_temp.access_check() returns table(test text, outcome text)
language plpgsql as $f$
declare
  v_admin  uuid := '00000000-0000-0000-0000-00000000b002';
  v_target uuid := '00000000-0000-0000-0000-00000000b001';
  v_super  uuid := '00000000-0000-0000-0000-00000000f001';
  v_msg text; v_n int; v_ip text;
  names text[] := '{}'; results text[] := '{}';
  claims text := json_build_object('sub', '00000000-0000-0000-0000-00000000b002', 'role', 'authenticated')::text;
begin
  if not exists (select 1 from public.users where id = v_admin) then
    test := 'AA: admin access'; outcome := 'SKIP - load tests/fixture.sql'; return next; return;
  end if;

  begin
    set local session_replication_role = replica;
    update public.users set role = 'admin' where id = v_admin;
    set local session_replication_role = origin;
    insert into public.admin_access (user_id, preset, levels)
    values (v_admin, 'custom', '{"support":"view","accounts":"view","activity":"view"}');
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, ip_address, user_agent)
    values (v_super, 'UPDATE', 'users', v_target::text, '1.2.3.4', 'TestUA');

    perform set_config('request.jwt.claims', claims, true);
    set local role authenticated;

    v_msg := case when public.can_view('support') and not public.can_edit('support') and not public.can_view('verification')
                  then 'PASS' else 'FAIL - levels not applied' end;
    names := names || 'AA1: view-only area reads but cannot edit'::text; results := results || v_msg;

    begin
      insert into public.account_notes (user_id, author_id, body) values (v_target, v_admin, 'x');
      v_msg := 'FAIL - view-only admin wrote a note';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'AA2: Accounts view cannot add notes'::text; results := results || v_msg;

    select count(*) into v_n from public.audit_logs where actor_id is distinct from v_admin;
    v_msg := case when v_n = 0 then 'PASS' else 'FAIL - read ' || v_n || ' audit rows' end;
    names := names || 'AA3: audit log is system-admin only'::text; results := results || v_msg;

    begin
      perform public.admin_set_account_status(v_target, 'suspended', 'test');
      v_msg := 'FAIL - suspended an account without Accounts edit';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'AA4: suspend needs Accounts edit'::text; results := results || v_msg;

    select x ->> 'ip_address' into v_ip from public.record_activity(array['users'], v_target::text) x
     where x ->> 'action' = 'UPDATE' and x -> 'actor' ->> 'full_name' is not null limit 1;
    select count(*) into v_n from public.record_activity(array['users'], v_target::text);
    v_msg := case when v_n > 0 and v_ip is null then 'PASS' when v_n = 0 then 'FAIL - no activity' else 'FAIL - device shown' end;
    names := names || 'AA5: Changes only hides the device'::text; results := results || v_msg;

    begin
      update public.admin_access set levels = '{"accounts":"edit"}' where user_id = v_admin;
      get diagnostics v_n = row_count;
      v_msg := case when v_n = 0 then 'PASS' else 'FAIL - changed own access' end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'AA6: an admin cannot raise their own access'::text; results := results || v_msg;

    reset role;
    update public.admin_access set expires_at = now() - interval '1 minute' where user_id = v_admin;
    set local role authenticated;
    v_msg := case when not public.is_admin(v_admin) and not public.can_view('support') then 'PASS' else 'FAIL - expired admin still an admin' end;
    names := names || 'AA7: expired access locks the admin out'::text; results := results || v_msg;

    begin
      perform public.check_session();
      v_msg := 'FAIL - expired admin passed check_session';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg;
    end;
    names := names || 'AA8: check_session refuses an expired admin'::text; results := results || v_msg;

    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'rollback' then names := names || 'AA: setup'::text; results := results || ('FAIL - ' || v_msg); end if;
  end;
  reset role;
  for i in 1 .. coalesce(array_length(names, 1), 0) loop
    test := names[i]; outcome := results[i]; return next;
  end loop;
end $f$;

-- Payment rules (20261006020000): amounts against what is owed, partial
-- payments, order of months, evidence. Acts on the fixture lease (2,500 rent).
create or replace function pg_temp.payment_check() returns table(test text, outcome text)
language plpgsql as $f$
declare
  v_lease uuid := '00000000-0000-0000-0000-00000000e001';
  v_month date;
  v_pay uuid; v_msg text; v_state text;
  names text[] := '{}'; results text[] := '{}';
  as_student text := json_build_object('sub', '00000000-0000-0000-0000-00000000b001', 'role', 'authenticated')::text;
  as_landlord text := json_build_object('sub', '00000000-0000-0000-0000-00000000a001', 'role', 'authenticated')::text;
begin
  if not exists (select 1 from public.leases where id = v_lease) then
    test := 'PY: payments'; outcome := 'SKIP - load tests/fixture.sql'; return next; return;
  end if;
  select date_trunc('month', start_date)::date into v_month from public.leases where id = v_lease;

  begin
    delete from public.payments where lease_id = v_lease;  -- a clean ledger for this block
    update public.leases set allow_partial = false where id = v_lease;
    perform set_config('request.jwt.claims', as_student, true);
    set local role authenticated;

    begin
      insert into public.payments (lease_id, month, amount, method, status, txn_reference, proof_url)
      values (v_lease, v_month, 3000, 'gcash', 'pending_verification', '1234567890123', 'cld:x');
      v_msg := 'FAIL - overpayment accepted';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY1: paying more than owed is refused'::text; results := results || v_msg;

    begin
      insert into public.payments (lease_id, month, amount, method, status, txn_reference, proof_url)
      values (v_lease, v_month, 1250, 'gcash', 'pending_verification', '1234567890123', 'cld:x');
      v_msg := 'FAIL - partial accepted without allow_partial';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY2: partial needs the landlord to allow it'::text; results := results || v_msg;

    begin
      update public.leases set allow_partial = true where id = v_lease;
      v_msg := 'FAIL - student turned on partial payments';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY3: a student cannot allow partial payments'::text; results := results || v_msg;

    begin
      insert into public.payments (lease_id, month, amount, method, status, txn_reference, proof_url)
      values (v_lease, v_month, 2500, 'gcash', 'pending_verification', '12345', 'cld:x');
      v_msg := 'FAIL - short GCash reference accepted';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY4: GCash reference must be 13 digits'::text; results := results || v_msg;

    begin
      insert into public.payments (lease_id, month, amount, method, status)
      values (v_lease, v_month, 2500, 'gcash', 'pending_verification');
      v_msg := 'FAIL - non-cash without reference accepted';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY5: non-cash needs a reference and proof'::text; results := results || v_msg;

    begin
      insert into public.payments (lease_id, month, amount, method, status)
      values (v_lease, (v_month + interval '1 month')::date, 2500, 'cash', 'pending_verification');
      v_msg := 'FAIL - skipped a month';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY6: months are paid in order'::text; results := results || v_msg;

    -- The landlord/landlady allows partial payments (50%).
    reset role;
    perform set_config('request.jwt.claims', as_landlord, true);
    set local role authenticated;
    update public.leases set allow_partial = true, partial_min_pct = 50 where id = v_lease;
    reset role;
    perform set_config('request.jwt.claims', as_student, true);
    set local role authenticated;

    begin
      insert into public.payments (lease_id, month, amount, method, status)
      values (v_lease, v_month, 1000, 'cash', 'pending_verification');
      v_msg := 'FAIL - partial below the minimum accepted';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY7: partial below 50% is refused'::text; results := results || v_msg;

    begin
      insert into public.payments (lease_id, month, amount, method, status)
      values (v_lease, v_month, 1250, 'cash', 'pending_verification') returning id into v_pay;
      v_msg := 'PASS';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg; end;
    names := names || 'PY8: half is accepted once allowed'::text; results := results || v_msg;

    -- 20261006070000: the rest can be paid while the first part waits (rolled
    -- back here so the steps below still see one half pending).
    begin
      insert into public.payments (lease_id, month, amount, method, status)
      values (v_lease, v_month, 1250, 'cash', 'pending_verification');
      raise exception 'ok';
    exception when others then get stacked diagnostics v_msg = message_text;
      v_msg := case when v_msg = 'ok' then 'PASS' else 'FAIL - ' || v_msg end; end;
    names := names || 'PY9: the rest can be paid while the first part waits'::text; results := results || v_msg;

    -- The landlord/landlady confirms the half.
    reset role;
    perform set_config('request.jwt.claims', as_landlord, true);
    set local role authenticated;
    begin
      update public.payments set status = 'rejected' where id = v_pay;
      v_msg := 'FAIL - rejected without a reason';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY10: rejecting needs a reason'::text; results := results || v_msg;
    update public.payments set status = 'paid' where id = v_pay;
    begin
      update public.payments set amount = 2500 where id = v_pay;
      v_msg := 'FAIL - confirmed amount changed';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY11: a confirmed amount cannot change'::text; results := results || v_msg;
    select l.state into v_state from public.lease_ledger(v_lease) l where l.kind = 'rent' and l.month = v_month;
    names := names || 'PY12: ledger shows the month as partly paid'::text;
    results := results || (case when v_state in ('partial', 'overdue') then 'PASS' else 'FAIL - state ' || coalesce(v_state, 'none') end);

    -- The student pays the rest; the month is then covered.
    reset role;
    perform set_config('request.jwt.claims', as_student, true);
    set local role authenticated;
    begin
      insert into public.payments (lease_id, month, amount, method, status)
      values (v_lease, v_month, 1250, 'cash', 'pending_verification');
      select l.state into v_state from public.lease_ledger(v_lease) l where l.kind = 'rent' and l.month = v_month;
      v_msg := case when v_state = 'pending' then 'PASS' else 'FAIL - state ' || v_state end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg; end;
    names := names || 'PY13: the remaining half settles the month'::text; results := results || v_msg;

    begin
      insert into public.payments (lease_id, month, amount, method, status)
      values (v_lease, (date_trunc('month', now()) + interval '7 months')::date, 2500, 'cash', 'pending_verification');
      v_msg := 'FAIL - paid seven months ahead';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY14: at most six months ahead'::text; results := results || v_msg;

    -- PY13 left a half awaiting confirmation: the student takes it back.
    begin
      select id into v_pay from public.payments where lease_id = v_lease and status = 'pending_verification' limit 1;
      perform public.review_payment(v_pay, 'withdraw');
      v_msg := case when (select status::text from public.payments where id = v_pay) = 'withdrawn' then 'PASS' else 'FAIL - not withdrawn' end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg; end;
    names := names || 'PY15: a student can withdraw a pending payment'::text; results := results || v_msg;

    begin
      perform public.waive_balance(v_lease, 'rent', v_month, null, 'test');
      v_msg := 'FAIL - student forgave a balance';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY16: a student cannot forgive a balance'::text; results := results || v_msg;

    begin
      update public.leases set grace_days = 15 where id = v_lease;
      v_msg := 'FAIL - student changed the grace period';
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'PASS - ' || v_msg; end;
    names := names || 'PY17: a student cannot change when rent is due'::text; results := results || v_msg;

    -- The landlord/landlady forgives the rest of the month.
    reset role;
    perform set_config('request.jwt.claims', as_landlord, true);
    set local role authenticated;
    begin
      perform public.waive_balance(v_lease, 'rent', v_month, null, 'Hardship');
      select l.state into v_state from public.lease_ledger(v_lease) l where l.kind = 'rent' and l.month = v_month;
      v_msg := case when v_state = 'paid' then 'PASS' else 'FAIL - state ' || coalesce(v_state, 'none') end;
    exception when others then get stacked diagnostics v_msg = message_text; v_msg := 'FAIL - ' || v_msg; end;
    names := names || 'PY18: forgiving the rest settles the month'::text; results := results || v_msg;

    raise exception 'rollback';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'rollback' then names := names || 'PY: setup'::text; results := results || ('FAIL - ' || v_msg); end if;
  end;
  reset role;
  for i in 1 .. coalesce(array_length(names, 1), 0) loop
    test := names[i]; outcome := results[i]; return next;
  end loop;
end $f$;

select * from pg_temp.rls_check()
union all
select * from pg_temp.added_check()
union all
select * from pg_temp.unverified_check()
union all
select * from pg_temp.mgr_check()
union all
select * from pg_temp.rpc_check()
union all
select * from pg_temp.release_check()
union all
select * from pg_temp.standing_check()
union all
select * from pg_temp.mfa_check()
union all
select * from pg_temp.private_ref_check()
union all
select * from pg_temp.ticket_check()
union all
select * from pg_temp.policy_check()
union all
select * from pg_temp.accreditation_check()
union all
select * from pg_temp.rate_limit_check()
union all
select * from pg_temp.hardening_check()
union all
select * from pg_temp.access_check()
union all
select * from pg_temp.payment_check();
