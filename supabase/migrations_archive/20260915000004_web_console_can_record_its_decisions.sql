-- The OSAS web console has been reporting success for writes the database
-- refused. Four of its writes are blocked by RLS and one read points at a view
-- that no longer exists; supabase-js returns errors rather than throwing, so
-- every one of them lands in a `catch` that never fires or a console.warn
-- nobody reads. The console says "User verified" and nothing is recorded.
--
-- Probed against the live database before writing this:
--
--   audit_logs          RLS on, two SELECT policies, NO insert policy.
--                       All 5,434 rows came from SECURITY DEFINER triggers;
--                       `select action, count(*)` returns only UPDATE/CREATE/
--                       DELETE. Not one verification.approve in the table.
--   notifications       insert is can_notify(user_id) or own row. can_notify()
--                       means self / shared lease / shared conversation --
--                       an admin is none of those to an applicant. The two
--                       rows go in one statement, so the applicant's row being
--                       refused takes the admin's own copy down with it.
--                       The accreditation decisions at 2026-09-10 19:24
--                       produced no notification rows at all.
--   review_admin_feed   dropped by 20260914000002. That migration's reason was
--                       "no caller in either app" -- accommo-web's
--                       pages/admin/Users.vue is the caller. The web app was
--                       missed in the cross-app check.
--   audit_logs realtime not in the supabase_realtime publication, so the live
--                       subscription on the Audit Logs page never fires.
--
-- Everything here is additive: four new policies, one recreated view, one
-- publication entry. No existing policy, grant or column changes, and the
-- mobile client reads none of it.


-- ── 1. An admin may record what they did ────────────────────────────────────
-- `authenticated` already holds the INSERT grant on audit_logs; only the policy
-- was missing. actor_id is pinned to auth.uid() so an admin cannot file an
-- action under someone else's name -- an audit trail you can forge entries in
-- is worse than none, because it looks authoritative.

DROP POLICY IF EXISTS audit_logs_insert_admin ON public.audit_logs;

CREATE POLICY audit_logs_insert_admin ON public.audit_logs
FOR INSERT
TO authenticated
WITH CHECK (
  public.is_admin(auth.uid())
  AND actor_id = auth.uid()
);


-- ── 2. An admin may notify the person they decided about ────────────────────
-- Deliberately a new policy rather than widening can_notify(): that function is
-- also the read half of users_select_related, and "an admin may send you a
-- notification" is not the same statement as "an admin is your counterparty".
-- Keep the blast radius to the one table that needs it.

DROP POLICY IF EXISTS notifications_insert_admin ON public.notifications;

CREATE POLICY notifications_insert_admin ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin(auth.uid()));


-- ── 3. An admin may read reviews ────────────────────────────────────────────
-- Reviews stay anonymous to the people involved -- *_select_involved still
-- scopes every other caller to their own side of the lease. OSAS is the one
-- party that has to see both, which is what the user drawer's Reviews tab is
-- for.
--
-- Grant + policy rather than a SECURITY DEFINER view, following the conclusion
-- 20260914000003 reached: the definer views were standing in for grants that
-- should always have been there, and RLS should do the work it does everywhere
-- else in this schema. SELECT is already granted to `authenticated` on all
-- three tables by that migration.

DROP POLICY IF EXISTS tenant_reviews_select_admin ON public.tenant_reviews;
CREATE POLICY tenant_reviews_select_admin ON public.tenant_reviews
FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS accommodation_manager_reviews_select_admin ON public.accommodation_manager_reviews;
CREATE POLICY accommodation_manager_reviews_select_admin ON public.accommodation_manager_reviews
FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS accommodation_reviews_select_admin ON public.accommodation_reviews;
CREATE POLICY accommodation_reviews_select_admin ON public.accommodation_reviews
FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));


-- ── 4. review_admin_feed, restored as a plain view ──────────────────────────
-- One shape over three tables that disagree about which column is the subject
-- and which is the author:
--
--   tenant                a manager reviewing their tenant
--                         subject = student_id,  author = accommodation_manager_id
--   manager               a student reviewing their manager
--                         subject = accommodation_manager_id, author = student_id
--   accommodation         a student reviewing the house
--                         subject = accommodation_id, author = student_id
--
-- security_invoker = true, so the admin SELECT policies above are what admits
-- the rows, not the view owner's rights. A non-admin gets their own rows back
-- through *_select_involved, exactly as they would reading the table directly.
--
-- Column list matches the block already generated into
-- accommo-web/src/types/database.gen.ts, so no type regeneration is needed.

DROP VIEW IF EXISTS public.review_admin_feed;

CREATE VIEW public.review_admin_feed
WITH (security_invoker = true)
AS
  SELECT
    tr.id,
    'tenant'::text                  AS kind,
    tr.student_id                   AS subject_id,
    tr.accommodation_manager_id     AS author_id,
    tr.rating,
    tr.comment,
    tr.created_at,
    tr.lease_id,
    NULL::uuid                      AS accommodation_id
  FROM public.tenant_reviews tr

  UNION ALL

  SELECT
    amr.id,
    'manager'::text                 AS kind,
    amr.accommodation_manager_id    AS subject_id,
    amr.student_id                  AS author_id,
    amr.rating,
    amr.comment,
    amr.created_at,
    amr.lease_id,
    NULL::uuid                      AS accommodation_id
  FROM public.accommodation_manager_reviews amr

  UNION ALL

  SELECT
    ar.id,
    'accommodation'::text           AS kind,
    ar.accommodation_id             AS subject_id,
    ar.student_id                   AS author_id,
    ar.rating,
    ar.comment,
    ar.created_at,
    ar.lease_id,
    ar.accommodation_id
  FROM public.accommodation_reviews ar;

REVOKE ALL ON public.review_admin_feed FROM anon;
GRANT SELECT ON public.review_admin_feed TO authenticated;


-- ── 5. Audit Logs can watch itself ──────────────────────────────────────────
-- The page subscribes to INSERTs on audit_logs and prepends them live. The
-- table was never in the publication, so the channel connected and sat silent.
-- Realtime still applies RLS, so a non-admin subscriber sees nothing.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'audit_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_logs;
  END IF;
END
$$;
