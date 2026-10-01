-- Amenities and utilities are two different questions, and this splits them.
--
-- An amenity is something the place has or does not have (Wi-Fi, CCTV, a
-- drinking-water dispenser, a backup generator, a fire extinguisher). Water and
-- electricity used to sit in the same chip list, where every listing ticked
-- them and the answer said nothing. What a student needs to know about them is
-- how they are paid, so they move to a billing setting on the accommodation:
--
--   included   - in the rent, nothing extra
--   own_meter  - the room's sub-meter, billed monthly by the landlord/landlady
--   split      - the house bill divided among tenants, billed monthly
--   flat_fee   - a fixed monthly amount, added to the rent payment
--
-- own_meter and split change every month, so the landlord/landlady posts each
-- one as a utility_bills row and the student pays it like rent: a payment that
-- points at the bill (payments.bill_id), verified the usual way. A bill is
-- settled when a payment against it is paid or awaiting verification; a
-- rejected one leaves it due again, the same as a rent month.

-- ---- Amenities --------------------------------------------------------------
alter type public.amenity add value if not exists 'water_dispenser';
alter type public.amenity add value if not exists 'generator';
alter type public.amenity add value if not exists 'fire_extinguisher';

-- Existing water/electric chips go. The check still admits them, though: APKs
-- released before this one offer them in the create form and would fail
-- mid-insert otherwise. Current clients never send them and skip any they find.
-- Drop them from the check once min_supported_version_code passes this release.
delete from public.accommodation_amenities where amenity::text in ('water', 'electric');

alter table public.accommodation_amenities
  drop constraint if exists accommodation_amenities_utilities_only;
alter table public.accommodation_amenities
  add constraint accommodation_amenities_utilities_only check (
    amenity::text = any (array[
      'wifi', 'cctv', 'water_dispenser', 'generator', 'fire_extinguisher',
      'water', 'electric' -- legacy, see above
    ])
  );

-- ---- Utility billing on the accommodation ------------------------------------
do $$ begin
  create type public.utility_billing as enum ('included', 'own_meter', 'split', 'flat_fee');
exception when duplicate_object then null;
end $$;

-- Null billing = not specified yet (every listing that predates this).
-- A flat fee carries its amount; every other mode carries none.
alter table public.accommodations
  add column if not exists water_billing public.utility_billing,
  add column if not exists water_flat_fee numeric,
  add column if not exists electric_billing public.utility_billing,
  add column if not exists electric_flat_fee numeric;

alter table public.accommodations
  drop constraint if exists accommodations_water_flat_fee,
  drop constraint if exists accommodations_electric_flat_fee;
alter table public.accommodations
  add constraint accommodations_water_flat_fee check (
    case when water_billing = 'flat_fee' then coalesce(water_flat_fee, 0) > 0 else water_flat_fee is null end
  ),
  add constraint accommodations_electric_flat_fee check (
    case when electric_billing = 'flat_fee' then coalesce(electric_flat_fee, 0) > 0 else electric_flat_fee is null end
  );

-- ---- Monthly utility bills ----------------------------------------------------
create table if not exists public.utility_bills (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.leases(id) on delete cascade,
  utility text not null check (utility in ('water', 'electric')),
  month date not null,
  amount numeric not null check (amount > 0),
  note text,
  created_at timestamptz not null default now(),
  unique (lease_id, utility, month)
);
create index if not exists idx_utility_bills_lease_id on public.utility_bills (lease_id);

alter table public.utility_bills enable row level security;

create policy "utility_bills_select_involved" on public.utility_bills
  for select to authenticated using (exists (
    select 1 from public.leases l
     where l.id = utility_bills.lease_id
       and (l.student_id = (select auth.uid()) or l.landlord_id = (select auth.uid()))
  ));
create policy "utility_bills_select_admin" on public.utility_bills
  for select to authenticated using ((select public.is_admin((select auth.uid()))));
-- Only the landlord/landlady of the lease writes bills.
create policy "utility_bills_write_landlord" on public.utility_bills
  for all to authenticated
  using (exists (select 1 from public.leases l where l.id = utility_bills.lease_id and l.landlord_id = (select auth.uid())))
  with check (exists (select 1 from public.leases l where l.id = utility_bills.lease_id and l.landlord_id = (select auth.uid())));

drop trigger if exists trg_audit_utility_bills on public.utility_bills;
create trigger trg_audit_utility_bills after insert or delete or update on public.utility_bills
  for each row execute function public.fn_audit_log_change();

-- ---- Paying a bill -----------------------------------------------------------
-- set null, not cascade: deleting a mis-posted bill must never take a payment
-- record with it. The payment keeps its description tag and stays readable.
alter table public.payments
  add column if not exists bill_id uuid references public.utility_bills(id) on delete set null;
create index if not exists idx_payments_bill_id on public.payments (bill_id);

-- A payment against a bill must be for that bill: same lease, same month, the
-- full amount. tg_payment_guard() already stops a student marking it paid.
-- Clearing bill_id is allowed — that is the FK's own set-null on bill delete.
create or replace function public.tg_payment_bill_check() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  b public.utility_bills;
begin
  if new.bill_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.bill_id is not distinct from old.bill_id then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    raise exception 'a payment cannot be moved to a different bill';
  end if;

  select * into b from public.utility_bills where id = new.bill_id;
  if b.id is null or b.lease_id <> new.lease_id then
    raise exception 'that bill does not belong to this lease';
  end if;
  if new.month <> b.month or new.amount <> b.amount then
    raise exception 'a bill payment must match the bill''s month and amount';
  end if;
  return new;
end;
$$;
revoke all on function public.tg_payment_bill_check() from public, anon, authenticated;
grant all on function public.tg_payment_bill_check() to service_role;

drop trigger if exists trg_payment_bill_check on public.payments;
create trigger trg_payment_bill_check before insert or update on public.payments
  for each row execute function public.tg_payment_bill_check();
