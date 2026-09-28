-- Make the server write the status it means.
--
-- `reviewing` means a reviewer currently has the request open. Two writers have
-- been asserting that about properties nobody had open:
--
--   sweep_expired_permits()    nightly: a lapsed permit -> 'reviewing'
--   tg_permit_needs_review()   on upload: a renewal     -> 'reviewing'
--
-- Both were saying "this needs looking at" with the only value available. Now
-- that `expired` exists, each says what it means: a lapse is `expired`, and a
-- renewal puts the property back in the queue as `pending`. The web console's
-- review lock treats a `reviewing` row with no reviewer present as abandoned and
-- sweeps it, so leaving these as they were would have had the two mechanisms
-- undoing each other nightly.

-- ── 1. a lapsed permit expires the accreditation ────────────────────────────
create or replace function public.sweep_expired_permits() returns void
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  -- Latest version per (accommodation, doc_type): an accreditation lapses when
  -- the newest copy of any required permit is past its expiry.
  with latest as (
    select distinct on (d.accommodation_id, d.doc_type)
           d.accommodation_id, d.doc_type, d.expires_at
    from public.accommodation_documents d
    order by d.accommodation_id, d.doc_type, d.version desc
  ),
  lapsed as (
    select distinct accommodation_id from latest
    where expires_at is not null and expires_at < now()
  )
  update public.accommodations a
  set status = 'expired'
  where a.status = 'accredited'
    and a.id in (select accommodation_id from lapsed);
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      'Accreditation expired',
      n || ' accommodation(s) have a permit that has expired and are no longer listed.',
      'verification', '/verifications');
  end if;
end $$;

revoke all on function public.sweep_expired_permits() from public, anon, authenticated;

-- ── 2. the accreditation term itself runs out ───────────────────────────────
-- `accreditation_expires_at` is stamped when OSAS approves a property. Until
-- now nothing wrote it and nothing read it for a decision, so an accreditation
-- once granted never ended on its own.
create or replace function public.sweep_expired_accreditations() returns void
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  update public.accommodations a
  set status = 'expired'
  where a.status = 'accredited'
    and a.accreditation_expires_at is not null
    and a.accreditation_expires_at < now();
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      'Accreditation term ended',
      n || ' accommodation(s) reached the end of their accreditation term and are no longer listed.',
      'verification', '/verifications');
  end if;
end $$;

revoke all on function public.sweep_expired_accreditations() from public, anon, authenticated;

-- 18:30 UTC (02:30 Manila), half an hour behind the permit sweep so a property
-- that fails both is reported once by the first job rather than twice.
select cron.unschedule('sweep-expired-accreditations')
where exists (select 1 from cron.job where jobname = 'sweep-expired-accreditations');

select cron.schedule('sweep-expired-accreditations', '30 18 * * *',
                     $$select public.sweep_expired_accreditations();$$);

-- ── 3. a renewal returns the property to the queue, not to a reviewer ───────
-- Also widened: the old `where status = 'accredited'` meant a manager replacing
-- the permit that got them expired or sent back for revision changed nothing at
-- all, and their property sat outside the queue with a fresh document in it.
create or replace function public.tg_permit_needs_review() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.permit_review', 'true', true);
  update public.accommodations set status = 'pending'
  where id = new.accommodation_id
    and status in ('accredited', 'expired', 'needs_revision', 'rejected');
  perform set_config('app.permit_review', 'false', true);
  return new;
end $$;

-- ── 4. the guard has to allow the transition the trigger now makes ──────────
-- lock_verification_columns whitelists exactly one manager-triggered status
-- change. It named the old one literally, so without this the trigger above
-- raises 'Only OSAS may change accreditation status.' on every permit upload.
create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  -- No JWT means service_role, the SQL console or a migration.
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
      if new.status <> 'pending' then
        raise exception 'A new accommodation must start as pending.';
      end if;
    elsif new.status is distinct from old.status then
      -- tg_permit_needs_review puts a listing back in the queue on the
      -- manager's behalf when they upload a permit; that one transition is
      -- allowed through, from any state a new permit can rescue.
      if not (coalesce(current_setting('app.permit_review', true), 'false') = 'true'
              and new.status = 'pending'
              and old.status in ('accredited', 'expired', 'needs_revision', 'rejected')) then
        raise exception 'Only OSAS may change accreditation status.';
      end if;
    end if;
  end if;

  if tg_table_name = 'verification_documents' then
    -- 'approved' is the only doc status that grants anything, so guard just that
    -- and leave the owner's own resubmission (back to 'pending') working.
    if new.status = 'approved' then
      raise exception 'Only OSAS may approve a document.';
    end if;
  end if;

  return new;
end $fn$;
