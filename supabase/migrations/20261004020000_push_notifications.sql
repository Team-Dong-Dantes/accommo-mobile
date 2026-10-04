-- Push notifications. Every notification is a row in public.notifications, from
-- whichever trigger, RPC or client wrote it, so one AFTER INSERT trigger there
-- covers them all: it hands the row and the recipient's device tokens to the
-- send-push edge function, which delivers them through FCM.
--
-- The function's URL and shared secret live in Vault ('push_url',
-- 'push_secret'), not here. A database without them (a local reset, CI) simply
-- sends nothing.

create extension if not exists pg_net with schema extensions;

create table if not exists public.push_tokens (
  token      text        primary key,
  user_id    uuid        not null references public.users(id) on delete cascade,
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user_id_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

-- Writes go through register_push_token(); a user may only see and drop their own.
create policy push_tokens_select_own on public.push_tokens
  for select to authenticated using (user_id = (select auth.uid()));
create policy push_tokens_delete_own on public.push_tokens
  for delete to authenticated using (user_id = (select auth.uid()));

-- A security-definer upsert rather than an insert policy: a token belongs to a
-- device, not a person, so when a second account signs in on the same phone
-- the row has to move to them — an update RLS would refuse, since the row
-- still names the previous account.
create or replace function public.register_push_token(p_token text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in.'; end if;
  if coalesce(length(p_token), 0) not between 1 and 4096 then raise exception 'Bad token.'; end if;
  insert into public.push_tokens (token, user_id) values (p_token, auth.uid())
  on conflict (token) do update set user_id = excluded.user_id, updated_at = now();
end $$;

revoke all on function public.register_push_token(text) from public, anon;
grant execute on function public.register_push_token(text) to authenticated;

create or replace function public.tg_notification_push()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_url    text;
  v_secret text;
  v_tokens text[];
begin
  -- The Settings toggle. Defaults to on, as the column does.
  if (select (notification_prefs ->> 'push') = 'false' from public.users where id = new.user_id) then
    return null;
  end if;

  select array_agg(token) into v_tokens from public.push_tokens where user_id = new.user_id;
  if v_tokens is null then return null; end if;

  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'push_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_secret';
  if v_url is null or v_secret is null then return null; end if;

  -- pg_net queues the request and returns at once, so a slow or failing push
  -- never holds up or rolls back the insert that caused it.
  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object('content-type', 'application/json', 'x-push-secret', v_secret),
    body    := jsonb_build_object(
      'tokens', to_jsonb(v_tokens),
      'id', new.id, 'type', new.type, 'title', new.title, 'body', new.body,
      'link_url', new.link_url, 'ref_id', new.ref_id
    )
  );
  return null;
end $$;

revoke all on function public.tg_notification_push() from public, anon, authenticated;

drop trigger if exists notification_push on public.notifications;
create trigger notification_push
  after insert on public.notifications
  for each row execute function public.tg_notification_push();
