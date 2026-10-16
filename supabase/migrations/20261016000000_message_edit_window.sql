-- Edit and unsend close 15 minutes after a message is sent. The client hides
-- the menu items past that (CHANGE_WINDOW_MS in src/utils/chat.ts); this is
-- what enforces it. Keep the two intervals in step.
--
-- Body is 20261015000000_messaging_controls.sql's tg_message_before_update()
-- plus the window check.
create or replace function public.tg_message_before_update() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user <> 'authenticated' then return new; end if;
  if old.deleted_at is not null then
    raise exception 'This message was removed.' using errcode = '42501';
  end if;
  if (new.deleted_at is not null or new.body is distinct from old.body)
     and old.sent_at < now() - interval '15 minutes' then
    raise exception 'Messages can only be edited or unsent within 15 minutes of sending.' using errcode = '42501';
  end if;
  if new.deleted_at is not null then
    new.deleted_at       := now();
    new.body             := '';
    new.attachment_url   := null;
    new.accommodation_id := null;
    new.reactions        := '{}'::jsonb;
    return new;
  end if;
  if new.attachment_url is distinct from old.attachment_url then
    raise exception 'A sent file cannot be swapped. Unsend it instead.' using errcode = '42501';
  end if;
  if new.body is distinct from old.body then
    if trim(new.body) = '' and old.attachment_url is null then
      raise exception 'A message cannot be edited to nothing. Unsend it instead.' using errcode = '22023';
    end if;
    new.edited_at := now();
  end if;
  return new;
end $$;
