-- Concerns workflow improvements: a per-status timestamp for the "in progress"
-- step (activity trail), an optional photo attachment, and realtime so both
-- sides see status/response changes live instead of requiring a reload.
-- Idempotent + self-contained.

alter table public.concerns add column if not exists in_progress_at timestamptz;
alter table public.concerns add column if not exists photo_url text;

alter publication supabase_realtime add table public.concerns;
