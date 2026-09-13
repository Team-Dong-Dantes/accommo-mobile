-- All three review tables had RLS that made them unusable as designed. The
-- bug wasn't limited to INSERT — UPDATE and DELETE on two of the three
-- tables had the identical mistake: every write policy checked the SUBJECT
-- of the review instead of its AUTHOR.
--
-- - accommodation_manager_reviews (student reviews manager): insert/update/
--   delete all checked accommodation_manager_id = auth.uid() — the manager
--   being reviewed, not the student writing the review. A student could
--   never write, edit, or delete their own review. No student SELECT policy
--   either, so a correctly-inserted row (impossible anyway) couldn't even
--   be read back by its author.
-- - tenant_reviews (manager reviews student): insert/update/delete all
--   checked student_id = auth.uid() — the tenant being reviewed, not the
--   manager writing the review. Same bug, opposite direction. No manager
--   SELECT policy.
-- - accommodation_reviews (student reviews accommodation): write policies
--   were correct, but a `roles: public, qual: true` SELECT policy made
--   every review readable by anyone, including anonymous visitors —
--   contradicting the intended design.
--
-- Design: a review is visible to the party who wrote it and the party it's
-- about, never to anyone else. Writes are gated on the author actually
-- having a completed (ended/terminated) lease connecting them to the party
-- being reviewed, so a review can't be fabricated against an unrelated
-- lease/accommodation/manager/tenant.

-- ---- accommodation_reviews (student -> accommodation), author = student ----
drop policy if exists accommodation_reviews_select_public on public.accommodation_reviews;

drop policy if exists accommodation_reviews_insert_own_student on public.accommodation_reviews;
create policy accommodation_reviews_insert_own_student on public.accommodation_reviews
for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (
    select 1 from leases l
    where l.id = accommodation_reviews.lease_id
      and l.student_id = auth.uid()
      and l.status in ('ended', 'terminated')
      and exists (
        select 1 from rooms r
        where r.id = l.room_id and r.accommodation_id = accommodation_reviews.accommodation_id
      )
  )
);

drop policy if exists accommodation_reviews_select_own_student on public.accommodation_reviews;
create policy accommodation_reviews_select_involved on public.accommodation_reviews
for select to authenticated
using (
  student_id = auth.uid()
  or exists (
    select 1 from accommodations a
    where a.id = accommodation_reviews.accommodation_id and a.accommodation_manager_id = auth.uid()
  )
);

alter table public.accommodation_reviews
  add constraint accommodation_reviews_rating_range check (rating between 1 and 5);

-- ---- accommodation_manager_reviews (student -> manager), author = student ----
drop policy if exists accommodation_manager_reviews_insert_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_insert_own_student on public.accommodation_manager_reviews
for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (
    select 1 from leases l
    where l.id = accommodation_manager_reviews.lease_id
      and l.student_id = auth.uid()
      and l.status in ('ended', 'terminated')
      and l.accommodation_manager_id = accommodation_manager_reviews.accommodation_manager_id
  )
);

drop policy if exists accommodation_manager_reviews_update_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_update_own_student on public.accommodation_manager_reviews
for update to authenticated
using (student_id = auth.uid())
with check (student_id = auth.uid());

drop policy if exists accommodation_manager_reviews_delete_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_delete_own_student on public.accommodation_manager_reviews
for delete to authenticated
using (student_id = auth.uid());

drop policy if exists accommodation_manager_reviews_select_own_manager on public.accommodation_manager_reviews;
create policy accommodation_manager_reviews_select_involved on public.accommodation_manager_reviews
for select to authenticated
using (accommodation_manager_id = auth.uid() or student_id = auth.uid());

alter table public.accommodation_manager_reviews
  add constraint accommodation_manager_reviews_rating_range check (rating between 1 and 5);

-- ---- tenant_reviews (manager -> student), author = manager ----
drop policy if exists tenant_reviews_insert_own_student on public.tenant_reviews;
create policy tenant_reviews_insert_own_manager on public.tenant_reviews
for insert to authenticated
with check (
  accommodation_manager_id = auth.uid()
  and exists (
    select 1 from leases l
    where l.id = tenant_reviews.lease_id
      and l.accommodation_manager_id = auth.uid()
      and l.status in ('ended', 'terminated')
      and l.student_id = tenant_reviews.student_id
  )
);

drop policy if exists tenant_reviews_update_own_student on public.tenant_reviews;
create policy tenant_reviews_update_own_manager on public.tenant_reviews
for update to authenticated
using (accommodation_manager_id = auth.uid())
with check (accommodation_manager_id = auth.uid());

drop policy if exists tenant_reviews_delete_own_student on public.tenant_reviews;
create policy tenant_reviews_delete_own_manager on public.tenant_reviews
for delete to authenticated
using (accommodation_manager_id = auth.uid());

drop policy if exists tenant_reviews_select_own_student on public.tenant_reviews;
create policy tenant_reviews_select_involved on public.tenant_reviews
for select to authenticated
using (student_id = auth.uid() or accommodation_manager_id = auth.uid());

alter table public.tenant_reviews
  add constraint tenant_reviews_rating_range check (rating between 1 and 5);
