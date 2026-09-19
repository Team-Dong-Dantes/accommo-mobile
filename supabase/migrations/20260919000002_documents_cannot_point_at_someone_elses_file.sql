-- A document row may only point at a file its writer uploaded.
--
-- doc-access (supabase/functions/doc-access/index.ts) mints a short-lived signed
-- Cloudinary URL for a document row, and authorizes that by re-running the
-- caller's own RLS: if you cannot select the row, you get nothing. That checks
-- WHICH ROW you may read. It never checked WHAT THE ROW POINTS AT -- and
-- verification_documents_insert_own / verification_documents_update_own let you
-- write file_url on your own rows freely.
--
-- So the authorization was circular. Insert a row of your own carrying
--   cld:image:authenticated::accommo/docs/<somebody else>/<their file>
-- (or just UPDATE an existing one of yours to say that), ask doc-access to view
-- it, and the function signs a download for a file belonging to someone else.
-- That is exactly the "oracle that signs any public_id on request" its own
-- header comment says it is not. The assets behind those ids are government IDs,
-- school IDs and business permits.
--
-- Pinning the pointer at write time is what closes it. Every upload made through
-- uploadSecureDocument() lands in `accommo/docs/<uploader's uuid>/` -- the folder
-- is chosen by the edge function from auth.uid() and is part of the signature, so
-- it is not something a client picks. Requiring a newly written ref to sit in the
-- writer's own folder therefore costs the real flow nothing while leaving a
-- forged pointer nowhere to aim.
--
-- Only `cld:` refs are constrained. Two other shapes are stored:
--   * plain https:// URLs from the public unsigned preset, which doc-access hands
--     back untouched because they are public assets anyway, and
--   * the 25 rows the one-off authenticated-delivery migration rewrote, which sit
--     in `accommo/docs/migrated/` or at the Cloudinary root.
-- Existing rows are untouched: a BEFORE trigger only sees writes, so the historic
-- pointers keep resolving for the people they belong to. What changes is that
-- nobody can aim a row at them from now on.

begin;

create or replace function public.lock_document_ref() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  public_id text;
begin
  -- No JWT: service_role, a migration, or the SQL console. Same carve-out the
  -- sibling lock_verification_columns() trigger makes.
  if auth.uid() is null then return new; end if;
  if public.is_admin(auth.uid()) then return new; end if;

  -- Unchanged on an update, or not a signed reference: nothing to pin.
  if new.file_url is null or new.file_url not like 'cld:%' then return new; end if;
  if tg_op = 'UPDATE' and new.file_url is not distinct from old.file_url then return new; end if;

  -- cld:<resource_type>:<type>:<format>:<public_id>, and a public_id may itself
  -- contain ':' -- so take everything from the fifth field on, not just it.
  public_id := substr(new.file_url, length(split_part(new.file_url, ':', 1) || ':' ||
                                           split_part(new.file_url, ':', 2) || ':' ||
                                           split_part(new.file_url, ':', 3) || ':' ||
                                           split_part(new.file_url, ':', 4) || ':') + 1);

  if public_id !~ ('^accommo/docs/' || auth.uid()::text || '/') then
    raise exception 'A document may only reference a file you uploaded.';
  end if;

  return new;
end $$;

revoke all on function public.lock_document_ref() from anon, authenticated;

drop trigger if exists trg_lock_document_ref on public.verification_documents;
create trigger trg_lock_document_ref before insert or update on public.verification_documents
  for each row execute function public.lock_document_ref();

drop trigger if exists trg_lock_document_ref on public.accommodation_documents;
create trigger trg_lock_document_ref before insert or update on public.accommodation_documents
  for each row execute function public.lock_document_ref();

commit;
