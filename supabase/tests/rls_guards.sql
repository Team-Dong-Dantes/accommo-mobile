-- The smallest thing that fails if 20260914000000 regresses.
--
-- Run it against any environment that has at least one active lease with a
-- payment on it:
--
--   supabase db execute --file supabase/tests/rls_guards.sql
--
-- or paste it into the SQL editor. It impersonates a real student via
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
select * from pg_temp.rls_check()
union all
select * from pg_temp.mgr_check()
union all
select * from pg_temp.rpc_check()
union all
select * from pg_temp.release_check()
union all
select * from pg_temp.standing_check();
