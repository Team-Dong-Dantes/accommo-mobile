-- "One month advance" is rent paid ahead: the first month(s) of the stay,
-- settled at move-in. It was a separate charge that never paid for any month,
-- so a student owed the advance AND the first month's rent on moving in, and
-- past_stay_balance() then counted a month the advance was meant to cover.
--
-- Now there is no advance item. The room's advance_months are the first rent
-- months of the stay, all due on the move-in date; the deposit stays a charge
-- of its own. Advance payments already made are moved onto those rent months.

-- An advance-tagged payment from an older build now has nothing to pay toward
-- ("Nothing is owed for this item"), and record_payments() skips p_advance.
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
    when 'advance' then 0
    when 'deposit' then l.monthly_rent * greatest(coalesce(r.deposit_months, 1), 0)
    when 'bill' then (select b.amount from public.utility_bills b where b.id = p_bill)
  end, 2)
  from public.leases l
  left join public.rooms r on r.id = l.room_id
  where l.id = p_lease;
$$;

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
  -- Rent months paid in advance, due on moving in. Unset means one, as the
  -- advance charge used to.
  v_ahead date;
  b record;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or l.status::text in ('pending', 'rejected') then return; end if;

  kind := 'deposit'; month := null; bill_id := null; due_date := l.start_date;
  due := public.payment_due(p_lease, 'deposit', null);
  select c.confirmed, c.waived, c.pending into confirmed, waived, pending from public.payment_covered(p_lease, 'deposit', null, null, null) c;
  if due > 0 or confirmed + waived + pending > 0 then
    balance := greatest(due - confirmed - waived - pending, 0);
    state := case when confirmed + waived + 0.009 >= due then 'paid'
                  when confirmed + waived + pending + 0.009 >= due then 'pending'
                  when confirmed + waived + pending > 0 then 'partial' else 'unpaid' end;
    return next;
  end if;

  select (date_trunc('month', l.start_date) + make_interval(months => greatest(coalesce(r.advance_months, 1), 0)))::date
    into v_ahead from public.rooms r where r.id = l.room_id;

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
    -- No month falls due before move-in; the advance months fall due on it.
    due_date := case when v_m < coalesce(v_ahead, v_m) then l.start_date
                     else greatest(public.rent_due_date(l.rent_due_day, l.start_date, v_m), l.start_date) end;
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

-- Advance payments already made become rent, oldest month still owing first —
-- so a student who paid the advance and month one separately has month two
-- covered. A payment bigger than one month is split across months, each part
-- keeping the original's status, proof and batch. A relabel, not a new event:
-- triggers (notices, receipts, rules) stay out of it.
do $$
declare
  p public.payments;
  l public.leases;
  v_left numeric;
  v_m date;
  v_cap date;
  v_bal numeric;
  v_take numeric;
  v_n int;
begin
  set local session_replication_role = replica;
  for p in select * from public.payments
            where kind = 'advance' and status::text not in ('rejected', 'withdrawn')
            order by created_at loop
    select * into l from public.leases where id = p.lease_id;
    v_left := p.amount;
    v_m := date_trunc('month', l.start_date)::date;
    -- Whatever is left at the last month of the stay stays there, overpaid.
    v_cap := date_trunc('month', greatest(coalesce(l.end_date, l.start_date), l.start_date))::date;
    v_n := 0;
    while v_left > 0.009 loop
      select greatest(public.payment_due(p.lease_id, 'rent', v_m) - c.confirmed - c.waived - c.pending, 0)
        into v_bal from public.payment_covered(p.lease_id, 'rent', v_m, null, p.id) c;
      if v_bal > 0.009 or v_m >= v_cap then
        v_take := case when v_m >= v_cap then v_left else least(v_left, v_bal) end;
        if v_n = 0 then
          update public.payments set kind = 'rent', description = null, month = v_m, amount = v_take where id = p.id;
        else
          insert into public.payments
          select * from jsonb_populate_record(null::public.payments, to_jsonb(p) || jsonb_build_object(
            'id', gen_random_uuid(), 'kind', 'rent', 'description', null, 'month', v_m, 'amount', v_take,
            'receipt_no', case when p.receipt_no is null then null else p.receipt_no || '-' || (v_n + 1) end));
        end if;
        v_n := v_n + 1;
        v_left := v_left - v_take;
      end if;
      v_m := (v_m + interval '1 month')::date;
    end loop;
  end loop;
end $$;
