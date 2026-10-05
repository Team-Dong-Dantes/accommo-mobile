-- Role-based access for invited admins.
--
-- Until now every admin could do everything but manage other admins. The
-- system admin (users.is_superadmin) now gives each invited admin a level per
-- area — none, view or edit — optionally until a date:
--
--   accounts        Users page: suspend/restrict, profiles, notes, sign-in actions
--   verification    approve/reject students and landlords/landladies
--   accreditation   accreditation decisions and permits
--   accommodations  Accommodation Hub, Room Hub, Map: hide/suspend/restore
--   support         support tickets (and the landlord-tenant concerns behind them)
--   announcements   announcements and policies
--   reports         view = export, edit = report settings
--   activity        record activity tabs: view = changes, edit = changes + device
--
-- Audit Logs and Administrators stay system-admin only and are not grantable.
-- Shared lookup data (users, accommodations, rooms, leases, payments, reviews,
-- profiles) stays readable by every active admin: every drawer reads it.
--
-- Expired access locks the admin out: is_admin() turns false and check_session
-- refuses every request until the system admin extends it. Existing invited
-- admins start as Full admin, so nothing changes for them on the day.

-- 1 Table -----------------------------------------------------------------------

create or replace function public.admin_levels_valid(p jsonb)
returns boolean
language sql
immutable
as $$
  select jsonb_typeof(p) = 'object'
     and not exists (
       select 1 from jsonb_each_text(p) e
        where e.key not in ('accounts', 'verification', 'accreditation', 'accommodations',
                            'support', 'announcements', 'reports', 'activity')
           or e.value not in ('none', 'view', 'edit'));
$$;

create table if not exists public.admin_access (
  user_id     uuid primary key references public.users(id) on delete cascade,
  preset      text not null default 'custom',
  levels      jsonb not null default '{}' check (public.admin_levels_valid(levels)),
  expires_at  timestamptz,
  granted_by  uuid references public.users(id) on delete set null,
  updated_at  timestamptz not null default now()
);

alter table public.admin_access enable row level security;
revoke all on public.admin_access from public, anon, authenticated;
grant select, insert, update, delete on public.admin_access to authenticated;

-- Your own row, so the console knows what to show; the system admin sees all.
create policy admin_access_select on public.admin_access for select to authenticated
  using (user_id = (select auth.uid()) or (select public.current_is_superadmin()));
-- Only the system admin grants access, and never to themselves.
create policy admin_access_write on public.admin_access for all to authenticated
  using ((select public.current_is_superadmin()) and user_id <> (select auth.uid()))
  with check ((select public.current_is_superadmin()) and user_id <> (select auth.uid()));

create trigger trg_audit_admin_access after insert or delete or update on public.admin_access
  for each row execute function public.fn_audit_log_change();

-- Everyone who is an admin today keeps what they had (minus Audit Logs).
insert into public.admin_access (user_id, preset, levels)
select u.id, 'full', jsonb_build_object(
         'accounts', 'edit', 'verification', 'edit', 'accreditation', 'edit', 'accommodations', 'edit',
         'support', 'edit', 'announcements', 'edit', 'reports', 'edit', 'activity', 'edit')
  from public.users u
 where u.role = 'admin' and not u.is_superadmin
on conflict (user_id) do nothing;

-- 2 Checks ----------------------------------------------------------------------

