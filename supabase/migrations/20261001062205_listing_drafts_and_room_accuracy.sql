-- Listing drafts, and the room data a landlord/landlady enters made accurate.
--
-- 1. Drafts. An accommodation used to be created already submitted to OSAS,
--    which meant every permit had to be in hand before a single room could be
--    set up. It can now be created as a 'draft': private to its owner, invisible
--    to students and to OSAS, editable at leisure. submit_accommodation() is the
--    one way out of draft, and it refuses a listing that is not complete — so
--    OSAS still only ever sees whole submissions.
-- 2. Room numbers are unique within an accommodation (case- and space-blind),
--    and never blank. They used to be "count on floor + 1", which handed out a
--    taken number after any delete.
-- 3. Rent must be above zero. A ₱0 room went live as "On request".
-- 4. total_floors / total_rooms / capacity follow the rooms and floors instead
--    of being typed separately and drifting from them.

-- ---- 1. Drafts ----------------------------------------------------------------
alter type public.accommodation_status add value if not exists 'draft';

-- Compared as text throughout: the new enum value cannot be used as a literal
-- inside the transaction that adds it.

-- OSAS never sees a draft. One policy covers every admin query in the web app.
alter policy "accommodations_select_admin" on public.accommodations
  using ((select public.is_admin((select auth.uid()))) and status::text <> 'draft');

create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path to 'public' as $function$
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  if tg_table_name = 'student_profiles' then
    if tg_op = 'INSERT' then
      if new.osas_verified_at is not null then
        raise exception 'Only OSAS may set verification status.';
      end if;
    elsif new.osas_verified_at is distinct from old.osas_verified_at then
      raise exception 'Only OSAS may change verification status.';
    end if;
  end if;

  if tg_table_name = 'accommodations' then
    if tg_op = 'INSERT' then
      if new.status::text not in ('pending', 'draft') then
        raise exception 'A new accommodation must start as a draft or pending.';
      end if;
    elsif new.status is distinct from old.status then
      if coalesce(current_setting('app.permit_review', true), 'false') = 'true'
         and new.status = 'pending'
         and old.status in ('accredited', 'expired', 'needs_revision', 'rejected') then
        null;
      -- draft -> pending only through submit_accommodation(), which checks the
      -- listing is complete before it sets this flag.
      elsif coalesce(current_setting('app.submit_review', true), 'false') = 'true'
         and old.status::text = 'draft'
         and new.status = 'pending' then
        null;
      elsif auth.uid() = old.landlord_id
            and new.landlord_id = old.landlord_id
            and (
              (old.status = 'accredited' and new.status = 'delisted')
              or (old.status = 'delisted' and new.status = 'accredited'
                  and (new.accreditation_expires_at is null
                       or new.accreditation_expires_at > now()))
            ) then
        null;
      else
        raise exception 'Only OSAS may change accreditation status.';
      end if;
    end if;
  end if;

  if tg_table_name = 'verification_documents' then
    if new.status = 'approved' then
      raise exception 'Only OSAS may approve a document.';
    end if;
  end if;

  return new;
end $function$;

-- Send a draft to OSAS. Every check is one the wizard also makes, repeated here
-- because a draft is finished in the editor, where nothing walks the steps.
create or replace function public.submit_accommodation(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  a public.accommodations;
  p public.accommodation_policies;
  missing text[] := '{}';
  doc text;
begin
  select * into a from public.accommodations where id = p_id;
  if a.id is null or a.landlord_id is distinct from auth.uid() then
    raise exception 'Accommodation not found.';
  end if;
  if a.status::text <> 'draft' then
    raise exception 'This accommodation has already been submitted.';
  end if;

  if a.accommodation_type is null or a.gender_policy is null then missing := missing || 'type and who it accepts'; end if;
  if a.lat is null or a.lng is null or a.barangay is null or a.city is null then missing := missing || 'location'; end if;
  if a.water_billing is null or a.electric_billing is null or a.wifi_billing is null then missing := missing || 'utilities'; end if;

  select * into p from public.accommodation_policies where accommodation_id = p_id;
  if p.curfew_time is null or p.quiet_hours is null or p.visitor_policy is null then missing := missing || 'house rules'; end if;

  if not exists (select 1 from public.accommodation_images where accommodation_id = p_id) then
    missing := missing || 'an exterior photo';
  end if;
  foreach doc in array array['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] loop
    if not exists (select 1 from public.accommodation_documents where accommodation_id = p_id and doc_type = doc) then
      missing := missing || 'all four permits';
      exit;
    end if;
  end loop;

  if array_length(missing, 1) > 0 then
    raise exception 'Still missing: %.', array_to_string(missing, ', ');
  end if;

  perform set_config('app.submit_review', 'true', true);
  update public.accommodations set status = 'pending' where id = p_id;
  perform set_config('app.submit_review', 'false', true);

  -- Same notice trg_new_accommodation sends for a listing created as pending.
  perform public.notify_admins(
    'New accommodation for accreditation',
    coalesce(a.name, 'An accommodation') || ' was submitted for accreditation.',
    'accommodation',
    '/verifications?focus=verification:' || p_id::text
  );
end;
$$;
revoke all on function public.submit_accommodation(uuid) from public, anon;
grant execute on function public.submit_accommodation(uuid) to authenticated, service_role;

-- ---- 2 & 3. Room numbers and rent ---------------------------------------------
alter table public.rooms drop constraint if exists rooms_room_number_not_blank;
alter table public.rooms
  add constraint rooms_room_number_not_blank check (room_number is null or btrim(room_number) <> '');
create unique index if not exists rooms_accommodation_room_number_key
  on public.rooms (accommodation_id, lower(btrim(room_number)))
  where room_number is not null;

alter table public.rooms drop constraint if exists rooms_monthly_rent_positive;
alter table public.rooms
  add constraint rooms_monthly_rent_positive check (monthly_rent is not null and monthly_rent > 0);

-- ---- 4. Derived totals --------------------------------------------------------
create or replace function public.sync_accommodation_totals(p_id uuid) returns void
language sql security definer set search_path to 'public' as $$
  update public.accommodations a set
    total_floors = (
      select count(*) from (
        select floor_number as f from public.accommodation_floors where accommodation_id = p_id
        union
        select floor from public.rooms where accommodation_id = p_id and floor is not null
      ) floors
    ),
    total_rooms = (select count(*) from public.rooms where accommodation_id = p_id),
    capacity = (select coalesce(sum(capacity), 0) from public.rooms where accommodation_id = p_id)
  where a.id = p_id;
$$;
revoke all on function public.sync_accommodation_totals(uuid) from public, anon, authenticated;

create or replace function public.tg_sync_accommodation_totals() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.sync_accommodation_totals(old.accommodation_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and (tg_op = 'INSERT' or new.accommodation_id is distinct from old.accommodation_id) then
    perform public.sync_accommodation_totals(new.accommodation_id);
  end if;
  return null;
end;
$$;
revoke all on function public.tg_sync_accommodation_totals() from public, anon, authenticated;

drop trigger if exists trg_sync_totals_rooms on public.rooms;
create trigger trg_sync_totals_rooms after insert or delete or update of floor, capacity, accommodation_id on public.rooms
  for each row execute function public.tg_sync_accommodation_totals();
drop trigger if exists trg_sync_totals_floors on public.accommodation_floors;
create trigger trg_sync_totals_floors after insert or delete or update on public.accommodation_floors
  for each row execute function public.tg_sync_accommodation_totals();

-- Bring every existing listing into line once.
select public.sync_accommodation_totals(id) from public.accommodations;
