-- Payment validation, partial payments, and a ledger both apps read.
--
-- Until now the database checked only that an amount was above zero. A month
-- counted as paid after one payment of any size, the order of months, "one at a
-- time", required references and proof were all client-side, a reference or a
-- receipt could be reused, advance/deposit were never marked as paid, and
-- add_student_to_room charged each occupant of a whole-room lease the whole
-- room. This migration moves the rules into the database:
--
--   * payments.kind: rent | advance | deposit | bill, derived from bill_id and
--     the description tags (so older app builds that don't send it still work).
--   * What is owed: rent month = lease rent + flat fees; advance/deposit =
--     lease rent x the room's months; bill = the bill. Rounded to centavos.
--   * A payment may not exceed what is still owed (no overpayment). Less than
--     owed is a partial payment: always allowed when the landlord/landlady
--     records it; a student needs leases.allow_partial and at least
--     partial_min_pct of the amount (or the whole remainder if smaller).
--   * Rent months are paid in order, within the lease, at most two months
--     ahead; a month stays current until it is fully covered.
--   * A student has one submission awaiting confirmation per item at a time;
--     non-cash needs a reference and proof; GCash references are 13 digits,
--     others 6-30 letters/digits; a reference (or receipt image fingerprint)
--     can't be reused except on the same lease within 24 hours (one transfer
--     covering rent and a bill).
--   * Confirming: only a pending (or due/overdue) payment becomes paid, and it
--     still may not overpay; rejecting needs a reason; a confirmed payment's
--     amount, month and kind can't change.
--   * lease_ledger(): per item, owed / confirmed / pending / balance / state
--     (paid, pending, partial, unpaid, overdue).
-- OSAS (admins) and the database itself (no auth.uid()) are not subject to
-- these rules, so data can still be corrected.

-- 1 Columns ---------------------------------------------------------------------

alter table public.payments
  add column if not exists kind text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists proof_hash text,
  add column if not exists receipt_no text;

update public.payments set kind = case
    when bill_id is not null or description in ('Water bill', 'Electricity bill', 'Wi-Fi bill') then 'bill'
    when description = 'Advance payment' then 'advance'
    when description = 'Security deposit' then 'deposit'
    else 'rent' end
 where kind is null;
alter table public.payments alter column kind set not null;
-- tg_payment_rules sets it on every write; the default only keeps clients from having to.
alter table public.payments alter column kind set default 'rent';
alter table public.payments add constraint payments_kind_check check (kind in ('rent', 'advance', 'deposit', 'bill'));
alter table public.payments add constraint payments_amount_sane check (amount <= 1000000 and amount = round(amount, 2));
create index if not exists payments_lease_kind_month_idx on public.payments (lease_id, kind, month);
create index if not exists payments_reference_idx on public.payments (method, txn_reference) where txn_reference is not null;

alter table public.leases
  add column if not exists allow_partial boolean not null default false,
  add column if not exists partial_min_pct integer not null default 50
    constraint leases_partial_min_pct_check check (partial_min_pct between 10 and 100);

-- 2 What is owed and what covers it ---------------------------------------------

create or replace function public.payment_due(p_lease uuid, p_kind text, p_month date, p_bill uuid default null)
returns numeric
language sql
stable
security definer
set search_path to 'public'
as $$
  select round(case p_kind
    when 'rent' then l.monthly_rent
      + case when l.water_billing = 'flat_fee' then coalesce(l.water_flat_fee, 0) else 0 end
      + case when l.electric_billing = 'flat_fee' then coalesce(l.electric_flat_fee, 0) else 0 end
      + case when l.wifi_billing = 'flat_fee' then coalesce(l.wifi_flat_fee, 0) else 0 end
    when 'advance' then l.monthly_rent * greatest(coalesce(r.advance_months, 1), 0)
    when 'deposit' then l.monthly_rent * greatest(coalesce(r.deposit_months, 1), 0)
    when 'bill' then (select b.amount from public.utility_bills b where b.id = p_bill)
  end, 2)
  from public.leases l
  left join public.rooms r on r.id = l.room_id
  where l.id = p_lease;
$$;

-- Confirmed (paid) and awaiting-confirmation totals for one item, leaving out
-- one payment (the one being checked).
create or replace function public.payment_covered(p_lease uuid, p_kind text, p_month date, p_bill uuid, p_except uuid,
                                                  out confirmed numeric, out pending numeric)
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(sum(p.amount) filter (where p.status = 'paid'), 0),
         coalesce(sum(p.amount) filter (where p.status = 'pending_verification'), 0)
    from public.payments p
   where p.lease_id = p_lease and p.kind = p_kind
     and p.id is distinct from p_except
     and case p_kind when 'rent' then p.month = p_month
                     when 'bill' then p.bill_id = p_bill
                     else true end;
