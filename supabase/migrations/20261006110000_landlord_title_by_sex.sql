-- Messages about one specific landlord/landlady call them by their own title:
-- Landlord (users.sex = 'M'), Landlady ('F'), or the neutral compound when sex
-- is not on file. Generic wording (rules about the role, anonymous ratings)
-- keeps "landlord/landlady". Mirrors landlordTitle() in both apps.

create or replace function public.landlord_title(p_user uuid)
returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce((
    select case upper(btrim(coalesce(u.sex, ''))) when 'M' then 'landlord' when 'F' then 'landlady' end
      from public.users u where u.id = p_user
  ), 'landlord/landlady');
$$;
revoke all on function public.landlord_title(uuid) from public, anon;
grant execute on function public.landlord_title(uuid) to authenticated;

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

-- Payments: the student's own landlord/landlady (l is the stay).
select pg_temp.patch_fn('public.tg_payment_rules',
  $p$raise exception 'The advance and deposit are settled with your landlord/landlady when a stay ends.';$p$,
  $p$raise exception 'The advance and deposit are settled with your % when a stay ends.', public.landlord_title(l.landlord_id);$p$);
select pg_temp.patch_fn('public.tg_payment_rules',
  $p$raise exception 'Only your landlord/landlady can forgive a balance.';$p$,
  $p$raise exception 'Only your % can forgive a balance.', public.landlord_title(l.landlord_id);$p$);
select pg_temp.patch_fn('public.tg_payment_rules',
  $p$raise exception 'This stay has no rent set yet. Ask your landlord/landlady to set it.';$p$,
  $p$raise exception 'This stay has no rent set yet. Ask your % to set it.', public.landlord_title(l.landlord_id);$p$);
select pg_temp.patch_fn('public.tg_payment_rules',
  $p$raise exception 'Pay the full ₱% — your landlord/landlady hasn''t turned on partial payments.', to_char(v_left, 'FM999,999,990.00');$p$,
  $p$raise exception 'Pay the full ₱% — your % hasn''t turned on partial payments.', to_char(v_left, 'FM999,999,990.00'), public.landlord_title(l.landlord_id);$p$);

select pg_temp.patch_fn('public.review_payment',
  $p$else 'Your landlord/landlady confirmed '$p$,
  $p$else 'Your ' || public.landlord_title(l.landlord_id) || ' confirmed '$p$);
select pg_temp.patch_fn('public.review_payment',
  $p$'Your landlord/landlady undid the confirmation of '$p$,
  $p$'Your ' || public.landlord_title(l.landlord_id) || ' undid the confirmation of '$p$);

select pg_temp.patch_fn('public.waive_balance',
  $p$'Your landlord/landlady forgave '$p$,
  $p$'Your ' || public.landlord_title(l.landlord_id) || ' forgave '$p$);
select pg_temp.patch_fn('public.waive_balance',
  $p$raise exception 'Only the landlord/landlady of this stay can forgive a balance.' using errcode = '42501';$p$,
  $p$raise exception 'Only the % of this stay can forgive a balance.', public.landlord_title(l.landlord_id) using errcode = '42501';$p$);

-- Notifications to a student about their landlord/landlady.
select pg_temp.patch_fn('public.tg_lease_notify',
  $p$'Your landlord/landlady added you to '$p$,
  $p$'Your ' || public.landlord_title(new.landlord_id) || ' added you to '$p$);
select pg_temp.patch_fn('public.tg_invite_notify',
  $p$'Your landlord/landlady sent you an application form for '$p$,
  $p$'Your ' || public.landlord_title(v_landlord) || ' sent you an application form for '$p$);

-- About one named person (the new row itself: its sex, not a lookup).
select pg_temp.patch_fn('public.trg_new_landlord',
  $p$      'New landlord/landlady registered',
      coalesce(new.full_name, new.email)
        || ' joined as a landlord/landlady and needs verification.',$p$,
  $p$      'New ' || case upper(btrim(coalesce(new.sex, ''))) when 'M' then 'landlord' when 'F' then 'landlady' else 'landlord/landlady' end || ' registered',
      coalesce(new.full_name, new.email)
        || ' joined as a ' || case upper(btrim(coalesce(new.sex, ''))) when 'M' then 'landlord' when 'F' then 'landlady' else 'landlord/landlady' end || ' and needs verification.',$p$);
select pg_temp.patch_fn('public.admin_change_role',
  $p$else 'a landlord/landlady' end$p$,
  $p$else 'a ' || public.landlord_title(p_user) end$p$);
