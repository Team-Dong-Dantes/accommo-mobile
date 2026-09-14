-- The APK is sideloaded from GitHub Releases; there is no store pushing updates,
-- so an install stays frozen on whatever build it was given. This row is what an
-- installed app asks on launch: "am I current, and am I still allowed to run?"
--
-- One row, never more. `latest_version_code` is a nudge; `min_supported_version_code`
-- is a floor — the app blocks itself below it. The floor exists because mobile and
-- web share one Supabase project, so a migration that breaks old clients otherwise
-- has no way to stop them.
--
-- Version numbers are Android `versionCode` integers, which CI sets to the workflow
-- run number (see .github/workflows/build.yml). Nothing parses a version string.

create table public.app_release (
  id                         int  primary key default 1 check (id = 1),
  latest_version_code        int  not null,
  latest_version_name        text not null,
  min_supported_version_code int  not null default 1,
  apk_url                    text not null,
  release_notes              text,
  updated_at                 timestamptz not null default now()
);

alter table public.app_release enable row level security;

-- Readable by anon on purpose, unlike the tightening in 20260914000001 and
-- ...000002. The blocking dialog has to be able to appear on the login screen:
-- a build old enough to be cut off may also be too old to authenticate, and a
-- gate that only works after sign-in would never reach the users it is for.
-- There is no insert/update/delete grant — only the service role writes here.
create policy app_release_read_all on public.app_release for select using (true);

-- Supabase's default privileges hand anon and authenticated the full
-- INSERT/UPDATE/DELETE set on any new table in `public` — the same loose grant
-- 20260914000002 was closing elsewhere. RLS already denies those writes for want
-- of a policy, but take the grants back so the table is read-only at both layers.
revoke all on public.app_release from anon, authenticated;
grant select on public.app_release to anon, authenticated;

-- Seeded to match what is already installed, so nothing prompts until the next
-- CI release writes the real numbers.
insert into public.app_release (latest_version_code, latest_version_name, apk_url)
values (
  1,
  '1.0',
  'https://github.com/Team-Dong-Dantes/accommo-mobile/releases/latest/download/app-release.apk'
);
