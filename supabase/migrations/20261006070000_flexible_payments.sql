-- Flexible payments, for a student who is short on money and a landlord/landlady
-- who wants to work with them. Builds on 20261006020000_payment_rules.
--
--   * Partial payments are on by default with a 10% floor (the landlord/landlady
--     can still raise it or turn it off per stay); utility bills follow the same
--     rule instead of being all-or-nothing.
--   * record_payment(): any amount goes to the oldest rent month still owed and
--     spills over into the next ones (up to six months ahead) — one transfer can
--     cover two months, or half a month. Rows from one submission share batch_id.
--   * A student may pay more while an earlier part still awaits confirmation,
--     add a note/promise date ("rest on the 20th"), and withdraw a submission
--     that hasn't been confirmed.
--   * review_payment(): the landlord/landlady confirms (optionally only the
--     amount that actually arrived), rejects, or undoes a confirmation within
--     7 days; waive_balance() forgives what is left of an item.
--   * Every confirmed payment gets a receipt number, not only cash.
--   * Rent due day + grace days decide when a month is overdue.
--   * landlord_payout: where students send money, readable only by tenants.
--   * Rent and utility terms are fixed once a stay is accepted, so the ledger
--     can never re-price months that were already paid.
--   * A student who still owes on an ended stay can't start a new one until it
--     is paid or forgiven; OSAS sees the balance (student_past_balance()).
--
-- New enum values are compared as text throughout: they can't be used as enum
-- literals in the same transaction that adds them.

-- 1 Columns ---------------------------------------------------------------------

alter type public.payment_status add value if not exists 'withdrawn';
alter type public.payment_status add value if not exists 'waived';

alter table public.payments
  add column if not exists batch_id uuid,
  add column if not exists note text,
  add column if not exists promise_date date,
  add column if not exists claimed_amount numeric,
  add column if not exists undo_reason text;
alter table public.payments add constraint payments_note_length check (char_length(note) <= 300);
create index if not exists payments_batch_idx on public.payments (batch_id) where batch_id is not null;

alter table public.leases
  add column if not exists rent_due_day smallint constraint leases_rent_due_day_check check (rent_due_day between 1 and 28),
  add column if not exists grace_days smallint not null default 3 constraint leases_grace_days_check check (grace_days between 0 and 15);
alter table public.leases alter column allow_partial set default true;
alter table public.leases alter column partial_min_pct set default 10;
-- Stays still on the old defaults (off, 50%) move to the new ones; a landlord/
-- landlady who chose something else keeps it.
update public.leases set allow_partial = true, partial_min_pct = 10 where not allow_partial and partial_min_pct = 50;

-- 2 Due dates and what covers an item ------------------------------------------

-- The day rent for p_month is due: the stay's due day, or the day it started
-- (capped at the 28th so every month has one).
create or replace function public.rent_due_date(p_due_day smallint, p_start date, p_month date)
returns date
language sql
immutable
as $$
  select p_month + (coalesce(p_due_day, least(extract(day from p_start)::int, 28)) - 1);
$$;

