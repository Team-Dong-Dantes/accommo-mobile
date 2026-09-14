-- Move four rules out of the Vue apps and into the database, where a client
-- cannot talk its way around them.
--
-- Every one of these was reachable with a plain REST call against the anon key.
-- The apps themselves behave correctly; nothing was stopping anyone from simply
-- not using the app.


-- 1. Reading another user's row ------------------------------------------------
--
-- "Authenticated users can view public profile info" was USING (true), added so
-- a student could see their manager's name on a boarding-house card. But RLS is
-- row-level, and PostgREST will still hand over every column of every row it
-- lets through: one signed-in student could select email, phone, status and
-- is_superadmin for all 173 accounts.
--
-- can_notify() already encodes the relationship we actually meant -- yourself,
-- someone you share a lease with, someone you share a conversation with -- and
-- is SECURITY DEFINER, so it does not recurse back through this policy. The
-- second clause is the genuinely public case: a manager is visible to everyone
-- while they have an accredited accommodation listed.
--
-- Managers with no accredited accommodation now drop out of the Discover
-- manager list server-side instead of being fetched and filtered away in JS.
-- That is the intended reading of "public".

DROP POLICY IF EXISTS "Authenticated users can view public profile info" ON public.users;

CREATE POLICY users_select_related ON public.users
FOR SELECT
TO authenticated
USING (
  public.can_notify(id)
  OR EXISTS (
    SELECT 1 FROM public.accommodations a
    WHERE a.accommodation_manager_id = users.id
      AND a.status = 'accredited'
  )
);


-- 2. Verifying your own rent ----------------------------------------------------
--
-- payments_insert_involved and payments_update_involved ask only "are you on
-- this lease", so the student half of the lease could PATCH their own payment to
-- status='paid' and fill in verified_by themselves. The whole verify/reject
-- workflow in ManagerTenantsPage.vue was advisory.
--
-- leases has had exactly this guard since tg_lease_guard_student_update();
-- payments never got the matching one. Same shape, same failure mode.

CREATE OR REPLACE FUNCTION public.tg_payment_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_student uuid;
  v_manager uuid;
begin
  select l.student_id, l.accommodation_manager_id
    into v_student, v_manager
    from public.leases l
   where l.id = new.lease_id;

  -- Managers keep the full range of edits on their own leases. So does anyone
  -- who is somehow both parties. Everything past here is the student path.
  if auth.uid() is distinct from v_student or auth.uid() = v_manager then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'pending_verification'
    or new.paid_at          is not null
    or new.verified_by      is not null
    or new.rejection_reason is not null then
      raise exception 'a student may only submit a payment for verification';
    end if;
  else
    if new.status           is distinct from old.status
    or new.amount           is distinct from old.amount
    or new.month            is distinct from old.month
    or new.lease_id         is distinct from old.lease_id
    or new.paid_at          is distinct from old.paid_at
    or new.verified_by      is distinct from old.verified_by
    or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'a student may not verify or alter a submitted payment';
    end if;
  end if;

  return new;
end;
$function$;

DROP TRIGGER IF EXISTS payment_guard ON public.payments;
CREATE TRIGGER payment_guard
  BEFORE INSERT OR UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.tg_payment_guard();

-- A zero or negative payment is nonsense from either side of the lease, so it
-- belongs on the column rather than in each caller. No existing row violates it.
ALTER TABLE public.payments
  ADD CONSTRAINT payments_amount_positive CHECK (amount > 0);

-- Deleting the record of a payment is a manager action. The old policy let the
-- student delete a rejected payment out of the history.
DROP POLICY IF EXISTS payments_delete_involved ON public.payments;

CREATE POLICY payments_delete_manager ON public.payments
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.leases l
    WHERE l.id = payments.lease_id
      AND l.accommodation_manager_id = auth.uid()
  )
);


-- 3. The anonymous RPC surface ---------------------------------------------------
--
-- 45 SECURITY DEFINER functions were callable without signing in, including
-- notify_admins(), which took a title, body and link and inserted them into
-- every admin's notification feed. An unauthenticated POST to it returned 204.
--
-- No screen in either app calls an RPC before authentication -- has_pin() on the
-- login page fires after sign-in -- so anon needs none of them. The five helpers
-- kept below are predicates used inside RLS policies that anon is still subject
-- to (rooms_select_admin calls is_admin, for one); revoking those would break
-- anonymous reads of the public listings instead of securing anything. They all
-- key off auth.uid(), which is null for anon, so they answer false and disclose
-- nothing.

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;

