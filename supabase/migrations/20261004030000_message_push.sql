-- Chat messages push too, but without a bell row (the per-message notification
-- was removed from the bell on purpose) and without their text: the push only
-- says someone wrote. One push per conversation until the recipient reads it,
-- so a burst of messages is one buzz, not twenty.

-- The send half of tg_notification_push, so a message can push without
-- writing a notifications row.
create or replace function public.send_push(p_user uuid, p_payload jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_url    text;
  v_secret text;
  v_tokens text[];
begin
  -- The Settings toggle. Defaults to on, as the column does.
  if (select (notification_prefs ->> 'push') = 'false' from public.users where id = p_user) then
    return;
  end if;

  select array_agg(token) into v_tokens from public.push_tokens where user_id = p_user;
  if v_tokens is null then return; end if;

  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'push_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_secret';
  if v_url is null or v_secret is null then return; end if;

  -- pg_net queues the request and returns at once, so a slow or failing push
  -- never holds up or rolls back the write that caused it.
  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object('content-type', 'application/json', 'x-push-secret', v_secret),
    body    := p_payload || jsonb_build_object('tokens', to_jsonb(v_tokens))
  );
end $$;

revoke all on function public.send_push(uuid, jsonb) from public, anon, authenticated;

create or replace function public.tg_notification_push()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.send_push(new.user_id, jsonb_build_object(
    'id', new.id, 'type', new.type, 'title', new.title, 'body', new.body,
    'link_url', new.link_url, 'ref_id', new.ref_id
  ));
  return null;
end $$;

create or replace function public.tg_message_push()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  c         public.conversations;
  v_to      uuid;
  v_unread  int;
  v_sender  public.users;
  v_to_role public.user_role;
begin
  select * into c from public.conversations where id = new.conversation_id;
  if not found then return null; end if;

  if c.user_a_id = new.sender_id then
    v_to := c.user_b_id; v_unread := c.unread_b;
  else
    v_to := c.user_a_id; v_unread := c.unread_a;
  end if;

  -- messages_after_insert has already counted this message, so 1 means it is
  -- the first one the recipient has not read yet.
  if v_to is null or v_unread <> 1 then return null; end if;

  select * into v_sender from public.users where id = new.sender_id;
  select role into v_to_role from public.users where id = v_to;

  perform public.send_push(v_to, case
    when v_sender.role = 'student' and v_to_role = 'landlord' then jsonb_build_object(
      'type', 'message', 'title', 'New inquiry', 'body', 'A student wants to inquire.')
    else jsonb_build_object(
      'type', 'message', 'title', 'New message',
      'body', coalesce(nullif(trim(v_sender.full_name), ''), 'Someone') || ' sent you a message.')
  end);
  return null;
end $$;

revoke all on function public.tg_message_push() from public, anon, authenticated;

-- Named to sort after messages_after_insert: same-event triggers fire in name
-- order, and this one reads the unread count that one maintains.
drop trigger if exists messages_push on public.messages;
create trigger messages_push
  after insert on public.messages
  for each row execute function public.tg_message_push();
