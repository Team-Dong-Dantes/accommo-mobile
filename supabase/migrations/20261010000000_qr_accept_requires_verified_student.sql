-- Accepting a walk-in student with their QR asks OSAS's verification itself.
--
-- 20261009020000 let a landlord/landlady add a student OSAS has not verified,
-- leaving guard_lease_writes (pending → active asks student_may_lease) as the
-- one check between that student and moving in. accept_added_student never
-- reached it: it is security definer, so the update it makes runs as the
-- function's owner, and guard_lease_writes returns early for anyone who is not
-- `authenticated`. Before 20261009020000 that did not matter — an unverified
-- student could not be added in the first place — but since then the QR scan
-- made them a tenant (RLS guard L3).
--
-- So the function asks the same question the trigger would have, after the QR
-- has proven the student is standing there and before the stay starts.

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

select pg_temp.patch_fn('public.accept_added_student',
  $p$  perform set_config('app.qr_accept', 'true', true);$p$,
  $p$  if not public.student_may_lease(v_student) then
    raise exception 'OSAS has not verified this student yet, so they cannot move in. They stay added until OSAS does.' using errcode = '42501';
  end if;

  perform set_config('app.qr_accept', 'true', true);$p$);
