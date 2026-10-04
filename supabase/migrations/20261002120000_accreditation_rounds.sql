-- Accreditation as a sequence of rounds, decided in one place.
--
-- Before this, an OSAS decision was five separate writes from the browser
-- (status, audit log, two notifications, a history row), any of which could
-- fail on its own and leave a listing accredited with no record of who did it
-- or why. OSAS could not say which permit was wrong, a single re-uploaded
-- permit re-queued the whole listing, a permit replaced on a LIVE listing took
-- it offline, and a landlord/landlady could change the name, location, type or
-- gender policy of an accredited listing without anyone looking.
--
-- 1. accreditation_rounds: one row per thing OSAS has to look at — a new
--    listing, a resubmission, an appeal, a renewal, a change to what OSAS
--    checked, or a permit replaced on a live listing. The open round (at most
--    one) IS the OSAS queue; decided rounds are the history both apps show.
-- 2. decide_accreditation(): the only way a round is decided. One transaction.
-- 3. submit / resubmit / appeal: the only ways a landlord/landlady opens one.
-- 4. A permit uploaded to a live listing opens a permit_update round and
--    leaves the listing live, instead of sending it back to pending.
-- 5. The columns OSAS checked are locked once a listing leaves draft, except
--    while OSAS has sent it back for changes.
-- 6. Tenants and the landlord/landlady are told when accreditation is
--    suspended or expires.
-- 7. Notices the backend sends keep their own type (see notify_system).

-- ---- 7 first: system notices ------------------------------------------------
-- tg_notification_attribution demotes any notification written in a non-admin
-- session to type 'message' and stamps the caller as its sender — right for a
-- peer's message, wrong for "a landlord/landlady resubmitted", which only the
-- backend says. notify_system() marks its own inserts so the trigger leaves
-- them alone, restoring whatever an enclosing caller had set.
create or replace function public.tg_notification_attribution() returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare
  sender_name text;
begin
  -- Sent by the backend itself (notify_system), not by the signed-in user.
  if coalesce(current_setting('app.system_notice', true), 'false') = 'true' then
    return new;
  end if;

  -- Addressed to yourself, or written by OSAS: nothing to attribute.
  if new.user_id = auth.uid() or public.is_admin(auth.uid()) then
    return new;
  end if;

  -- Service-role and trigger-driven writes have no auth.uid() at all; those are
  -- the backend's own fan-outs and are equally not somebody's peer.
  if auth.uid() is null then
    return new;
  end if;

  select u.full_name into sender_name from public.users u where u.id = auth.uid();
  new.source := coalesce(nullif(trim(sender_name), ''), 'Another user');

  -- The types a conversation peer has any business sending. Anything else --
  -- 'verification', 'policy', 'announcement', 'system' -- is OSAS's voice, so it
  -- is demoted rather than rejected: a refused insert would fail the message
  -- send that carried it.
  if new.type is null or new.type not in ('message', 'application', 'lease', 'leave', 'payment', 'concern', 'review') then
    new.type := 'message';
  end if;

  return new;
end;
$function$;

create or replace function public.notify_system(
  p_user uuid, p_type text, p_title text, p_body text, p_link text
) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  prev text := coalesce(current_setting('app.system_notice', true), 'false');
begin
  if p_user is null then return; end if;
  perform set_config('app.system_notice', 'true', true);
  insert into public.notifications (user_id, type, title, body, link_url)
  values (p_user, p_type, p_title, p_body, p_link);
  perform set_config('app.system_notice', prev, true);
end;
$$;

create or replace function public.notify_admins(p_title text, p_body text, p_type text, p_link_url text) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  prev text := coalesce(current_setting('app.system_notice', true), 'false');
begin
  perform set_config('app.system_notice', 'true', true);
  insert into public.notifications (user_id, title, body, type, link_url)
  select u.id, p_title, p_body, p_type, p_link_url
  from public.users u
  where u.role = 'admin' or u.is_superadmin = true;
  perform set_config('app.system_notice', prev, true);
