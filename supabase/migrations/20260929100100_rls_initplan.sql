-- Evaluate the admin/role checks once per query instead of once per row.
--
-- 51 policies called `is_admin(auth.uid())` or `get_my_role()` bare. Postgres
-- re-runs a bare function call for every row it checks; wrapped in a scalar
-- subquery it becomes an InitPlan, evaluated once per statement. All three
-- functions are STABLE and depend only on the session, so the results are the
-- same — this is Supabase's documented RLS performance fix. Measured on the
-- admin dashboard's queries: ~316 ms → ~61 ms of database time.
--
-- Rewritten in place from pg_policies, so every policy that matches — now or
-- from the baseline on a fresh database — gets the same treatment.

do $$
declare
  p record;
  q text;
  c text;
begin
  for p in
    select * from pg_policies
     where schemaname = 'public'
       and coalesce(qual, '') || coalesce(with_check, '') ~ 'is_admin\(auth\.uid\(\)\)|(?<!SELECT )get_my_role\(\)'
  loop
    q := regexp_replace(regexp_replace(p.qual,
           'is_admin\(auth\.uid\(\)\)', '(SELECT is_admin((SELECT auth.uid())))', 'g'),
           '(?<!SELECT )get_my_role\(\)', '(SELECT get_my_role())', 'g');
    c := regexp_replace(regexp_replace(p.with_check,
           'is_admin\(auth\.uid\(\)\)', '(SELECT is_admin((SELECT auth.uid())))', 'g'),
           '(?<!SELECT )get_my_role\(\)', '(SELECT get_my_role())', 'g');
    execute format('alter policy %I on public.%I', p.policyname, p.tablename)
      || case when q is not null then format(' using (%s)', q) else '' end
      || case when c is not null then format(' with check (%s)', c) else '' end;
  end loop;
end $$;

-- is_verified_landlord / student_may_lease answered "is this user verified?"
-- for any id, to anyone. Only insert policies for signed-in users need them.
revoke execute on function public.is_verified_landlord(uuid) from anon, public;
revoke execute on function public.student_may_lease(uuid) from anon, public;
grant execute on function public.is_verified_landlord(uuid) to authenticated;
grant execute on function public.student_may_lease(uuid) to authenticated;
