-- Only adults may use Accommo. The birth-date bound moves from "not in the
-- future" to "at least 18 years ago". Two existing accounts carried dates under
-- that bound (one a typo for this year); their date is cleared so OSAS can
-- re-enter the real one from the person's ID.

update public.users
   set date_of_birth = null
 where date_of_birth > current_date - interval '18 years';

alter table public.users drop constraint users_date_of_birth_plausible;
alter table public.users add constraint users_date_of_birth_plausible check (
  date_of_birth is null
  or (date_of_birth > '1900-01-01'::date and date_of_birth <= current_date - interval '18 years')
);
