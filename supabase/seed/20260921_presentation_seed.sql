-- Accommo presentation seed: wipe, then one year of activity.
--
--   Oct 2025 -> Sep 2026, ISU Echague. 8 managers, 45 students, 12
--   accommodations, 66 rooms, 54 tenancies, 222 payments, 64 reviews.
--
-- ############################################################################
-- # THIS DELETES EVERY ACCOUNT NOT ON THE KEEP LIST, AND ALL THEIR DATA.      #
-- # Supabase's own daily backup is the only way back. Read KEEP_LIST.md.      #
-- ############################################################################
--
-- Run top to bottom, in order. Parts are separated because three triggers
-- fight a bulk seed and each needs a correction immediately afterwards:
--
--   1. A trigger on auth.users writes its own public.users row and overwrites
--      `role` to 'student'. Part 1 fixes the managers' role after inserting.
--   2. Inserting accommodation_documents puts the accommodation back to
--      'pending' (the resubmission path). Part 2 restores status afterwards.
--   3. tg_payment_guard blocks the FK's ON DELETE SET NULL for
--      payments.verified_by, so Part 0 empties the data tables before deleting
--      users rather than relying on the cascade.
--
-- Re-running is safe: Part 0 clears everything the later parts create.


-- ===========================================================================
-- PART 0 - WIPE
-- ===========================================================================
-- session_replication_role = replica disables triggers and FK checks for the
-- truncate. It also suppresses the auth.users -> auth.identities cascade, so
-- the orphans are cleaned explicitly at the end of this part.
set session_replication_role = replica;

truncate table
  public.audit_logs, public.notifications, public.tickets, public.ticket_messages,
  public.announcements, public.payments, public.qr_scans, public.verification_requests,
  public.leases, public.boarding_history, public.messages, public.conversations,
  public.accommodations, public.rooms, public.room_images, public.accommodation_images,
  public.accommodation_amenities, public.accommodation_policies, public.accommodation_floors,
  public.accommodation_facilities, public.accommodation_facility_images,
  public.accommodation_documents, public.verification_documents,
  public.accommodation_reviews, public.accommodation_manager_reviews, public.tenant_reviews,
  public.student_profiles, public.accommodation_manager_profiles, public.admin_profiles,
  public.concerns, public.policies, public.user_pins
  restart identity cascade;

-- app_release is NOT truncated: it drives the mobile UpdateGate, and an empty
-- table locks every install out of the app.

create temporary table _keep(id uuid primary key);
insert into _keep(id) values
 ('672e25f5-8798-4a47-9c94-dbb7774bccd8'), -- admin@gmail.com (superadmin, email/password)
 ('230d487b-c075-48d7-9139-a00a4470b4f8'), -- lichtzy1202@gmail.com (invited admin)
 ('d1cba6c8-8e7e-4f08-b0f1-171ef44fe01f'), -- titusplaza1202@gmail.com (manager)
 ('44dbbe8f-3e81-4fdd-9274-4359db24167b'), -- deannsamuel.d.blanza@isu.edu.ph (manager)
 ('f11dfae8-57e9-4a20-a4e1-34a8e1f34a04'),('3790371d-f041-47a5-9c9a-59b6e2871825'),
 ('c8676af2-fa1b-4f2b-9857-7407ad324c8d'),('294dc90d-4979-4a7c-8d2f-585c84261678'),
 ('bc6307fe-7c61-4efc-a644-8ecb6fd06062'),('531e6ca2-528e-4605-9ff4-7635c5f33bbe'),
 ('a9036c34-0528-4f64-ae24-0913928f82a5'),('e69e8745-a6f6-4d5b-852c-3cebffe3cd11'),
 ('61b28b55-12ce-4897-ae8f-6dbf9822ff1f'),('73c1ec37-0bd1-47db-9941-1022534f3b80'),
 ('4307fa70-c433-4d79-a7c1-2006cf811283'),('a6032a53-84f3-44f0-8236-53d2eed88454'),
 ('ead1c811-8cde-4554-81ec-916a3b8e03ef'),('25da668e-38f2-4687-896e-1984ee0981a2');

delete from public.users where id not in (select id from _keep);
delete from auth.users  where id not in (select id from _keep);

set session_replication_role = origin;

-- The cascade that replica mode suppressed.
delete from auth.identities     i where not exists (select 1 from auth.users u where u.id = i.user_id);
delete from auth.sessions       s where not exists (select 1 from auth.users u where u.id = s.user_id);
delete from auth.mfa_factors    f where not exists (select 1 from auth.users u where u.id = f.user_id);
delete from auth.one_time_tokens t where not exists (select 1 from auth.users u where u.id = t.user_id);
delete from auth.refresh_tokens r where r.user_id is not null
  and not exists (select 1 from auth.users u where u.id::text = r.user_id);


-- ===========================================================================
-- PART 1 - PEOPLE  (password for every seeded account: Accommo2026!)
-- ===========================================================================

-- 1a. Backdate the two Google managers. Their id/email/name/photo are kept.
update public.users set
  status='verified', onboarding_complete=true, sex='M',
  phone=case when email like 'titus%' then '+639171234501' else '+639171234502' end,
  date_of_birth=case when email like 'titus%' then date '1994-03-11' else date '1991-07-22' end,
  registered_at=case when email like 'titus%' then timestamptz '2025-10-14 09:12:00+08' else timestamptz '2025-11-03 14:40:00+08' end,
  created_at  =case when email like 'titus%' then timestamp '2025-10-14 09:12:00' else timestamp '2025-11-03 14:40:00' end,
  email_verified_at=case when email like 'titus%' then timestamp '2025-10-14 09:30:00' else timestamp '2025-11-03 15:02:00' end,
  terms_accepted_at=case when email like 'titus%' then timestamptz '2025-10-14 09:12:00+08' else timestamptz '2025-11-03 14:40:00+08' end,
  privacy_accepted_at=case when email like 'titus%' then timestamptz '2025-10-14 09:12:00+08' else timestamptz '2025-11-03 14:40:00+08' end,
  last_login_at=timestamp '2026-09-19 20:15:00'
where role='accommodation_manager';

