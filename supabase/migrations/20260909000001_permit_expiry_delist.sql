-- #10 (remainder): a permit that simply lapses used to change nothing.
-- expires_at was read only by three mobile manager screens, so an accreditation
-- once granted never expired. A renewal already reopens review via
-- trg_permit_needs_review; this covers the permit nobody replaces.
create extension if not exists pg_cron;

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
  set status = 'reviewing'
  where a.status = 'accredited'
    and a.id in (select accommodation_id from lapsed);
  get diagnostics n = row_count;

  if n > 0 then
    perform public.notify_admins(
      'Accreditation needs review',
      n || ' accommodation(s) have a permit that has expired and were sent back for review.',
      'verification', '/verifications');
  end if;
end $$;

revoke all on function public.sweep_expired_permits() from public, anon, authenticated;

-- Daily at 18:00 UTC (02:00 Manila).
select cron.unschedule('sweep-expired-permits')
where exists (select 1 from cron.job where jobname = 'sweep-expired-permits');

select cron.schedule('sweep-expired-permits', '0 18 * * *',
                     $$select public.sweep_expired_permits();$$);