$$;

-- 3 The rules -------------------------------------------------------------------

create or replace function public.tg_payment_rules()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_me uuid := auth.uid();
  l public.leases;
  v_student boolean;
  v_due numeric;
  v_conf numeric;
  v_pend numeric;
  v_left numeric;
  v_min numeric;
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_m date;
  v_ref text;
begin
  -- Kind follows the row, never the client.
  new.kind := case
    when new.bill_id is not null or new.description in ('Water bill', 'Electricity bill', 'Wi-Fi bill') then 'bill'
    when new.description = 'Advance payment' then 'advance'
    when new.description = 'Security deposit' then 'deposit'
    else 'rent' end;
  new.month := date_trunc('month', new.month)::date;
  new.txn_reference := nullif(upper(regexp_replace(coalesce(new.txn_reference, ''), '[\s-]', '', 'g')), '');

  if v_me is null or public.is_admin(v_me) then
    return new;
  end if;

  select * into l from public.leases where id = new.lease_id;
  v_student := (v_me = l.student_id);

  -- Updates: status moves only; what was paid for stays put.
  if tg_op = 'UPDATE' then
    if new.amount is distinct from old.amount or new.month is distinct from old.month
       or new.lease_id is distinct from old.lease_id or new.kind is distinct from old.kind
       or new.bill_id is distinct from old.bill_id then
      raise exception 'A payment''s amount, month and item can''t be changed. Reject it and record a new one.';
    end if;
    if new.status is distinct from old.status then
      if old.status = 'paid' then
        raise exception 'This payment is already confirmed.';
      end if;
      if old.status = 'rejected' then
        raise exception 'A rejected payment stays rejected. The student can submit a new one.';
      end if;
      if new.status = 'rejected' then
        if coalesce(btrim(new.rejection_reason), '') = '' then
          raise exception 'Give a reason for rejecting — the student is told it.';
        end if;
        new.verified_by := v_me;
      elsif new.status = 'paid' then
        select c.confirmed into v_conf from public.payment_covered(new.lease_id, new.kind, new.month, new.bill_id, new.id) c;
        v_due := public.payment_due(new.lease_id, new.kind, new.month, new.bill_id);
        if v_due is not null and v_conf + new.amount > v_due + 0.009 then
          raise exception 'Confirming this would collect more than is owed (₱% of ₱% is already confirmed).', to_char(v_conf, 'FM999,999,990.00'), to_char(v_due, 'FM999,999,990.00');
        end if;
        new.verified_by := v_me;
        new.paid_at := coalesce(new.paid_at, now());
      end if;
    end if;
    if new.paid_at is not null and new.paid_at > now() + interval '5 minutes' then
      raise exception 'The payment date can''t be in the future.';
    end if;
    return new;
  end if;

  -- Inserts.
  if l.id is null then
    raise exception 'That stay no longer exists.';
  end if;
  if v_student and l.status not in ('active', 'leave_requested') then
    raise exception 'Payments are made on a current stay.';
  end if;
  if not v_student and l.status not in ('active', 'leave_requested', 'ended') then
    raise exception 'This stay isn''t active.';
  end if;
  if new.paid_at is not null and new.paid_at > now() + interval '5 minutes' then
    raise exception 'The payment date can''t be in the future.';
  end if;

  v_due := public.payment_due(new.lease_id, new.kind, new.month, new.bill_id);
  if v_due is null then
    raise exception 'This stay has no rent set yet. Ask your landlord/landlady to set it.';
  end if;
  if v_due <= 0 then
    raise exception 'Nothing is owed for this item.';
  end if;

  if new.kind = 'rent' then
    if new.month < date_trunc('month', l.start_date)::date then
      raise exception 'That month is before the stay began.';
    end if;
    if l.end_date is not null and new.month > date_trunc('month', l.end_date)::date then
      raise exception 'That month is after the stay ends.';
    end if;
    if new.month > (date_trunc('month', v_today) + interval '2 months')::date then
      raise exception 'Rent can be paid at most two months ahead.';
    end if;
    -- Months in order: every earlier month of the stay must be covered.
    v_m := date_trunc('month', l.start_date)::date;
    while v_m < new.month loop
      select c.confirmed + c.pending into v_conf from public.payment_covered(new.lease_id, 'rent', v_m, null, null) c;
      if v_conf + 0.009 < public.payment_due(new.lease_id, 'rent', v_m) then
        raise exception 'Pay % first — months are paid in order.', to_char(v_m, 'FMMonth YYYY');
      end if;
      v_m := (v_m + interval '1 month')::date;
    end loop;
  end if;

  select c.confirmed, c.pending into v_conf, v_pend from public.payment_covered(new.lease_id, new.kind, new.month, new.bill_id, null) c;
  v_left := v_due - v_conf - v_pend;

  if v_student and v_pend > 0 then
    raise exception 'A payment for this is already waiting for your landlord/landlady to confirm.';
  end if;
  if v_left <= 0.009 then
    raise exception 'This is already fully paid or awaiting confirmation.';
  end if;
  if new.amount > v_left + 0.009 then
    raise exception 'That is more than is owed — ₱% is left to pay.', to_char(v_left, 'FM999,999,990.00');
  end if;
  if new.amount + 0.009 < v_left then
    if new.kind = 'bill' then
      raise exception 'A bill is paid in full: ₱%.', to_char(v_left, 'FM999,999,990.00');
    end if;
    if v_student then
      if not l.allow_partial then
        raise exception 'Pay the full ₱% — your landlord/landlady hasn''t turned on partial payments.', to_char(v_left, 'FM999,999,990.00');
      end if;
      v_min := least(v_left, ceil(v_due * l.partial_min_pct / 100.0));
      if new.amount + 0.009 < v_min then
        raise exception 'A partial payment must be at least ₱%.', to_char(v_min, 'FM999,999,990.00');
      end if;
    end if;
  end if;

  -- Evidence for anything that isn't cash.
  if v_student and new.method <> 'cash' then
    if new.txn_reference is null then
      raise exception 'Enter the reference number from your receipt.';
    end if;
    if coalesce(new.proof_url, '') = '' then
      raise exception 'Attach a photo or screenshot of your receipt.';
    end if;
  end if;
  if new.txn_reference is not null then
    if new.method = 'gcash' and new.txn_reference !~ '^[0-9]{13}$' then
      raise exception 'A GCash reference number has 13 digits.';
    elsif new.method <> 'gcash' and new.txn_reference !~ '^[A-Z0-9]{6,30}$' then
      raise exception 'A reference number is 6 to 30 letters or digits.';
    end if;
    v_ref := new.txn_reference;
    if exists (select 1 from public.payments p
                where p.method = new.method and p.txn_reference = v_ref and p.status <> 'rejected'
                  and not (p.lease_id = new.lease_id and p.created_at > now() - interval '24 hours')) then
      raise exception 'That reference number was already used for another payment.';
    end if;
  end if;
  if new.proof_hash is not null and exists (
       select 1 from public.payments p
        where p.proof_hash = new.proof_hash and p.status <> 'rejected'
          and not (p.lease_id = new.lease_id and p.created_at > now() - interval '24 hours')) then
    raise exception 'That receipt image was already used for another payment.';
  end if;

  -- A landlord/landlady recording a cash payment gets a receipt number.
  if new.status = 'paid' then
    new.verified_by := coalesce(new.verified_by, v_me);
    new.paid_at := coalesce(new.paid_at, now());
    if new.method = 'cash' and new.receipt_no is null then
      new.receipt_no := 'R-' || to_char(now() at time zone 'Asia/Manila', 'YYMMDD') || '-'
                        || upper(substr(replace(new.id::text, '-', ''), 1, 6));
    end if;
  end if;
  return new;
