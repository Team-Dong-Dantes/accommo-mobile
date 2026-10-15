-- Supabase Advisors cleanup (performance + the safe security items).
--
-- 1. auth_rls_initplan: `auth.uid()` / `auth.jwt()` / `auth.role()` called bare
--    in a policy is re-evaluated per row; wrapped in `(select ...)` it is
--    evaluated once per statement. Rewritten in place from the live policy text
--    (ALTER POLICY, same roles and commands), so the logic cannot drift from
--    what is deployed. Already-wrapped calls are left alone.
-- 2. unindexed_foreign_keys: indexes for the eight FKs the advisor lists.
-- 3. anon/authenticated_security_definer_function_executable, only for the four
--    trigger functions: a trigger fires regardless of EXECUTE, so nobody needs
--    the grant. check_session stays executable by anon: it is PostgREST's
--    db_pre_request hook. The other RPCs are called by the apps on purpose.
--
-- Deliberately NOT touched (advisor items that are by design or need a decision):
--   users_full security_definer view  - masks date_of_birth per viewer; invoker
--                                       mode would hit users RLS and break it.
--   rls_enabled_no_policy (4 tables)  - only security-definer functions use them.
--   multiple_permissive_policies      - merging policies changes semantics.
--   unused_index                      - dashboard stats; confirm before dropping.
--   auth_leaked_password_protection   - dashboard setting (Auth > Passwords).

do $$
declare
  r record;
  v_using text;
  v_check text;
  v_sql text;
  v_re constant text := '(?<!select )auth\.(uid|jwt|role)\(\)';
begin
  for r in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') ~* v_re or coalesce(with_check, '') ~* v_re)
  loop
    v_sql := format('alter policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
    if r.qual is not null then
      v_using := regexp_replace(r.qual, v_re, '(select auth.\1())', 'gi');
      v_sql := v_sql || format(' using (%s)', v_using);
    end if;
    if r.with_check is not null then
      v_check := regexp_replace(r.with_check, v_re, '(select auth.\1())', 'gi');
      v_sql := v_sql || format(' with check (%s)', v_check);
    end if;
    execute v_sql;
  end loop;
end $$;

create index if not exists accommodations_reviewing_by_idx          on public.accommodations (reviewing_by);
create index if not exists account_notes_author_id_idx              on public.account_notes (author_id);
create index if not exists account_standing_updated_by_idx          on public.account_standing (updated_by);
create index if not exists accreditation_rounds_decided_by_idx      on public.accreditation_rounds (decided_by);
create index if not exists accreditation_rounds_submitted_by_idx    on public.accreditation_rounds (submitted_by);
create index if not exists admin_access_granted_by_idx              on public.admin_access (granted_by);
create index if not exists report_settings_updated_by_idx           on public.report_settings (updated_by);
create index if not exists users_reviewing_by_idx                   on public.users (reviewing_by);

revoke execute on function public.enforce_rate_limit()        from public, anon, authenticated;
revoke execute on function public.guard_admin_user_edit()     from public, anon, authenticated;
revoke execute on function public.guard_hidden_from_listings() from public, anon, authenticated;
revoke execute on function public.tg_payment_rules()          from public, anon, authenticated;
