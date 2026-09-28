-- One row per user per document type.
--
-- `registerManager` inserted its two documents unconditionally, so a retried
-- registration wrote a second copy of each — same file, minutes apart, both
-- pending. The manager's record then listed every document twice, and a
-- resubmission could leave a stale rejected row sitting beside the new pending
-- one, because ManagerOsasPage only updates the row it happened to have loaded.
--
-- Enforced here rather than in each caller: three code paths write this table
-- across two apps, and a guard in each is three chances to miss one. With the
-- constraint, a re-upload has to be an upsert and "the latest document" and
-- "the only document" become the same thing.
--
-- Unlike accommodation_documents, this table has no `version` column and never
-- kept history on purpose — a superseded personal document is not a record
-- worth holding, it is the same document photographed again.

-- Drop superseded copies first, keeping the newest upload of each pair.
delete from public.verification_documents vd
where exists (
  select 1
  from public.verification_documents newer
  where newer.user_id = vd.user_id
    and newer.doc_type = vd.doc_type
    and (newer.uploaded_at, newer.id) > (vd.uploaded_at, vd.id)
);

create unique index if not exists verification_documents_user_doc_type_key
  on public.verification_documents (user_id, doc_type);