-- 1b. Six more managers.
with newmgr(idx, email, fname, sex, phone, dob, reg) as (values
  (1,'rosalinda.bagtas@gmail.com','Rosalinda Bagtas','F','+639171234511',date '1972-05-19',timestamptz '2025-10-02 08:05:00+08'),
  (2,'ernesto.dalisay@gmail.com','Ernesto Dalisay','M','+639171234512',date '1968-11-30',timestamptz '2025-10-09 10:22:00+08'),
  (3,'marilou.pascua@gmail.com','Marilou Pascua','F','+639171234513',date '1975-02-14',timestamptz '2025-11-20 16:48:00+08'),
  (4,'gregorio.tumaliuan@gmail.com','Gregorio Tumaliuan','M','+639171234514',date '1966-08-07',timestamptz '2026-01-15 09:33:00+08'),
  (5,'aileen.mangaoang@gmail.com','Aileen Mangaoang','F','+639171234515',date '1980-04-26',timestamptz '2026-03-04 13:10:00+08'),
  (6,'benjamin.cauilan@gmail.com','Benjamin Cauilan','M','+639171234516',date '1971-09-12',timestamptz '2026-06-18 11:55:00+08')
), ins_auth as (
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous)
  select '00000000-0000-0000-0000-000000000000',
         ('00000000-0000-4000-8000-' || lpad((100+idx)::text,12,'0'))::uuid,
         'authenticated','authenticated', email,
         extensions.crypt('Accommo2026!', extensions.gen_salt('bf')),
         reg, reg, reg,
         '{"provider":"email","providers":["email"]}'::jsonb,
         jsonb_build_object('full_name', fname), false, false
  from newmgr returning id
)
insert into public.users (id, email, phone, role, status, full_name, initials, avatar_color, sex,
                          email_verified_at, created_at, updated_at, last_login_at, is_superadmin,
                          onboarding_complete, registered_at, terms_accepted_at, privacy_accepted_at, date_of_birth)
select ('00000000-0000-4000-8000-' || lpad((100+idx)::text,12,'0'))::uuid,
       email, phone, 'accommodation_manager',
       case idx when 5 then 'pending'::user_status when 6 then 'reviewing'::user_status else 'verified'::user_status end,
       fname,
       upper(left(split_part(fname,' ',1),1) || left(split_part(fname,' ',2),1)),
       'teal-7', sex, reg::timestamp, reg::timestamp, reg::timestamp,
       (date '2026-09-18' + (idx % 2))::timestamp + interval '19 hours 40 minutes',
       false, idx <= 4, reg, reg, reg, dob
from newmgr;

-- GOTCHA 1: the auth.users trigger just overwrote role to 'student'.
update public.users set role='accommodation_manager'
where id::text like '00000000-0000-4000-8000-0000000001%';

insert into public.accommodation_manager_profiles (user_id, response_rate, avg_response_minutes, extracted_name)
select id, 78 + (abs(hashtext(email)) % 21), 25 + (abs(hashtext(email)) % 180), full_name
from public.users where role='accommodation_manager'
on conflict (user_id) do update set response_rate=excluded.response_rate,
  avg_response_minutes=excluded.avg_response_minutes, extracted_name=excluded.extracted_name;

-- 1c. 31 more students (the 14 Google ones are enriched in place below).
with n(idx, fname) as (values
 (1,'Andrea Bautista'),(2,'Joshua Ramirez'),(3,'Kristine Manalo'),(4,'Paulo Gaffud'),
 (5,'Bianca Tolentino'),(6,'Miguel Cabanilla'),(7,'Trisha Domingo'),(8,'Rafael Bulusan'),
 (9,'Angelica Ramos'),(10,'Nathaniel Soriano'),(11,'Camille Ordonez'),(12,'Dominic Pagaduan'),
 (13,'Hazel Guzman'),(14,'Lorenzo Baccay'),(15,'Faith Alvarez'),(16,'Sergio Mabborang'),
 (17,'Jasmine Corpuz'),(18,'Elijah Tumamao'),(19,'Patricia Lazaro'),(20,'Kenneth Urbano'),
 (21,'Micaela Fontanilla'),(22,'Adrian Calubaquib'),(23,'Erika Sabado'),(24,'Vincent Malana'),
 (25,'Nicole Battung'),(26,'Jerome Quilang'),(27,'Sheila Rapanut'),(28,'Marlon Addun'),
 (29,'Precious Layugan'),(30,'Carlo Bunagan'),(31,'Diana Cauilan')
)
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous)
select '00000000-0000-0000-0000-000000000000',
       ('00000000-0000-4000-8000-' || lpad((200+idx)::text,12,'0'))::uuid,
       'authenticated','authenticated',
       'stu.' || lower(replace(fname,' ','.')) || '@isu.edu.ph',
       extensions.crypt('Accommo2026!', extensions.gen_salt('bf')),
       (date '2025-10-01' + (idx*11 % 350))::timestamptz,
       (date '2025-10-01' + (idx*11 % 350))::timestamptz,
       (date '2025-10-01' + (idx*11 % 350))::timestamptz,
       '{"provider":"email","providers":["email"]}'::jsonb,
       jsonb_build_object('full_name', fname), false, false
from n;

-- 1d. Every student, new and Google, gets a backdated registration and a status.
--     hashtext keeps it deterministic: the same email always lands the same way.
update public.users u set
  role='student',
  status = case when (abs(hashtext(u.email)) % 12) = 0 then 'pending'::user_status
                when (abs(hashtext(u.email)) % 23) = 0 then 'rejected'::user_status
                else 'verified'::user_status end,
  sex = coalesce(u.sex, case when (abs(hashtext(u.email)) % 2)=0 then 'M' else 'F' end),
  phone = '+639' || lpad((170000000 + (abs(hashtext(u.email)) % 29999999))::text, 9, '0'),
  date_of_birth = date '2003-01-01' + (abs(hashtext(u.email)) % 1400),
  onboarding_complete = true,
  avatar_color = 'indigo-5',
  registered_at = coalesce(u.registered_at, (date '2025-10-01' + (abs(hashtext(u.email)) % 350))::timestamptz + interval '9 hours'),
  created_at    = coalesce(u.created_at,    (date '2025-10-01' + (abs(hashtext(u.email)) % 350))::timestamp + interval '9 hours'),
  email_verified_at = (date '2025-10-01' + (abs(hashtext(u.email)) % 350))::timestamp + interval '10 hours',
  terms_accepted_at = coalesce(u.terms_accepted_at, (date '2025-10-01' + (abs(hashtext(u.email)) % 350))::timestamptz + interval '9 hours'),
  privacy_accepted_at = coalesce(u.privacy_accepted_at, (date '2025-10-01' + (abs(hashtext(u.email)) % 350))::timestamptz + interval '9 hours'),
  last_login_at = timestamp '2026-09-15 08:00:00' + ((abs(hashtext(u.email)) % 130) * interval '1 hour'),
  initials = coalesce(nullif(u.initials,''), upper(left(split_part(u.full_name,' ',1),1) || left(split_part(u.full_name,' ',2),1)))
