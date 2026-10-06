-- One payment for several things at once: the pay sheet lists everything owed
-- (rent months as chips, bills and the advance/deposit as tick boxes) and
-- submits them as one transfer. Builds on 20261006070000_flexible_payments.
--
-- record_payments(): p_months rent months (the oldest ones still owed — months
-- stay in order), the ticked bills, advance and/or deposit. Without p_amount
-- everything ticked is paid in full; with a smaller p_amount the money goes to
-- the items in that order (rent, bills, advance, deposit) and the rest stays
-- owed. Every row is written through tg_payment_rules, so its checks (partial
-- minimum on the first item, evidence, references, six months ahead) still
-- apply; the rows share batch_id, so review_payment handles them as one.

create or replace function public.record_payments(
  p_lease uuid, p_months integer, p_bills uuid[], p_advance boolean, p_deposit boolean,
  p_method text, p_amount numeric default null,
  p_reference text default null, p_proof_url text default null, p_proof_hash text default null,
  p_note text default null, p_promise_date date default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_me uuid := auth.uid();
  l public.leases;
  v_student boolean;
  v_batch uuid := gen_random_uuid();
  v_today date := (now() at time zone 'Asia/Manila')::date;
  -- The items, in the order money is applied to them.
  v_kind text[] := '{}';
  v_month date[] := '{}';
  v_bill uuid[] := '{}';
  v_bal numeric[] := '{}';
  v_tag text[] := '{}';
  v_total numeric := 0;
  v_left numeric;
  v_take numeric;
  v_m date;
  v_n int := 0;
  v_b numeric;
  v_what text[] := '{}';
  r record;
  i int;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or v_me is null or v_me not in (l.student_id, l.landlord_id) then
    raise exception 'Not your stay.' using errcode = '42501';
  end if;
  v_student := (v_me = l.student_id);

  -- Rent: the oldest p_months months that still have something owed.
  if coalesce(p_months, 0) > 0 then
    v_m := date_trunc('month', l.start_date)::date;
    while v_n < p_months loop
      if v_m > (date_trunc('month', v_today) + interval '6 months')::date
         or (l.end_date is not null and v_m > date_trunc('month', l.end_date)::date) then
        raise exception 'Only % month(s) of rent can be paid now.', v_n;
      end if;
      select public.payment_due(p_lease, 'rent', v_m) - c.confirmed - c.waived - c.pending
        into v_b from public.payment_covered(p_lease, 'rent', v_m, null, null) c;
      if v_b > 0.009 then
        v_kind := v_kind || 'rent'::text; v_month := v_month || v_m; v_bill := v_bill || null::uuid;
        v_bal := v_bal || round(v_b, 2); v_tag := v_tag || null::text;
        v_what := v_what || to_char(v_m, 'FMMon');
        v_n := v_n + 1;
      end if;
      v_m := (v_m + interval '1 month')::date;
    end loop;
  end if;

  for r in select b.* from public.utility_bills b
            where b.lease_id = p_lease and b.id = any(coalesce(p_bills, '{}'))
            order by b.due_date, b.utility loop
    select public.payment_due(p_lease, 'bill', r.month, r.id) - c.confirmed - c.waived - c.pending
      into v_b from public.payment_covered(p_lease, 'bill', null, r.id, null) c;
    if v_b > 0.009 then
      v_kind := v_kind || 'bill'::text; v_month := v_month || r.month; v_bill := v_bill || r.id;
      v_bal := v_bal || round(v_b, 2);
      v_tag := v_tag || (case r.utility when 'water' then 'Water bill' when 'electric' then 'Electricity bill' else 'Wi-Fi bill' end);
      v_what := v_what || (case r.utility when 'water' then 'water' when 'electric' then 'electricity' else 'Wi-Fi' end);
    end if;
  end loop;

  if p_advance then
    select public.payment_due(p_lease, 'advance', null) - c.confirmed - c.waived - c.pending
      into v_b from public.payment_covered(p_lease, 'advance', null, null, null) c;
    if v_b > 0.009 then
      v_kind := v_kind || 'advance'::text; v_month := v_month || date_trunc('month', v_today)::date; v_bill := v_bill || null::uuid;
      v_bal := v_bal || round(v_b, 2); v_tag := v_tag || 'Advance payment'::text; v_what := v_what || 'advance'::text;
    end if;
  end if;
  if p_deposit then
    select public.payment_due(p_lease, 'deposit', null) - c.confirmed - c.waived - c.pending
      into v_b from public.payment_covered(p_lease, 'deposit', null, null, null) c;
    if v_b > 0.009 then
      v_kind := v_kind || 'deposit'::text; v_month := v_month || date_trunc('month', v_today)::date; v_bill := v_bill || null::uuid;
      v_bal := v_bal || round(v_b, 2); v_tag := v_tag || 'Security deposit'::text; v_what := v_what || 'deposit'::text;
    end if;
  end if;

  if coalesce(array_length(v_kind, 1), 0) = 0 then
    raise exception 'Pick what this payment is for.';
  end if;
  select sum(x) into v_total from unnest(v_bal) x;
  v_left := round(coalesce(p_amount, v_total), 2);
  if v_left <= 0 then
    raise exception 'Enter an amount.';
  end if;
  if v_left > v_total + 0.009 then
    raise exception 'That is more than what you picked (₱%). Tick more months or items.', to_char(v_total, 'FM999,999,990.00');
  end if;

  perform set_config('app.payment_batch', 'on', true);
  for i in 1 .. array_length(v_kind, 1) loop
    exit when v_left <= 0.009;
    v_take := least(v_left, v_bal[i]);
    insert into public.payments (lease_id, bill_id, month, amount, method, status, description, txn_reference,
                                 proof_url, proof_hash, note, promise_date, batch_id)
    values (p_lease, v_bill[i], v_month[i], v_take, p_method::public.payment_method,
            (case when v_student then 'pending_verification' else 'paid' end)::public.payment_status,
            v_tag[i], p_reference, p_proof_url, p_proof_hash, p_note,
            case when v_left + 0.009 < v_total then p_promise_date end, v_batch);
    -- Only the first item is held to the partial minimum.
    perform set_config('app.payment_spill', 'on', true);
    v_left := v_left - v_take;
  end loop;
  perform set_config('app.payment_spill', '', true);
  perform set_config('app.payment_batch', '', true);

  if v_student then
    perform public.notify_peer(l.landlord_id, 'payment', 'Payment submitted',
      'A payment of ' || public.peso(round(coalesce(p_amount, v_total), 2)) || ' (' || array_to_string(v_what, ', ')
        || ') was submitted for verification.' || coalesce(' Note: ' || nullif(btrim(p_note), ''), ''),
      '/manager/tenant/' || l.id, l.student_id);
  end if;
  return v_batch;
end $$;

revoke all on function public.record_payments(uuid, integer, uuid[], boolean, boolean, text, numeric, text, text, text, text, date) from public, anon;
grant execute on function public.record_payments(uuid, integer, uuid[], boolean, boolean, text, numeric, text, text, text, text, date) to authenticated;
