-- Tables only the database itself uses move out of `public` into `private`,
-- which the API does not expose at all: nothing a client can query, so nothing
-- a policy mistake can leak. Neither app reads them; only the security-definer
-- functions below do, and they are edited in place to the new schema.
--
--   user_pins        PIN hashes (has_pin, set_pin, verify_pin, clear_pin)
--   rate_limit_hits  rate-limit counters
--   sign_in_history  admin sign-ins (my_sign_ins, the new-sign-in alert)
--   reminders_sent   one log instead of expiry_reminders + payment_reminders,
--                    so a scheduled reminder is never sent twice
--
-- The two old reminder tables move to `archive` with their rows intact.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- reminders_sent --------------------------------------------------------------
create table private.reminders_sent (
  kind text not null check (kind in ('expiry', 'payment')),
  accommodation_id uuid references public.accommodations(id) on delete cascade,
  lease_id uuid references public.leases(id) on delete cascade,
  -- expiry: '<subject>:<due date>:<days before>'; payment: the reminder's own key.
  key text not null,
  sent_at timestamptz not null default now(),
  constraint reminders_sent_target check (
    (kind = 'expiry' and accommodation_id is not null and lease_id is null)
    or (kind = 'payment' and lease_id is not null and accommodation_id is null)
  )
);
create unique index reminders_sent_expiry_key on private.reminders_sent (accommodation_id, key) where kind = 'expiry';
create unique index reminders_sent_payment_key on private.reminders_sent (lease_id, key) where kind = 'payment';
create index reminders_sent_lease_id on private.reminders_sent (lease_id);

insert into private.reminders_sent (kind, accommodation_id, lease_id, key, sent_at)
select 'expiry', accommodation_id, null, subject || ':' || due_date || ':' || days_before, sent_at
  from public.expiry_reminders
union all
select 'payment', null, lease_id, key, sent_at
  from public.payment_reminders;

do $$
begin
  if (select count(*) from private.reminders_sent where kind = 'expiry') <> (select count(*) from public.expiry_reminders)
     or (select count(*) from private.reminders_sent where kind = 'payment') <> (select count(*) from public.payment_reminders) then
    raise exception 'reminders copy does not match the old tables; nothing was changed';
  end if;
end $$;

-- Move the three internal tables (rows, keys and indexes go with them).
alter table public.user_pins set schema private;
alter table public.rate_limit_hits set schema private;
alter table public.sign_in_history set schema private;
alter table public.expiry_reminders set schema archive;
alter table public.payment_reminders set schema archive;
revoke all on private.user_pins, private.rate_limit_hits, private.sign_in_history, private.reminders_sent
  from public, anon, authenticated;
revoke all on archive.expiry_reminders, archive.payment_reminders from public, anon, authenticated;

-- Point the functions at the new homes ----------------------------------------
-- Edit the live definitions rather than restating them, so nothing else in a
-- function can drift; each edit must change something and leave no old name.
do $$
declare
  f record;
  v_def text;
  v_new text;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('has_pin', 'set_pin', 'clear_pin', 'pin_attempt', 'admin_close_account',
                         'rate_limit_hit', 'purge_rate_limit_hits', 'my_sign_ins', 'notify_admin_sign_in',
                         'remind_payments', 'remind_accreditation_expiry')
  loop
    v_def := pg_get_functiondef(f.sig);
    v_new := replace(v_def, 'public.user_pins', 'private.user_pins');
    v_new := replace(v_new, 'public.rate_limit_hits', 'private.rate_limit_hits');
    v_new := replace(v_new, 'public.sign_in_history', 'private.sign_in_history');
    v_new := replace(v_new, 'insert into public.payment_reminders (lease_id, key) values (',
                            'insert into private.reminders_sent (kind, lease_id, key) values (''payment'', ');
    v_new := regexp_replace(v_new,
      'insert into public\.expiry_reminders \(accommodation_id, subject, due_date, days_before\)\s+values \(rec\.id, ([^,]+), rec\.due, (case when rec\.days_left <= 7 then 7 else 30 end)\)',
      'insert into private.reminders_sent (kind, accommodation_id, key)
    values (''expiry'', rec.id, \1 || '':'' || rec.due || '':'' || (\2))', 'g');
    if v_new = v_def then
      raise exception '% did not change', f.sig;
    end if;
    if v_new ~ '(public\.(user_pins|rate_limit_hits|sign_in_history)|payment_reminders|expiry_reminders)' then
      raise exception '% still names a moved table', f.sig;
    end if;
    execute v_new;
  end loop;
end $$;