end;
$$;

-- ---- 1. The rounds --------------------------------------------------------------
create table public.accreditation_rounds (
  id uuid primary key default gen_random_uuid(),
  accommodation_id uuid not null references public.accommodations(id) on delete cascade,
  round integer not null check (round >= 1),
  kind text not null check (kind in ('new', 'resubmission', 'appeal', 'renewal', 'change', 'permit_update')),
  submitted_at timestamptz not null default now(),
  submitted_by uuid references public.users(id) on delete set null,
  -- What the landlord/landlady wrote: the appeal, or a note with a resubmission.
  message text check (message is null or char_length(message) <= 1000),
  -- kind = 'change' only: the values asked for, keyed by column.
  proposed_changes jsonb,
  decided_at timestamptz,
  decided_by uuid references public.users(id) on delete set null,
  decision text check (decision in ('approved', 'returned', 'rejected')),
  -- Which permits OSAS wants replaced, by doc_type.
  flagged_docs text[],
  tags text[],
  note text,
  constraint accreditation_rounds_decided_together check ((decided_at is null) = (decision is null))
);

comment on table public.accreditation_rounds is
  'One row per thing OSAS must look at for an accommodation. The undecided row (at most one) is the queue entry; decided rows are the history.';

create unique index accreditation_rounds_one_open
  on public.accreditation_rounds (accommodation_id) where decided_at is null;
create index accreditation_rounds_accommodation_idx
  on public.accreditation_rounds (accommodation_id, round desc);

alter table public.accreditation_rounds enable row level security;

create policy accreditation_rounds_select_owner on public.accreditation_rounds
  for select to authenticated
  using (exists (select 1 from public.accommodations a
                 where a.id = accreditation_rounds.accommodation_id
                   and a.landlord_id = (select auth.uid())));

create policy accreditation_rounds_select_admin on public.accreditation_rounds
  for select to authenticated
  using ((select public.is_admin((select auth.uid()))));

-- Written only by the functions below.
revoke insert, update, delete on public.accreditation_rounds from anon, authenticated;
grant select on public.accreditation_rounds to authenticated;

alter table public.accommodations
  add column if not exists appeal_used boolean not null default false;

-- Lets OSAS spot the same permit file submitted for two different listings.
alter table public.accommodation_documents
  add column if not exists file_sha256 text;
create index if not exists accommodation_documents_sha256_idx
  on public.accommodation_documents (file_sha256) where file_sha256 is not null;

-- ---- Small shared pieces --------------------------------------------------------
-- How long an accreditation lasts. accommo-web used to hold this as a constant
-- of its own; the decision now happens here, so this is the one copy.
create or replace function public.accreditation_term() returns interval
language sql immutable as $$ select interval '1 year' $$;

create or replace function public.permit_label(p_type text) returns text
language sql immutable as $$
  select case p_type
    when 'sanitary_permit' then 'sanitary permit'
    when 'fire_safety' then 'fire safety permit'
    when 'business_permit' then 'business permit'
    when 'building_permit' then 'building permit'
    else replace(p_type, '_', ' ')
  end
$$;

-- What a listing still lacks before OSAS can review it. Shared by submit,
-- resubmit and the stale-draft reminder so the three cannot disagree.
create or replace function public.accommodation_missing(p_id uuid) returns text[]
language plpgsql stable security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  p public.accommodation_policies;
  missing text[] := '{}';
  doc text;
  latest_expiry date;
  undated boolean := false;
  lapsed boolean := false;
