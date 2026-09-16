-- A manager may withdraw their own listing.
--
-- `AccommodationDetail.vue:288` has always offered "Delist this accommodation"
-- and "Reactivate this accommodation", and both have always failed:
-- lock_verification_columns let a non-admin change `status` only through the
-- permit-upload exemption, so every tap came back as
-- "Only OSAS may change accreditation status." Verified against the live
-- database by impersonating a real manager before writing this.
--
-- Delisting is not OSAS revoking anything. It is the manager saying the house is
-- full, or closed for renovation, or sold — a business decision about listing,
-- not about accreditation, and the accreditation survives it. So exactly two
-- transitions open up, and only for the owner of the row:
--
--     accredited -> delisted     withdraw
--     delisted   -> accredited   re-list
--
-- The re-list is fenced by the accreditation term. `sweep_expired_accreditations`
-- only touches `accredited` rows, so without that fence a manager could delist,
-- sit out the end of their term where the sweep cannot see them, and then
-- re-list themselves as accredited past it — granting themselves an
-- accreditation nothing could take back.
--
-- Everything else stays OSAS-only. `suspended`, `expired`, `rejected` and
-- `needs_revision` cannot be escaped by delisting and re-listing, because
-- neither allowed transition starts from them.

create or replace function public.lock_verification_columns() returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  -- No JWT means service_role, the SQL console or a migration.
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
      if new.status <> 'pending' then
        raise exception 'A new accommodation must start as pending.';
      end if;
    elsif new.status is distinct from old.status then
      if coalesce(current_setting('app.permit_review', true), 'false') = 'true'
         and new.status = 'pending'
         and old.status in ('accredited', 'expired', 'needs_revision', 'rejected') then
        -- tg_permit_needs_review puts a listing back in the queue on the
        -- manager's behalf when they upload a permit.
        null;
      elsif auth.uid() = old.accommodation_manager_id
            and new.accommodation_manager_id = old.accommodation_manager_id
            and (
              (old.status = 'accredited' and new.status = 'delisted')
              or (old.status = 'delisted' and new.status = 'accredited'
                  and (new.accreditation_expires_at is null
                       or new.accreditation_expires_at > now()))
            ) then
        -- The owner withdrawing or restoring their own listing. The ownership
        -- column is pinned in the same breath so the transition cannot be taken
        -- by handing the property to yourself in the same statement.
        null;
      else
        raise exception 'Only OSAS may change accreditation status.';
      end if;
    end if;
  end if;

  if tg_table_name = 'verification_documents' then
    -- 'approved' is the only doc status that grants anything, so guard just that
    -- and leave the owner's own resubmission (back to 'pending') working.
    if new.status = 'approved' then
      raise exception 'Only OSAS may approve a document.';
    end if;
  end if;

  return new;
end $fn$;
