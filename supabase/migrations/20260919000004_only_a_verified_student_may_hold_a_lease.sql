-- One answer to "may this person be given a room", asked on every path there.
--
-- The rule was only ever enforced on the path the student walks.
-- leases_insert_student_application checks that the applicant has
-- student_profiles.osas_verified_at set; leases_insert_manager, written at a
-- different time, checks only that the manager owns the room. So a manager could
-- hand a lease to anyone at all -- a student OSAS has not verified, one still
-- pending, one it rejected, or somebody with no student_profiles row whatsoever.
-- Ten active leases in this database belong to students whose accounts are still
-- `pending`, and four of those students have no profile row at all; those rows
-- predate the policies, but nothing stopped new ones joining them.
--
-- leases_update_manager was the same gap by another door: it constrains only
-- accommodation_manager_id, so a manager could take a lease that passed the
-- check and repoint student_id at somebody who would not have.
--
-- Rather than copy the predicate to each policy and let the copies drift the way
-- these two already did, it becomes a function all of them call.
--
-- It asks for users.status = 'verified' as well as the osas_verified_at stamp.
-- The two agree today (91 verified students, all stamped; 46 pending, none), and
-- they are meant to be set together by accommo-web's approval flow -- but the
-- stamp is a cached copy of a decision and the status is the decision, and the
-- revocation fix below exists precisely because the copy could go stale.
-- Requiring both means a stale stamp grants nothing.

begin;