create or replace function public.admin_expired(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
set row_security to 'off'
as $$
  select exists (
    select 1 from public.admin_access a
      join public.users u on u.id = a.user_id
     where a.user_id = p_uid and a.expires_at is not null and a.expires_at <= now()
       and not u.is_superadmin);
$$;

-- An expired admin is no admin at all.
create or replace function public.is_admin(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
set row_security to 'off'
as $$
  select exists (
    select 1 from public.users
    where id = p_uid and (role = 'admin' or is_superadmin = true)
  ) and public.mfa_ok(p_uid) and not public.admin_expired(p_uid);
$$;

create or replace function public.admin_level(p_area text)
returns text
language sql
stable
security definer
set search_path to 'public'
set row_security to 'off'
as $$
  select case
    when not public.is_admin(auth.uid()) then 'none'
    when public.current_is_superadmin() then 'edit'
    else coalesce((select a.levels ->> p_area from public.admin_access a where a.user_id = auth.uid()), 'none')
  end;
$$;

create or replace function public.can_view(p_area text)
returns boolean language sql stable set search_path to 'public'
as $$ select public.admin_level(p_area) in ('view', 'edit') $$;

create or replace function public.can_edit(p_area text)
returns boolean language sql stable set search_path to 'public'
as $$ select public.admin_level(p_area) = 'edit' $$;

revoke all on function public.admin_expired(uuid), public.admin_level(text),
  public.can_view(text), public.can_edit(text) from public, anon;
grant execute on function public.admin_expired(uuid), public.admin_level(text),
  public.can_view(text), public.can_edit(text) to authenticated, service_role;

-- Expired admins are refused on every request, so an open console stops at once.
create or replace function public.check_session()
returns void
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  sid text := auth.jwt() ->> 'session_id';
begin
  if sid is not null and not exists (select 1 from auth.sessions s where s.id = sid::uuid) then
    raise sqlstate 'PT401' using message = 'Your session has ended. Sign in again.';
  end if;
  if auth.uid() is not null and public.admin_expired(auth.uid()) then
    raise sqlstate 'PT401' using message = 'Your admin access has expired. Ask the system admin to extend it.';
  end if;
end $$;

-- 3 Policies --------------------------------------------------------------------

-- Permits
drop policy accommodation_documents_select_admin on public.accommodation_documents;
create policy accommodation_documents_select_admin on public.accommodation_documents for select to authenticated
  using ((select public.can_view('accreditation')) or (select public.can_view('accommodations')));
drop policy accommodation_documents_update_admin on public.accommodation_documents;
create policy accommodation_documents_update_admin on public.accommodation_documents for update to authenticated
  using ((select public.can_edit('accreditation')));
drop policy accommodation_documents_delete_admin on public.accommodation_documents;
create policy accommodation_documents_delete_admin on public.accommodation_documents for delete to authenticated
  using ((select public.can_edit('accreditation')));
drop policy accommodation_documents_delete_unaccredited on public.accommodation_documents;
create policy accommodation_documents_delete_unaccredited on public.accommodation_documents for delete to authenticated
  using ((not exists (select 1 from public.accommodations a
                       where a.id = accommodation_documents.accommodation_id
                         and a.status = any (array['accredited'::accommodation_status, 'delisted'::accommodation_status])))
         or (select public.can_edit('accreditation')));
drop policy accommodation_documents_update_unaccredited on public.accommodation_documents;
create policy accommodation_documents_update_unaccredited on public.accommodation_documents for update to authenticated
  using ((not exists (select 1 from public.accommodations a
                       where a.id = accommodation_documents.accommodation_id
                         and a.status = any (array['accredited'::accommodation_status, 'delisted'::accommodation_status])))
         or (select public.can_edit('accreditation')));
drop policy accommodation_documents_insert_open on public.accommodation_documents;
create policy accommodation_documents_insert_open on public.accommodation_documents for insert to authenticated
  with check (public.permit_replacement_open(accommodation_id, doc_type) or (select public.can_edit('accreditation')));

drop policy accreditation_rounds_select_admin on public.accreditation_rounds;
create policy accreditation_rounds_select_admin on public.accreditation_rounds for select to authenticated
  using ((select public.can_view('accreditation')));

-- Accommodations: a landlord/landlady's own inserts are unchanged; OSAS needs edit.
drop policy accommodation_facilities_insert_accredited on public.accommodation_facilities;
create policy accommodation_facilities_insert_accredited on public.accommodation_facilities for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.can_edit('accommodations')));
drop policy accommodation_facilities_insert_verified on public.accommodation_facilities;
create policy accommodation_facilities_insert_verified on public.accommodation_facilities for insert to authenticated
  with check (public.is_verified_landlord(auth.uid()) or (select public.can_edit('accommodations')));
drop policy accommodation_floors_insert_accredited on public.accommodation_floors;
create policy accommodation_floors_insert_accredited on public.accommodation_floors for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.can_edit('accommodations')));
drop policy rooms_insert_accredited on public.rooms;
create policy rooms_insert_accredited on public.rooms for insert to authenticated
  with check (public.is_accredited_accommodation(accommodation_id) or (select public.can_edit('accommodations')));
drop policy rooms_insert_verified on public.rooms;
create policy rooms_insert_verified on public.rooms for insert to authenticated
  with check (public.is_verified_landlord(auth.uid()) or (select public.can_edit('accommodations')));
drop policy accommodations_insert_verified on public.accommodations;
create policy accommodations_insert_verified on public.accommodations for insert to authenticated
  with check (public.is_verified_landlord(auth.uid()) or (select public.can_edit('accommodations')));
