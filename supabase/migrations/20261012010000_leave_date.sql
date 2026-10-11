-- A leave request carries the day the student moves out (leases.leave_date).
--
-- Approving it no longer ends the stay on the spot: the stay runs to that day
-- (end_date := leave_date) and a nightly job closes it then. A date today or
-- earlier still ends it at once, as before. The landlord/landlady approves or
-- declines; they don't move the date — a decline (with its reason) lets the
-- student ask again.
--
-- While waiting:  status 'leave_requested', leave_date set.
-- Approved:       status 'active', leave_date set, end_date = leave_date.
-- Declined:       status 'active', leave_date null.

alter table public.leases add column if not exists leave_date date;

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

-- The date is checked where every write passes. An older build that sends no
-- date asks to leave today, which is what it meant.
select pg_temp.patch_fn('public.guard_lease_writes',
  $p$  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;$p$,
  $p$  if tg_op = 'UPDATE' and new.status = 'leave_requested' and old.status is distinct from 'leave_requested' then
    new.leave_date := coalesce(new.leave_date, v_today);
    if new.leave_date < v_today then
      raise exception 'The move-out date can''t be in the past.';
    end if;
    if old.end_date is not null and new.leave_date > old.end_date then
      raise exception 'The move-out date is after your stay ends (%).', to_char(old.end_date, 'Mon FMDD, YYYY');
    end if;
  end if;

  if current_user <> 'authenticated' or public.is_admin(auth.uid()) then return new; end if;$p$);

-- Approve: end today if the day has come, otherwise run the stay to that day.
create or replace function public.approve_leave(p_lease uuid)
returns date
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  l public.leases;
  v_today date := (now() at time zone 'Asia/Manila')::date;
begin
  select * into l from public.leases where id = p_lease;
  if l.id is null or auth.uid() is distinct from l.landlord_id then
    raise exception 'Only the landlord/landlady of this stay can approve leaving.' using errcode = '42501';
  end if;
  if l.status::text <> 'leave_requested' then
    raise exception 'There is no leave request to approve.';
  end if;
  if coalesce(l.leave_date, v_today) <= v_today then
    update public.leases set status = 'ended', ended_reason = 'leave_approved' where id = p_lease;
    return v_today;
  end if;
  update public.leases set status = 'active', end_date = l.leave_date where id = p_lease;
  return l.leave_date;
end $$;
revoke all on function public.approve_leave(uuid) from public, anon;
grant execute on function public.approve_leave(uuid) to authenticated;

-- The notices: the request names its date, an approval for later says when,
-- and the stay closing on that day says it happened as planned.
select pg_temp.patch_fn('public.tg_lease_notify',
  $p$      'A tenant requested to leave '
        || coalesce((select a.name from public.rooms r join public.accommodations a on a.id = r.accommodation_id
                      where r.id = new.room_id), 'their room') || '.',$p$,
  $p$      coalesce((select nullif(btrim(full_name), '') from public.users where id = new.student_id), 'A tenant')
        || ' wants to move out of '
        || coalesce((select a.name from public.rooms r join public.accommodations a on a.id = r.accommodation_id
                      where r.id = new.room_id), 'their room')
        || coalesce(' on ' || to_char(new.leave_date, 'Mon FMDD'), '') || '.',$p$);

select pg_temp.patch_fn('public.tg_lease_notify',
  $p$  elsif old.status = 'leave_requested' and new.status = 'active' then$p$,
  $p$  elsif old.status = 'leave_requested' and new.status = 'active' and new.leave_date is not null then
    perform public.notify_peer(new.student_id, 'lease', 'Leave request approved',
      'Your move-out from ' || v_room || ' on ' || to_char(new.leave_date, 'Mon FMDD') || ' was approved. Rent is owed until then.',
      '/student/stay', new.landlord_id);
  elsif old.status = 'active' and new.status = 'ended' and new.ended_reason = 'leave_approved' then
    perform public.notify_peer(new.student_id, 'lease', 'Your stay has ended',
      'Your stay at ' || v_room || ' ended today, as planned. You can now rate your stay.',
      '/student/profile/history', new.landlord_id);
  elsif old.status = 'leave_requested' and new.status = 'active' then$p$);

-- Nightly, just after midnight in Manila: approved stays whose day has come.
create or replace function public.end_approved_leaves() returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.leases
     set status = 'ended', ended_reason = 'leave_approved'
   where status = 'active' and leave_date is not null
     and leave_date <= (now() at time zone 'Asia/Manila')::date;
end $$;
revoke all on function public.end_approved_leaves() from public, anon, authenticated;

select cron.unschedule('end-approved-leaves') where exists (select 1 from cron.job where jobname = 'end-approved-leaves');
select cron.schedule('end-approved-leaves', '5 16 * * *', 'select public.end_approved_leaves()');
