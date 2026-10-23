-- Bring OSAS "Policies & Guidelines" back (dropped in
-- 20261008020000_drop_osas_policies). OSAS publishes policy documents that
-- students and landlords/landladies accept per revision; superseded text is kept
-- in policy_versions, and publishing (or a new revision) sends a 'policy'
-- notification. Recreated as it stood before the drop: baseline +
-- 20260928130000_policy_versions_acceptance + the per-area access of
-- 20261006000000_admin_access. Rows from before the drop are gone.
--
-- The Terms of Service and Privacy Notice are still not part of this: they ship
-- in the app bundle (src/constants/legal.ts).

-- Tables ----------------------------------------------------------------------
create table if not exists public.policies (
  id uuid primary key default gen_random_uuid(),
  title character varying not null,
  body text not null,
  effective_date date not null,
  version character varying,
  created_by uuid not null references public.users(id) on delete cascade,
  archived boolean not null default false,
  revision integer not null default 1,
  updated_at timestamptz not null default now()
);
create index if not exists idx_policies_created_by on public.policies (created_by);

create table if not exists public.policy_versions (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.policies(id) on delete cascade,
  revision integer not null,
  version character varying,
  title character varying not null,
  body text not null,
  effective_date date not null,
  created_by uuid,
  superseded_at timestamptz not null default now(),
  unique (policy_id, revision)
);

create table if not exists public.policy_acceptances (
  policy_id uuid not null references public.policies(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  revision integer not null,
  accepted_at timestamptz not null default now(),
  primary key (policy_id, user_id)
);
create index if not exists idx_policy_acceptances_user_id on public.policy_acceptances (user_id);

-- Access ----------------------------------------------------------------------
alter table public.policies enable row level security;
alter table public.policy_versions enable row level security;
alter table public.policy_acceptances enable row level security;

create policy policies_select_admin on public.policies for select to authenticated
  using ((select public.can_view('announcements')));
create policy policies_insert_admin on public.policies for insert to authenticated
  with check ((select public.can_edit('announcements')));
create policy policies_update_admin on public.policies for update to authenticated
  using ((select public.can_edit('announcements'))) with check ((select public.can_edit('announcements')));
create policy policies_delete_admin on public.policies for delete to authenticated
  using ((select public.can_edit('announcements')));
-- Students and landlords/landladies read live documents only.
create policy policies_select_authenticated on public.policies for select to authenticated
  using (not archived and effective_date <= now()
         and (select public.get_my_role()) = any (array['student', 'landlord']));

create policy policy_versions_select_admin on public.policy_versions for select to authenticated
  using ((select public.can_view('announcements')));

-- No insert/update/delete policies on purpose: accept_policy() is the only writer.
create policy policy_acceptances_select_own on public.policy_acceptances for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_view('announcements')));

revoke all on table public.policies, public.policy_versions, public.policy_acceptances from public, anon;
grant select, insert, update, delete on table public.policies to authenticated;
grant select on table public.policy_versions, public.policy_acceptances to authenticated;
grant all on table public.policies, public.policy_versions, public.policy_acceptances to service_role;

-- Versions --------------------------------------------------------------------
-- OSAS bumps `revision` when a change is a new version everyone must accept
-- again; the previous text is kept. A save that leaves `revision` alone is a
-- silent correction and keeps no history.
create or replace function public.snapshot_policy_version() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  new.updated_at := now();
  if new.revision > old.revision then
    insert into public.policy_versions (policy_id, revision, version, title, body, effective_date, created_by)
    values (old.id, old.revision, old.version, old.title, old.body, old.effective_date, old.created_by)
    on conflict (policy_id, revision) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists trg_policy_version on public.policies;
create trigger trg_policy_version before update on public.policies
  for each row execute function public.snapshot_policy_version();

-- Acceptance ------------------------------------------------------------------
create or replace function public.accept_policy(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_rev integer;
begin
  if coalesce(public.get_my_role(), '') not in ('student', 'landlord') then
    raise exception 'only students and landlords accept policies';
  end if;
  select revision into v_rev from public.policies
   where id = p_id and not archived and effective_date <= now();
  if v_rev is null then
    raise exception 'policy is not in effect';
  end if;
  insert into public.policy_acceptances (policy_id, user_id, revision)
  values (p_id, auth.uid(), v_rev)
  on conflict (policy_id, user_id)
  do update set revision = excluded.revision, accepted_at = now();
end $$;

-- Notifications ---------------------------------------------------------------
create or replace function public.notify_policy() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare v_revised boolean := tg_op = 'UPDATE' and new.revision > old.revision;
begin
  if new.archived or new.effective_date > now() then return new; end if;
  -- Already live before this update: only a new revision is news.
  if tg_op = 'UPDATE' and not (old.archived or old.effective_date > now()) and not v_revised then
    return new;
  end if;

  insert into public.notifications (user_id, title, body, type, link_url, ref_id, source)
  select
    u.id,
    new.title,
    case when v_revised then 'Updated' || coalesce(' to ' || new.version, '') || '. '
         else coalesce(new.version || ' · ', '') end
      || 'In effect from ' || to_char(new.effective_date AT TIME ZONE 'Asia/Manila', 'Mon DD, YYYY')
      || '. Open Policies & guidelines to read and accept it.',
    'policy',
    null,
    new.id,
    'System Admin'
  from public.users u
  where u.status <> 'suspended'
    and u.role in ('student', 'landlord');

  return new;
end $$;

drop trigger if exists trg_notify_policy on public.policies;
create trigger trg_notify_policy after insert or update of effective_date, archived, revision
  on public.policies for each row execute function public.notify_policy();

drop trigger if exists trg_audit_policies on public.policies;
create trigger trg_audit_policies after insert or delete or update on public.policies
  for each row execute function public.fn_audit_log_change();

-- Admin read-outs -------------------------------------------------------------
create or replace function public.policy_acceptance_stats()
returns table(policy_id uuid, accepted integer, eligible integer)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.can_view('announcements') then raise exception 'admins only'; end if;
  return query
    with elig as (
      select id from public.users where status <> 'suspended' and role in ('student', 'landlord')
    )
    select p.id,
           (select count(*) from public.policy_acceptances a
             where a.policy_id = p.id and a.revision = p.revision
               and a.user_id in (select id from elig))::int,
           (select count(*) from elig)::int
      from public.policies p;
end $$;

create or replace function public.policy_pending_users(p_id uuid)
returns table(id uuid, full_name text, email text, role text)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.can_view('announcements') then raise exception 'admins only'; end if;
  return query
    select u.id, u.full_name::text, u.email::text, u.role::text
      from public.users u
      join public.policies p on p.id = p_id
     where u.status <> 'suspended' and u.role in ('student', 'landlord')
       and not exists (select 1 from public.policy_acceptances a
                        where a.policy_id = p.id and a.user_id = u.id and a.revision = p.revision)
     order by u.full_name;
end $$;

revoke all on function public.accept_policy(uuid) from public, anon;
revoke all on function public.policy_acceptance_stats() from public, anon;
revoke all on function public.policy_pending_users(uuid) from public, anon;
revoke all on function public.snapshot_policy_version() from public, anon, authenticated;
revoke all on function public.notify_policy() from public, anon, authenticated;
grant execute on function public.accept_policy(uuid), public.policy_acceptance_stats(),
                          public.policy_pending_users(uuid)
   to authenticated;