where u.role = 'student';

with prog(i, college, program) as (values
 (0,'College of Computing Studies, Information and Communication Technology (CCSICT)','BS in Information Technology'),
 (1,'College of Computing Studies, Information and Communication Technology (CCSICT)','BS in Computer Science'),
 (2,'College of Business, Accountancy and Public Administration (CBAPA)','BS in Business Administration'),
 (3,'College of Business, Accountancy and Public Administration (CBAPA)','BS in Accountancy'),
 (4,'College of Education (CEd)','Bachelor of Elementary Education'),
 (5,'College of Engineering (CoE)','BS in Civil Engineering'),
 (6,'College of Arts and Sciences (CAS)','BS in Psychology'),
 (7,'College of Agriculture (CAgri)','BS in Agriculture')
)
insert into public.student_profiles (user_id, student_id, program, year_level, college, osas_verified_at, emergency_contact_json)
select u.id,
       to_char(date '2020-01-01' + ((abs(hashtext(u.email)) % 5) * 365), 'YY') || '-' || lpad((abs(hashtext(u.email)) % 9999)::text, 4, '0'),
       p.program, 1 + (abs(hashtext(u.email)) % 4), p.college,
       case when u.status='verified' then u.registered_at::timestamp + interval '3 days' end,
       jsonb_build_object(
         'name', (array['Rosa','Manuel','Teresita','Efren','Lolita','Arnel'])[1 + (abs(hashtext(u.email)) % 6)] || ' ' || coalesce(nullif(split_part(u.full_name,' ',2),''),'Santos'),
         'relationship', (array['Mother','Father','Guardian','Aunt','Uncle'])[1 + (abs(hashtext(u.email)) % 5)],
         'phone', '+639' || lpad((180000000 + (abs(hashtext(u.email||'e')) % 19999999))::text, 9, '0'))
from public.users u
join prog p on p.i = (abs(hashtext(u.email)) % 8)
where u.role='student'
on conflict (user_id) do update set student_id=excluded.student_id, program=excluded.program,
  year_level=excluded.year_level, college=excluded.college, osas_verified_at=excluded.osas_verified_at,
  emergency_contact_json=excluded.emergency_contact_json;


-- ===========================================================================
-- PART 2 - ACCOMMODATIONS
-- ===========================================================================
-- Real barangays around the ISU Echague campus (16.7053, 121.6742), plus two
-- in Santiago City. 9 accredited / 1 pending / 1 reviewing / 1 rejected, so
-- the Verifications queue and the status filter are not all one colour.
with mgr as (
  select id, row_number() over (order by registered_at) rn from public.users where role='accommodation_manager'
), acc(idx, name, biz, atype, brgy, city, lat, lng, floors, descr, st, accr_at, expires) as (values
 (1,'Plaza Student Residences','Plaza Realty & Rentals','boarding_house','San Fabian','Echague',16.72214,121.67967,3,'A three-storey boarding house a seven-minute walk from the ISU main gate. Purpose-built for students, with study nooks on every floor and a curfew the barangay actually enforces.','accredited',timestamptz '2025-11-04 10:00+08',timestamptz '2027-11-04 10:00+08'),
 (2,'Bagtas Ladies Dormitory','Bagtas Family Rentals','residence_hall','Soyung','Echague',16.70981,121.66742,2,'Ladies-only dormitory run by the Bagtas family since 2009. House mother on site, gate locked at 10PM, and a covered dining area that doubles as a study hall during finals.','accredited',timestamptz '2025-10-20 09:30+08',timestamptz '2027-10-20 09:30+08'),
 (3,'Dalisay Apartelle','Dalisay Holdings','apartment','Garit Norte','Echague',16.71455,121.68310,3,'Self-contained units with private kitchens and bathrooms. Popular with senior students and those on practicum who keep irregular hours.','accredited',timestamptz '2025-10-28 14:15+08',timestamptz '2027-10-28 14:15+08'),
 (4,'Casa Pascua Boarding House','Casa Pascua','boarding_house','Silauan Sur','Echague',16.70122,121.67015,2,'Quiet family-run boarding house on a residential street. Ten rooms, a shared kitchen, and the owner living in the front unit.','accredited',timestamptz '2025-12-08 11:00+08',timestamptz '2027-12-08 11:00+08'),
 (5,'Tumaliuan Student Inn','Tumaliuan Enterprises','boarding_house','Angoluan','Echague',16.69760,121.68602,2,'Budget bedspace and shared rooms near the public market and jeepney terminal. The cheapest accredited option on the list.','accredited',timestamptz '2026-02-02 08:45+08',timestamptz '2028-02-02 08:45+08'),
 (6,'Blanza Hillside Lodging','Blanza Property Management','boarding_house','San Fabian','Echague',16.72540,121.68155,2,'Newer build on the hillside, concrete and steel, with a generator that actually gets used during brownouts. Fibre internet in every room.','accredited',timestamptz '2025-11-25 16:20+08',timestamptz '2027-11-25 16:20+08'),
 (7,'Mangaoang Residences','Mangaoang Rentals','apartment','Salay','Echague',16.70330,121.65980,3,'Studio-type units with individual meters, so tenants pay only what they use. Motorcycle parking in the courtyard.','pending',null,null),
 (8,'Cauilan Bedspace Center','Cauilan Bedspacing','boarding_house','Madadamian','Echague',16.69215,121.66421,2,'Bedspace-only operation aimed at working students. Twenty-four hour access and lockers in every room.','reviewing',null,null),
 (9,'Centro Student Hub','Centro Hub Inc.','condominium_unit','Centro East','Santiago',16.68804,121.54982,4,'Condominium units in Santiago City, for students commuting to the Echague campus on the weekday shuttle.','accredited',timestamptz '2026-01-20 13:00+08',timestamptz '2028-01-20 13:00+08'),
 (10,'Divisoria Suites','Divisoria Property Group','apartment','Divisoria','Santiago',16.69708,121.60500,3,'Apartment-style suites beside the Divisoria commercial strip. Two students per unit, each with their own room.','accredited',timestamptz '2026-03-11 10:30+08',timestamptz '2028-03-11 10:30+08'),
 (11,'Ipil Gardens Dormitory','Ipil Gardens','residence_hall','Ipil','Echague',16.71890,121.66120,2,'Garden dormitory with a large shared kitchen and a laundry area under a covered walkway. Mixed, with separate wings by floor.','accredited',timestamptz '2025-12-19 09:00+08',timestamptz '2027-12-19 09:00+08'),
 (12,'Dammang Transient Rooms','Dammang Rentals','boarding_house','Dammang East','Echague',16.68470,121.69340,1,'Single-storey rooms let by the month, mostly to students on short practicum rotations.','rejected',null,null)
)
insert into public.accommodations (id, accommodation_manager_id, name, business_name, accommodation_type, room_type,
  address, barangay, city, lat, lng, total_floors, description, status, accreditation_status, accredited_at,
  accreditation_expires_at, gender_policy)
