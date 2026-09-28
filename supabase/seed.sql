-- Local `supabase db reset` only: the two singleton config rows the apps read
-- on start. OSAS policies are not seeded — policies.created_by needs a real
-- admin, and they are edited in the web console anyway.
insert into public.report_settings (id) values (true) on conflict do nothing;

insert into public.app_release (id, apk_url, latest_version_code, latest_version_name, min_supported_version_code)
values (1, 'https://github.com/Team-Dong-Dantes/accommo-mobile/releases/latest/download/app-release.apk', 59, '1.63.59', 1)
on conflict do nothing;
