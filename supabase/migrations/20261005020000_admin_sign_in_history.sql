-- Admin sign-in history, quieter sign-in alerts, and signing out one device.
--
--  1. notify_admin_sign_in alerted on every new auth session, so signing in
--     again from the same phone raised "New sign-in" each time. Each admin
--     sign-in is now recorded, and the alert fires only when that IP and
--     browser have not signed in to the account in the last 30 days.
--  2. my_sign_ins() lists the caller's sign-ins (90 days) with whether each
--     session is still open and which one is this device.
--  3. sign_out_session() ends one of the caller's own sessions. check_session
--     refuses that device on its next request.

create table if not exists public.sign_in_history (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.users(id) on delete cascade,
  session_id  uuid not null,
  ip          inet,
  user_agent  text,
  created_at  timestamptz not null default now()
);
create index if not exists sign_in_history_user_idx on public.sign_in_history (user_id, created_at desc);

-- Read and written only through the security-definer functions below.
alter table public.sign_in_history enable row level security;
revoke all on public.sign_in_history from public, anon, authenticated;

create or replace function public.notify_admin_sign_in()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_alerts boolean;
  v_known boolean;
begin
  select u.login_alerts into v_alerts from public.users u where u.id = new.user_id and u.role = 'admin';
  if not found then
    return new;
  end if;

  select exists (
    select 1 from public.sign_in_history h
     where h.user_id = new.user_id
       and h.ip is not distinct from new.ip
       and h.user_agent is not distinct from new.user_agent
       and h.created_at > now() - interval '30 days'
  ) into v_known;

  insert into public.sign_in_history (user_id, session_id, ip, user_agent)
  values (new.user_id, new.id, new.ip, new.user_agent);
  delete from public.sign_in_history where user_id = new.user_id and created_at < now() - interval '90 days';

  if v_alerts and not v_known then
    insert into public.notifications (user_id, type, title, body, link_url, source)
    values (
      new.user_id, 'system', 'New sign-in to your OSAS account',
      'Signed in' || coalesce(' from ' || host(new.ip), '')
        || coalesce(' using ' || left(new.user_agent, 120), '')
        || '. If this was not you, change your password in Settings.',
      '/settings', 'system'
    );
  end if;
  return new;
end;
$$;

-- Admins' open sessions count as known devices, so the phone in use now does
-- not alert on its next sign-in.
insert into public.sign_in_history (user_id, session_id, ip, user_agent, created_at)
select s.user_id, s.id, s.ip, s.user_agent, s.created_at
  from auth.sessions s
  join public.users u on u.id = s.user_id and u.role = 'admin'
 where not exists (select 1 from public.sign_in_history h where h.session_id = s.id);

create or replace function public.my_sign_ins()
returns table (session_id uuid, ip text, user_agent text, signed_in_at timestamptz,
               last_active_at timestamptz, active boolean, current boolean)
language sql
stable
security definer
set search_path to 'public', 'auth'
as $$
  select h.session_id, host(h.ip), h.user_agent, h.created_at,
         coalesce(s.refreshed_at, s.updated_at, s.created_at),
         s.id is not null,
         h.session_id::text = (auth.jwt() ->> 'session_id')
    from public.sign_in_history h
    left join auth.sessions s on s.id = h.session_id
   where h.user_id = auth.uid()
   order by h.created_at desc
   limit 50;
$$;

create or replace function public.sign_out_session(p_session uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
begin
  delete from auth.sessions where id = p_session and user_id = auth.uid();
  return found;
end;
$$;

revoke all on function public.my_sign_ins() from public, anon;
revoke all on function public.sign_out_session(uuid) from public, anon;
grant execute on function public.my_sign_ins(), public.sign_out_session(uuid) to authenticated;
