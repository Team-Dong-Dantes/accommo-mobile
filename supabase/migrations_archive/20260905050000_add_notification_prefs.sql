alter table public.users
  add column if not exists notification_prefs jsonb not null default '{"push": true, "email": true}'::jsonb;