select ('00000000-0000-4000-8000-' || lpad((300+idx)::text,12,'0'))::uuid,
       m.id, a.name, a.biz, a.atype,
       (array['solo','duo','triple','bedspace','studio'])[1 + (idx % 5)]::room_type,
       'Purok ' || (1 + idx % 6) || ', ' || a.brgy, a.brgy, a.city, a.lat, a.lng, a.floors, a.descr,
       a.st::accommodation_status,
       case when a.st='accredited' then 'accredited' else a.st end,
       a.accr_at, a.expires,
       -- gender_policy is constrained to male | female | co_ed.
       case when idx=2 then 'female' when idx=8 then 'male' else 'co_ed' end
from acc a join mgr m on m.rn = 1 + ((a.idx - 1) % 8);

-- rent_basis is constrained to 'room' | 'person' (not per_room/per_head).
insert into public.rooms (id, accommodation_id, label, room_number, floor, capacity, current_pax,
                          monthly_rent, status, room_type, advance_months, deposit_months, rent_basis)
select ('00000000-0000-4000-8000-' || lpad((400 + (a.n*10) + r)::text,12,'0'))::uuid,
       a.id, 'Room ' || (a.n*100 + r), (a.n*100 + r)::text,
       1 + ((r-1) / 3), cap.c, 0, cap.rent, 'available'::room_status, cap.rt, 1, 1,
       case when cap.rt='bedspace' then 'person' else 'room' end
from (select id, row_number() over (order by name) n from public.accommodations) a
cross join lateral generate_series(1, 4 + (a.n % 4)) r
cross join lateral (select
    case when (a.n + r) % 4 = 0 then 1 when (a.n + r) % 4 = 1 then 2 when (a.n + r) % 4 = 2 then 3 else 4 end as c,
    case when (a.n + r) % 4 = 0 then 'solo' when (a.n + r) % 4 = 1 then 'duo' when (a.n + r) % 4 = 2 then 'triple' else 'bedspace' end as rt,
    case when (a.n + r) % 4 = 0 then 3500 when (a.n + r) % 4 = 1 then 2800 when (a.n + r) % 4 = 2 then 2200 else 1500 end as rent
  ) cap;

update public.accommodations a set
  total_rooms = (select count(*) from public.rooms r where r.accommodation_id = a.id),
  capacity    = (select coalesce(sum(capacity),0) from public.rooms r where r.accommodation_id = a.id);

insert into public.accommodation_amenities (accommodation_id, amenity)
select a.id, am::amenity
from (select id, row_number() over (order by name) n from public.accommodations) a
cross join lateral unnest(array['wifi','water','electric']) am
union
select a.id, t.am::amenity
from (select id, row_number() over (order by name) n from public.accommodations) a
cross join lateral unnest(array['aircon','parking','kitchen','laundry','cctv']) with ordinality t(am, k)
where (a.n + k) % 3 <> 0;

insert into public.accommodation_policies (accommodation_id, advance_months, deposit_months, min_stay,
  contract_type, quiet_hours, visitor_policy, curfew_time, cooking, laundry, pets, smoking)
select a.id, 1, 1, case when a.n % 3 = 0 then 5 else 4 end,
  case when a.n % 2 = 0 then 'Semestral' else 'Monthly' end,
  '9:00 PM - 5:00 AM',
  case when a.n % 3 = 0 then 'Visitors in common areas only, until 8:00 PM'
       else 'Visitors must be logged at the gate and leave by 9:00 PM' end,
  case when a.n % 4 = 0 then '11:00 PM' else '10:00 PM' end,
  a.n % 5 <> 0, true, false, false
from (select id, row_number() over (order by name) n from public.accommodations) a;

with pics(k, url) as (values
 (0,'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200&q=80'),
 (1,'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1200&q=80'),
 (2,'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200&q=80'),
 (3,'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200&q=80'),
 (4,'https://images.unsplash.com/photo-1554995207-c18c203602cb?w=1200&q=80'),
 (5,'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=1200&q=80'),
 (6,'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=1200&q=80'),
 (7,'https://images.unsplash.com/photo-1567767292278-a4f21aa2d36e?w=1200&q=80'),
 (8,'https://images.unsplash.com/photo-1505873242700-f289a29e1e0f?w=1200&q=80'),
 (9,'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?w=1200&q=80'),
 (10,'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=1200&q=80'),
 (11,'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200&q=80')
)
insert into public.accommodation_images (id, accommodation_id, url, sort_order)
select gen_random_uuid(), a.id, p.url, s.s
from (select id, row_number() over (order by name) n from public.accommodations) a
cross join generate_series(0,2) s(s)
join pics p on p.k = ((a.n + s.s * 4) % 12)::int;

with rpics(k, url) as (values
 (0,'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=900&q=80'),
 (1,'https://images.unsplash.com/photo-1540518614846-7eded433c457?w=900&q=80'),
 (2,'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=900&q=80'),
 (3,'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=900&q=80'),
 (4,'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?w=900&q=80'),
 (5,'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=900&q=80')
)
insert into public.room_images (id, room_id, url, sort_order)
select gen_random_uuid(), r.id, p.url, 0
from (select id, row_number() over (order by id) n from public.rooms) r
join rpics p on p.k = (r.n % 6)::int;

-- Permits. Two expiring inside 30 days and one expired, so the Compliance tab
-- has something other than green; house 12 is missing its building permit.
-- doc-access hands plain (non `cld:`) URLs straight back, so these open.
with docpics(t, url) as (values
 ('fire_safety',    'https://images.unsplash.com/photo-1568057373484-9b1b1e1e0c1f?w=1400&q=80'),
 ('business_permit','https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=1400&q=80'),
 ('sanitary_permit','https://images.unsplash.com/photo-1586281380349-632531db7ed4?w=1400&q=80'),
 ('building_permit','https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=1400&q=80')
)
insert into public.accommodation_documents (id, accommodation_id, doc_type, file_url, version, issued_at, expires_at, uploaded_at)
select gen_random_uuid(), a.id, d.t, dp.url, 1,
       (date '2025-09-01' + (a.n * 9)::int),
       case when a.n = 5 and d.k = 1 then current_date + 12
            when a.n = 9 and d.k = 3 then current_date + 25
            when a.n = 4 and d.k = 2 then current_date - 40
            else (date '2025-09-01' + (a.n * 9)::int) + 730 end,
       (date '2025-09-01' + (a.n * 9)::int)::timestamp + interval '10 hours'