drop function if exists public.payment_covered(uuid, text, date, uuid, uuid);
create function public.payment_covered(p_lease uuid, p_kind text, p_month date, p_bill uuid, p_except uuid,
                                       out confirmed numeric, out waived numeric, out pending numeric)
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(sum(p.amount) filter (where p.status::text = 'paid'), 0),
         coalesce(sum(p.amount) filter (where p.status::text = 'waived'), 0),
         coalesce(sum(p.amount) filter (where p.status::text = 'pending_verification'), 0)
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
  v_waive boolean := new.status::text = 'waived';
  -- Set by record_payment() after the first row: the rest of one transfer
  -- spills into later months and isn't held to the partial minimum.
  v_spill boolean := coalesce(current_setting('app.payment_spill', true), '') = 'on';
  v_due numeric;
  v_conf numeric;
  v_waived numeric;
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
  new.note := nullif(btrim(new.note), '');

  if v_me is null or public.is_admin(v_me) then
    return new;
  end if;

  select * into l from public.leases where id = new.lease_id;
  v_student := (v_me = l.student_id);

  if tg_op = 'UPDATE' then
    if new.month is distinct from old.month or new.lease_id is distinct from old.lease_id
       or new.kind is distinct from old.kind or new.bill_id is distinct from old.bill_id then
      raise exception 'A payment''s month and item can''t be changed. Reject it and record a new one.';
    end if;
    -- The one amount change: confirming only what actually arrived.
    if new.amount is distinct from old.amount then
      if v_student or old.status::text <> 'pending_verification' or new.status::text <> 'paid'
         or new.amount > old.amount or new.amount <= 0 then
        raise exception 'A payment''s amount can only be lowered to what actually arrived, while confirming it.';
      end if;
      new.claimed_amount := coalesce(old.claimed_amount, old.amount);
    end if;
    if new.status is distinct from old.status then
      if old.status::text in ('rejected', 'withdrawn', 'waived') then
        raise exception 'This payment is closed. Record a new one instead.';
      end if;
      if v_student then
        if not (old.status::text = 'pending_verification' and new.status::text = 'withdrawn') then
          raise exception 'You can only withdraw a payment that hasn''t been confirmed yet.';
        end if;
        return new;
      end if;
      if new.status::text in ('withdrawn', 'waived') then
        raise exception 'Only the student can withdraw a payment; reject it instead.';
      end if;
      if old.status::text = 'paid' then
        if new.status::text <> 'pending_verification' then
          raise exception 'A confirmed payment can only be undone, which puts it back to awaiting confirmation.';
        end if;
        if old.paid_at < now() - interval '7 days' then
          raise exception 'A confirmation can only be undone within 7 days. Ask OSAS to correct older ones.';
        end if;
        if coalesce(btrim(new.undo_reason), '') = '' then
          raise exception 'Give a reason for undoing — the student is told it.';
        end if;
        new.verified_by := null;
        new.paid_at := null;
        return new;
      end if;
      if new.status::text = 'rejected' then
        if coalesce(btrim(new.rejection_reason), '') = '' then
          raise exception 'Give a reason for rejecting — the student is told it.';
        end if;
        new.verified_by := v_me;
      elsif new.status::text = 'paid' then
        select c.confirmed + c.waived into v_conf from public.payment_covered(new.lease_id, new.kind, new.month, new.bill_id, new.id) c;
        v_due := public.payment_due(new.lease_id, new.kind, new.month, new.bill_id);
        if v_due is not null and v_conf + new.amount > v_due + 0.009 then
          raise exception 'Confirming this would collect more than is owed (₱% of ₱% is already settled).', to_char(v_conf, 'FM999,999,990.00'), to_char(v_due, 'FM999,999,990.00');
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
  if l.status::text in ('pending', 'rejected') then
    raise exception 'Payments are made on an accepted stay.';
  end if;
  -- After a stay ends, a student can still settle rent and bills they owe.
  if v_student and l.status::text in ('ended', 'terminated') and new.kind in ('advance', 'deposit') then
    raise exception 'The advance and deposit are settled with your landlord/landlady when a stay ends.';
  end if;
  if v_waive then
    if v_student then
      raise exception 'Only your landlord/landlady can forgive a balance.';
    end if;
    if new.note is null then
      raise exception 'Say why the balance is being forgiven — the student sees it.';
    end if;
  end if;
  if new.paid_at is not null and new.paid_at > now() + interval '5 minutes' then
    raise exception 'The payment date can''t be in the future.';
  end if;
  if new.promise_date is not null and new.promise_date < v_today then
    raise exception 'The date you''ll pay the rest can''t be in the past.';
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
    if new.month > (date_trunc('month', v_today) + interval '6 months')::date then
      raise exception 'Rent can be paid at most six months ahead.';
    end if;
    -- Months in order: every earlier month must be covered. Forgiving a month
    -- doesn't need the earlier ones settled.
    if not v_waive then
      v_m := date_trunc('month', l.start_date)::date;
      while v_m < new.month loop
        select c.confirmed + c.waived + c.pending into v_conf from public.payment_covered(new.lease_id, 'rent', v_m, null, null) c;
        if v_conf + 0.009 < public.payment_due(new.lease_id, 'rent', v_m) then
          raise exception 'Pay % first — months are paid in order.', to_char(v_m, 'FMMonth YYYY');
        end if;
        v_m := (v_m + interval '1 month')::date;
      end loop;
    end if;
  end if;

  select c.confirmed, c.waived, c.pending into v_conf, v_waived, v_pend
    from public.payment_covered(new.lease_id, new.kind, new.month, new.bill_id, null) c;
  v_left := v_due - v_conf - v_waived - v_pend;

  if v_left <= 0.009 then
    raise exception 'This is already fully paid or awaiting confirmation.';
  end if;
  if new.amount > v_left + 0.009 then
    raise exception 'That is more than is owed — ₱% is left to pay.', to_char(v_left, 'FM999,999,990.00');
  end if;
  if v_student and not v_spill and new.amount + 0.009 < v_left then
    if not l.allow_partial then
      raise exception 'Pay the full ₱% — your landlord/landlady hasn''t turned on partial payments.', to_char(v_left, 'FM999,999,990.00');
    end if;
    v_min := least(v_left, ceil(v_due * l.partial_min_pct / 100.0));
    if new.amount + 0.009 < v_min then
      raise exception 'A partial payment must be at least ₱%.', to_char(v_min, 'FM999,999,990.00');
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
                where p.method = new.method and p.txn_reference = v_ref and p.status::text not in ('rejected', 'withdrawn')
                  and not (p.lease_id = new.lease_id and p.created_at > now() - interval '24 hours')) then
      raise exception 'That reference number was already used for another payment.';
    end if;
  end if;
  if new.proof_hash is not null and exists (
       select 1 from public.payments p
        where p.proof_hash = new.proof_hash and p.status::text not in ('rejected', 'withdrawn')
          and not (p.lease_id = new.lease_id and p.created_at > now() - interval '24 hours')) then
    raise exception 'That receipt image was already used for another payment.';
  end if;

  if new.status::text = 'paid' then
    new.verified_by := coalesce(new.verified_by, v_me);
    new.paid_at := coalesce(new.paid_at, now());
  end if;
  if v_waive then
    new.verified_by := v_me;
  end if;
  return new;
