-- "Last active" that follows people actually using the app.
--
-- users.last_login_at was only ever written by handle_auth_user_sync(), whose
-- INSERT branch set it to null and whose UPDATE branch never copied
-- auth.users.last_sign_in_at — so no real sign-in reached it and the admin
-- Users page read "Never". And a sign-in time alone would not be enough: a
-- saved session reopened days later is not a sign-in.
--
-- 1. touch_last_active(): both apps call it when opened or brought back to the
--    foreground. Throttled here to one write per 5 minutes per person.
-- 2. The auth sync also carries last_sign_in_at across, so a sign-in counts.
-- 3. Backfill from auth.users.
-- 4. The audit trigger ignores last_login_at the way it ignores updated_at:
--    an app being opened is activity, not a change worth an audit row.

-- 1 ---------------------------------------------------------------------------
create or replace function public.touch_last_active() returns void
language sql security definer set search_path to 'public' as $$
  update public.users
     set last_login_at = now()
   where id = auth.uid()
     and (last_login_at is null or last_login_at < now() - interval '5 minutes');
$$;
revoke all on function public.touch_last_active() from public, anon;
grant execute on function public.touch_last_active() to authenticated;

-- 2 ---------------------------------------------------------------------------
create or replace function public.handle_auth_user_sync() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_domain text;
  v_allowed text[] := array['gmail.com', 'isu.edu.ph'];
  v_dob date;
begin
  begin
    v_dob := nullif(new.raw_user_meta_data ->> 'date_of_birth', '')::date;
  exception when others then
    v_dob := null;
  end;

  if tg_op = 'INSERT' then
    v_domain := lower(split_part(coalesce(new.email, ''), '@', 2));
    if v_domain <> all (v_allowed) then
      raise exception using
        errcode = 'check_violation',
        message = format('accommo: e-mail domain %L is not accepted', v_domain),
        hint = 'Accommo accounts must use @gmail.com or @isu.edu.ph.';
    end if;

    insert into public.users (
      id, email, phone, role, status, full_name, initials, avatar_color, sex,
      date_of_birth, email_verified_at, created_at, updated_at, last_login_at
    )
    values (
      new.id,
      new.email,
      coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, '+639000000000'),
      coalesce((new.raw_user_meta_data ->> 'role')::text, 'student')::user_role,
      'pending'::user_status,
      coalesce(new.raw_user_meta_data ->> 'full_name', 'Demo User'),
      coalesce(new.raw_user_meta_data ->> 'initials', 'DU'),
      coalesce((new.raw_user_meta_data ->> 'avatar_color'), 'blue'),
      nullif(new.raw_user_meta_data ->> 'sex', ''),
      v_dob,
      case when v_provider <> 'email' then coalesce(new.email_confirmed_at, now()) else null end,
      now(), now(), new.last_sign_in_at
    )
    on conflict (id) do update
      set email = excluded.email,
          phone = excluded.phone,
          role = excluded.role,
          full_name = excluded.full_name,
          initials = excluded.initials,
          avatar_color = excluded.avatar_color,
          sex = coalesce(excluded.sex, public.users.sex),
          date_of_birth = coalesce(excluded.date_of_birth, public.users.date_of_birth),
          email_verified_at = coalesce(public.users.email_verified_at, excluded.email_verified_at),
          updated_at = now();
    return new;

  elsif tg_op = 'UPDATE' then
    perform set_config('app.syncing_auth', 'true', true);
    update public.users
    set email = new.email,
        phone = case
          when new.phone is distinct from old.phone
            or (new.raw_user_meta_data ->> 'phone') is distinct from (old.raw_user_meta_data ->> 'phone')
          then coalesce(new.phone, (new.raw_user_meta_data ->> 'phone')::text, phone)
          else phone
        end,
        date_of_birth = case
          when (new.raw_user_meta_data ->> 'date_of_birth') is distinct from (old.raw_user_meta_data ->> 'date_of_birth')
          then coalesce(v_dob, public.users.date_of_birth)
          else public.users.date_of_birth
        end,
        email_verified_at = case
          when public.users.email_verified_at is not null then public.users.email_verified_at
          when v_provider <> 'email' then coalesce(new.email_confirmed_at, now())
          else null
        end,
        -- A sign-in is activity too; greatest() ignores null on either side.
        last_login_at = greatest(public.users.last_login_at, new.last_sign_in_at),
        updated_at = now()
    where id = new.id;
    return new;

  elsif tg_op = 'DELETE' then
    delete from public.users where id = old.id;
    return old;
  end if;

  return null;
end;
$$;

-- 3 ---------------------------------------------------------------------------
-- Replaying old sign-ins is housekeeping, not an event: keep it out of the audit log.
alter table public.users disable trigger trg_audit_users;
update public.users u
   set last_login_at = a.last_sign_in_at
  from auth.users a
 where a.id = u.id
   and a.last_sign_in_at is not null
   and (u.last_login_at is null or u.last_login_at < a.last_sign_in_at);
alter table public.users enable trigger trg_audit_users;

-- 4 ---------------------------------------------------------------------------
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
    -- Bookkeeping columns: an UPDATE that moved only these changed nothing.
    if TG_OP = 'UPDATE'
       and (to_jsonb(NEW) - 'updated_at' - 'last_login_at') = (to_jsonb(OLD) - 'updated_at' - 'last_login_at') then
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
