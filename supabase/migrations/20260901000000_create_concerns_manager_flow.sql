-- Create the `concerns` table (it does NOT exist in this DB yet) for the
-- student → accommodation-manager complaint flow, and add the manager-facing
-- fields so the manager can respond and both sides track progress.
-- Idempotent + self-contained.

create table if not exists public.concerns (
  id                uuid primary key default gen_random_uuid(),
  lease_id          uuid not null references public.leases(id) on delete cascade,
  category          text not null,                       -- maintenance | noise | cleanliness | amenities | security | others
  description       text,
  status            text not null default 'open',        -- open | acknowledged | in_progress | resolved | rejected
  reported_at       timestamptz not null default now(),
  resolved_at       timestamptz,
  acknowledged_at   timestamptz,
  manager_response  text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists concerns_lease_id_idx on public.concerns (lease_id);

alter table public.concerns enable row level security;

grant select, insert, update on public.concerns to authenticated;

-- RLS: the tenant (student of the lease) and the accommodation manager of the
-- lease can see + act on a concern; admins can do everything.
drop policy if exists "concerns_tenant_manager_read" on public.concerns;
create policy "concerns_tenant_manager_read"
  on public.concerns for select to authenticated
  using (
    lease_id in (select id from public.leases where student_id = auth.uid())
    or lease_id in (select id from public.leases where accommodation_manager_id = auth.uid())
    or public.is_admin(auth.uid())
  );

drop policy if exists "concerns_tenant_insert" on public.concerns;
create policy "concerns_tenant_insert"
  on public.concerns for insert to authenticated
  with check (
    lease_id in (select id from public.leases where student_id = auth.uid())
    or public.is_admin(auth.uid())
  );

-- Managers (and admins) update the concern: status, resolved_at, response.
drop policy if exists "concerns_manager_update" on public.concerns;
create policy "concerns_manager_update"
  on public.concerns for update to authenticated
  using (
    lease_id in (select id from public.leases where accommodation_manager_id = auth.uid())
    or public.is_admin(auth.uid())
  )
  with check (
    lease_id in (select id from public.leases where accommodation_manager_id = auth.uid())
    or public.is_admin(auth.uid())
  );