from (select id, row_number() over (order by name) n from public.accommodations) a
cross join lateral unnest(array['fire_safety','business_permit','sanitary_permit','building_permit']) with ordinality d(t, k)
join docpics dp on dp.t = d.t
where not (a.n = 12 and d.k = 4);

-- GOTCHA 2: inserting documents fired the resubmission trigger and reset every
-- accommodation to 'pending'. accreditation_status kept the intended value.
update public.accommodations set status = accreditation_status::accommodation_status
where accreditation_status is not null and status::text <> accreditation_status;


-- ===========================================================================
-- PART 3 - TENANCIES, RENT, HISTORY
-- ===========================================================================
create temporary table _slot as
select r.id as room_id, r.accommodation_id, r.monthly_rent, a.accommodation_manager_id,
       row_number() over (order by a.name, r.room_number, g.i) as sn
from public.rooms r
join public.accommodations a on a.id = r.accommodation_id
cross join lateral generate_series(1, coalesce(r.capacity,1)) g(i)
where a.status = 'accredited';

create temporary table _stud as
select u.id, row_number() over (order by u.registered_at, u.email) as sn
from public.users u where u.role='student' and u.status='verified';

-- First semester, finished.
insert into public.leases (id, room_id, student_id, accommodation_manager_id, start_date, end_date,
                           monthly_rent, advance_paid, deposit_paid, status, ended_reason)
select ('00000000-0000-4000-8000-' || lpad((600 + s.sn)::text,12,'0'))::uuid,
       sl.room_id, s.id, sl.accommodation_manager_id, date '2025-11-03', date '2026-03-27',
       sl.monthly_rent, sl.monthly_rent, sl.monthly_rent, 'ended'::lease_status,
       case when s.sn % 3 = 0 then 'Semester ended' when s.sn % 3 = 1 then 'Moved closer to campus' else 'Completed contract' end
from _stud s join _slot sl on sl.sn = s.sn where s.sn <= 14;

-- Second semester, current. Different rooms, so boarding history means something.
insert into public.leases (id, room_id, student_id, accommodation_manager_id, start_date, end_date,
                           monthly_rent, advance_paid, deposit_paid, status, leave_requested_at)
select ('00000000-0000-4000-8000-' || lpad((700 + s.sn)::text,12,'0'))::uuid,
       sl.room_id, s.id, sl.accommodation_manager_id,
       date '2026-06-08' + ((s.sn % 5) * 7)::int, date '2027-04-30',
       sl.monthly_rent, sl.monthly_rent, sl.monthly_rent,
       case when s.sn = 7 then 'leave_requested'::lease_status else 'active'::lease_status end,
       case when s.sn = 7 then timestamp '2026-09-12 14:20:00' end
from _stud s join _slot sl on sl.sn = 30 + s.sn where s.sn <= 40;

update public.rooms r set
  current_pax = (select count(*) from public.leases l where l.room_id=r.id and l.status in ('active','leave_requested')),
  status = case when (select count(*) from public.leases l where l.room_id=r.id and l.status in ('active','leave_requested')) >= coalesce(r.capacity,1)
                then 'occupied'::room_status else 'available'::room_status end;

update public.rooms set status='maintenance'
where id in (select id from public.rooms where current_pax = 0 order by id limit 2);

insert into public.boarding_history (id, student_id, accommodation_id, accommodation_name, room_type, period_start, period_end, end_reason)
select gen_random_uuid(), l.student_id, r.accommodation_id, a.name, r.room_type, l.start_date, l.end_date, l.ended_reason
from public.leases l join public.rooms r on r.id=l.room_id join public.accommodations a on a.id=r.accommodation_id
where l.status='ended';

insert into public.payments (id, lease_id, month, description, amount, status, method, txn_reference, paid_at, verified_by)
select gen_random_uuid(), l.id, m::date,
       'Monthly rent - ' || to_char(m, 'FMMonth YYYY'), l.monthly_rent,
       case when l.status = 'ended' then 'paid'::payment_status
            when m >= date_trunc('month', current_date) then
              case when (abs(hashtext(l.id::text)) % 7) = 0 then 'overdue'::payment_status
                   when (abs(hashtext(l.id::text)) % 5) = 0 then 'pending_verification'::payment_status
                   when (abs(hashtext(l.id::text)) % 3) = 0 then 'due'::payment_status
                   else 'paid'::payment_status end
            else 'paid'::payment_status end,
       (array['gcash','gcash','gcash','maya','bank','cash'])[1 + (abs(hashtext(l.id::text || m::text)) % 6)]::payment_method,
       'REF' || upper(substr(md5(l.id::text || m::text), 1, 10)),
       case when m < date_trunc('month', current_date) or (abs(hashtext(l.id::text)) % 3) <> 0
            then m::timestamp + interval '4 days' + ((abs(hashtext(l.id::text||m::text)) % 72) * interval '1 hour') end,
       case when m < date_trunc('month', current_date) then l.accommodation_manager_id end
from public.leases l
cross join lateral generate_series(
  date_trunc('month', l.start_date::timestamp),
  date_trunc('month', least(coalesce(l.end_date, current_date), current_date)::timestamp),
  interval '1 month') m;

-- An unpaid row must not carry a reference, a paid date or a verifier.
update public.payments set paid_at = null, verified_by = null, txn_reference = null
where status in ('due','overdue');


-- ===========================================================================
-- PART 4 - REVIEWS  (all three tables were empty; ratings had nothing behind them)
-- ===========================================================================
with c(k, body) as (values
 (0,'Malinis at tahimik. The house rules are strict but that is exactly why I could study at night.'),
 (1,'Walking distance to campus and the water never ran out. Wifi slows down around 9PM when everyone is online.'),
 (2,'Manager is responsive - reported a broken faucet in the morning and it was fixed by afternoon.'),
 (3,'Good value for the price. The shared kitchen gets crowded at dinner but everyone takes turns.'),
 (4,'Clean rooms and the curfew is enforced fairly. Would recommend to first-year students.'),
 (5,'Comfortable stay overall. Parking for my motorcycle was the deciding factor.'),
 (6,'Quiet neighbourhood and friendly housemates. The stairs are steep, which is my only complaint.'),
 (7,'Nothing fancy but everything works. Electricity is submetered so you only pay what you use.')
)
insert into public.accommodation_reviews (id, lease_id, student_id, accommodation_id, rating, comment, created_at)
select gen_random_uuid(), l.id, l.student_id, r.accommodation_id,
       3 + (abs(hashtext(l.id::text)) % 3), c.body,
       coalesce(l.end_date, current_date)::timestamp - interval '3 days'
