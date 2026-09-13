-- CRITICAL FIX: student registration was failing outright with
--     record "new" has no field "status"   (SQLSTATE 42703)
--
-- lock_verification_columns() guards three tables, and the verification_documents
-- check sat in a FLAT condition:
--     if tg_table_name = 'verification_documents' and new.status = 'approved'
-- PL/pgSQL hands the whole expression to the SQL executor, which resolves every
-- field reference before any short-circuit can apply. student_profiles has no
-- `status` column, so the guard raised on EVERY non-admin write to that table —
-- which is exactly what registration does.
--
-- Why the earlier verification missed it: those checks ran either as postgres
-- (auth.uid() is null, which returns before this line) or tripped the
-- osas_verified_at guard first and raised there. The trigger looked like it was
-- working, for the wrong reason. A guard that rejects the write you are testing
-- is indistinguishable from a guard that is broken, unless you also test the
-- write that is supposed to SUCCEED.
--
-- Fix: nest the check inside its own table branch, matching the other two, so the
-- field is only resolved for the table that actually has it.
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
      -- tg_permit_needs_review sends an accredited listing back to review on the
      -- manager's behalf; that one transition is allowed through.
      if not (coalesce(current_setting('app.permit_review', true), 'false') = 'true'
              and old.status = 'accredited' and new.status = 'reviewing') then
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
