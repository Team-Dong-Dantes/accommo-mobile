-- An escalated concern now points at the concern it came from.
--
-- Escalation used to insert a bare ticket with the student's id on it, so it
-- showed up in the student's OSAS tab as a ticket they never filed, the concern
-- itself never showed it had gone to OSAS, and each extra tap filed a duplicate.
-- Unique: one OSAS ticket per concern. Null for every ticket filed directly.
alter table public.tickets
  add column if not exists concern_id uuid unique references public.concerns(id) on delete set null;