end $$;

drop trigger if exists payment_rules on public.payments;
create trigger payment_rules before insert or update on public.payments
  for each row execute function public.tg_payment_rules();

-- 4 Ledger ----------------------------------------------------------------------

create or replace function public.lease_ledger(p_lease uuid)
returns table (kind text, month date, due numeric, confirmed numeric, pending numeric, balance numeric, state text)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  l public.leases;
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_last date;
  v_m date;
  v_k text;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null then return; end if;
  if not (auth.uid() in (l.student_id, l.landlord_id)
          or public.can_view('accounts') or public.can_view('accommodations')) then
    raise exception 'Not your stay.' using errcode = '42501';
  end if;

  foreach v_k in array array['advance', 'deposit'] loop
    kind := v_k; month := null;
    due := public.payment_due(p_lease, v_k, null);
    select c.confirmed, c.pending into confirmed, pending from public.payment_covered(p_lease, v_k, null, null, null) c;
    if due > 0 or confirmed + pending > 0 then
      balance := greatest(due - confirmed - pending, 0);
      state := case when confirmed + 0.009 >= due then 'paid'
                    when confirmed + pending + 0.009 >= due then 'pending'
                    when confirmed + pending > 0 then 'partial' else 'unpaid' end;
      return next;
    end if;
  end loop;

  -- Rent months from the start of the stay to two months ahead (or the end).
  v_last := (date_trunc('month', v_today) + interval '2 months')::date;
  if l.end_date is not null then v_last := least(v_last, date_trunc('month', l.end_date)::date); end if;
  if l.status in ('ended', 'rejected') then
    v_last := least(v_last, date_trunc('month', coalesce(l.end_date, v_today))::date);
  end if;
  v_m := date_trunc('month', l.start_date)::date;
  while v_m <= v_last loop
    kind := 'rent'; month := v_m;
    due := public.payment_due(p_lease, 'rent', v_m);
    select c.confirmed, c.pending into confirmed, pending from public.payment_covered(p_lease, 'rent', v_m, null, null) c;
    balance := greatest(due - confirmed - pending, 0);
    state := case when confirmed + 0.009 >= due then 'paid'
                  when confirmed + pending + 0.009 >= due then 'pending'
                  when v_m < date_trunc('month', v_today)::date then 'overdue'
                  when confirmed + pending > 0 then 'partial' else 'unpaid' end;
    return next;
    v_m := (v_m + interval '1 month')::date;
  end loop;
