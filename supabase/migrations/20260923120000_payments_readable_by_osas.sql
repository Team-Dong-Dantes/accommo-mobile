-- OSAS could read a student's leases (leases_select_admin) but not the payments
-- on them: payments only had payments_select_involved, which admits the student
-- and the landlord/landlady on the lease. RLS returns no rows rather than an
-- error, so the web console's student record showed "No payments recorded" for
-- students who had paid. Admins may now read payments; they still cannot write
-- them — no insert/update/delete policy is added.
drop policy if exists payments_select_admin on public.payments;
create policy payments_select_admin on public.payments
  for select to authenticated
  using (public.is_admin(auth.uid()));