end $$;

-- Every confirmed payment has a receipt number; it goes away if the
-- confirmation is undone and comes back (the same one) if it is redone.
create or replace function public.tg_payment_receipt()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if new.status::text = 'paid' then
    new.receipt_no := coalesce(new.receipt_no, 'R-' || to_char(coalesce(new.paid_at, now()) at time zone 'Asia/Manila', 'YYMMDD')
                                                 || '-' || upper(substr(replace(new.id::text, '-', ''), 1, 6)));
  else
    new.receipt_no := null;
  end if;
  return new;
end $$;

drop trigger if exists payment_receipt on public.payments;
create trigger payment_receipt before insert or update on public.payments
  for each row execute function public.tg_payment_receipt();

update public.payments
   set receipt_no = 'R-' || to_char(coalesce(paid_at, created_at) at time zone 'Asia/Manila', 'YYMMDD') || '-' || upper(substr(replace(id::text, '-', ''), 1, 6))
 where status = 'paid' and receipt_no is null;

-- Students may withdraw their own pending submission — the one status change
-- they make.
create or replace function public.tg_payment_guard()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_student uuid;
  v_landlord uuid;
begin
  select l.student_id, l.landlord_id
    into v_student, v_landlord
    from public.leases l
   where l.id = new.lease_id;

  if auth.uid() is distinct from v_student or auth.uid() = v_landlord then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status::text <> 'pending_verification'
    or new.paid_at          is not null
    or new.verified_by      is not null
    or new.rejection_reason is not null then
      raise exception 'a student may only submit a payment for verification';
    end if;
  else
    if (new.status is distinct from old.status
        and not (old.status::text = 'pending_verification' and new.status::text = 'withdrawn'))
    or new.amount           is distinct from old.amount
    or new.month            is distinct from old.month
    or new.lease_id         is distinct from old.lease_id
    or new.paid_at          is distinct from old.paid_at
    or new.verified_by      is distinct from old.verified_by
    or new.rejection_reason is distinct from old.rejection_reason
    or new.claimed_amount   is distinct from old.claimed_amount
    or new.undo_reason      is distinct from old.undo_reason then
      raise exception 'a student may not verify or alter a submitted payment';
    end if;
  end if;

  return new;
end;
$$;

-- A bill can be paid in parts now; tg_payment_rules keeps the total within it.
create or replace function public.tg_payment_bill_check()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
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
  if new.month <> b.month or new.amount > b.amount then
    raise exception 'a bill payment must be for the bill''s month and no more than the bill';
  end if;
  return new;
end;
$$;

