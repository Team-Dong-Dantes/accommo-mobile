-- The two trigger functions added in 20260919000001 and 20260919000002 were
-- revoked from `anon, authenticated` but not from PUBLIC, so they inherited the
-- default PUBLIC grant and showed up on the REST surface -- the same trap
-- 20260914000001 documented and 20260916000006 fell into, repeated here in the
-- very migration whose comment warned about it.
--
-- Calling either one over REST would fail anyway ("trigger functions can only be
-- called as triggers"), so nothing was exposed. It is the grant that is wrong,
-- and a wrong grant on a SECURITY DEFINER function is not worth leaving lying
-- around to be read as precedent.
revoke all on function public.lock_document_ref() from public, anon, authenticated;
revoke all on function public.tg_notification_attribution() from public, anon, authenticated;
