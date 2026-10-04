-- Per-user write caps on every table the apps insert into directly.
--
-- Only PIN attempts, QR rotation/scans and accreditation rounds were throttled;
-- every other insert (messages, tickets, notifications to a counterparty, ...)
-- was unbounded, so one stuck retry loop or one bad actor could flood a table
-- and everyone's realtime feed with it.
--
-- One fixed-window counter keyed by (who, table) instead of a count(*) per
-- table: the author/time columns differ table to table (sender_id/sent_at,
-- author_id/created_at, reported_at, ...) and several tables have neither.
-- ponytail: fixed window allows up to 2x the cap across a window boundary; a
-- sliding window is not worth the extra writes at this scale.

create table if not exists public.rate_limit_hits (
  key          text        not null,
  window_start timestamptz not null,
  hits         int         not null default 1,
  primary key (key, window_start)
);
-- No policies: only the security-definer functions below touch it.
alter table public.rate_limit_hits enable row level security;

-- Counts one hit against `p_key` and reports whether it is still within
-- `p_max` per `p_window` seconds. Also called by the request-admin-reset edge
-- function (service role) to cap reset e-mails per address.
create or replace function public.rate_limit_hit(p_key text, p_max int, p_window int)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_start timestamptz := to_timestamp(floor(extract(epoch from now()) / p_window) * p_window);
  v_hits int;
begin
  insert into public.rate_limit_hits as r (key, window_start)
  values (p_key, v_start)
  on conflict (key, window_start) do update set hits = r.hits + 1
  returning hits into v_hits;
  return v_hits <= p_max;
end $$;

revoke all on function public.rate_limit_hit(text, int, int) from public, anon, authenticated;
grant execute on function public.rate_limit_hit(text, int, int) to service_role;

-- BEFORE INSERT trigger. TG_ARGV: max, window seconds, what to call it in the error.
-- Only counts what a signed-in user inserts directly (depth 1): rows the
-- database writes on someone's behalf — announcement fan-out, ticket alerts,
-- message notifications — run at depth 2+ and must never be refused. OSAS is
-- exempt; their bulk tools are the reason the console exists.
create or replace function public.enforce_rate_limit()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_window int := TG_ARGV[1]::int;
begin
  if v_uid is null or pg_trigger_depth() > 1 or public.is_admin(v_uid) then
    return new;
  end if;
  if not public.rate_limit_hit(v_uid::text || ':' || TG_TABLE_NAME, TG_ARGV[0]::int, v_window) then
    raise exception 'Too many % in a short time. Please wait % and try again.',
      TG_ARGV[2],
      case when v_window <= 60 then 'a minute' when v_window <= 3600 then 'an hour' else 'a day' end
      using errcode = 'P0001';
  end if;
  return new;
end $$;

-- Caps sized for the busiest honest user, not the average one: a landlord/landlady
-- adding a whole boarding house at semester start, logging every tenant's
-- payment, or photographing every room must not hit them.
do $$
declare r record;
begin
  for r in select * from (values
    ('messages',                30,    60, 'messages'),
    ('conversations',           20,  3600, 'new conversations'),
    ('ticket_messages',         20,    60, 'replies'),
    ('tickets',                  5,  3600, 'support tickets'),
    ('concerns',                 5,  3600, 'concerns'),
    ('notifications',           30,    60, 'notifications'),
    ('payments',                60,  3600, 'payments'),
    ('leases',                  30, 86400, 'applications'),
    ('accommodation_reviews',    5, 86400, 'ratings'),
    ('landlord_reviews',         5, 86400, 'ratings'),
    ('tenant_reviews',          30, 86400, 'ratings'),
    ('verification_documents',  30,  3600, 'uploads'),
    ('accommodation_documents', 30,  3600, 'uploads'),
    ('accommodation_images',   100,  3600, 'photos'),
    ('room_images',            100,  3600, 'photos'),
    ('accommodations',          10, 86400, 'new accommodations'),
    ('rooms',                  100,  3600, 'new rooms'),
    ('announcements',           10,  3600, 'announcements')
  ) as t(tbl, max_hits, win, noun)
  loop
    execute format('drop trigger if exists rate_limit on public.%I', r.tbl);
    execute format(
      'create trigger rate_limit before insert on public.%I for each row execute function public.enforce_rate_limit(%L, %L, %L)',
      r.tbl, r.max_hits, r.win, r.noun);
  end loop;
end $$;

-- Windows are at most a day long; anything older is dead weight.
create or replace function public.purge_rate_limit_hits()
returns void language sql security definer set search_path = public as $$
  delete from public.rate_limit_hits where window_start < now() - interval '2 days';
$$;
select cron.schedule('purge-rate-limit-hits', '40 3 * * *', 'select public.purge_rate_limit_hits()');
