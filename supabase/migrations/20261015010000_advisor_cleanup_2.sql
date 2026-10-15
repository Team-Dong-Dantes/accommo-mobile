-- Second Advisors pass.
--
-- rls_enabled_no_policy: these tables are touched only by security-definer
-- functions and the service role, both of which bypass RLS. An explicit
-- deny-all policy states that intent and clears the advisor; it changes nothing
-- for any client role, which already got zero rows.
create policy deny_all on public.expiry_reminders  for all to anon, authenticated using (false) with check (false);
create policy deny_all on public.payment_reminders for all to anon, authenticated using (false) with check (false);
create policy deny_all on public.rate_limit_hits   for all to anon, authenticated using (false) with check (false);
create policy deny_all on public.sign_in_history   for all to anon, authenticated using (false) with check (false);

-- unused_index: non-FK indexes the advisor reports as never used.
-- idx_boarding_history_accommodation_id is a FK index and is kept.
drop index if exists public.accommodation_documents_doc_type_idx;
drop index if exists public.accommodation_documents_uploaded_at_idx;
