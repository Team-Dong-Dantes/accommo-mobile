-- Three follow-ups to per-room utilities and the listing editor.
--
-- 1. A lease keeps the utility terms it was agreed under. Rent was always
--    copied onto the lease (leases.monthly_rent); utilities were read live off
--    the room, so a landlord/landlady switching a room from "included" to a
--    flat fee raised every current tenant's next payment without a word. The
--    terms are now copied onto the lease when it is created and again when it
--    becomes active (the move-in), and never follow the room after that.
--    One exception: a lease whose terms were never specified — every lease that
--    predates utilities — picks them up the first time its room's are set,
--    because there was no earlier agreement to protect.
-- 2. Utility bills get a due date, and a daily job reminds the tenant the day
--    before and once when it goes overdue.
-- 3. Floors can carry a name ("Ground", "Annex"); the number stays the key.

-- ---- 1. Lease utility terms ---------------------------------------------------
alter table public.leases
  add column if not exists water_billing public.utility_billing,
  add column if not exists water_flat_fee numeric,
  add column if not exists electric_billing public.utility_billing,
  add column if not exists electric_flat_fee numeric,
  add column if not exists wifi_billing public.utility_billing,
  add column if not exists wifi_flat_fee numeric;

create or replace function public.tg_lease_utility_terms() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  -- The terms are what was agreed, not the tenant's to edit.
  -- tg_lease_guard_student_update predates these columns and does not list them.
  if tg_op = 'UPDATE' and auth.uid() = old.student_id and auth.uid() is distinct from old.landlord_id
     and (new.water_billing, new.water_flat_fee, new.electric_billing, new.electric_flat_fee, new.wifi_billing, new.wifi_flat_fee)
         is distinct from
         (old.water_billing, old.water_flat_fee, old.electric_billing, old.electric_flat_fee, old.wifi_billing, old.wifi_flat_fee) then
    raise exception 'a student may not change the utility terms of a lease';
  end if;

  if tg_op = 'INSERT'
     or new.room_id is distinct from old.room_id
     or (new.status = 'active' and old.status is distinct from 'active') then
    select r.water_billing, r.water_flat_fee, r.electric_billing, r.electric_flat_fee, r.wifi_billing, r.wifi_flat_fee
      into new.water_billing, new.water_flat_fee, new.electric_billing, new.electric_flat_fee, new.wifi_billing, new.wifi_flat_fee
      from public.rooms r where r.id = new.room_id;
  end if;
  return new;
end;
$$;
revoke all on function public.tg_lease_utility_terms() from public, anon, authenticated;

drop trigger if exists trg_lease_utility_terms on public.leases;
create trigger trg_lease_utility_terms before insert or update on public.leases
  for each row execute function public.tg_lease_utility_terms();

-- Unspecified lease terms are filled the first time the room's are set.
create or replace function public.tg_room_fills_unset_lease_terms() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  update public.leases l set water_billing = new.water_billing, water_flat_fee = new.water_flat_fee
   where l.room_id = new.id and l.water_billing is null and new.water_billing is not null
     and l.status in ('pending', 'active', 'leave_requested');
  update public.leases l set electric_billing = new.electric_billing, electric_flat_fee = new.electric_flat_fee
   where l.room_id = new.id and l.electric_billing is null and new.electric_billing is not null
     and l.status in ('pending', 'active', 'leave_requested');
  update public.leases l set wifi_billing = new.wifi_billing, wifi_flat_fee = new.wifi_flat_fee
   where l.room_id = new.id and l.wifi_billing is null and new.wifi_billing is not null
     and l.status in ('pending', 'active', 'leave_requested');
  return null;
end;
$$;
revoke all on function public.tg_room_fills_unset_lease_terms() from public, anon, authenticated;

drop trigger if exists trg_room_fills_unset_lease_terms on public.rooms;
create trigger trg_room_fills_unset_lease_terms
  after update of water_billing, electric_billing, wifi_billing on public.rooms
  for each row execute function public.tg_room_fills_unset_lease_terms();

-- Existing leases take their room's current terms, where it has any.
update public.leases l set
  water_billing = r.water_billing, water_flat_fee = r.water_flat_fee,
  electric_billing = r.electric_billing, electric_flat_fee = r.electric_flat_fee,
  wifi_billing = r.wifi_billing, wifi_flat_fee = r.wifi_flat_fee
from public.rooms r
where r.id = l.room_id
  and (r.water_billing is not null or r.electric_billing is not null or r.wifi_billing is not null);

-- ---- 2. Bill due dates and reminders -----------------------------------------
alter table public.utility_bills
  add column if not exists due_date date not null default ((now() at time zone 'Asia/Manila')::date + 7),
  add column if not exists reminded_at timestamptz,
  add column if not exists overdue_notified_at timestamptz;

-- Daily, 8 AM Manila. Each notice goes once per bill. A bill counts as unpaid
-- under the same rule the app uses: no payment that is paid or awaiting
-- verification.
create or replace function public.remind_utility_bills() returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  today date := (now() at time zone 'Asia/Manila')::date;
  b record;
  label text;
begin
  for b in
    select ub.*, l.student_id
      from public.utility_bills ub
      join public.leases l on l.id = ub.lease_id
     where l.status in ('active', 'leave_requested')
       and not exists (select 1 from public.payments p
                        where p.bill_id = ub.id and p.status in ('paid', 'pending_verification'))
       and ((ub.due_date = today + 1 and ub.reminded_at is null)
            or (ub.due_date < today and ub.overdue_notified_at is null))
  loop
    label := case b.utility when 'water' then 'Water' when 'electric' then 'Electricity' else 'Wi-Fi' end;
    if b.due_date < today then
      insert into public.notifications (user_id, type, title, body, link_url)
      values (b.student_id, 'payment', label || ' bill overdue',
              'Your ' || lower(label) || ' bill of ₱' || b.amount || ' was due ' || to_char(b.due_date, 'Mon FMDD') || '.',
              '/student/payments');
      update public.utility_bills set overdue_notified_at = now() where id = b.id;
    else
      insert into public.notifications (user_id, type, title, body, link_url)
      values (b.student_id, 'payment', label || ' bill due tomorrow',
              'Your ' || lower(label) || ' bill of ₱' || b.amount || ' is due tomorrow.',
              '/student/payments');
      update public.utility_bills set reminded_at = now() where id = b.id;
    end if;
  end loop;
end;
$$;
revoke all on function public.remind_utility_bills() from public, anon, authenticated;

select cron.unschedule('remind-utility-bills') where exists (select 1 from cron.job where jobname = 'remind-utility-bills');
select cron.schedule('remind-utility-bills', '0 0 * * *', 'select public.remind_utility_bills()');

-- ---- 3. Floor names -----------------------------------------------------------
alter table public.accommodation_floors
  add column if not exists label text check (label is null or btrim(label) <> '');

drop policy if exists "accommodation_floors_update_own" on public.accommodation_floors;
create policy "accommodation_floors_update_own" on public.accommodation_floors
  for update to authenticated
  using (exists (select 1 from public.accommodations a where a.id = accommodation_floors.accommodation_id and a.landlord_id = (select auth.uid())))
  with check (exists (select 1 from public.accommodations a where a.id = accommodation_floors.accommodation_id and a.landlord_id = (select auth.uid())));

-- Students see a listing's floor names the way they see its rooms.
drop policy if exists "accommodation_floors_select_accredited" on public.accommodation_floors;
create policy "accommodation_floors_select_accredited" on public.accommodation_floors
  for select using (exists (select 1 from public.accommodations a where a.id = accommodation_floors.accommodation_id and a.status = 'accredited'));
