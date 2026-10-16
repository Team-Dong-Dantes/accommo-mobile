-- A reaction pushes to the message's author, the same way a new message does:
-- a buzz with no bell row (chat stays out of the bell on purpose, see
-- 20261004030000_message_push.sql), and none for a muted thread.
--
-- Only a first reaction pushes. Swapping one emoji for another, or taking it
-- off, is silent, so tapping through the reaction bar is not a buzz per tap.
--
-- Body is 20261015000000_messaging_controls.sql's react_to_message() plus the
-- push at the end.
create or replace function public.react_to_message(p_message uuid, p_emoji text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_emoji  text := nullif(p_emoji, '');
  v_before jsonb;
  v_author uuid;
  v_convo  uuid;
  v_name   text;
  v_role   public.user_role;
begin
  if v_emoji is not null and v_emoji not in ('👍', '❤️', '😂', '😮', '😢', '🙏') then
    raise exception 'Unsupported reaction.' using errcode = '22023';
  end if;
  select m.reactions, m.sender_id, m.conversation_id into v_before, v_author, v_convo
    from messages m where m.id = p_message;
  update messages m
     set reactions = case when v_emoji is null then m.reactions - v_uid::text
                          else m.reactions || jsonb_build_object(v_uid::text, v_emoji) end
   where m.id = p_message
     and m.deleted_at is null
     and exists (select 1 from conversations c
                  where c.id = m.conversation_id and v_uid in (c.user_a_id, c.user_b_id));
  if not found then
    raise exception 'Message not found.' using errcode = 'P0002';
  end if;

  if v_emoji is null or v_author = v_uid or v_before ? v_uid::text then return; end if;
  if exists (select 1 from conversation_prefs p
              where p.conversation_id = v_convo and p.user_id = v_author and p.muted) then
    return;
  end if;

  select coalesce(nullif(trim(full_name), ''), 'Someone') into v_name from users where id = v_uid;
  select role into v_role from users where id = v_author;
  perform public.send_push(v_author, jsonb_build_object(
    'type', 'message',
    'title', 'New reaction',
    'body', v_name || ' reacted ' || v_emoji || ' to your message.',
    'link_url', case when v_role = 'landlord' then '/manager' else '/student' end || '/messages?c=' || v_convo
  ));
end $$;

revoke all on function public.react_to_message(uuid, text) from public, anon;
grant execute on function public.react_to_message(uuid, text) to authenticated;