from public.leases l
join public.rooms r on r.id = l.room_id
join c on c.k = (abs(hashtext(l.id::text)) % 8)
where l.status = 'ended' or (l.status='active' and (abs(hashtext(l.id::text)) % 2) = 0);

with c(k, body) as (values
 (0,'Approachable and easy to talk to. Replies to messages the same day.'),
 (1,'Fair with the deposit and explained every charge on the bill.'),
 (2,'Handles repairs quickly and checks in on the tenants now and then.'),
 (3,'Strict about the rules but consistent, which I appreciated.')
)
insert into public.accommodation_manager_reviews (id, lease_id, student_id, accommodation_manager_id, rating, comment, created_at)
select gen_random_uuid(), l.id, l.student_id, l.accommodation_manager_id,
       4 + (abs(hashtext(l.id::text || 'm')) % 2), c.body,
       coalesce(l.end_date, current_date)::timestamp - interval '2 days'
from public.leases l join c on c.k = (abs(hashtext(l.id::text || 'm')) % 4)
where l.status = 'ended';

with c(k, body) as (values
 (0,'Paid on time every month and kept the room in good condition.'),
 (1,'Quiet tenant, no complaints from the neighbours.'),
 (2,'Followed house rules and got along with the other boarders.'),
 (3,'Left the room clean at the end of the contract.')
)
insert into public.tenant_reviews (id, lease_id, accommodation_manager_id, student_id, rating, comment, created_at)
select gen_random_uuid(), l.id, l.accommodation_manager_id, l.student_id,
       4 + (abs(hashtext(l.id::text || 't')) % 2), c.body,
       coalesce(l.end_date, current_date)::timestamp - interval '1 day'
from public.leases l join c on c.k = (abs(hashtext(l.id::text || 't')) % 4)
where l.status = 'ended';

-- The number on the card must match the reviews behind it.
update public.accommodations a set reviews_count = coalesce(x.c, 0), rating_avg = x.r
from (select accommodation_id, count(*) c, round(avg(rating)::numeric, 1) r
      from public.accommodation_reviews group by accommodation_id) x
where x.accommodation_id = a.id;

update public.accommodations set reviews_count = 0, rating_avg = null
where id not in (select accommodation_id from public.accommodation_reviews);


-- ===========================================================================
-- PART 5 - FACILITIES
-- ===========================================================================
-- accommodation_facilities enforces the split itself: shared => room_id null,
-- private => room_id set.
insert into public.accommodation_facilities (id, accommodation_id, room_id, facility_type, access_scope, label, description, sort_order, floor)
select gen_random_uuid(), a.id, null, 'bathroom', 'shared',
       'Shared bathroom, ' || f.fl || case f.fl when 1 then 'st' when 2 then 'nd' when 3 then 'rd' else 'th' end || ' floor',
       'Two cubicles and two shower stalls, cleaned daily by the caretaker.', f.fl, f.fl
from (select id, total_floors, row_number() over (order by name) n from public.accommodations) a
cross join lateral generate_series(1, greatest(coalesce(a.total_floors,1),1)) f(fl);

insert into public.accommodation_facilities (id, accommodation_id, room_id, facility_type, access_scope, label, description, sort_order, floor)
select gen_random_uuid(), a.id, null, v.t, 'shared', v.lab, v.descr, 10 + v.k, 1
from (select id, row_number() over (order by name) n from public.accommodations) a
cross join lateral (values
  (1,'kitchen','Shared kitchen','Four gas burners, a communal refrigerator and a dish rack. Label your own food.'),
  (2,'laundry','Laundry area','Covered washing area with concrete sinks and a drying line.')
) v(k, t, lab, descr);

insert into public.accommodation_facilities (id, accommodation_id, room_id, facility_type, access_scope, label, description, sort_order, floor)
select gen_random_uuid(), a.id, null, v.t, 'shared', v.lab, v.descr, 20 + v.k, 1
from (select id, row_number() over (order by name) n from public.accommodations) a
cross join lateral (values
  (1,'common_area','Common area','Sofa, dining table and a wall-mounted television. Quiet hours apply after 9PM.'),
  (2,'study_area','Study area','Long tables with outlets at every seat, open all night during finals week.'),
  (3,'parking','Parking','Gated courtyard with space for motorcycles and two cars.')
) v(k, t, lab, descr)
where (a.n + v.k) % 3 <> 0;

insert into public.accommodation_facilities (id, accommodation_id, room_id, facility_type, access_scope, label, description, sort_order, floor)
select gen_random_uuid(), r.accommodation_id, r.id, 'bathroom', 'private',
       'Private bathroom', 'Ensuite toilet and shower for this room only.', 1, r.floor
from public.rooms r where r.room_type in ('solo','studio');

insert into public.accommodation_facilities (id, accommodation_id, room_id, facility_type, access_scope, label, description, sort_order, floor)
select gen_random_uuid(), r.accommodation_id, r.id, 'balcony', 'private',
       'Balcony', 'Private balcony with a drying rail, facing the courtyard.', 2, r.floor
from (select *, row_number() over (order by id) n from public.rooms) r
where r.room_type in ('solo','studio') and r.n % 2 = 0 and r.floor > 1;

with pics(k, url) as (values
 (0,'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=900&q=80'),
 (1,'https://images.unsplash.com/photo-1556911220-bff31c812dba?w=900&q=80'),
 (2,'https://images.unsplash.com/photo-1626806787461-102c1bfaaea1?w=900&q=80'),
 (3,'https://images.unsplash.com/photo-1567016432779-094069958ea5?w=900&q=80')
)
insert into public.accommodation_facility_images (id, facility_id, url, sort_order)
select gen_random_uuid(), f.id, p.url, 0
from (select id, row_number() over (order by id) n from public.accommodation_facilities
      where access_scope='shared' and facility_type in ('bathroom','kitchen','laundry','common_area')) f
join pics p on p.k = (f.n % 4)::int
where f.n % 3 = 0;