GRANT EXECUTE ON FUNCTION public.is_admin(uuid)            TO anon;
GRANT EXECUTE ON FUNCTION public.can_notify(uuid)          TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_role()             TO anon;
GRANT EXECUTE ON FUNCTION public.my_accommodation_ids()    TO anon;
GRANT EXECUTE ON FUNCTION public.current_is_superadmin()   TO anon;

-- An existence oracle over student IDs, which are guessable. Nothing in either
-- app calls it.
REVOKE EXECUTE ON FUNCTION public.check_student_id_exists(text) FROM anon, authenticated;

-- Write grants anon was never meant to hold. RLS already refuses these, but the
-- grant is the wrong default to leave lying around, and qr_scans has no INSERT
-- policy at all -- only verify_student_qr() is supposed to write it.
REVOKE INSERT, UPDATE, DELETE ON public.qr_scans           FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.concerns           FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.tickets            FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.ticket_messages    FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.review_inbox           FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.review_admin_feed      FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.review_written_leases  FROM anon;


-- 4. Looking a student up by their student number ---------------------------------
--
-- verify_student_qr() required only *a* session, not a manager's. Its fallback
-- branch looks a student up by student_id, which -- unlike the UUID QR token --
-- is guessable, so any signed-in account could walk the student numbers and
-- collect names, programs, colleges and year levels 12 at a time.
--
-- The QR-token branch is unchanged: holding the token is the proof. Only the
-- typed-in-by-hand branch now asks who is doing the typing.
--
-- A token with no expiry is also treated as expired here. It previously fell
-- through the expiry check and stayed valid forever.

CREATE OR REPLACE FUNCTION public.verify_student_qr(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  me uuid := auth.uid();
  recent integer;
  sp record;
  u record;
  is_mine boolean;
  v_method text := 'qr';
  v_result text;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;

  SELECT count(*) INTO recent
    FROM public.qr_scans
   WHERE scanner_id = me AND scanned_at > now() - interval '1 minute';
  IF recent >= 12 THEN
    RAISE EXCEPTION 'Too many scans in a row. Wait a minute and try again.';
  END IF;

  SELECT * INTO sp FROM public.student_profiles WHERE qr_code_token = p_code;

  IF sp.user_id IS NOT NULL
     AND (sp.qr_token_expires_at IS NULL OR sp.qr_token_expires_at <= now()) THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, sp.user_id, 'qr', 'expired');
    RETURN jsonb_build_object('found', false, 'reason', 'expired');
  END IF;

  -- Typing a student number instead of scanning is a manager/OSAS action. For
  -- anyone else the code simply does not resolve.
  IF sp.user_id IS NULL THEN
    IF public.get_my_role() IN ('accommodation_manager', 'admin') THEN
      v_method := 'manual';
      SELECT * INTO sp FROM public.student_profiles WHERE student_id = p_code;
    END IF;
  END IF;

  IF sp.user_id IS NULL THEN
    INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
    VALUES (me, NULL, v_method, 'not_found');
    RETURN jsonb_build_object('found', false, 'reason', 'not_found');
  END IF;

  SELECT * INTO u FROM public.users WHERE id = sp.user_id;

  SELECT EXISTS (
    SELECT 1 FROM public.leases l
     WHERE l.student_id = sp.user_id AND l.accommodation_manager_id = me
  ) INTO is_mine;

  v_result := CASE WHEN sp.osas_verified_at IS NOT NULL THEN 'verified' ELSE 'unverified' END;
  INSERT INTO public.qr_scans (scanner_id, student_id, method, result)
  VALUES (me, sp.user_id, v_method, v_result);

  RETURN jsonb_build_object(
    'found', true,
    'user_id', sp.user_id,
    'student_id', sp.student_id,
    'full_name', u.full_name,
    'initials', u.initials,
    'avatar_url', u.avatar_url,
    'program', sp.program,
    'college', sp.college,
    'year_level', sp.year_level,
    'osas_verified', sp.osas_verified_at IS NOT NULL,
    'verified_at', sp.osas_verified_at,
    'account_status', u.status,
    'is_my_tenant', is_mine,
    'method', v_method
  );
END;
$function$;