drop policy "Admins can update accommodation statuses" on public.accommodations;
create policy "Admins can update accommodation statuses" on public.accommodations for update to authenticated
  using ((select public.can_edit('accommodations')) or (select public.can_edit('accreditation')))
  with check ((select public.can_edit('accommodations')) or (select public.can_edit('accreditation')));

-- Accounts
drop policy account_notes_select_admin on public.account_notes;
create policy account_notes_select_admin on public.account_notes for select to authenticated
  using ((select public.can_view('accounts')));
drop policy account_notes_insert_admin on public.account_notes;
create policy account_notes_insert_admin on public.account_notes for insert to authenticated
  with check ((select public.can_edit('accounts')) and author_id = (select auth.uid()));
drop policy account_notes_delete_author on public.account_notes;
create policy account_notes_delete_author on public.account_notes for delete to authenticated
  using (author_id = (select auth.uid()) and (select public.can_edit('accounts')));
drop policy account_standing_select on public.account_standing;
create policy account_standing_select on public.account_standing for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_view('accounts')));

drop policy users_update_admin on public.users;
create policy users_update_admin on public.users for update to authenticated
  using ((select public.can_edit('accounts')) or (select public.can_edit('verification')))
  with check ((select public.can_edit('accounts')) or (select public.can_edit('verification')));

drop policy admin_all_student_profiles on public.student_profiles;
create policy admin_select_student_profiles on public.student_profiles for select to authenticated
  using ((select public.is_admin((select auth.uid()))));
create policy admin_write_student_profiles on public.student_profiles for all to authenticated
  using ((select public.can_edit('accounts')) or (select public.can_edit('verification')))
  with check ((select public.can_edit('accounts')) or (select public.can_edit('verification')));

-- Verification (people) and accreditation (accommodations) share one request table.
drop policy verification_requests_admin_all on public.verification_requests;
create policy verification_requests_admin_select on public.verification_requests for select to authenticated
  using (case when entity_type = 'user'
              then (select public.can_view('verification')) or (select public.can_view('accounts'))
              else (select public.can_view('accreditation')) end);
create policy verification_requests_admin_write on public.verification_requests for all to authenticated
  using (case when entity_type = 'user' then (select public.can_edit('verification'))
              else (select public.can_edit('accreditation')) end)
  with check (case when entity_type = 'user' then (select public.can_edit('verification'))
                   else (select public.can_edit('accreditation')) end);

drop policy admin_all_verification_documents on public.verification_documents;
create policy admin_select_verification_documents on public.verification_documents for select to authenticated
  using ((select public.can_view('verification')) or (select public.can_view('accounts')));
create policy admin_write_verification_documents on public.verification_documents for all to authenticated
  using ((select public.can_edit('verification')))
  with check ((select public.can_edit('verification')));

-- Announcements and policies
drop policy announcements_select_admin on public.announcements;
create policy announcements_select_admin on public.announcements for select to authenticated
  using ((select public.can_view('announcements')));
drop policy announcements_insert_admin on public.announcements;
create policy announcements_insert_admin on public.announcements for insert to authenticated
  with check ((select public.can_edit('announcements')));
drop policy announcements_update_admin on public.announcements;
create policy announcements_update_admin on public.announcements for update to authenticated
  using ((select public.can_edit('announcements'))) with check ((select public.can_edit('announcements')));
drop policy announcements_delete_admin on public.announcements;
create policy announcements_delete_admin on public.announcements for delete to authenticated
  using ((select public.can_edit('announcements')));
drop policy policies_select_admin on public.policies;
create policy policies_select_admin on public.policies for select to authenticated
  using ((select public.can_view('announcements')));
drop policy policies_insert_admin on public.policies;
create policy policies_insert_admin on public.policies for insert to authenticated
  with check ((select public.can_edit('announcements')));
drop policy policies_update_admin on public.policies;
create policy policies_update_admin on public.policies for update to authenticated
  using ((select public.can_edit('announcements'))) with check ((select public.can_edit('announcements')));
drop policy policies_delete_admin on public.policies;
create policy policies_delete_admin on public.policies for delete to authenticated
  using ((select public.can_edit('announcements')));
drop policy policy_versions_select_admin on public.policy_versions;
create policy policy_versions_select_admin on public.policy_versions for select to authenticated
  using ((select public.can_view('announcements')));
drop policy policy_acceptances_select_own on public.policy_acceptances;
create policy policy_acceptances_select_own on public.policy_acceptances for select to authenticated
  using (user_id = auth.uid() or (select public.can_view('announcements')));

