-- Pin search_path on the small pure helpers the security advisor flags as
-- "Function Search Path Mutable". They only touch pg_catalog built-ins, which
-- stay reachable with an empty path.
alter function public.admin_levels_valid(jsonb) set search_path = '';
alter function public.rent_due_date(smallint, date, date) set search_path = '';
alter function public.peso(numeric) set search_path = '';
alter function public.accreditation_term() set search_path = '';
alter function public.permit_label(text) set search_path = '';
