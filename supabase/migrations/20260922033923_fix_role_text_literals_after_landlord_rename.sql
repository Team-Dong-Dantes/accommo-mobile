-- Follow-up to 20260922000000_rename_accommodation_manager_to_landlord.sql.
--
-- That migration assumed every RLS policy would follow the enum rename, because
-- a policy stores a parsed expression tree and ALTER TYPE ... RENAME VALUE keeps
-- the label's OID. That holds only where the comparison is against the enum
-- type. These two policies instead compare `get_my_role()`, which returns TEXT,
-- against a plain string literal — nothing about that is OID-tracked, so the
-- literal survived the rename and was left matching a role that no longer
-- exists.
--
-- Effect while broken: landlords could not read OSAS policies, and could not see
-- announcements addressed to them. Both are SELECT policies, so they failed
-- closed — access was denied, never widened.
--
-- The other eight policies that compare a role as text all test for 'admin',
-- which did not change.

begin;

drop policy if exists policies_select_authenticated on public.policies;
create policy policies_select_authenticated on public.policies
  for select to authenticated
  using (
    (not archived)
    and (effective_date <= now())
    and (public.get_my_role() = any (array['student'::text, 'landlord'::text]))
  );

drop policy if exists announcements_select_audience on public.announcements;
create policy announcements_select_audience on public.announcements
  for select to authenticated
  using (
    (published_at is not null)
    and (published_at <= now())
    and (not archived)
    and ((expires_at is null) or (expires_at > now()))
    and case
      when (accommodation_id is null) then (
        (audience = 'all'::audience_type)
        or ((audience = 'students'::audience_type) and (public.get_my_role() = 'student'::text))
        or ((audience = 'landlords'::audience_type) and (public.get_my_role() = 'landlord'::text))
      )
      else (accommodation_id in (select id from public.my_accommodation_ids()))
    end
  );

commit;