-- Support
drop policy tickets_admin_all on public.tickets;
create policy tickets_admin_select on public.tickets for select to authenticated
  using ((select public.can_view('support')));
create policy tickets_admin_write on public.tickets for all to authenticated
  using ((select public.can_edit('support'))) with check ((select public.can_edit('support')));
drop policy ticket_messages_admin_all on public.ticket_messages;
create policy ticket_messages_admin_select on public.ticket_messages for select to authenticated
  using ((select public.can_view('support')));
create policy ticket_messages_admin_write on public.ticket_messages for all to authenticated
  using ((select public.can_edit('support'))) with check ((select public.can_edit('support')));

drop policy concerns_tenant_manager_read on public.concerns;
create policy concerns_tenant_manager_read on public.concerns for select to authenticated
  using (lease_id in (select leases.id from public.leases where leases.student_id = auth.uid())
         or lease_id in (select leases.id from public.leases where leases.landlord_id = auth.uid())
         or (select public.can_view('support')));
drop policy concerns_manager_update on public.concerns;
create policy concerns_manager_update on public.concerns for update to authenticated
  using (lease_id in (select leases.id from public.leases where leases.landlord_id = auth.uid())
         or (select public.can_edit('support')))
  with check (lease_id in (select leases.id from public.leases where leases.landlord_id = auth.uid())
              or (select public.can_edit('support')));
drop policy concerns_tenant_insert on public.concerns;
create policy concerns_tenant_insert on public.concerns for insert to authenticated
  with check (lease_id in (select leases.id from public.leases where leases.student_id = auth.uid())
              or (select public.can_edit('support')));

-- Reports
drop policy report_settings_admin_read on public.report_settings;
create policy report_settings_admin_read on public.report_settings for select to authenticated
  using ((select public.can_view('reports')));
drop policy report_settings_admin_update on public.report_settings;
create policy report_settings_admin_update on public.report_settings for update to authenticated
  using ((select public.can_edit('reports'))) with check ((select public.can_edit('reports')));

-- Audit Logs page: system admin only. Record activity goes through
-- record_activity() / audit_entry() below.
drop policy audit_logs_select_admin on public.audit_logs;
create policy audit_logs_select_admin on public.audit_logs for select to authenticated
  using ((select public.current_is_superadmin()));

-- tickets_reporter_insert lets OSAS open a ticket on someone's behalf.
do $$
declare
  q text;
begin
  select with_check into q from pg_policies
   where schemaname = 'public' and tablename = 'tickets' and policyname = 'tickets_reporter_insert';
  q := replace(q, '( SELECT is_admin(( SELECT auth.uid() AS uid)) AS is_admin)', '( SELECT can_edit(''support''::text) AS can_edit)');
  if q !~ 'can_edit' then raise exception 'tickets_reporter_insert: admin clause not found'; end if;
  execute 'alter policy tickets_reporter_insert on public.tickets with check (' || q || ')';
end $$;

-- 4 Functions -------------------------------------------------------------------

-- Replaces one fragment of a live function, failing loudly if it is not there.
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

-- Account actions (role change, Google, sign out everywhere, close) need Accounts edit.
select pg_temp.patch_fn('public.assert_admin_over',
  $p$if not public.is_admin(auth.uid()) then
    raise exception 'Only OSAS can do this.' using errcode = '42501';$p$,
  $p$if not public.can_edit('accounts') then
    raise exception 'Your admin access doesn''t include changing accounts.' using errcode = '42501';$p$);

select pg_temp.patch_fn('public.admin_sign_in_methods',
  $p$perform public.assert_admin_over(p_user);$p$,
  $p$if not public.can_view('accounts') then
    raise exception 'Your admin access doesn''t include accounts.' using errcode = '42501';
  end if;$p$);

-- A verification decision on an unverified account needs Verification edit;
-- anything else (suspend, restrict, reactivate) needs Accounts edit.
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$    raise exception 'Administrator accounts are managed under Settings.';
  end if;$p$,
  $p$    raise exception 'Administrator accounts are managed under Settings.';
  end if;
  if not (public.can_edit('accounts')
          or (public.can_edit('verification')
              and v_user.status in ('pending', 'reviewing')
              and p_status in ('pending', 'reviewing', 'verified', 'rejected')
              and p_until is null and p_restrictions is null)) then
    raise exception 'Your admin access doesn''t include this change.' using errcode = '42501';
  end if;$p$);