-- ===========================================================================
-- PART 6 - TICKETS, ANNOUNCEMENTS, DECISIONS, FEEDS
-- ===========================================================================
-- Support tickets are the student-to-OSAS channel, so ticket_messages.author_role
-- is constrained to 'student' | 'agent' and the replies come from OSAS.
with t(k, subj, descr, cat, pri, st, age) as (values
 (0,'Leaking faucet in the shared bathroom','The tap on the second floor bathroom has been dripping for three days and the basin is always wet.','maintenance','medium','resolved',54),
 (1,'Wifi keeps disconnecting at night','From around 9PM the connection drops every few minutes. Hard to submit online requirements.','utilities','medium','resolved',41),
 (2,'Request for official receipt','I need an official receipt for my rent payments for my scholarship requirements.','billing','low','resolved',33),
 (3,'Noise after curfew','A group in the next room plays music past 11PM on weekends.','conduct','medium','in_progress',12),
 (4,'Broken window latch','The latch on my window does not lock anymore. Concerned about security.','maintenance','high','in_progress',8),
 (5,'Clarification on deposit refund','My contract ends next month. How long before the deposit is returned?','billing','low','open',5),
 (6,'No water supply this morning','There was no water from 6AM to 10AM today, no advance notice.','utilities','high','open',2),
 (7,'Request to transfer rooms','I would like to move to a solo room if one becomes available next semester.','other','low','open',1)
)
insert into public.tickets (id, lease_id, subject, description, category, photo_urls, priority, status,
                            reported_at, updated_at, resolved_at, student_id, accommodation_manager_id,
                            accommodation_id, assignee_id, reporter_name)
select ('00000000-0000-4000-8000-' || lpad((800 + row_number() over (order by l.id, t.k))::text,12,'0'))::uuid,
       l.id, t.subj, t.descr, t.cat, '{}'::text[], t.pri, t.st,
       (current_date - t.age)::timestamptz + interval '9 hours',
       (current_date - greatest(t.age - 2, 0))::timestamptz + interval '11 hours',
       case when t.st='resolved' then (current_date - greatest(t.age - 4, 0))::timestamptz + interval '15 hours' end,
       l.student_id, l.accommodation_manager_id, r.accommodation_id,
       case when t.st <> 'open' then '672e25f5-8798-4a47-9c94-dbb7774bccd8'::uuid end,
       u.full_name
from (select l.*, row_number() over (order by id) rn from public.leases l where l.status in ('active','leave_requested')) l
join public.rooms r on r.id = l.room_id
join public.users u on u.id = l.student_id
join t on t.k = (l.rn % 8)
where l.rn <= 16;

insert into public.ticket_messages (id, ticket_id, author_id, author_role, body, is_internal, attachment_urls, created_at)
select gen_random_uuid(), tk.id, tk.student_id, 'student', tk.description, false, '{}'::text[], tk.reported_at
from public.tickets tk
union all
select gen_random_uuid(), tk.id, '672e25f5-8798-4a47-9c94-dbb7774bccd8'::uuid, 'agent',
       case tk.status
         when 'resolved' then 'We coordinated with the accommodation manager and this has been taken care of. Closing the ticket - reopen it if it comes back.'
         when 'in_progress' then 'Thank you for reporting. OSAS has endorsed this to the accommodation manager and we are following it up this week.'
         else 'Received. OSAS is reviewing this and will get back to you within two working days.' end,
       false, '{}'::text[], tk.reported_at + interval '5 hours'
from public.tickets tk where tk.status <> 'open'
union all
select gen_random_uuid(), tk.id, tk.student_id, 'student', 'Thank you po, confirmed fixed.', false, '{}'::text[], tk.resolved_at
from public.tickets tk where tk.status='resolved';

insert into public.announcements (id, author_id, title, body, summary, audience, published_at, expires_at, archived, event_at, deadline_at, location)
values
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Accommo is now live for ISU Echague','The Office of Student Affairs and Services is rolling out Accommo, the accredited housing directory for ISU Echague. Browse accredited boarding houses, apply for a room, and raise concerns directly with OSAS.','Accommo launches for ISU Echague.','all',timestamp '2025-10-06 08:00',timestamp '2025-12-31 23:59',true,null,null,'OSAS Office'),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Call for accommodation accreditation, AY 2025-2026','Owners of boarding houses, dormitories and apartments serving ISU students are invited to apply for accreditation. Submit your fire safety, sanitary, business and building permits through the Accommo manager app.','Accreditation applications are open.','accommodation_managers',timestamp '2025-10-15 09:00',timestamp '2026-01-31 23:59',true,null,timestamp '2026-01-31 17:00','OSAS Office'),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Reminder: second semester move-in schedule','Students moving in for the second semester should coordinate with their accommodation manager before 3 January. Bring your validated ID and proof of enrolment.','Coordinate move-in before 3 January.','students',timestamp '2025-12-18 10:00',timestamp '2026-01-15 23:59',true,timestamp '2026-01-03 08:00',null,null),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Boarding house safety inspection, February','OSAS together with the Bureau of Fire Protection will conduct the annual safety inspection of accredited accommodations. Managers should ensure extinguishers are within their inspection date.','Annual BFP safety inspection.','accommodation_managers',timestamp '2026-01-28 08:30',timestamp '2026-03-01 23:59',true,timestamp '2026-02-10 08:00',null,'All accredited accommodations'),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Summer break: securing your belongings','Students leaving for the summer break should coordinate with their manager about storage and whether their room is being held. OSAS is not liable for belongings left behind.','Coordinate storage before the break.','students',timestamp '2026-04-02 09:00',timestamp '2026-06-01 23:59',true,null,timestamp '2026-04-20 17:00',null),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Accredited housing list for first semester AY 2026-2027','The updated list of accredited accommodations is now available in the app. Nine houses passed accreditation this cycle. Staying in a non-accredited house is at your own risk.','Nine accredited houses for the new year.','all',timestamp '2026-06-01 08:00',timestamp '2026-10-31 23:59',false,null,null,null),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Rent payment reminders now in the app','Payments are now tracked in Accommo. You will get a reminder three days before rent is due, and your payment history is visible under My Stay.','Rent reminders are now automatic.','students',timestamp '2026-07-14 13:00',timestamp '2026-12-31 23:59',false,null,null,null),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Permit renewal deadline approaching','Accommodation managers whose permits expire within the next sixty days should upload the renewed documents. Accreditation lapses automatically when a required permit expires.','Renew expiring permits now.','accommodation_managers',timestamp '2026-09-08 08:00',timestamp '2026-11-30 23:59',false,null,timestamp '2026-10-15 17:00',null),
 (gen_random_uuid(),'672e25f5-8798-4a47-9c94-dbb7774bccd8','Student welfare check, October','OSAS will visit accredited accommodations for the semestral welfare check. Tenants may raise concerns anonymously through the support ticket channel in the app.','Semestral welfare check in October.','all',timestamp '2026-09-16 10:00',timestamp '2026-10-31 23:59',false,timestamp '2026-10-06 09:00',null,'Accredited accommodations');

