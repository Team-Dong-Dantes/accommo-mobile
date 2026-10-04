-- Over-the-air web bundles. CI zips each release's web build and records it
-- here; installs whose APK is at least min_supported_version_code download it
-- and apply it on the next relaunch (src/utils/liveUpdate.ts). Null until the
-- first OTA-capable release is published.
alter table public.app_release
  add column if not exists bundle_version integer,
  add column if not exists bundle_url text,
  add column if not exists bundle_checksum text;

comment on column public.app_release.bundle_version is 'CI run number of the latest OTA web bundle.';
comment on column public.app_release.bundle_url is 'Download URL of the OTA web bundle zip (a GitHub release asset).';
comment on column public.app_release.bundle_checksum is 'sha256 of the bundle zip, verified by the updater plugin.';
