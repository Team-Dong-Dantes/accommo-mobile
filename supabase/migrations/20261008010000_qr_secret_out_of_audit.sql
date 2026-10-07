-- qr_code_token is now the HMAC key behind the 5-second student QR, so it is
-- a secret, not a value to keep history of. The audit trigger stops recording it
-- (and a change to it alone is not an audit event), the copies already in
-- audit_logs are scrubbed, and every student gets a new key: the old ones were
-- shown inside the old hour-long QR codes.

CREATE OR REPLACE FUNCTION public.fn_audit_log_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_action     text;
    v_entity_id  text;
    v_before     jsonb;
    v_after      jsonb;
    v_actor      uuid := auth.uid();
    v_pk         text;
    row_json     jsonb;
begin
    -- Bookkeeping columns: an UPDATE that moved only these changed nothing.
    if TG_OP = 'UPDATE'
       and (to_jsonb(NEW) - 'updated_at' - 'last_login_at' - 'qr_code_token') = (to_jsonb(OLD) - 'updated_at' - 'last_login_at' - 'qr_code_token') then
        return NEW;
    end if;

    case TG_OP
        when 'INSERT' then v_action := 'CREATE';
        when 'DELETE' then v_action := 'DELETE';
        else               v_action := 'UPDATE';
    end case;

    if TG_OP in ('INSERT', 'UPDATE') then
        v_after := to_jsonb(NEW) - 'qr_code_token';
        row_json := v_after;
    else
        row_json := to_jsonb(OLD);
    end if;
    if TG_OP in ('UPDATE', 'DELETE') then
        v_before := to_jsonb(OLD) - 'qr_code_token';
    end if;

    -- Resolve the primary key column name for THIS table, then read its value
    -- off the row JSON (handles uuid and varchar/text/numeric PKs alike).
    select a.attname into v_pk
    from pg_index i
    join pg_attribute a
         on a.attrelid = i.indrelid
        and a.attnum  = any(i.indkey)
    where i.indrelid = TG_RELID
      and i.indisprimary
    limit 1;

    v_entity_id := coalesce(row_json ->> v_pk, '');

    insert into public.audit_logs (
        actor_id, action, entity_type, entity_id, before_json, after_json,
        created_at, ip_address, user_agent
    ) values (
        v_actor, v_action, TG_TABLE_NAME, v_entity_id, v_before, v_after,
        now(),
        nullif(nullif(current_setting('audit.ip_address', true), ''), null),
        nullif(nullif(current_setting('audit.user_agent', true), ''), null)
    );

    return coalesce(NEW, OLD);
end;
$function$;

update public.audit_logs
   set before_json = before_json - 'qr_code_token',
       after_json = after_json - 'qr_code_token'
 where entity_type = 'student_profiles'
   and (before_json ? 'qr_code_token' or after_json ? 'qr_code_token');

update public.student_profiles set qr_code_token = null where qr_code_token is not null;
