-- Signed-out visitors held SELECT on these, left over from Supabase's default
-- grants. No anon policy exists on any of them, so RLS returned nothing — but
-- one permissive policy written for `public` instead of `authenticated` would
-- have opened support tickets, concerns, QR scans and permits to the internet.
-- No signed-out screen in either app reads them.
revoke all on public.tickets, public.ticket_messages, public.concerns, public.qr_scans,
  public.verification_requests, public.accommodation_documents, public.accreditation_rounds,
  public.latest_accommodation_documents
  from anon;

-- The root cause: tables created by migrations (owner postgres) were granted to
-- anon by default. From now on a table a signed-out visitor should read needs
-- its own `grant select ... to anon`. Existing public tables keep theirs.
alter default privileges for role postgres in schema public revoke all on tables from anon;