-- record_payment / review_payment send one notification per submission
-- themselves, instead of one per month it covers.
create or replace function public.tg_payment_notify()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  l public.leases;
begin
  if coalesce(current_setting('app.payment_batch', true), '') = 'on' then return null; end if;
  select * into l from public.leases where id = new.lease_id;
  if not found then return null; end if;

  if tg_op = 'INSERT' then
    if new.status = 'pending_verification' then
      perform public.notify_peer(l.landlord_id, 'payment', 'Payment submitted',
        'A payment of ' || public.peso(new.amount) || ' was submitted for verification.',
        '/manager/tenant/' || l.id, l.student_id);
    end if;
  elsif new.status is distinct from old.status and old.status = 'pending_verification' then
    if new.status = 'paid' then
      perform public.notify_peer(l.student_id, 'payment', 'Payment verified',
        'Your payment for ' || public.room_display(l.room_id) || ' was marked as paid.',
        '/student/payments', l.landlord_id);
    elsif new.status = 'rejected' then
      perform public.notify_peer(l.student_id, 'payment', 'Payment rejected',
        'Your payment for ' || public.room_display(l.room_id) || ' was rejected.'
          || coalesce(' Reason: ' || nullif(trim(new.rejection_reason), ''), ''),
        '/student/payments', l.landlord_id);
    end if;
  end if;
  return null;
end $$;

-- 4 Ledger ----------------------------------------------------------------------

-- Everything owed on a stay, without the caller check (lease_ledger adds it).
drop function if exists public.lease_ledger(uuid);
create or replace function public.ledger_rows(p_lease uuid)
returns table (kind text, month date, bill_id uuid, due_date date, due numeric, confirmed numeric,
               waived numeric, pending numeric, balance numeric, state text)
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
  b record;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or l.status::text in ('pending', 'rejected') then return; end if;

  foreach v_k in array array['advance', 'deposit'] loop
    kind := v_k; month := null; bill_id := null; due_date := l.start_date;
    due := public.payment_due(p_lease, v_k, null);
    select c.confirmed, c.waived, c.pending into confirmed, waived, pending from public.payment_covered(p_lease, v_k, null, null, null) c;
    if due > 0 or confirmed + waived + pending > 0 then
      balance := greatest(due - confirmed - waived - pending, 0);
      state := case when confirmed + waived + 0.009 >= due then 'paid'
                    when confirmed + waived + pending + 0.009 >= due then 'pending'
                    when confirmed + waived + pending > 0 then 'partial' else 'unpaid' end;
      return next;
    end if;
  end loop;

  -- Rent months from the start of the stay to six months ahead, or to the
  -- month a closed stay ended.
  v_last := (date_trunc('month', v_today) + interval '6 months')::date;
  if l.end_date is not null then v_last := least(v_last, date_trunc('month', l.end_date)::date); end if;
  if l.status::text in ('ended', 'terminated') then
    v_last := least(v_last, date_trunc('month', least(coalesce(l.end_date, v_today), v_today))::date);
  end if;
  v_m := date_trunc('month', l.start_date)::date;
  while v_m <= v_last loop
    kind := 'rent'; month := v_m; bill_id := null;
    due_date := public.rent_due_date(l.rent_due_day, l.start_date, v_m);
    due := public.payment_due(p_lease, 'rent', v_m);
    select c.confirmed, c.waived, c.pending into confirmed, waived, pending from public.payment_covered(p_lease, 'rent', v_m, null, null) c;
    balance := greatest(due - confirmed - waived - pending, 0);
    state := case when confirmed + waived + 0.009 >= due then 'paid'
                  when confirmed + waived + pending + 0.009 >= due then 'pending'
                  when v_today > due_date + l.grace_days then 'overdue'
                  when confirmed + waived + pending > 0 then 'partial' else 'unpaid' end;
    return next;
    v_m := (v_m + interval '1 month')::date;
  end loop;

  for b in select * from public.utility_bills u where u.lease_id = p_lease order by u.due_date, u.utility loop
    kind := 'bill'; month := b.month; bill_id := b.id; due_date := b.due_date;
    due := round(b.amount, 2);
    select c.confirmed, c.waived, c.pending into confirmed, waived, pending from public.payment_covered(p_lease, 'bill', null, b.id, null) c;
    balance := greatest(due - confirmed - waived - pending, 0);
    state := case when confirmed + waived + 0.009 >= due then 'paid'
                  when confirmed + waived + pending + 0.009 >= due then 'pending'
                  when v_today > b.due_date then 'overdue'
                  when confirmed + waived + pending > 0 then 'partial' else 'unpaid' end;
    return next;
  end loop;