begin
  select * into a from public.accommodations where id = p_id;
  if a.id is null then return array['the accommodation itself']; end if;

  if a.accommodation_type is null or a.gender_policy is null then missing := array_append(missing, 'type and who it accepts'); end if;
  if a.lat is null or a.lng is null or a.barangay is null or a.city is null then missing := array_append(missing, 'location'); end if;
  if exists (
    select 1 from public.rooms r
     where r.accommodation_id = p_id
       and (r.water_billing is null or r.electric_billing is null or r.wifi_billing is null)
  ) then
    missing := array_append(missing, 'utilities on every room');
  end if;

  select * into p from public.accommodation_policies where accommodation_id = p_id;
  if p.curfew_time is null or p.quiet_hours is null or p.visitor_policy is null then missing := array_append(missing, 'house rules'); end if;

  if not exists (select 1 from public.accommodation_images where accommodation_id = p_id) then
    missing := array_append(missing, 'an exterior photo');
  end if;

  foreach doc in array array['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] loop
    if not exists (select 1 from public.accommodation_documents where accommodation_id = p_id and doc_type = doc) then
      missing := array_append(missing, 'all four permits');
      return missing;
    end if;
    select d.expires_at into latest_expiry
      from public.accommodation_documents d
     where d.accommodation_id = p_id and d.doc_type = doc
     order by d.version desc limit 1;
    if latest_expiry is null then undated := true;
    elsif latest_expiry < current_date then lapsed := true;
    end if;
  end loop;
  if undated then missing := array_append(missing, 'an expiry date on every permit'); end if;
  if lapsed then missing := array_append(missing, 'permits that have not expired'); end if;

  return missing;
end;
$$;

-- Opens the next round. Internal: callers have already checked who may.
create or replace function public.open_accreditation_round(
  p_id uuid, p_kind text, p_message text default null, p_changes jsonb default null
) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare
  v_round int;
  v_id uuid;
begin
  select coalesce(max(round), 0) + 1 into v_round from public.accreditation_rounds where accommodation_id = p_id;
  insert into public.accreditation_rounds (accommodation_id, round, kind, submitted_by, message, proposed_changes)
  values (p_id, v_round, p_kind, auth.uid(), nullif(trim(p_message), ''), p_changes)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---- 5. Locks --------------------------------------------------------------------
create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path to 'public' as $function$
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = 'student_profiles' then
    if tg_op = 'INSERT' then
      if new.osas_verified_at is not null then
        raise exception 'Only OSAS may set verification status.';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception 'Only OSAS may change verification status.';
    end if;
  end if;

  if tg_table_name = 'accommodations' then
    if tg_op = 'INSERT' then
      if new.status::text not in ('pending', 'draft') then
        raise exception 'A new accommodation must start as a draft or pending.';
      end if;
      if new.accredited_at is not null or new.accreditation_expires_at is not null or new.appeal_used then
        raise exception 'Only OSAS may set accreditation details.';
      end if;
    else
      if new.status is distinct from old.status then
        -- Into review only through submit/resubmit/appeal, each of which checks
        -- the listing first and then sets this flag.
        if coalesce(current_setting('app.submit_review', true), 'false') = 'true'
           and old.status::text in ('draft', 'needs_revision', 'rejected')
           and new.status = 'pending' then
          null;
        elsif auth.uid() = old.landlord_id
              and new.landlord_id = old.landlord_id
              and (
                (old.status = 'accredited' and new.status = 'delisted')
                or (old.status = 'delisted' and new.status = 'accredited'
                    and (new.accreditation_expires_at is null
                         or new.accreditation_expires_at > now()))
              ) then
          null;
        else
          raise exception 'Only OSAS may change accreditation status.';
        end if;
      end if;

      -- Written by OSAS, or by the functions in this file on its behalf.
      if (new.accredited_at, new.accreditation_expires_at, new.reviewing_by, new.reviewing_at)
           is distinct from (old.accredited_at, old.accreditation_expires_at, old.reviewing_by, old.reviewing_at)
         or (new.appeal_used is distinct from old.appeal_used
             and coalesce(current_setting('app.submit_review', true), 'false') <> 'true') then
        raise exception 'Only OSAS may change accreditation details.';
      end if;

      -- What OSAS checked. Free while it is a private draft or sent back for
      -- changes; otherwise it changes through request_details_change().
      if old.status::text not in ('draft', 'needs_revision')
         and (new.name, new.accommodation_type, new.gender_policy, new.lat, new.lng, new.purok, new.barangay, new.city)
             is distinct from
             (old.name, old.accommodation_type, old.gender_policy, old.lat, old.lng, old.purok, old.barangay, old.city) then
        raise exception 'OSAS checked this when it reviewed the listing. Ask OSAS for the change instead.'
          using errcode = '42501';
      end if;
    end if;
  end if;

  if tg_table_name = 'verification_documents' then
    if new.status = 'approved' then
      raise exception 'Only OSAS may approve a document.';
    end if;
  end if;

  return new;
end $function$;

-- ---- 3. Landlord/landlady side ----------------------------------------------------
-- Send a draft to OSAS. Every check is one the wizard also makes, repeated here
-- because a draft is finished in the editor, where nothing walks the steps.
create or replace function public.submit_accommodation(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  missing text[];
begin
  select * into a from public.accommodations where id = p_id for update;
  if a.id is null or a.landlord_id is distinct from auth.uid() then
    raise exception 'Accommodation not found.';
  end if;
  if a.status::text <> 'draft' then
    raise exception 'This accommodation has already been submitted.';
  end if;

  missing := public.accommodation_missing(p_id);
  if array_length(missing, 1) > 0 then
    raise exception 'Still missing: %.', array_to_string(missing, ', ');
  end if;

  perform set_config('app.submit_review', 'true', true);
  update public.accommodations set status = 'pending' where id = p_id;
  perform set_config('app.submit_review', 'false', true);

  perform public.open_accreditation_round(p_id, 'new');
  perform public.notify_admins(
    'New accommodation for accreditation',
    coalesce(a.name, 'An accommodation') || ' was submitted for accreditation.',
    'accommodation',
    '/verifications?focus=verification:' || p_id::text
  );
end;
$$;

-- Back to OSAS after it asked for changes. Every permit OSAS flagged must have
-- been replaced since it said so — resubmitting the same files is the thing
-- this exists to prevent.
create or replace function public.resubmit_accommodation(p_id uuid, p_message text default null) returns integer
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  last public.accreditation_rounds;
  doc text;
  unreplaced text[] := '{}';
  missing text[];
  v_round int;
begin
  select * into a from public.accommodations where id = p_id for update;
  if a.id is null or a.landlord_id is distinct from auth.uid() then
    raise exception 'Accommodation not found.';
  end if;
  if a.status::text <> 'needs_revision' then
    raise exception 'Only an accommodation OSAS sent back for changes can be resubmitted.';
  end if;

  select * into last from public.accreditation_rounds
   where accommodation_id = p_id and decision = 'returned'
   order by round desc limit 1;

  if last.id is not null then
    foreach doc in array coalesce(last.flagged_docs, '{}') loop
      if not exists (select 1 from public.accommodation_documents d
                      where d.accommodation_id = p_id and d.doc_type = doc
                        and d.uploaded_at::timestamptz > last.decided_at) then
        unreplaced := array_append(unreplaced, public.permit_label(doc));
      end if;
    end loop;
  end if;
  if array_length(unreplaced, 1) > 0 then
    raise exception 'Replace the % first.', array_to_string(unreplaced, ', ');
  end if;

  missing := public.accommodation_missing(p_id);
  if array_length(missing, 1) > 0 then
    raise exception 'Still missing: %.', array_to_string(missing, ', ');
  end if;

  perform set_config('app.submit_review', 'true', true);
  update public.accommodations set status = 'pending' where id = p_id;
  perform set_config('app.submit_review', 'false', true);

  perform public.open_accreditation_round(p_id, 'resubmission', p_message);
  select round into v_round from public.accreditation_rounds where accommodation_id = p_id and decided_at is null;

  perform public.notify_admins(
    'Accommodation resubmitted',
    coalesce(a.name, 'An accommodation') || ' was resubmitted for accreditation (round ' || v_round || ').',
    'accommodation',
    '/verifications?focus=verification:' || p_id::text
  );
  return v_round;
end;
$$;

-- One appeal against an outright refusal. OSAS either upholds it (final) or
-- reopens the listing for changes.
create or replace function public.appeal_accommodation(p_id uuid, p_message text) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  last public.accreditation_rounds;
begin
  select * into a from public.accommodations where id = p_id for update;
  if a.id is null or a.landlord_id is distinct from auth.uid() then
    raise exception 'Accommodation not found.';
  end if;
  if a.status::text <> 'rejected' then
    raise exception 'Only a refused accommodation can be appealed.';
  end if;
  if a.appeal_used then
    raise exception 'This accommodation has already been appealed once.';
  end if;
  if nullif(trim(p_message), '') is null then
    raise exception 'Say why OSAS should look at it again.';
  end if;

  select * into last from public.accreditation_rounds
   where accommodation_id = p_id and decided_at is not null
   order by round desc limit 1;
  if last.kind = 'appeal' then
    raise exception 'This accommodation has already been appealed once.';
  end if;

  perform set_config('app.submit_review', 'true', true);
  update public.accommodations set status = 'pending', appeal_used = true where id = p_id;
  perform set_config('app.submit_review', 'false', true);

  perform public.open_accreditation_round(p_id, 'appeal', p_message);
  perform public.notify_admins(
    'Accreditation appeal',
    coalesce(a.name, 'An accommodation') || ' appealed its refusal.',
    'accommodation',
    '/verifications?focus=verification:' || p_id::text
  );
end;
$$;

-- ---- 2. OSAS side -----------------------------------------------------------------
create or replace function public.decide_accreditation(
  p_accommodation uuid,
  p_decision text,
  p_flagged_docs text[] default null,
  p_tags text[] default null,
  p_note text default null,
  p_override boolean default false
) returns text
language plpgsql security definer set search_path to 'public' as $$
declare
  v_uid uuid := auth.uid();
  a public.accommodations;
  r public.accreditation_rounds;
  v_status text;
  v_note text := nullif(trim(p_note), '');
  v_flags text[] := nullif(p_flagged_docs, '{}');
  v_title text;
  v_body text;
  v_name text;
  v_flag_text text;
  v_until text;
  ch jsonb;
begin
  if not public.is_admin(v_uid) then
    raise exception 'Only OSAS can decide accreditation requests.' using errcode = '42501';
  end if;
  if p_decision not in ('approved', 'returned', 'rejected') then
    raise exception 'Unknown decision: %.', p_decision;
  end if;

  select * into a from public.accommodations where id = p_accommodation for update;
  if a.id is null then raise exception 'Accommodation not found.'; end if;
  select * into r from public.accreditation_rounds
   where accommodation_id = a.id and decided_at is null for update;
  if r.id is null then
    raise exception 'Nothing on this accommodation is waiting for a decision.';
  end if;
  if a.reviewing_by is distinct from v_uid then
    raise exception 'Open this request for review before deciding it.';
  end if;
  if v_flags is not null and not (v_flags <@ array['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit']) then
    raise exception 'Unknown permit in the flagged list.';
  end if;
  if p_decision = 'returned' and v_flags is null and v_note is null then
    raise exception 'Say what needs fixing: flag a permit or add a note.';
  end if;
  if p_override and v_note is null then
    raise exception 'An override needs a note explaining it.';
  end if;

  v_status := a.status::text;
  v_name := coalesce(nullif(trim(a.name), ''), 'Your accommodation');
  -- "the fire safety permit, sanitary permit and building permit"
  select regexp_replace(string_agg(public.permit_label(f), ', '), ', ([^,]*)$', ' and \1')
    into v_flag_text from unnest(coalesce(v_flags, '{}')) f;

  if r.kind in ('new', 'resubmission', 'appeal') then
    v_status := case p_decision when 'approved' then 'accredited' when 'returned' then 'needs_revision' else 'rejected' end;
    update public.accommodations
       set status = v_status::public.accommodation_status,
           accredited_at = case when p_decision = 'approved' then now() else accredited_at end,
           accreditation_expires_at = case when p_decision = 'approved' then now() + public.accreditation_term() else accreditation_expires_at end
     where id = a.id;
  elsif r.kind = 'renewal' then
    if p_decision = 'approved' then
      v_status := case when a.status::text = 'expired' then 'accredited' else a.status::text end;
      update public.accommodations
         set status = v_status::public.accommodation_status,
             accreditation_expires_at = greatest(coalesce(a.accreditation_expires_at, now()), now()) + public.accreditation_term()
       where id = a.id;
    end if;
  elsif r.kind = 'change' and p_decision = 'approved' then
    ch := coalesce(r.proposed_changes, '{}'::jsonb);
    update public.accommodations set
      name = case when ch ? 'name' then ch->>'name' else name end,
      accommodation_type = case when ch ? 'accommodation_type' then ch->>'accommodation_type' else accommodation_type end,
      gender_policy = case when ch ? 'gender_policy' then ch->>'gender_policy' else gender_policy end,
      lat = case when ch ? 'lat' then (ch->>'lat')::numeric else lat end,
      lng = case when ch ? 'lng' then (ch->>'lng')::numeric else lng end,
      purok = case when ch ? 'purok' then ch->>'purok' else purok end,
      barangay = case when ch ? 'barangay' then ch->>'barangay' else barangay end,
      city = case when ch ? 'city' then ch->>'city' else city end
    where id = a.id;
  end if;
  -- permit_update: approving accepts the file; sending back flags it. The
  -- listing's status is untouched either way.

  update public.accommodations set reviewing_by = null, reviewing_at = null where id = a.id;

  update public.accreditation_rounds
     set decided_at = now(), decided_by = v_uid, decision = p_decision,
         flagged_docs = v_flags, tags = nullif(p_tags, '{}'), note = v_note
   where id = r.id;

  insert into public.audit_logs (actor_id, action, entity_id, entity_type, before_json, after_json)
  values (
    v_uid,
    case p_decision when 'approved' then 'verification.approve' when 'returned' then 'verification.resubmit' else 'verification.reject' end,
    a.id::text,
    'accommodation',
    jsonb_build_object('status', a.status),
    jsonb_build_object(
      'status', v_status, 'decision', p_decision, 'kind', r.kind, 'round', r.round,
      'override', p_override, 'allow_resubmission', p_decision = 'returned',
      'tags', p_tags, 'notes', v_note, 'flagged_docs', v_flags
    )
  );

  v_until := to_char((select accreditation_expires_at from public.accommodations where id = a.id) at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY');
  if r.kind in ('new', 'resubmission', 'appeal') then
    if p_decision = 'approved' then
      v_title := 'Accommodation accredited';
      v_body := v_name || ' is accredited until ' || v_until || ' and is now visible to students.';
    elsif p_decision = 'returned' then
      v_title := 'OSAS needs changes';
      v_body := v_name || ' needs changes before it can be accredited'
        || coalesce(': replace the ' || v_flag_text, '') || '.' || coalesce(' ' || v_note, '');
    elsif r.kind = 'appeal' then
      v_title := 'Appeal not granted';
      v_body := 'OSAS upheld its decision on ' || v_name || '.' || coalesce(' ' || v_note, '');
    else
      v_title := 'Accreditation refused';
      v_body := v_name || ' was not accredited.' || coalesce(' Reason: ' || v_note, '')
        || case when a.appeal_used then '' else ' You can appeal this once.' end;
    end if;
  elsif r.kind = 'renewal' then
    v_title := case p_decision when 'approved' then 'Accreditation renewed' when 'returned' then 'Renewal needs changes' else 'Renewal refused' end;
    v_body := case p_decision
      when 'approved' then v_name || ' is accredited until ' || v_until || '.'
      when 'returned' then 'OSAS needs changes before renewing ' || v_name || coalesce(': replace the ' || v_flag_text, '') || '.' || coalesce(' ' || v_note, '')
      else 'OSAS did not renew ' || v_name || '.' || coalesce(' Reason: ' || v_note, '')
    end;
  elsif r.kind = 'change' then
    v_title := case p_decision when 'approved' then 'Change approved' else 'Change not approved' end;
    v_body := case p_decision
      when 'approved' then 'Your change to ' || v_name || ' is now live.'
      else 'OSAS did not approve your change to ' || v_name || '.' || coalesce(' ' || v_note, '')
    end;
  else
    v_title := case p_decision when 'approved' then 'Permit accepted' else 'Permit needs replacing' end;
    v_body := case p_decision
      when 'approved' then 'OSAS accepted the permit you uploaded for ' || v_name || '.'
      else 'OSAS could not accept the permit for ' || v_name || coalesce(': replace the ' || v_flag_text, '') || '.' || coalesce(' ' || v_note, '')
    end;
  end if;

  perform public.notify_system(a.landlord_id, 'verification', v_title, v_body, '/manager/properties/' || a.id::text);
  return v_status;
end;
$$;

-- Median days from submission to decision over the last 90 days, for the
-- "OSAS usually replies within" line. Null until there is enough to go on.
-- Rounds carried over from before rounds existed have no real submission time
-- (submitted_at = decided_at) and are left out.
create or replace function public.accreditation_wait_estimate() returns numeric
language sql stable security definer set search_path to 'public' as $$
  select case when count(*) >= 3 then
    round((percentile_cont(0.5) within group (order by extract(epoch from decided_at - submitted_at)) / 86400)::numeric, 1)
  end
  from public.accreditation_rounds
  where decided_at > now() - interval '90 days'
    and decided_at > submitted_at
    and kind in ('new', 'resubmission', 'appeal')
$$;

-- ---- 4. A permit replaced on a live listing -------------------------------------
-- Used to send the listing straight back to pending, which took it off
-- Discover until OSAS looked. Now the listing stays live and OSAS gets a
-- permit_update round. Sent-back listings wait for an explicit resubmit;
-- drafts, pending and refused listings need nothing here.
create or replace function public.tg_permit_needs_review() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
begin
  select * into a from public.accommodations where id = new.accommodation_id;
  if a.status::text in ('accredited', 'delisted')
     and not exists (select 1 from public.accreditation_rounds
                      where accommodation_id = a.id and decided_at is null) then
    perform public.open_accreditation_round(a.id, 'permit_update');
    perform public.notify_admins(
      'Permit updated',
      coalesce(a.name, 'An accommodation') || ' uploaded a new ' || public.permit_label(new.doc_type) || '.',
      'accommodation',
      '/verifications?focus=verification:' || a.id::text
    );
  end if;
  return new;
end $$;

-- ---- 6. Status changes OSAS or the clock makes --------------------------------
create or replace function public.tg_accreditation_status_change() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_name text := coalesce(nullif(trim(new.name), ''), 'Your boarding house');
  v_student uuid;
begin
  if new.status is not distinct from old.status then return new; end if;

  -- A decision written straight to the row (an accommodo-web build from before
  -- decide_accreditation) still closes the round it answered, so the queue
  -- does not keep a request nobody will ever look at again.
  if old.status::text in ('pending', 'reviewing')
     and new.status::text in ('accredited', 'needs_revision', 'rejected') then
    update public.accreditation_rounds
       set decided_at = now(), decided_by = auth.uid(),
           decision = case new.status::text when 'accredited' then 'approved' when 'needs_revision' then 'returned' else 'rejected' end
     where accommodation_id = new.id and decided_at is null and kind in ('new', 'resubmission', 'appeal');
  end if;

  if new.status::text in ('suspended', 'expired') then
    perform public.notify_system(
      new.landlord_id, 'verification',
      case new.status::text when 'suspended' then 'Accreditation suspended' else 'Accreditation ended' end,
      case new.status::text
        when 'suspended' then v_name || ' is suspended by OSAS and hidden from students. Check OSAS for the reason.'
        else v_name || '''s accreditation has ended and it is hidden from students. Renew it from the listing.'
      end,
      '/manager/properties/' || new.id::text
    );
    for v_student in
      select distinct l.student_id
        from public.leases l join public.rooms r on r.id = l.room_id
       where r.accommodation_id = new.id and l.status in ('active', 'leave_requested')
    loop
      perform public.notify_system(
        v_student, 'lease',
        case new.status::text when 'suspended' then 'Your boarding house was suspended' else 'Your boarding house is no longer accredited' end,
        v_name || ' is no longer accredited by OSAS'
          || case new.status::text when 'suspended' then ' while it is suspended' else '' end
          || '. Your stay is not ended by this. Contact OSAS from Support if you have concerns.',
        '/student/stay'
      );
    end loop;
  end if;
  return new;
end $$;

create trigger trg_accreditation_status_change
  after update of status on public.accommodations
  for each row execute function public.tg_accreditation_status_change();

-- ---- Grants -------------------------------------------------------------------------
revoke all on function public.notify_system(uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.open_accreditation_round(uuid, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.accommodation_missing(uuid) from public, anon, authenticated;
revoke all on function public.tg_accreditation_status_change() from public, anon, authenticated;

revoke all on function public.submit_accommodation(uuid) from public, anon;
revoke all on function public.resubmit_accommodation(uuid, text) from public, anon;
revoke all on function public.appeal_accommodation(uuid, text) from public, anon;
revoke all on function public.decide_accreditation(uuid, text, text[], text[], text, boolean) from public, anon;
revoke all on function public.accreditation_wait_estimate() from public, anon;
grant execute on function public.submit_accommodation(uuid) to authenticated, service_role;
grant execute on function public.resubmit_accommodation(uuid, text) to authenticated, service_role;
grant execute on function public.appeal_accommodation(uuid, text) to authenticated, service_role;
grant execute on function public.decide_accreditation(uuid, text, text[], text[], text, boolean) to authenticated, service_role;
grant execute on function public.accreditation_wait_estimate() to authenticated, service_role;

-- ---- Backfill -----------------------------------------------------------------------
-- The decisions already made, from the old history table, so both apps have a
-- past to show. Their submission times were never recorded; submitted_at takes
-- the decision time, which also keeps them out of the wait estimate.
insert into public.accreditation_rounds
  (accommodation_id, round, kind, submitted_at, decided_at, decided_by, decision, tags, note)
select v.entity_id,
       row_number() over w,
       case when row_number() over w = 1 then 'new' else 'resubmission' end,
       v.reviewed_at, v.reviewed_at, v.reviewed_by,
       case v.status when 'approved' then 'approved' when 'resubmission_requested' then 'returned' else 'rejected' end,
       v.rejection_reasons, v.decision_notes
  from public.verification_requests v
  join public.accommodations a on a.id = v.entity_id
 where v.entity_type = 'accommodation'
window w as (partition by v.entity_id order by v.reviewed_at);

-- What is in the queue right now becomes an open round.
insert into public.accreditation_rounds (accommodation_id, round, kind, submitted_by)
select a.id,
       coalesce((select max(round) from public.accreditation_rounds r where r.accommodation_id = a.id), 0) + 1,
       case when exists (select 1 from public.accreditation_rounds r where r.accommodation_id = a.id) then 'resubmission' else 'new' end,
       a.landlord_id
  from public.accommodations a
 where a.status::text in ('pending', 'reviewing');
