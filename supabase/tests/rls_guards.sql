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
declare v_mgr uuid; v_payment uuid; v_msg text;
begin
  select l.landlord_id, p.id into v_mgr, v_payment
    from public.leases l join public.payments p on p.lease_id = l.id
   where l.status = 'active' limit 1;

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
    select p.lease_id, '2027-03-01', 1500, 'cash', 'paid', now(), v_mgr
      from public.payments p where p.id = v_payment;
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

  begin
    perform public.has_pin();
    outcome := 'PASS';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    outcome := 'FAIL - an RPC the app needs was revoked: ' || v_msg;
  end;
  test := 'R2: has_pin still callable'; return next;

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
  end if;

  -- U4-U6: a student OSAS has not verified may not apply for a room, and a
  -- landlord/landlady may not add them to one. U5 has OSAS verify the same
  -- student and retries, so U4 is known to fail on verification and nothing
  -- else. The room invite is set up first, as the app does before applying.
  -- Skipped when there is no such student or no available room.
  select u.id into v_student from public.users u join public.student_profiles sp on sp.user_id = u.id
   where u.role = 'student' and u.status = 'verified' and sp.osas_verified_at is null limit 1;
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
end $;
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
language plpgsql as $
declare
  v_landlord uuid; v_room uuid; v_student uuid; v_other uuid; v_lease uuid; v_status text; v_msg text;
  o1 text; o2 text; o3 text; o4 text; o5 text; o6 text;
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
        perform public.accept_added_student(v_lease, 'rls-tok-b');
        o5 := 'FAIL - accepted with another student''s QR';
      exception when others then
        get stacked diagnostics v_msg = message_text;
        o5 := 'PASS - ' || v_msg;
      end;
      begin
        perform public.accept_added_student(v_lease, 'rls-tok-a');
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
end $;
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
select * from pg_temp.policy_check();