end $$;

create function public.lease_ledger(p_lease uuid)
returns table (kind text, month date, bill_id uuid, due_date date, due numeric, confirmed numeric,
               waived numeric, pending numeric, balance numeric, state text)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  l public.leases;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null then return; end if;
  if not (auth.uid() in (l.student_id, l.landlord_id)
          or public.can_view('accounts') or public.can_view('accommodations')) then
    raise exception 'Not your stay.' using errcode = '42501';
  end if;
  return query select * from public.ledger_rows(p_lease);
end $$;

-- 5 Paying, reviewing, forgiving -------------------------------------------------

create or replace function public.record_payment(
  p_lease uuid, p_kind text, p_amount numeric, p_method text,
  p_bill uuid default null, p_reference text default null, p_proof_url text default null,
  p_proof_hash text default null, p_note text default null, p_promise_date date default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_me uuid := auth.uid();
  l public.leases;
  b public.utility_bills;
  v_student boolean;
  v_batch uuid := gen_random_uuid();
  v_left numeric := round(coalesce(p_amount, 0), 2);
  v_take numeric;
  v_bal numeric;
  v_m date;
  v_months text[] := '{}';
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_tag text;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or v_me is null or v_me not in (l.student_id, l.landlord_id) then
    raise exception 'Not your stay.' using errcode = '42501';
  end if;
  v_student := (v_me = l.student_id);
  if v_left <= 0 then
    raise exception 'Enter an amount.';
  end if;
  if p_kind not in ('rent', 'advance', 'deposit', 'bill') then
    raise exception 'Pick what this payment is for.';
  end if;
  if p_kind = 'bill' then
    select * into b from public.utility_bills where id = p_bill and lease_id = p_lease;
    if b.id is null then raise exception 'That bill isn''t on this stay.'; end if;
    v_tag := case b.utility when 'water' then 'Water bill' when 'electric' then 'Electricity bill' else 'Wi-Fi bill' end;
  else
    v_tag := case p_kind when 'advance' then 'Advance payment' when 'deposit' then 'Security deposit' end;
  end if;

  perform set_config('app.payment_batch', 'on', true);
  if p_kind <> 'rent' then
    insert into public.payments (lease_id, bill_id, month, amount, method, status, description, txn_reference,
                                 proof_url, proof_hash, note, promise_date, batch_id)
    values (p_lease, b.id, coalesce(b.month, date_trunc('month', v_today)::date), v_left, p_method::public.payment_method,
            (case when v_student then 'pending_verification' else 'paid' end)::public.payment_status,
            v_tag, p_reference, p_proof_url, p_proof_hash, p_note, p_promise_date, v_batch);
  else
    -- Oldest month first; whatever is left spills into the next months.
    v_m := date_trunc('month', l.start_date)::date;
    while v_left > 0.009 loop
      if v_m > (date_trunc('month', v_today) + interval '6 months')::date
         or (l.end_date is not null and v_m > date_trunc('month', l.end_date)::date) then
        raise exception 'That is more than is owed — ₱% would be left over.', to_char(v_left, 'FM999,999,990.00');
      end if;
      select greatest(public.payment_due(p_lease, 'rent', v_m) - c.confirmed - c.waived - c.pending, 0)
        into v_bal from public.payment_covered(p_lease, 'rent', v_m, null, null) c;
      if v_bal > 0.009 then
        v_take := least(v_left, v_bal);
        insert into public.payments (lease_id, month, amount, method, status, txn_reference, proof_url, proof_hash,
                                     note, promise_date, batch_id)
        values (p_lease, v_m, v_take, p_method::public.payment_method,
                (case when v_student then 'pending_verification' else 'paid' end)::public.payment_status,
                p_reference, p_proof_url, p_proof_hash, p_note, p_promise_date, v_batch);
        perform set_config('app.payment_spill', 'on', true);
        v_months := v_months || to_char(v_m, 'FMMon YYYY');
        v_left := v_left - v_take;
      end if;
      v_m := (v_m + interval '1 month')::date;
    end loop;
  end if;
  perform set_config('app.payment_spill', '', true);
  perform set_config('app.payment_batch', '', true);

  if v_student then
    perform public.notify_peer(l.landlord_id, 'payment', 'Payment submitted',
      'A payment of ' || public.peso(round(p_amount, 2)) || ' for '
        || coalesce(v_tag, array_to_string(v_months, ', ')) || ' was submitted for verification.'
        || coalesce(' Note: ' || nullif(btrim(p_note), ''), ''),
      '/manager/tenant/' || l.id, l.student_id);
  end if;
  return v_batch;
end $$;

-- Acts on the whole submission a payment belongs to (one transfer that covered
-- several months is confirmed or rejected as one). The row triggers decide
-- what each side may do; this only checks the caller is on the stay.
create or replace function public.review_payment(p_payment uuid, p_action text, p_received numeric default null,
                                                 p_reason text default null)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_me uuid := auth.uid();
  p public.payments;
  l public.leases;
  r record;
  v_ids uuid[];
  v_total numeric;
  v_left numeric;
  v_n int;
begin
  select * into p from public.payments where id = p_payment;
  select * into l from public.leases where id = p.lease_id;
  if p.id is null or v_me is null or v_me not in (l.student_id, l.landlord_id) then
    raise exception 'Not your stay.' using errcode = '42501';
  end if;
  if (p_action = 'withdraw') <> (v_me = l.student_id) then
    raise exception 'That isn''t yours to do.' using errcode = '42501';
  end if;
  select array_agg(id order by kind, month), sum(amount) into v_ids, v_total
    from public.payments
   where (id = p_payment or (p.batch_id is not null and batch_id = p.batch_id))
     and status::text = case when p_action = 'undo' then 'paid' else 'pending_verification' end;
  if v_ids is null then
    raise exception 'This payment has already been handled.';
  end if;

  perform set_config('app.payment_batch', 'on', true);
  if p_action = 'confirm' then
    if p_received is not null and round(p_received, 2) > v_total + 0.009 then
      raise exception 'That is more than was submitted (₱%).', to_char(v_total, 'FM999,999,990.00');
    end if;
    if p_received is not null and p_received <= 0 then
      raise exception 'If nothing arrived, reject the payment instead.';
    end if;
    v_left := round(coalesce(p_received, v_total), 2);
    for r in select id, amount from public.payments where id = any(v_ids) order by kind, month loop
      if v_left <= 0.009 then
        update public.payments set status = 'rejected',
               rejection_reason = 'Not received — ' || public.peso(round(p_received, 2)) || ' of ' || public.peso(v_total) || ' arrived.'
         where id = r.id;
      else
        update public.payments set status = 'paid', amount = least(r.amount, v_left) where id = r.id;
      end if;
      v_left := v_left - r.amount;
    end loop;
    perform public.notify_peer(l.student_id, 'payment', 'Payment confirmed',
      case when p_received is null or round(p_received, 2) >= v_total
           then 'Your payment of ' || public.peso(v_total) || ' for ' || public.room_display(l.room_id) || ' was confirmed.'
           else 'Your landlord/landlady confirmed ' || public.peso(round(p_received, 2)) || ' of the ' || public.peso(v_total)
                || ' you submitted. The rest is still owed.' end,
      '/student/payments', l.landlord_id);
  elsif p_action = 'reject' then
    update public.payments set status = 'rejected', rejection_reason = p_reason where id = any(v_ids);
    perform public.notify_peer(l.student_id, 'payment', 'Payment rejected',
      'Your payment of ' || public.peso(v_total) || ' was rejected.' || coalesce(' Reason: ' || nullif(btrim(p_reason), ''), ''),
      '/student/payments', l.landlord_id);
  elsif p_action = 'undo' then
    update public.payments set status = 'pending_verification', undo_reason = p_reason where id = any(v_ids);
    perform public.notify_peer(l.student_id, 'payment', 'Confirmation undone',
      'Your landlord/landlady undid the confirmation of ' || public.peso(v_total) || '.'
        || coalesce(' Reason: ' || nullif(btrim(p_reason), ''), ''),
      '/student/payments', l.landlord_id);
  elsif p_action = 'withdraw' then
    update public.payments set status = 'withdrawn' where id = any(v_ids);
  else
    raise exception 'Unknown action.';
  end if;
  perform set_config('app.payment_batch', '', true);
end $$;

-- Forgive what is left of one item (a rent month, a bill, the advance or the
-- deposit). Recorded as a 'waived' row: it settles the item but is never
-- counted as money received.
create or replace function public.waive_balance(p_lease uuid, p_kind text, p_month date, p_bill uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  l public.leases;
  b public.utility_bills;
  v_left numeric;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or auth.uid() is distinct from l.landlord_id then
    raise exception 'Only the landlord/landlady of this stay can forgive a balance.' using errcode = '42501';
  end if;
  if p_kind = 'bill' then
    select * into b from public.utility_bills where id = p_bill and lease_id = p_lease;
    if b.id is null then raise exception 'That bill isn''t on this stay.'; end if;
  end if;
  select public.payment_due(p_lease, p_kind, date_trunc('month', p_month)::date, p_bill) - c.confirmed - c.waived - c.pending
    into v_left
    from public.payment_covered(p_lease, p_kind, date_trunc('month', p_month)::date, p_bill, null) c;
  if coalesce(v_left, 0) <= 0.009 then
    raise exception 'Nothing is left to forgive (anything awaiting confirmation counts as paid).';
  end if;
  insert into public.payments (lease_id, bill_id, month, amount, method, status, description, note)
  values (p_lease, b.id, coalesce(b.month, date_trunc('month', coalesce(p_month, current_date))::date), round(v_left, 2), 'others',
          'waived'::text::public.payment_status,
          case p_kind when 'advance' then 'Advance payment' when 'deposit' then 'Security deposit'
                      when 'bill' then case b.utility when 'water' then 'Water bill' when 'electric' then 'Electricity bill' else 'Wi-Fi bill' end end,
          p_reason);
  perform public.notify_peer(l.student_id, 'payment', 'Balance forgiven',
    'Your landlord/landlady forgave ' || public.peso(round(v_left, 2)) || '. ' || coalesce(nullif(btrim(p_reason), ''), ''),
    '/student/payments', l.landlord_id);
end $$;

-- 6 Unpaid past stays ----------------------------------------------------------

-- What a student still owes on stays that have ended (rent and bills; payments
-- awaiting confirmation count as paid). guard_lease_writes runs as the caller,
-- so this is callable — but only says anything to the student themself, OSAS,
-- or a verified landlord/landlady deciding whether to add them.
create or replace function public.past_stay_balance(p_student uuid)
returns numeric
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(sum(r.balance), 0)
    from public.leases l cross join lateral public.ledger_rows(l.id) r
   where l.student_id = p_student and l.status::text in ('ended', 'terminated') and r.kind in ('rent', 'bill')
     and (auth.uid() is null or auth.uid() = p_student or public.is_admin(auth.uid()) or public.is_verified_landlord(auth.uid()));
$$;

-- Per ended stay, for OSAS and for the student.
create or replace function public.student_past_balance(p_student uuid)
returns table (lease_id uuid, accommodation text, room text, ended_on date, balance numeric)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not (auth.uid() = p_student or public.can_view('accounts') or public.is_admin(auth.uid())) then
    raise exception 'Not allowed.' using errcode = '42501';
  end if;
  return query
    select l.id, a.name::text, public.room_display(l.room_id)::text, l.end_date, sum(r.balance)
      from public.leases l
      join public.rooms rm on rm.id = l.room_id
      join public.accommodations a on a.id = rm.accommodation_id
      cross join lateral public.ledger_rows(l.id) r
     where l.student_id = p_student and l.status::text in ('ended', 'terminated') and r.kind in ('rent', 'bill')
     group by l.id, a.name, l.room_id, l.end_date
    having sum(r.balance) > 0.009
     order by l.end_date desc nulls last;
end $$;

-- Lease writes: owing on a past stay blocks a new one, and rent and utility
-- terms are fixed once a stay is accepted.
create or replace function public.guard_lease_writes()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  r public.rooms;
  v_owed numeric;
begin
  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;

  if tg_op = 'INSERT' then
    select * into r from public.rooms where id = new.room_id;
    if r.id is null then
      raise exception 'That room is not open for applications.' using errcode = '42501';
    end if;
    v_owed := public.past_stay_balance(new.student_id);
    if v_owed > 0.009 then
      raise exception 'You still owe ₱% on a past stay. Settle it with that landlord/landlady before applying.', to_char(v_owed, 'FM999,999,990.00');
    end if;
    new.monthly_rent := round(case when r.rent_basis = 'person' then r.monthly_rent
                             else r.monthly_rent / greatest(coalesce(r.capacity, 1), 1) end, 2);
    new.added_by_landlord := false;
    new.advance_paid := null;
    new.deposit_paid := null;
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
  return new;
end $$;

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

select pg_temp.patch_fn('public.add_student_to_room',
  $p$  if exists (select 1 from public.leases l where l.student_id = v_student and l.status in ('active', 'leave_requested', 'pending')) then$p$,
  $p$  if public.past_stay_balance(v_student) > 0.009 then
    raise exception 'This student still owes ₱% on a past stay, so they can''t be added until it is settled.',
      to_char(public.past_stay_balance(v_student), 'FM999,999,990.00');
  end if;
  if exists (select 1 from public.leases l where l.student_id = v_student and l.status in ('active', 'leave_requested', 'pending')) then$p$);

-- Due day and grace are the landlord/landlady's to set.
select pg_temp.patch_fn('public.tg_lease_guard_student_update',
  $p$    or new.partial_min_pct is distinct from old.partial_min_pct then$p$,
  $p$    or new.partial_min_pct is distinct from old.partial_min_pct
    or new.rent_due_day is distinct from old.rent_due_day
    or new.grace_days is distinct from old.grace_days then$p$);

-- 7 Where to send the money ------------------------------------------------------

create table if not exists public.landlord_payout (
  landlord_id uuid primary key references public.users(id) on delete cascade,
  gcash_number text constraint landlord_payout_gcash_check check (gcash_number ~ '^09[0-9]{9}$'),
  gcash_name text constraint landlord_payout_gcash_name_check check (char_length(gcash_name) <= 100),
  maya_number text constraint landlord_payout_maya_check check (maya_number ~ '^09[0-9]{9}$'),
  maya_name text constraint landlord_payout_maya_name_check check (char_length(maya_name) <= 100),
  bank_name text constraint landlord_payout_bank_check check (char_length(bank_name) <= 100),
  bank_account_number text constraint landlord_payout_bank_no_check check (bank_account_number ~ '^[0-9 -]{6,30}$'),
  bank_account_name text constraint landlord_payout_bank_name_check check (char_length(bank_account_name) <= 100),
  note text constraint landlord_payout_note_check check (char_length(note) <= 300),
  updated_at timestamptz not null default now()
);
alter table public.landlord_payout enable row level security;

drop policy if exists landlord_payout_own on public.landlord_payout;
create policy landlord_payout_own on public.landlord_payout for all to authenticated
  using (landlord_id = (select auth.uid())) with check (landlord_id = (select auth.uid()));
drop policy if exists landlord_payout_tenants on public.landlord_payout;
create policy landlord_payout_tenants on public.landlord_payout for select to authenticated
  using (exists (select 1 from public.leases l
                  where l.landlord_id = landlord_payout.landlord_id and l.student_id = (select auth.uid())
                    and l.status::text in ('active', 'leave_requested', 'ended', 'terminated')));
drop policy if exists landlord_payout_admin on public.landlord_payout;
create policy landlord_payout_admin on public.landlord_payout for select to authenticated
  using ((select public.is_admin((select auth.uid()))));

revoke all on public.landlord_payout from anon;
grant select, insert, update, delete on public.landlord_payout to authenticated;

-- 8 Grants ------------------------------------------------------------------------

revoke all on function public.payment_due(uuid, text, date, uuid), public.payment_covered(uuid, text, date, uuid, uuid),
  public.ledger_rows(uuid) from public, anon, authenticated;
revoke all on function public.past_stay_balance(uuid) from public, anon;
grant execute on function public.past_stay_balance(uuid) to authenticated;
revoke all on function public.lease_ledger(uuid), public.record_payment(uuid, text, numeric, text, uuid, text, text, text, text, date),
  public.review_payment(uuid, text, numeric, text), public.waive_balance(uuid, text, date, uuid, text),
  public.student_past_balance(uuid) from public, anon;
grant execute on function public.lease_ledger(uuid), public.record_payment(uuid, text, numeric, text, uuid, text, text, text, text, date),
  public.review_payment(uuid, text, numeric, text), public.waive_balance(uuid, text, date, uuid, text),
  public.student_past_balance(uuid) to authenticated;
