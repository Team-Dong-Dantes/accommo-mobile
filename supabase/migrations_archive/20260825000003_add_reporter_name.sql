-- Store the reporter's display name on the ticket at submission time so the
-- OSAS inbox can always show a name without depending on a separate users
-- lookup (which can be empty for some accounts).
alter table public.tickets add column if not exists reporter_name text;

update public.tickets t
set reporter_name = coalesce(
  (select u.full_name from public.users u where u.id = t.student_id),
  (select u.full_name from public.users u where u.id = t.landlord_id),
  (select u.email from public.users u where u.id = t.student_id),
  (select u.email from public.users u where u.id = t.landlord_id)
)
where t.reporter_name is null;
