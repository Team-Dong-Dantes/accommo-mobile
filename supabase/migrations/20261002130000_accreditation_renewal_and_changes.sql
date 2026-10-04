-- After accreditation: renewing it, changing what OSAS checked, and being told
-- in time. Builds on accreditation_rounds (20261002120000).
--
-- 1. request_renewal(): a landlord/landlady renews from the listing instead of
--    starting over. Allowed in the last 60 days of the term, or once it has
--    expired. The listing stays live while OSAS looks.
-- 2. request_details_change(): the way to change what OSAS checked (name, type,
--    gender policy, location) on a listing that has left draft. The listing
--    keeps its current values until OSAS approves; withdraw_details_change()
--    takes the request back.
-- 3. Reminders: 30 and 7 days before an accreditation or a permit runs out,
--    each sent once; and one nudge for a draft left unfinished for a week.

alter table public.accommodations
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists draft_reminded_at timestamptz;

-- One row per reminder sent, so a daily job never sends the same one twice.
-- subject is 'accreditation' or a permit doc_type; due_date is what it warns about.
create table if not exists public.expiry_reminders (
  accommodation_id uuid not null references public.accommodations(id) on delete cascade,
  subject text not null,
  due_date date not null,
  days_before integer not null,
  sent_at timestamptz not null default now(),
  primary key (accommodation_id, subject, due_date, days_before)
);
alter table public.expiry_reminders enable row level security;
revoke all on public.expiry_reminders from anon, authenticated;