end $$;

revoke all on function public.payment_due(uuid, text, date, uuid), public.payment_covered(uuid, text, date, uuid, uuid),
  public.lease_ledger(uuid) from public, anon;
grant execute on function public.lease_ledger(uuid) to authenticated;

-- 5 Whole-room rent is shared -----------------------------------------------------

-- Same rule as accepting an application (ApplicationCard): a whole-room rent is
-- split by the room's capacity; per-person rent is charged as is.
create or replace function public.add_student_to_room(p_room uuid, p_student_no text, p_start date)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_me uuid := auth.uid();
  v_student uuid;
  v_rent numeric;
  v_id uuid;
begin
  if v_me is null then raise exception 'Not signed in'; end if;
  if not public.is_verified_landlord(v_me) then
    raise exception 'Only a verified landlord/landlady can add students.';
  end if;
  select round(case when r.rent_basis = 'person' or coalesce(r.capacity, 1) <= 1 then r.monthly_rent
                    else r.monthly_rent / r.capacity end, 2)
    into v_rent
    from public.rooms r join public.accommodations a on a.id = r.accommodation_id
   where r.id = p_room and a.landlord_id = v_me and r.status = 'available';
  if not found then
    raise exception 'That room is not yours, or is no longer available.';
  end if;
  select sp.user_id into v_student from public.student_profiles sp where sp.student_id = trim(p_student_no);
  if v_student is null then raise exception 'No student has that student ID.'; end if;
  if not public.student_may_lease(v_student) then
    raise exception 'OSAS has not verified this student yet, so they cannot be added to a room.';
  end if;
  if exists (select 1 from public.leases l where l.student_id = v_student and l.status in ('active', 'leave_requested', 'pending')) then
    raise exception 'This student already has a stay or an application in progress.';
  end if;
  insert into public.leases (room_id, student_id, landlord_id, start_date, end_date, monthly_rent, status, added_by_landlord)
  values (p_room, v_student, v_me, coalesce(p_start, current_date),
          (coalesce(p_start, current_date) + interval '12 months')::date, v_rent, 'pending', true)
  returning id into v_id;
  return v_id;
end $$;

-- 6 Lease guards ------------------------------------------------------------------

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

-- Partial-payment terms are the landlord/landlady's to set, not the student's.
select pg_temp.patch_fn('public.tg_lease_guard_student_update',
  $p$    or new.advance_paid is distinct from old.advance_paid then$p$,
  $p$    or new.advance_paid is distinct from old.advance_paid
    or new.allow_partial is distinct from old.allow_partial
    or new.partial_min_pct is distinct from old.partial_min_pct then$p$);

-- A whole-room share is stored in centavos, so a month can be paid off exactly
-- (₱2,200 / 3 was ₱733.3333…, which no payment could ever settle).
select pg_temp.patch_fn('public.guard_lease_writes',
  $p$    new.monthly_rent := case when r.rent_basis = 'person' then r.monthly_rent
                             else r.monthly_rent / greatest(coalesce(r.capacity, 1), 1) end;$p$,
  $p$    new.monthly_rent := round(case when r.rent_basis = 'person' then r.monthly_rent
                             else r.monthly_rent / greatest(coalesce(r.capacity, 1), 1) end, 2);$p$);
