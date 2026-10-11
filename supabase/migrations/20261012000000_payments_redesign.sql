-- Payments redesign (both apps read this; the screens are accommo-mobile's).
--
-- 1. No undo. A confirmation is final: the app asks the landlord/landlady to
--    type CONFIRM first instead of offering a 7-day undo afterwards.
-- 2. A student taking a payment back tells the landlord/landlady.
-- 3. landlord_ledger(): what every tenant owes, in one call, for the Payments tab.
-- 4. The deposit pays for something at the end of a stay (its last month, or
--    what is still owed at move-out), or is marked returned. Payments made from
--    it carry method 'deposit'; only the landlord/landlady records them, and
--    never more than the deposit still held.
-- 5. A bill with payments against it can be corrected (never below what is
--    already paid toward it); posting or correcting a bill tells the student.
-- 6. remind_payments(): the daily reminders for rent, promises, payments left
--    waiting, unposted bills, move-ins and deposits still held.

alter type public.payment_method add value if not exists 'deposit';

alter table public.leases add column if not exists deposit_returned_at timestamptz;

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

-- ---- 1, 2. review_payment ------------------------------------------------------

select pg_temp.patch_fn('public.review_payment',
  $p$  elsif p_action = 'undo' then
    update public.payments set status = 'pending_verification', undo_reason = p_reason where id = any(v_ids);
    perform public.notify_peer(l.student_id, 'payment', 'Confirmation undone',
      'Your ' || public.landlord_title(l.landlord_id) || ' undid the confirmation of ' || public.peso(v_total) || '.'
        || coalesce(' Reason: ' || nullif(btrim(p_reason), ''), ''),
      '/student/payments', l.landlord_id);
  elsif p_action = 'withdraw' then
    update public.payments set status = 'withdrawn' where id = any(v_ids);$p$,
  $p$  elsif p_action = 'withdraw' then
    update public.payments set status = 'withdrawn' where id = any(v_ids);
    perform public.notify_peer(l.landlord_id, 'payment', 'Payment taken back',
      coalesce((select nullif(btrim(full_name), '') from public.users where id = l.student_id), 'Your tenant')
        || ' took back a ' || public.peso(v_total) || ' payment before you reviewed it.',
      '/manager/tenant/' || l.id, l.student_id);$p$);

-- 'undo' looked up confirmed rows; with its branch gone it would fall through
-- to "Unknown action". Say why instead.
select pg_temp.patch_fn('public.review_payment',
  $p$  if (p_action = 'withdraw') <> (v_me = l.student_id) then$p$,
  $p$  if p_action = 'undo' then
    raise exception 'A confirmed payment can''t be undone.';
  end if;
  if (p_action = 'withdraw') <> (v_me = l.student_id) then$p$);

-- The direct-update route to the same undo.
select pg_temp.patch_fn('public.tg_payment_rules',
  $p$      if old.status::text = 'paid' then
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
      end if;$p$,
  $p$      if old.status::text = 'paid' then
        raise exception 'A confirmed payment can''t be undone.';
      end if;$p$);

-- ---- 4. Deposit ---------------------------------------------------------------

-- The deposit still held on a stay: what was paid toward it, less what has
-- already paid for something, and nothing once it is marked returned.
create or replace function public.deposit_held(p_lease uuid)
returns numeric
language sql
stable
security definer
set search_path to 'public'
as $$
  select case when l.deposit_returned_at is not null then 0 else greatest(
    coalesce((select sum(p.amount) from public.payments p
               where p.lease_id = l.id and p.kind = 'deposit' and p.status::text = 'paid'), 0)
    - coalesce((select sum(p.amount) from public.payments p
                 where p.lease_id = l.id and p.method::text = 'deposit' and p.status::text = 'paid'), 0), 0) end
  from public.leases l where l.id = p_lease;
$$;
revoke all on function public.deposit_held(uuid) from public, anon, authenticated;

select pg_temp.patch_fn('public.tg_payment_rules',
  $p$  if new.paid_at is not null and new.paid_at > now() + interval '5 minutes' then
    raise exception 'The payment date can''t be in the future.';
  end if;
  if new.promise_date is not null and new.promise_date < v_today then$p$,
  $p$  if new.method::text = 'deposit' then
    if v_student then
      raise exception 'Only your % can use the deposit.', public.landlord_title(l.landlord_id);
    end if;
    if new.kind = 'deposit' then
      raise exception 'The deposit can''t pay for itself.';
    end if;
    if new.amount > public.deposit_held(new.lease_id) + 0.009 then
      raise exception 'That is more than the deposit still held (₱%).', to_char(public.deposit_held(new.lease_id), 'FM999,999,990.00');
    end if;
  end if;
  if new.paid_at is not null and new.paid_at > now() + interval '5 minutes' then
    raise exception 'The payment date can''t be in the future.';
  end if;
  if new.promise_date is not null and new.promise_date < v_today then$p$);

-- Use the deposit: 'last_month' pays the final month's rent; 'owed' pays rent
-- already due and every unpaid bill, oldest first. Never more than is held.
create or replace function public.use_deposit(p_lease uuid, p_mode text)
returns numeric
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  l public.leases;
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_held numeric;
  v_months int;
  v_bills uuid[];
  v_total numeric;
  v_use numeric;
  v_last date;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or auth.uid() is distinct from l.landlord_id then
    raise exception 'Only the landlord/landlady of this stay can use its deposit.' using errcode = '42501';
  end if;
  v_held := public.deposit_held(p_lease);
  if v_held <= 0.009 then
    raise exception 'No deposit is held on this stay.';
  end if;

  if p_mode = 'last_month' then
    if l.end_date is null then
      raise exception 'This stay has no end date, so it has no last month yet.';
    end if;
    v_last := date_trunc('month', l.end_date)::date;
    if exists (select 1 from public.ledger_rows(p_lease) r
                where r.kind = 'rent' and r.month < v_last and r.balance > 0.009) then
      raise exception 'Settle the earlier months first — rent is paid in order.';
    end if;
    select count(*), sum(r.balance) into v_months, v_total from public.ledger_rows(p_lease) r
     where r.kind = 'rent' and r.month = v_last and r.balance > 0.009;
    v_bills := '{}';
  elsif p_mode = 'owed' then
    select count(*) filter (where r.kind = 'rent' and r.due_date <= v_today),
           array_agg(r.bill_id) filter (where r.kind = 'bill'),
           coalesce(sum(r.balance) filter (where (r.kind = 'rent' and r.due_date <= v_today) or r.kind = 'bill'), 0)
      into v_months, v_bills, v_total
      from public.ledger_rows(p_lease) r where r.balance > 0.009 and r.kind in ('rent', 'bill');
  else
    raise exception 'Unknown way to use the deposit.';
  end if;
  if coalesce(v_total, 0) <= 0.009 then
    raise exception 'Nothing is owed for the deposit to pay.';
  end if;

  v_use := round(least(v_held, v_total), 2);
  perform public.record_payments(p_lease, v_months, coalesce(v_bills, '{}'), false, false, 'deposit', v_use);
  perform public.notify_peer(l.student_id, 'payment', 'Deposit used',
    'Your ' || public.landlord_title(l.landlord_id) || ' used ' || public.peso(v_use) || ' of your deposit for '
      || case when p_mode = 'last_month' then 'your last month''s rent.' else 'what was still owed.' end,
    '/student/payments', l.landlord_id);
  return v_use;
end $$;
revoke all on function public.use_deposit(uuid, text) from public, anon;
grant execute on function public.use_deposit(uuid, text) to authenticated;

-- Mark what is left of the deposit as handed back.
create or replace function public.return_deposit(p_lease uuid)
returns numeric
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  l public.leases;
  v_held numeric;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or auth.uid() is distinct from l.landlord_id then
    raise exception 'Only the landlord/landlady of this stay can return its deposit.' using errcode = '42501';
  end if;
  v_held := public.deposit_held(p_lease);
  if v_held <= 0.009 then
    raise exception 'No deposit is held on this stay.';
  end if;
  update public.leases set deposit_returned_at = now() where id = p_lease;
  perform public.notify_peer(l.student_id, 'payment', 'Deposit returned',
    'Your ' || public.landlord_title(l.landlord_id) || ' marked ' || public.peso(v_held) || ' of your deposit as returned to you.',
    '/student/payments', l.landlord_id);
  return v_held;
end $$;
revoke all on function public.return_deposit(uuid) from public, anon;
grant execute on function public.return_deposit(uuid) to authenticated;

-- ---- 3. landlord_ledger --------------------------------------------------------

create or replace function public.landlord_ledger()
returns table (lease_id uuid, kind text, month date, bill_id uuid, due_date date, due numeric, confirmed numeric,
               waived numeric, pending numeric, balance numeric, state text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select l.id, r.kind, r.month, r.bill_id, r.due_date, r.due, r.confirmed, r.waived, r.pending, r.balance, r.state
    from public.leases l
    cross join lateral public.ledger_rows(l.id) r
   where l.landlord_id = auth.uid()
     and l.status::text in ('active', 'leave_requested', 'ended', 'terminated');
$$;
revoke all on function public.landlord_ledger() from public, anon;
grant execute on function public.landlord_ledger() to authenticated;

-- ---- 5. Bills: correct, and tell the student ----------------------------------

create or replace function public.guard_utility_bills() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  l public.leases;
  v_billing text;
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_paid numeric;
begin
  if auth.uid() is null or public.is_admin(auth.uid()) then return coalesce(new, old); end if;

  if tg_op <> 'INSERT' then
    select coalesce(sum(p.amount), 0) into v_paid from public.payments p
     where p.bill_id = old.id and p.status::text not in ('rejected', 'withdrawn');
    if tg_op = 'DELETE' and v_paid > 0 then
      raise exception 'This bill has payments against it, so it can''t be removed. Correct its amount instead.';
    end if;
    if tg_op = 'UPDATE' and v_paid > 0 and (new.lease_id, new.utility, new.month) is distinct from (old.lease_id, old.utility, old.month) then
      raise exception 'This bill has payments against it, so only its amount can be corrected.';
    end if;
    if tg_op = 'UPDATE' and new.amount is distinct from old.amount then
      if new.amount <= 0 then
        raise exception 'Enter the correct amount.';
      end if;
      if new.amount + 0.009 < v_paid then
        raise exception 'A bill can''t be less than the ₱% already paid toward it.', to_char(v_paid, 'FM999,999,990.00');
      end if;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;

  select * into l from public.leases where id = new.lease_id;
  if l.status::text in ('pending', 'rejected') then
    raise exception 'Bills go on an accepted stay.';
  end if;
  v_billing := case new.utility when 'water' then l.water_billing::text
                                when 'electric' then l.electric_billing::text
                                else l.wifi_billing::text end;
  if v_billing is distinct from 'own_meter' and v_billing is distinct from 'split' then
    raise exception 'This stay''s terms don''t bill that utility monthly.';
  end if;
  if date_trunc('month', new.month) < date_trunc('month', l.start_date)
     or date_trunc('month', new.month) > date_trunc('month', l.end_date) then
    raise exception 'That month is outside this stay.';
  end if;
  -- The last month's meter reading arrives after move-out; a month is enough.
  if tg_op = 'INSERT' and l.status::text in ('ended', 'terminated') and v_today > l.end_date + 30 then
    raise exception 'This stay ended more than 30 days ago, so no more bills can go on it.';
  end if;
  return new;
end $$;

create or replace function public.tg_utility_bill_notify() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  l public.leases;
  v_label text := case new.utility when 'water' then 'Water bill' when 'electric' then 'Electricity bill' else 'Wi-Fi bill' end;
begin
  select * into l from public.leases where id = new.lease_id;
  if l.id is null then return null; end if;
  if tg_op = 'INSERT' then
    perform public.notify_peer(l.student_id, 'payment', 'New ' || lower(v_label) || ' · ' || public.peso(new.amount),
      'For ' || to_char(new.month, 'FMMonth') || ', due ' || to_char(new.due_date, 'Mon FMDD') || '.'
        || coalesce(' ' || nullif(btrim(new.note), ''), ''),
      '/student/payments', l.landlord_id);
  elsif new.amount is distinct from old.amount then
    perform public.notify_peer(l.student_id, 'payment', v_label || ' corrected',
      to_char(new.month, 'FMMonth') || ': ' || public.peso(old.amount) || ' → ' || public.peso(new.amount) || '.'
        || coalesce(' ' || nullif(btrim(new.note), ''), ''),
      '/student/payments', l.landlord_id);
  end if;
  return null;
end $$;
revoke all on function public.tg_utility_bill_notify() from public, anon, authenticated;
drop trigger if exists trg_utility_bill_notify on public.utility_bills;
create trigger trg_utility_bill_notify after insert or update on public.utility_bills
  for each row execute function public.tg_utility_bill_notify();

-- ---- 6. Daily reminders --------------------------------------------------------

-- One row per reminder sent, so the daily job never sends the same one twice.
create table if not exists public.payment_reminders (
  lease_id uuid not null references public.leases(id) on delete cascade,
  key text not null,
  sent_at timestamptz not null default now(),
  primary key (lease_id, key)
);
alter table public.payment_reminders enable row level security;

create or replace function public.remind_payments() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_today date := (now() at time zone 'Asia/Manila')::date;
  l record;
  r record;
  p record;
  -- 1 when a reminder key was claimed just now (the insert went in).
  v_n int;
  v_amt numeric;
begin
  -- Rent: three days before, and once it is overdue (after the grace days).
  for l in select le.*, coalesce(nullif(btrim(u.full_name), ''), 'Your tenant') as student_name
             from public.leases le join public.users u on u.id = le.student_id
            where le.status::text in ('active', 'leave_requested') loop
    for r in select * from public.ledger_rows(l.id) x where x.kind = 'rent' and x.balance > 0.009 loop
      if r.due_date = v_today + 3 and r.state <> 'pending' then
        insert into public.payment_reminders (lease_id, key) values (l.id, 'rent-due:' || r.month)
        on conflict do nothing;
        get diagnostics v_n = row_count;
        if v_n > 0 then
          perform public.notify_peer(l.student_id, 'payment', 'Rent due in 3 days',
            to_char(r.month, 'FMMonth') || ' rent, ' || public.peso(r.balance) || ', is due ' || to_char(r.due_date, 'Mon FMDD') || '.',
            '/student/payments', l.landlord_id);
        end if;
      -- Only recent months: the first run must not replay a backlog of old ones.
      elsif r.state = 'overdue' and r.due_date >= v_today - 30 then
        insert into public.payment_reminders (lease_id, key) values (l.id, 'rent-overdue:' || r.month)
        on conflict do nothing;
        get diagnostics v_n = row_count;
        if v_n > 0 then
          perform public.notify_peer(l.student_id, 'payment', to_char(r.month, 'FMMonth') || ' rent is overdue',
            public.peso(r.balance) || ' was due ' || to_char(r.due_date, 'Mon FMDD') || '.',
            '/student/payments', l.landlord_id);
          perform public.notify_peer(l.landlord_id, 'payment', l.student_name || '''s rent is late',
            to_char(r.month, 'FMMonth') || ' rent, ' || public.peso(r.balance) || ', was due ' || to_char(r.due_date, 'Mon FMDD') || '.',
            '/manager/tenant/' || l.id, l.student_id);
        end if;
      end if;
    end loop;

    -- Moving in within three days: the advance and deposit fall due then.
    if l.start_date = v_today + 3 then
      select coalesce(sum(x.balance), 0) into v_amt from public.ledger_rows(l.id) x where x.due_date = l.start_date;
      if v_amt > 0.009 then
        insert into public.payment_reminders (lease_id, key) values (l.id, 'move-in') on conflict do nothing;
        get diagnostics v_n = row_count;
        if v_n > 0 then
          perform public.notify_peer(l.landlord_id, 'payment', l.student_name || ' moves in ' || to_char(l.start_date, 'Mon FMDD'),
            public.peso(v_amt) || ' (advance and deposit) is due on moving in.',
            '/manager/tenant/' || l.id, l.student_id);
        end if;
      end if;
    end if;
  end loop;

  -- A promised date for the rest has come and something is still owed.
  for p in select distinct on (pa.lease_id, pa.promise_date) pa.lease_id, pa.promise_date, le.student_id, le.landlord_id
             from public.payments pa join public.leases le on le.id = pa.lease_id
            where pa.promise_date = v_today and pa.status::text in ('paid', 'pending_verification') loop
    select coalesce(sum(x.balance), 0) into v_amt from public.ledger_rows(p.lease_id) x where x.kind in ('rent', 'bill') and x.due_date <= v_today;
    if v_amt > 0.009 then
      insert into public.payment_reminders (lease_id, key) values (p.lease_id, 'promise:' || p.promise_date) on conflict do nothing;
      get diagnostics v_n = row_count;
      if v_n > 0 then
        perform public.notify_peer(p.student_id, 'payment', 'Time to pay the rest',
          'You said you''d pay the rest today. ' || public.peso(v_amt) || ' is still owed.',
          '/student/payments', p.landlord_id);
      end if;
    end if;
  end loop;

  -- A payment left waiting on the landlord/landlady for three days.
  for p in select pa.lease_id, coalesce(pa.batch_id, pa.id) as batch, sum(pa.amount) as total,
                  le.student_id, le.landlord_id, coalesce(nullif(btrim(u.full_name), ''), 'Your tenant') as student_name
             from public.payments pa join public.leases le on le.id = pa.lease_id join public.users u on u.id = le.student_id
            where pa.status::text = 'pending_verification'
            group by pa.lease_id, coalesce(pa.batch_id, pa.id), le.student_id, le.landlord_id, u.full_name
           having min(pa.created_at) <= now() - interval '3 days' loop
    insert into public.payment_reminders (lease_id, key) values (p.lease_id, 'waiting:' || p.batch) on conflict do nothing;
    get diagnostics v_n = row_count;
    if v_n > 0 then
      perform public.notify_peer(p.landlord_id, 'payment', p.student_name || ' has waited 3 days',
        'Check the ' || public.peso(p.total) || ' payment, then confirm or reject it.',
        '/manager/tenants?tab=payments', p.student_id);
    end if;
  end loop;

  -- From the 25th: this month's metered bills not posted yet, once per landlord/landlady.
  if extract(day from v_today) >= 25 then
    for p in select le.landlord_id, min(le.id::text)::uuid as lease_id, count(*) as n
               from public.leases le
              where le.status::text in ('active', 'leave_requested')
                and le.start_date <= v_today
                and exists (select 1 from unnest(array['water', 'electric', 'wifi']) ut
                             where (case ut when 'water' then le.water_billing::text when 'electric' then le.electric_billing::text
                                            else le.wifi_billing::text end) in ('own_meter', 'split')
                               and not exists (select 1 from public.utility_bills b
                                                where b.lease_id = le.id and b.utility::text = ut
                                                  and b.month = date_trunc('month', v_today)::date))
              group by le.landlord_id loop
      insert into public.payment_reminders (lease_id, key) values (p.lease_id, 'bills:' || to_char(v_today, 'YYYY-MM'))
      on conflict do nothing;
      get diagnostics v_n = row_count;
      if v_n > 0 then
        perform public.notify_peer(p.landlord_id, 'payment', 'Time to post ' || to_char(v_today, 'FMMonth') || ' bills',
          p.n || case when p.n = 1 then ' tenant doesn''t' else ' tenants don''t' end || ' have this month''s utility bills yet.',
          '/manager/tenants?tab=payments', null);
      end if;
    end loop;
  end if;

  -- A stay has ended and its deposit is still held.
  for l in select le.*, coalesce(nullif(btrim(u.full_name), ''), 'Your tenant') as student_name
             from public.leases le join public.users u on u.id = le.student_id
            where le.status::text in ('ended', 'terminated') and le.deposit_returned_at is null
              and coalesce(le.end_date, v_today) >= v_today - 60 loop
    v_amt := public.deposit_held(l.id);
    if v_amt > 0.009 then
      insert into public.payment_reminders (lease_id, key) values (l.id, 'deposit') on conflict do nothing;
      get diagnostics v_n = row_count;
      if v_n > 0 then
        perform public.notify_peer(l.landlord_id, 'payment', l.student_name || '''s stay ended · decide the deposit',
          public.peso(v_amt) || ' deposit is still held.',
          '/manager/tenant/' || l.id, l.student_id);
      end if;
    end if;
  end loop;
end $$;
revoke all on function public.remind_payments() from public, anon, authenticated;

select cron.unschedule('remind-payments') where exists (select 1 from cron.job where jobname = 'remind-payments');
select cron.schedule('remind-payments', '0 0 * * *', 'select public.remind_payments()');
