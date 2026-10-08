-- Unverified students may apply; only a verified one may move in.
--
-- student_may_lease() gated every step of an application — the landlord/landlady
-- sending the form (invite_application), the student submitting it (the lease
-- insert policy), the walk-in add, and the acceptance. So OSAS had to verify
-- every student who signed up before they could so much as ask about a room,
-- and the queue held everyone who was only browsing, ahead of the few with a
-- landlord/landlady waiting on them.
--
-- Now the first three ask student_may_apply(): a student OSAS has not turned
-- down, suspended or paused. Acceptance (guard_lease_writes, pending → active)
-- still asks student_may_lease(), so nobody becomes a tenant unverified — the
-- check moved to the step it protects. The landlord/landlady already sees "Not
-- OSAS verified" on the application, and accommo-web puts students with a
-- pending application first in the verification queue.

create or replace function public.student_may_apply(p_student uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.users u
     where u.id = p_student
       and u.role::text = 'student'
       and u.status::text not in ('rejected', 'suspended')
       and not exists (
         select 1 from public.account_standing s
          where s.user_id = u.id and 'apply' = any(s.restrictions)
       )
  );
$$;

revoke execute on function public.student_may_apply(uuid) from anon, public;
grant execute on function public.student_may_apply(uuid) to authenticated;

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

select pg_temp.patch_fn('public.invite_application',
  $p$  if not public.student_may_lease(v_student) then
    raise exception 'OSAS has not verified this student yet, so they cannot be offered a room.';$p$,
  $p$  if not public.student_may_apply(v_student) then
    raise exception 'OSAS has turned down, suspended or paused this student, so they cannot be offered a room.';$p$);

select pg_temp.patch_fn('public.add_student_to_room',
  $p$  if not public.student_may_lease(v_student) then
    raise exception 'OSAS has not verified this student yet, so they cannot be added to a room.';$p$,
  $p$  if not public.student_may_apply(v_student) then
    raise exception 'OSAS has turned down, suspended or paused this student, so they cannot be added to a room.';$p$);

drop policy if exists "leases_insert_student_application" on public.leases;
create policy "leases_insert_student_application" on public.leases for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and status = 'pending'::public.lease_status
    and exists (select 1 from public.rooms r join public.accommodations a on a.id = r.accommodation_id
                 where r.id = leases.room_id and a.landlord_id = leases.landlord_id)
    and public.student_may_apply(student_id)
    and exists (select 1 from public.conversations c
                 where c.invited_room_id = leases.room_id
                   and ((c.user_a_id = leases.student_id and c.user_b_id = leases.landlord_id)
                     or (c.user_b_id = leases.student_id and c.user_a_id = leases.landlord_id)))
  );
