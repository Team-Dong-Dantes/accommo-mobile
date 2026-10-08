-- Remove the OSAS "Policies & Guidelines" feature.
--
-- OSAS published policy documents (public.policies) that students and
-- landlords/landladies accepted per revision (policy_acceptances, accept_policy),
-- with superseded text kept in policy_versions and a 'policy' notification on
-- every publish. The feature is gone from both apps, so its tables, functions and
-- notifications go too.
--
-- Not touched on purpose:
--   * the Terms of Service / Privacy Notice consent (users.terms_accepted_at,
--     users.privacy_accepted_at) — those ship in the app bundle and were never
--     part of this feature;
--   * accommodation_policies (house rules per listing) — a different thing;
--   * audit_logs rows with entity_type = 'policies' — history of what admins did
--     stays readable in the web audit log.

drop table if exists public.policy_acceptances;
drop table if exists public.policy_versions;
-- Takes trg_policy_version, trg_notify_policy and trg_audit_policies with it.
drop table if exists public.policies;

drop function if exists public.accept_policy(uuid);
drop function if exists public.policy_acceptance_stats();
drop function if exists public.policy_pending_users(uuid);
drop function if exists public.snapshot_policy_version();
drop function if exists public.notify_policy();

-- Their links pointed at a screen that no longer exists.
delete from public.notifications where type = 'policy';
