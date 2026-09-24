-- Who signs OSAS reports. Every printed report carries "Prepared by" (the admin
-- who generated it) and "Noted by" (the OSAS Director), and optionally
-- "Approved by". The names and positions are office-wide, so they live in one
-- row here rather than in each admin's browser. Only admins read or write it.
create table if not exists public.report_settings (
  id boolean primary key default true check (id), -- exactly one row
  noted_by_name text,
  noted_by_position text,
  approved_by_name text,
  approved_by_position text,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (id) on delete set null
);

insert into public.report_settings (id) values (true) on conflict do nothing;

alter table public.report_settings enable row level security;

create policy report_settings_admin_read on public.report_settings
  for select to authenticated
  using (public.is_admin(auth.uid()));

create policy report_settings_admin_update on public.report_settings
  for update to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

revoke all on public.report_settings from anon;
revoke insert, delete, truncate, references, trigger on public.report_settings from authenticated;
grant select, update on public.report_settings to authenticated;