-- ---- 1. Renewal --------------------------------------------------------------------
create or replace function public.request_renewal(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  missing text[];
begin
  select * into a from public.accommodations where id = p_id for update;
  if a.id is null or a.landlord_id is distinct from auth.uid() then
    raise exception 'Accommodation not found.';
  end if;
  if not (
    a.status::text = 'expired'
    or (a.status::text in ('accredited', 'delisted')
        and a.accreditation_expires_at is not null
        and a.accreditation_expires_at <= now() + interval '60 days')
  ) then
    raise exception 'Renewal opens 60 days before the accreditation ends.';
  end if;
  if exists (select 1 from public.accreditation_rounds where accommodation_id = p_id and decided_at is null) then
    raise exception 'OSAS is already reviewing this listing.';
  end if;

  missing := public.accommodation_missing(p_id);
  if array_length(missing, 1) > 0 then
    raise exception 'Before renewing, add: %.', array_to_string(missing, ', ');
  end if;

  perform public.open_accreditation_round(p_id, 'renewal');
  perform public.notify_admins(
    'Accreditation renewal',
    coalesce(a.name, 'An accommodation') || ' asked to renew its accreditation.',
    'accommodation',
    '/verifications?focus=verification:' || p_id::text
  );
end;
$$;

-- ---- 2. Changes to what OSAS checked ------------------------------------------------
create or replace function public.request_details_change(p_id uuid, p_changes jsonb, p_message text default null) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  open_round public.accreditation_rounds;
  clean jsonb := '{}'::jsonb;
  k text;
  v jsonb;
begin
  select * into a from public.accommodations where id = p_id for update;
  if a.id is null or a.landlord_id is distinct from auth.uid() then
    raise exception 'Accommodation not found.';
  end if;
  if a.status::text not in ('accredited', 'delisted') then
    raise exception 'Only an accredited listing takes change requests. Edit it directly while it is a draft or sent back.';
  end if;
  if jsonb_typeof(p_changes) is distinct from 'object' then
    raise exception 'Nothing to change.';
  end if;

  for k, v in select * from jsonb_each(p_changes) loop
    if k not in ('name', 'accommodation_type', 'gender_policy', 'lat', 'lng', 'purok', 'barangay', 'city') then
      raise exception 'OSAS does not review %; edit it directly.', k;
    end if;
    if k = 'name' and nullif(trim(v #>> '{}'), '') is null then
      raise exception 'The name cannot be blank.';
    end if;
    if k = 'accommodation_type' and (v #>> '{}') not in ('boarding_house', 'residence', 'dormitory') then
      raise exception 'Unknown accommodation type.';
    end if;
    if k = 'gender_policy' and (v #>> '{}') not in ('male', 'female', 'co_ed') then
      raise exception 'Unknown gender policy.';
    end if;
    if k in ('lat', 'lng') and jsonb_typeof(v) <> 'number' then
      raise exception 'The location must be a point on the map.';
    end if;
    -- Only what actually differs from the listing as it stands.
    if (to_jsonb(a) -> k) is distinct from v
       and not (k in ('lat', 'lng') and (to_jsonb(a) ->> k)::numeric = (v #>> '{}')::numeric) then
      clean := clean || jsonb_build_object(k, case when jsonb_typeof(v) = 'string' then to_jsonb(trim(v #>> '{}')) else v end);
    end if;
  end loop;
  if clean = '{}'::jsonb then
    raise exception 'That is already how the listing reads.';
  end if;

  select * into open_round from public.accreditation_rounds
   where accommodation_id = p_id and decided_at is null for update;
  if open_round.id is not null then
    if open_round.kind <> 'change' then
      raise exception 'OSAS is reviewing something else on this listing. Ask again once it decides.';
    end if;
    update public.accreditation_rounds
       set proposed_changes = coalesce(proposed_changes, '{}'::jsonb) || clean,
           message = coalesce(nullif(trim(p_message), ''), message),
           submitted_at = now()
     where id = open_round.id;
    return;
  end if;

  perform public.open_accreditation_round(p_id, 'change', p_message, clean);
  perform public.notify_admins(
    'Listing change for review',
    coalesce(a.name, 'An accommodation') || ' asked to change details OSAS checked.',
    'accommodation',
    '/verifications?focus=verification:' || p_id::text
  );
end;
$$;

-- Takes back a change request OSAS has not decided yet.
create or replace function public.withdraw_details_change(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  if not exists (select 1 from public.accommodations where id = p_id and landlord_id = auth.uid()) then
    raise exception 'Accommodation not found.';
  end if;
  delete from public.accreditation_rounds
   where accommodation_id = p_id and decided_at is null and kind = 'change';
  if not found then
    raise exception 'There is no change waiting for OSAS.';
  end if;
  -- A reviewer who had it open keeps a stale claim; accommo-web ages those out.
end;
$$;

-- ---- 3. Reminders ----------------------------------------------------------------------
create or replace function public.remind_accreditation_expiry() returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  rec record;
begin
  -- The accreditation term itself.
  for rec in
    select a.id, a.landlord_id, a.name, a.accreditation_expires_at::date as due,
           (a.accreditation_expires_at::date - current_date) as days_left
      from public.accommodations a
     where a.status::text in ('accredited', 'delisted')
       and a.accreditation_expires_at is not null
       and a.accreditation_expires_at::date - current_date between 0 and 30
  loop
    insert into public.expiry_reminders (accommodation_id, subject, due_date, days_before)
    values (rec.id, 'accreditation', rec.due, case when rec.days_left <= 7 then 7 else 30 end)
    on conflict do nothing;
    if found then
      perform public.notify_system(
        rec.landlord_id, 'verification',
        'Accreditation ends in ' || rec.days_left || ' day' || case when rec.days_left = 1 then '' else 's' end,
        coalesce(nullif(trim(rec.name), ''), 'Your accommodation') || '''s accreditation ends on '
          || to_char(rec.due, 'FMMonth FMDD, YYYY') || '. Renew it from the listing so it stays visible to students.',
        '/manager/properties/' || rec.id::text
      );
    end if;
  end loop;

  -- Each permit, by its latest version.
  for rec in
    with latest as (
      select distinct on (d.accommodation_id, d.doc_type)
             d.accommodation_id, d.doc_type, d.expires_at
        from public.accommodation_documents d
       order by d.accommodation_id, d.doc_type, d.version desc
    )
    select a.id, a.landlord_id, a.name, l.doc_type, l.expires_at as due,
           (l.expires_at - current_date) as days_left
      from latest l join public.accommodations a on a.id = l.accommodation_id
     where a.status::text in ('accredited', 'delisted')
       and l.expires_at is not null
       and l.expires_at - current_date between 0 and 30
  loop
    insert into public.expiry_reminders (accommodation_id, subject, due_date, days_before)
    values (rec.id, rec.doc_type, rec.due, case when rec.days_left <= 7 then 7 else 30 end)
    on conflict do nothing;
    if found then
      perform public.notify_system(
        rec.landlord_id, 'verification',
        'A permit expires in ' || rec.days_left || ' day' || case when rec.days_left = 1 then '' else 's' end,
        'The ' || public.permit_label(rec.doc_type) || ' for ' || coalesce(nullif(trim(rec.name), ''), 'your accommodation')
          || ' expires on ' || to_char(rec.due, 'FMMonth FMDD, YYYY')
          || '. Upload the renewed permit before then, or the listing is hidden from students.',
        '/manager/properties/' || rec.id::text
      );
    end if;
  end loop;
end;
$$;

create or replace function public.remind_stale_drafts() returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  rec record;
  missing text[];
begin
  for rec in
    select a.id, a.landlord_id, a.name from public.accommodations a
     where a.status::text = 'draft'
       and a.created_at < now() - interval '7 days'
       and a.draft_reminded_at is null
  loop
    missing := public.accommodation_missing(rec.id);
    perform public.notify_system(
      rec.landlord_id, 'accommodation',
      'Finish your listing',
      coalesce(nullif(trim(rec.name), ''), 'Your draft') || ' is still a draft. '
        || case when array_length(missing, 1) > 0
             then 'Add ' || array_to_string(missing, ', ') || ', then submit it to OSAS.'
             else 'It is complete — submit it to OSAS when you are ready.' end,
      '/manager/properties/' || rec.id::text
    );
    update public.accommodations set draft_reminded_at = now() where id = rec.id;
  end loop;
end;
$$;

-- 01:00 UTC is 9 in the morning in the Philippines: read, not slept through.
select cron.schedule('remind-accreditation-expiry', '0 1 * * *', 'select public.remind_accreditation_expiry()');
select cron.schedule('remind-stale-drafts', '5 1 * * *', 'select public.remind_stale_drafts()');

-- ---- Grants -----------------------------------------------------------------------------
revoke all on function public.request_renewal(uuid) from public, anon;
revoke all on function public.request_details_change(uuid, jsonb, text) from public, anon;
revoke all on function public.withdraw_details_change(uuid) from public, anon;
grant execute on function public.request_renewal(uuid) to authenticated, service_role;
grant execute on function public.request_details_change(uuid, jsonb, text) to authenticated, service_role;
grant execute on function public.withdraw_details_change(uuid) to authenticated, service_role;

revoke all on function public.remind_accreditation_expiry() from public, anon, authenticated;
revoke all on function public.remind_stale_drafts() from public, anon, authenticated;
grant execute on function public.remind_accreditation_expiry() to service_role;
grant execute on function public.remind_stale_drafts() to service_role;
