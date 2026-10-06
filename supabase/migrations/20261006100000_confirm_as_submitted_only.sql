-- "Only part of it arrived" is gone (20261006070000 let a landlord/landlady
-- confirm a lower amount than the student submitted). Lowering a student's
-- figure on their behalf was too easy to get wrong or abuse; a payment is now
-- confirmed exactly as submitted, or rejected with a reason and resubmitted.
-- claimed_amount stays for the rows already confirmed that way.

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

select pg_temp.patch_fn('public.tg_payment_rules',
  $p$    -- The one amount change: confirming only what actually arrived.
    if new.amount is distinct from old.amount then
      if v_student or old.status::text <> 'pending_verification' or new.status::text <> 'paid'
         or new.amount > old.amount or new.amount <= 0 then
        raise exception 'A payment''s amount can only be lowered to what actually arrived, while confirming it.';
      end if;
      new.claimed_amount := coalesce(old.claimed_amount, old.amount);
    end if;$p$,
  $p$    if new.amount is distinct from old.amount then
      raise exception 'A payment''s amount can''t be changed. Reject it so the student can submit the right amount.';
    end if;$p$);

select pg_temp.patch_fn('public.review_payment',
  $p$  if p_action = 'confirm' then
$p$,
  $p$  if p_action = 'confirm' then
    if p_received is not null then
      raise exception 'A payment is confirmed as submitted. If the amount is wrong, reject it so the student can resubmit.';
    end if;
$p$);
