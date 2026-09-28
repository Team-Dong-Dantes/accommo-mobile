-- The least data rls_guards.sql needs on an empty database (CI, or a local
-- `supabase db reset`): one student with an active lease and a payment on it,
-- plus a second student and an OSAS superadmin, so "can I see other people's rows" has an answer.
--
-- Never run this against the live project.

begin;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'landlord@gmail.com', '', now(), '{"full_name":"Test Landlord","role":"landlord"}', now(), now()),
  ('00000000-0000-0000-0000-00000000b001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'student1@gmail.com', '', now(), '{"full_name":"Test Student One","role":"student"}', now(), now()),
  ('00000000-0000-0000-0000-00000000b002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'student2@gmail.com', '', now(), '{"full_name":"Test Student Two","role":"student"}', now(), now()),
  ('00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'admin@gmail.com', '', now(), '{"full_name":"Test Admin"}', now(), now());

-- handle_auth_user_sync wrote the public.users rows; make them real accounts.
-- The S-tests act as OSAS, which means the superadmin. prevent_non_superadmin_escalation
-- rightly refuses this from a non-admin, so triggers are off for this one row.
set local session_replication_role = replica;
update public.users set role = 'admin', status = 'verified', is_superadmin = true where id = '00000000-0000-0000-0000-00000000f001';
set local session_replication_role = origin;
update public.users set role = 'landlord', status = 'verified' where id = '00000000-0000-0000-0000-00000000a001';
update public.users set status = 'verified' where id in ('00000000-0000-0000-0000-00000000b001', '00000000-0000-0000-0000-00000000b002');

insert into public.landlord_profiles (user_id) values ('00000000-0000-0000-0000-00000000a001') on conflict do nothing;
-- Student one is OSAS-verified (trg_lock_osas keeps that stamp OSAS-only).
set local session_replication_role = replica;
insert into public.student_profiles (user_id, osas_verified_at) values
  ('00000000-0000-0000-0000-00000000b001', now()), ('00000000-0000-0000-0000-00000000b002', null) on conflict do nothing;
set local session_replication_role = origin;

insert into public.accommodations (id, landlord_id, name, status)
values ('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-00000000a001', 'Test Boarding House', 'accredited');

insert into public.rooms (id, accommodation_id, status, capacity)
values ('00000000-0000-0000-0000-00000000d001', '00000000-0000-0000-0000-00000000c001', 'available', 4);

insert into public.leases (id, room_id, student_id, landlord_id, start_date, end_date, status)
values ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-00000000d001',
        '00000000-0000-0000-0000-00000000b001', '00000000-0000-0000-0000-00000000a001',
        date_trunc('month', now())::date, (date_trunc('month', now()) + interval '10 months')::date, 'active');

insert into public.payments (lease_id, month, amount, method)
values ('00000000-0000-0000-0000-00000000e001', date_trunc('month', now())::date, 2500, 'gcash');
commit;
