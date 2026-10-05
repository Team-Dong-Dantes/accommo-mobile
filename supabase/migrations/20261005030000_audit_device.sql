-- Record who-was-where on every audit entry.
--
-- audit_logs.ip_address / user_agent were read from audit.* settings that no
-- client ever set, so every row had them empty. One BEFORE INSERT trigger now
-- fills whatever the writer left empty from the API request's headers, which
-- covers fn_audit_log_change and every function that inserts its own entry.
-- Rows written outside an API request (cron, auth hooks) stay empty.

create or replace function public.audit_fill_device()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  h json := nullif(current_setting('request.headers', true), '')::json;
begin
  if h is null then
    return new;
  end if;
  new.ip_address := coalesce(new.ip_address,
    nullif(h ->> 'cf-connecting-ip', ''),
    nullif(trim(split_part(h ->> 'x-forwarded-for', ',', 1)), ''),
    nullif(h ->> 'x-real-ip', ''));
  new.user_agent := coalesce(new.user_agent, left(nullif(h ->> 'user-agent', ''), 500));
  return new;
exception when others then
  -- A malformed header must never block the write it is describing.
  return new;
end;
$$;

drop trigger if exists audit_fill_device on public.audit_logs;
create trigger audit_fill_device before insert on public.audit_logs
  for each row execute function public.audit_fill_device();
