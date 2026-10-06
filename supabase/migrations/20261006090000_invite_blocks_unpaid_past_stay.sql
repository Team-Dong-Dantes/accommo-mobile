-- A student who still owes on an ended stay can't be sent an application form
-- either — the earliest point in the flow, so nobody fills a form in only to be
-- refused at submit (guard_lease_writes, 20261006070000).

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
  $p$  if exists (
    select 1 from public.leases l
    where l.student_id = v_student$p$,
  $p$  if public.past_stay_balance(v_student) > 0.009 then
    raise exception 'This student still owes ₱% on a past stay, so they can''t be sent a form until it is settled.',
      to_char(public.past_stay_balance(v_student), 'FM999,999,990.00');
  end if;

  if exists (
    select 1 from public.leases l
    where l.student_id = v_student$p$);