select pg_temp.patch_fn('public.decide_accreditation',
  $p$if not public.is_admin(v_uid) then$p$,
  $p$if not public.can_edit('accreditation') then$p$);

select pg_temp.patch_fn('public.get_verification_queue',
  $p$where public.is_admin(auth.uid())$p$,
  $p$where public.can_view('verification')$p$);

select pg_temp.patch_fn('public.announcement_reach_all',
  $p$if not public.is_admin(auth.uid()) then raise exception 'admins only'; end if;$p$,
  $p$if not public.can_view('announcements') then raise exception 'admins only'; end if;$p$);
select pg_temp.patch_fn('public.policy_acceptance_stats',
  $p$if not public.is_admin(auth.uid()) then raise exception 'admins only'; end if;$p$,
  $p$if not public.can_view('announcements') then raise exception 'admins only'; end if;$p$);
select pg_temp.patch_fn('public.policy_pending_users',
  $p$if not public.is_admin(auth.uid()) then raise exception 'admins only'; end if;$p$,
  $p$if not public.can_view('announcements') then raise exception 'admins only'; end if;$p$);

-- Hiding listings: Accommodations edit, or Accounts edit (the "hide listings"
-- restriction on a landlord/landlady's account flips it for all of theirs).
select pg_temp.patch_fn('public.guard_hidden_from_listings',
  $p$and not is_admin(auth.uid()) then$p$,
  $p$and not (public.can_edit('accommodations') or public.can_edit('accounts')) then$p$);

-- An admin with Verification edit but not Accounts edit may only move an
-- account through review — not rename it or change its contact details.
create or replace function public.guard_admin_user_edit()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null or new.id = auth.uid() or not public.is_admin(auth.uid())
     or public.can_edit('accounts') then
    return new;
  end if;
  if (to_jsonb(new) - array['status', 'reviewing_by', 'reviewing_at', 'updated_at'])
     is distinct from (to_jsonb(old) - array['status', 'reviewing_by', 'reviewing_at', 'updated_at']) then
    raise exception 'Your admin access only covers verification decisions.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_admin_user_edit on public.users;
create trigger trg_guard_admin_user_edit before update on public.users
  for each row execute function public.guard_admin_user_edit();

-- 5 Record activity -------------------------------------------------------------

-- Which audit entries an admin may see in a record's Activity tab: Activity
-- history access, plus view access to the record's own area.
create or replace function public.audit_visible(p_type text)
returns boolean
language sql
stable
set search_path to 'public'
as $$
  select public.current_is_superadmin() or (public.can_view('activity') and case
    when p_type in ('users', 'user', 'account_standing', 'student_profiles', 'landlord_profiles')
      then public.can_view('accounts')
    when p_type in ('accommodations', 'accommodation')
      then public.can_view('accommodations') or public.can_view('accreditation')
    when p_type = 'tickets' then public.can_view('support')
    else false end);
$$;

-- An entry shaped like the console's audit select; device only with Activity edit.
create or replace function public.audit_json(a public.audit_logs)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
  select jsonb_build_object(
    'id', a.id, 'action', a.action, 'created_at', a.created_at, 'actor_id', a.actor_id,
    'entity_id', a.entity_id, 'entity_type', a.entity_type,
    'ip_address', case when public.can_edit('activity') then a.ip_address end,
    'user_agent', case when public.can_edit('activity') then a.user_agent end,
    'before_json', a.before_json, 'after_json', a.after_json,
    'actor', (select jsonb_build_object('full_name', u.full_name, 'initials', u.initials,
                                        'role', u.role, 'avatar_color', u.avatar_color)
                from public.users u where u.id = a.actor_id));
$$;

create or replace function public.record_activity(p_types text[], p_entity text, p_limit int default 100)
returns setof jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.audit_json(a)
    from public.audit_logs a
   where a.entity_type = any (p_types) and a.entity_id = p_entity and public.audit_visible(a.entity_type)
   order by a.created_at desc
   limit least(greatest(p_limit, 1), 500);
$$;

create or replace function public.audit_entry(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.audit_json(a) from public.audit_logs a
   where a.id = p_id and public.audit_visible(a.entity_type);
$$;

revoke all on function public.audit_visible(text), public.audit_json(public.audit_logs),
  public.record_activity(text[], text, int), public.audit_entry(uuid) from public, anon;
grant execute on function public.record_activity(text[], text, int), public.audit_entry(uuid) to authenticated;