create or replace function public.student_may_lease(p_student uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $fn$
  select exists (
    select 1
      from public.users u
      join public.student_profiles sp on sp.user_id = u.id
     where u.id = p_student
       and u.role::text = 'student'
       and u.status::text = 'verified'
       and sp.osas_verified_at is not null
  );
$fn$;

-- New functions are granted to PUBLIC by default, which is how 20260916000006
-- quietly reopened get_verification_queue(). Be explicit. `anon` is deliberately
-- left out: this is only ever evaluated by INSERT policies on leases, and an
-- anonymous session has no business reaching those.
revoke all on function public.student_may_lease(uuid) from public, anon;
grant execute on function public.student_may_lease(uuid) to authenticated, service_role;

-- The gap this migration exists for.
alter policy leases_insert_manager on public.leases
  with check (
    accommodation_manager_id = (select auth.uid())
    and exists (
      select 1 from public.rooms r
        join public.accommodations a on a.id = r.accommodation_id
       where r.id = leases.room_id
         and a.accommodation_manager_id = (select auth.uid())
    )
    and public.student_may_lease(leases.student_id)
  );

-- Same rule, same words. The inline EXISTS this replaces checked the stamp only.
alter policy leases_insert_student_application on public.leases
  with check (
    student_id = (select auth.uid())
    and status = 'pending'::lease_status
    and exists (
      select 1 from public.rooms r
        join public.accommodations a on a.id = r.accommodation_id
       where r.id = leases.room_id
         and a.accommodation_manager_id = leases.accommodation_manager_id
    )
    and public.student_may_lease(leases.student_id)
    and exists (
      select 1 from public.conversations c
       where c.invited_room_id = leases.room_id
         and ((c.user_a_id = leases.student_id and c.user_b_id = leases.accommodation_manager_id)
           or (c.user_b_id = leases.student_id and c.user_a_id = leases.accommodation_manager_id))
    )
  );

-- The door that makes the whole thing LOOK open.
--
-- invite_application() is what puts the application form in front of a student.
-- It checks that the caller is the manager, that the room is theirs and still
-- available, and that the student has no current stay -- but never that OSAS has
-- verified them. So a manager could issue the form to an unverified student, who
-- would then fill it in and only be refused at the final submit, by an RLS error
-- rather than by anything that explains itself. Refusing to issue the form is
-- both the honest place to say no and the reason this looked like unverified
-- students could apply: for every step but the last one, they could.
create or replace function public.invite_application(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_me uuid := auth.uid();
  v_room uuid;
  v_student uuid;
begin
  if v_me is null then
    raise exception 'Not signed in';
  end if;

  select c.inquiry_room_id,
         case when c.user_a_id = v_me then c.user_b_id else c.user_a_id end
    into v_room, v_student
  from public.conversations c
  where c.id = p_conversation
    and (c.user_a_id = v_me or c.user_b_id = v_me);

  if not found then
    raise exception 'Conversation not found';
  end if;

  if (select u.role::text from public.users u where u.id = v_me) <> 'accommodation_manager' then
    raise exception 'Only the accommodation manager can send an application form';
  end if;

  if v_room is null then
    raise exception 'This student has not asked about a room yet';
  end if;

  if not exists (
    select 1
    from public.rooms r
    join public.accommodations a on a.id = r.accommodation_id
    where r.id = v_room
      and a.accommodation_manager_id = v_me
      and r.status = 'available'
  ) then
    raise exception 'That room is not yours, or is no longer available';
  end if;

  if not public.student_may_lease(v_student) then
    raise exception 'OSAS has not verified this student yet, so they cannot be offered a room.';
  end if;

  if exists (
    select 1 from public.leases l
    where l.student_id = v_student
      and l.status in ('pending', 'active', 'leave_requested')
  ) then
    raise exception 'This student already has a current application or stay';
  end if;

  update public.conversations
     set invited_room_id = v_room,
         invited_at = now()
   where id = p_conversation;
end $fn$;

-- The update door. Deliberately NOT done by adding student_may_lease() to
-- leases_update_manager's WITH CHECK: a manager must still be able to end the
-- lease of a tenant OSAS has just suspended, and a policy cannot see OLD, so it
-- could not tell "reassigning this lease" from "closing it". Forbidding the
-- reassignment outright is both narrower and truer -- a lease belongs to one
-- person for its whole life, and moving tenants means ending one and starting
-- another.
create or replace function public.tg_lease_guard_student_update()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $fn$
begin
  if new.student_id is distinct from old.student_id
     and not public.is_admin(auth.uid()) then
    raise exception 'a lease cannot be reassigned to a different student';
  end if;

  if auth.uid() = old.student_id and auth.uid() <> old.accommodation_manager_id then
    if new.room_id                   is distinct from old.room_id
    or new.student_id                is distinct from old.student_id
    or new.accommodation_manager_id  is distinct from old.accommodation_manager_id
    or new.monthly_rent              is distinct from old.monthly_rent
    or new.start_date                is distinct from old.start_date
    or new.end_date                  is distinct from old.end_date
    or new.deposit_paid              is distinct from old.deposit_paid
    or new.advance_paid              is distinct from old.advance_paid then
      raise exception 'a student may only request leave on their own lease';
    end if;
  end if;
  return new;
end $fn$;

-- Revocation missed a route. It cleared osas_verified_at only when the status
-- moved straight from 'verified', so the ordinary OSAS path of sending an
-- account back for changes first -- verified -> reviewing -> rejected -- left the
-- stamp in place, and with it the right to apply for a room. The end state is
-- what matters, not which way it was reached, so drop the old.status condition.
create or replace function public.tg_revoke_on_unverify()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'auth'
as $fn$
declare
  became_registered boolean := old.registered_at is null and new.registered_at is not null;
  -- Only 'pending' is a closed door; a manager OSAS has replied to must be able
  -- to sign in and fix what was asked for.
  awaiting_review boolean := new.role = 'accommodation_manager' and new.status = 'pending';
begin
  if new.status in ('rejected','suspended') and new.status is distinct from old.status then
    update public.student_profiles set osas_verified_at = null where user_id = new.id;
    update public.accommodations set status = 'delisted'
      where accommodation_manager_id = new.id and status = 'accredited';
  end if;

  -- Suspension: always bans, any role.
  if new.status = 'suspended' and old.status is distinct from 'suspended' then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- A manager finishing registration, or sent back to pending, waits outside.
  if awaiting_review and (became_registered or new.status is distinct from old.status)
     and new.registered_at is not null then
    update auth.users set banned_until = now() + interval '100 years' where id = new.id;
    delete from auth.sessions where user_id = new.id;
    delete from auth.refresh_tokens where user_id = new.id::text;
    return new;
  end if;

  -- OSAS approving, or asking for changes, reopens sign-in. Suspension is the
  -- exception and is handled above.
  if new.status in ('verified','rejected','reviewing')
     and new.status is distinct from old.status then
    update auth.users set banned_until = null where id = new.id;
  end if;

  return new;
end $fn$;

commit;
