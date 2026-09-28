-- Stop auditing updates that change nothing.
--
-- Most `users` UPDATE rows in audit_logs were noise: the row was rewritten with
-- identical values, or only `updated_at` moved (566 of 768 over two weeks).
-- They buried every real action on the admin Audit Logs page. An UPDATE whose
-- row is unchanged apart from `updated_at` is now not written at all.
--
-- Existing no-op rows are left in place — the audit trail stays append-only;
-- the page hides them instead. The function is otherwise the baseline's.

create or replace function public.fn_audit_log_change() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
    v_action     text;
    v_entity_id  text;
    v_before     jsonb;
    v_after      jsonb;
    v_actor      uuid := auth.uid();
    v_pk         text;
    row_json     jsonb;
begin
    if TG_OP = 'UPDATE' and (to_jsonb(NEW) - 'updated_at') = (to_jsonb(OLD) - 'updated_at') then
        return NEW;
    end if;

    case TG_OP
        when 'INSERT' then v_action := 'CREATE';
        when 'DELETE' then v_action := 'DELETE';
        else               v_action := 'UPDATE';
    end case;

    if TG_OP in ('INSERT', 'UPDATE') then
        v_after := to_jsonb(NEW);
        row_json := v_after;
    else
        row_json := to_jsonb(OLD);
    end if;
    if TG_OP in ('UPDATE', 'DELETE') then
        v_before := to_jsonb(OLD);
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
$$;
