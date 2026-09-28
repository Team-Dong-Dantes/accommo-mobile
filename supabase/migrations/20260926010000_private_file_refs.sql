-- Payment proofs, chat photos, concern photos and support-ticket photos move
-- to the same signed Cloudinary delivery as requirements: the row stores a
-- `cld:` reference, and doc-access signs a 5-minute link for whoever the row's
-- own RLS lets read it.
--
-- lock_document_ref() already stops a requirement pointing at someone else's
-- file. This is the same rule for any column, named as the trigger argument,
-- text or text[] alike.

create or replace function public.lock_private_ref()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  col text := tg_argv[0];
  v jsonb := to_jsonb(new) -> col;
  refs text[];
  r text;
begin
  if auth.uid() is null or public.is_admin(auth.uid()) then return new; end if;
  if tg_op = 'UPDATE' and v is not distinct from (to_jsonb(old) -> col) then return new; end if;

  refs := case jsonb_typeof(v)
            when 'array'  then array(select jsonb_array_elements_text(v))
            when 'string' then array[v #>> '{}']
            else '{}'::text[] end;

  foreach r in array refs loop
    -- cld:<resource_type>:<type>:<format>:<public_id>; only signed refs are pinned.
    continue when r not like 'cld:%';
    if substr(r, length(split_part(r, ':', 1) || ':' || split_part(r, ':', 2) || ':' ||
                        split_part(r, ':', 3) || ':' || split_part(r, ':', 4) || ':') + 1)
       !~ ('^accommo/docs/' || auth.uid()::text || '/') then
      raise exception 'A file may only reference something you uploaded.';
    end if;
  end loop;
  return new;
end $$;

revoke all on function public.lock_private_ref() from public, anon, authenticated;

drop trigger if exists trg_lock_private_ref on public.payments;
create trigger trg_lock_private_ref before insert or update on public.payments
  for each row execute function public.lock_private_ref('proof_url');

drop trigger if exists trg_lock_private_ref on public.messages;
create trigger trg_lock_private_ref before insert or update on public.messages
  for each row execute function public.lock_private_ref('attachment_url');

drop trigger if exists trg_lock_private_ref on public.concerns;
create trigger trg_lock_private_ref before insert or update on public.concerns
  for each row execute function public.lock_private_ref('photo_url');

drop trigger if exists trg_lock_private_ref on public.tickets;
create trigger trg_lock_private_ref before insert or update on public.tickets
  for each row execute function public.lock_private_ref('photo_urls');

drop trigger if exists trg_lock_private_ref on public.ticket_messages;
create trigger trg_lock_private_ref before insert or update on public.ticket_messages
  for each row execute function public.lock_private_ref('attachment_urls');
