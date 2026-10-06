-- Initials come from the person's name, not a "DU" placeholder.
--
-- handle_auth_user_sync fell back to 'DU' ("Demo User") whenever sign-up
-- metadata carried no initials, and only a completed registration replaced it.
-- Every account that never went through that screen — all seeded accounts, and
-- Google sign-ups that stopped half-way — showed "DU" as its avatar in both
-- apps, because the clients prefer the stored value over computing one.

-- First letter of the first and last name parts, skipping a lone middle
-- initial, as initialsOf() does in both apps.
create or replace function public.initials_from_name(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  with parts as (
    select p, ord
      from regexp_split_to_table(btrim(coalesce(p_name, '')), '\s+') with ordinality as t(p, ord)
     where p <> '' and p !~ '^[[:alpha:]]\.?$'
  )
  select coalesce(nullif(upper(
           left((select p from parts order by ord limit 1), 1) ||
           case when (select count(*) from parts) > 1
                then left((select p from parts order by ord desc limit 1), 1) else '' end
         ), ''), '?')
$$;

create or replace function pg_temp.patch_fn(p_fn regproc, p_old text, p_new text)
returns void
language plpgsql
as $$
declare
  d text := pg_get_functiondef(p_fn);
begin
  if position(p_old in d) = 0 then
    raise exception 'patch_fn: % does not contain: %', p_fn, p_old;
  end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.patch_fn('public.handle_auth_user_sync',
  $p$coalesce(new.raw_user_meta_data ->> 'initials', 'DU'),$p$,
  $p$coalesce(new.raw_user_meta_data ->> 'initials',
               public.initials_from_name(new.raw_user_meta_data ->> 'full_name')),$p$);

-- Backfill without writing an Audit Logs entry per account.
set local session_replication_role = replica;
update public.users
   set initials = public.initials_from_name(full_name)
 where initials = 'DU'
   and public.initials_from_name(full_name) <> 'DU';