-- verification_requests records decisions only: approved | rejected |
-- resubmission_requested. Pending and reviewing entities correctly have no row.
insert into public.verification_requests (id, entity_type, entity_id, type, status, reviewed_by, reviewed_at, rejection_reasons, decision_notes, created_at)
select gen_random_uuid(), 'accommodation', a.id, 'accreditation',
       case a.status::text when 'accredited' then 'approved' else 'rejected' end,
       '672e25f5-8798-4a47-9c94-dbb7774bccd8'::uuid,
       coalesce(a.accredited_at, now() - interval '9 days'),
       case when a.status='rejected' then array['Incomplete permits','Fire safety certificate not submitted'] end,
       case when a.status='accredited' then 'All four permits verified against the originals. Site inspection passed.'
            else 'Building permit and fire safety certificate were missing at the time of review. May reapply once complete.' end,
       coalesce(a.accredited_at, now() - interval '20 days') - interval '10 days'
from public.accommodations a where a.status in ('accredited','rejected');

insert into public.verification_requests (id, entity_type, entity_id, type, status, reviewed_by, reviewed_at, decision_notes, created_at)
select gen_random_uuid(), 'user', u.id, 'student_verification', 'approved',
       '672e25f5-8798-4a47-9c94-dbb7774bccd8'::uuid, u.registered_at + interval '3 days',
       'School ID and assessment of fees verified against the registrar record.', u.registered_at
from public.users u where u.role='student' and u.status='verified';

-- Personal documents. expires_at only on the types that expire.
with userpics(t, url) as (values
 ('school_id',          'https://images.unsplash.com/photo-1606159068539-43f36b99d1b1?w=1400&q=80'),
 ('assessment_of_fees', 'https://images.unsplash.com/photo-1554224154-26032ffc0d07?w=1400&q=80'),
 ('government_id',      'https://images.unsplash.com/photo-1614064641938-3bbee52942c7?w=1400&q=80'),
 ('business_permit',    'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=1400&q=80')
)
insert into public.verification_documents (id, user_id, doc_type, filename, file_url, status, uploaded_at, verified_at, verified_by, expires_at)
select gen_random_uuid(), u.id, d.t, d.t || '.jpg', up.url,
       case u.status::text when 'verified' then 'approved' when 'rejected' then 'rejected' else 'pending' end::doc_status,
       u.registered_at::timestamp,
       case when u.status='verified' then u.registered_at::timestamp + interval '3 days' end,
       case when u.status='verified' then '672e25f5-8798-4a47-9c94-dbb7774bccd8'::uuid end,
       case when d.t in ('government_id','business_permit') then (u.registered_at + interval '3 years')::date end
from public.users u
cross join lateral unnest(
  case when u.role='student' then array['school_id','assessment_of_fees']
       else array['government_id','business_permit'] end) d(t)
join userpics up on up.t = d.t
where u.role in ('student','accommodation_manager')
on conflict (user_id, doc_type) do nothing;

insert into public.notifications (id, user_id, type, title, body, link_url, read_at, created_at, ref_id, source)
select gen_random_uuid(), l.student_id, 'payment',
       'Rent due for ' || to_char(p.month, 'FMMonth YYYY'),
       'Your rent of PHP ' || to_char(p.amount, 'FM999,999') || ' for ' || to_char(p.month, 'FMMonth YYYY') || ' is ' ||
         case p.status::text when 'paid' then 'settled. Thank you.' when 'overdue' then 'past due. Please settle as soon as possible.' else 'due this month.' end,
       '/student/my-stay',
       case when p.status = 'paid' then p.month::timestamp + interval '6 days' end,
       p.month::timestamptz + interval '8 hours', p.id, 'system'
from public.payments p join public.leases l on l.id = p.lease_id
where p.month >= current_date - interval '5 months';

insert into public.notifications (id, user_id, type, title, body, link_url, read_at, created_at, ref_id, source)
select gen_random_uuid(), u.id, 'announcement', an.title, coalesce(an.summary, left(an.body, 140)), '/announcements',
       case when an.published_at < now() - interval '14 days' then an.published_at + interval '2 days' end,
       an.published_at, an.id, 'osas'
from public.announcements an
join public.users u on (an.audience = 'all'
   or (an.audience = 'students' and u.role='student')
   or (an.audience = 'accommodation_managers' and u.role='accommodation_manager'))
where an.published_at > now() - interval '120 days';

insert into public.audit_logs (actor_id, action, entity_type, entity_id, created_at, after_json)
select '672e25f5-8798-4a47-9c94-dbb7774bccd8',
       case vr.status when 'approved' then 'verification.approved' else 'verification.rejected' end,
       vr.entity_type, vr.entity_id::text, vr.reviewed_at,
       jsonb_build_object('type', vr.type, 'notes', vr.decision_notes)
from public.verification_requests vr;


-- ===========================================================================
-- VERIFY - every line should read 0 except the counts
-- ===========================================================================
select 'orphan profiles'      as check, count(*)::text as result from public.users u left join auth.users a on a.id=u.id where a.id is null
union all select 'google identities kept', count(*)::text from auth.identities where provider='google'
union all select 'rating mismatch', count(*)::text from public.accommodations a
   join (select accommodation_id, count(*) c, round(avg(rating)::numeric,1) r from public.accommodation_reviews group by 1) x
     on x.accommodation_id=a.id where a.reviews_count <> x.c or a.rating_avg <> x.r
union all select 'rooms over capacity', count(*)::text from public.rooms where current_pax > capacity
union all select 'leases without payments', count(*)::text from public.leases l where not exists (select 1 from public.payments p where p.lease_id=l.id)
union all select 'duplicate user documents', count(*)::text from (select user_id, doc_type from public.verification_documents group by 1,2 having count(*)>1) d
union all select 'facility scope violations', count(*)::text from public.accommodation_facilities where (access_scope='shared') <> (room_id is null)
union all select 'unpaid rows carrying a receipt', count(*)::text from public.payments where status in ('due','overdue') and (paid_at is not null or verified_by is not null)
union all select 'COUNT users', count(*)::text from public.users
union all select 'COUNT accommodations', count(*)::text from public.accommodations
union all select 'COUNT leases', count(*)::text from public.leases
union all select 'COUNT payments', count(*)::text from public.payments;
