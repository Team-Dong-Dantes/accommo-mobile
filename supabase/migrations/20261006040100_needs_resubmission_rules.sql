-- needs_resubmission behaves as rejected does — verification withdrawn,
-- listings delisted, sign-in kept, re-upload allowed — and only reads
-- differently. See 20261006040000.

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

-- admin_set_account_status: OSAS's request takes the new value; a plain
-- rejection now says so in its notice and its verification history.
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$p_status in ('pending', 'reviewing', 'verified', 'rejected')$p$,
  $p$p_status in ('pending', 'reviewing', 'verified', 'rejected', 'needs_resubmission')$p$);
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$(p_status in ('suspended', 'rejected') and$p$,
  $p$(p_status in ('suspended', 'rejected', 'needs_resubmission') and$p$);
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$p_status in ('rejected', 'verified') then$p$,
  $p$p_status in ('rejected', 'needs_resubmission', 'verified') then$p$);
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$case when p_status = 'rejected' then 'resubmission_requested' else 'approved' end,$p$,
  $p$case p_status when 'verified' then 'approved' when 'needs_resubmission' then 'resubmission_requested' else 'rejected' end,$p$);
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$when 'rejected' then 'Resubmission requested'$p$,
  $p$when 'needs_resubmission' then 'Resubmission requested'
         when 'rejected' then 'Verification rejected'$p$);
select pg_temp.patch_fn('public.admin_set_account_status',
  $p$when 'rejected' then 'OSAS needs new requirements from you. Note: ' || v_reason$p$,
  $p$when 'needs_resubmission' then 'OSAS needs new requirements from you. Note: ' || v_reason
         when 'rejected' then 'OSAS rejected your requirements. Reason: ' || v_reason$p$);

-- tg_revoke_on_unverify: withdraw verification and keep sign-in, as for rejected.
select pg_temp.patch_fn('public.tg_revoke_on_unverify',
  $p$new.status in ('rejected','suspended')$p$,
  $p$new.status in ('rejected','needs_resubmission','suspended')$p$);
select pg_temp.patch_fn('public.tg_revoke_on_unverify',
  $p$new.status in ('verified','rejected','reviewing')$p$,
  $p$new.status in ('verified','rejected','needs_resubmission','reviewing')$p$);

-- lock_user_privileges: their own re-upload may put them back in the queue.
select pg_temp.patch_fn('public.lock_user_privileges',
  $p$old.status in ('rejected','unverified')$p$,
  $p$old.status in ('rejected','needs_resubmission','unverified')$p$);

-- Accounts already sent back for resubmission: the latest decision on them says so.
set local session_replication_role = replica;
update public.users u
   set status = 'needs_resubmission'
 where u.status = 'rejected'
   and (select v.status from public.verification_requests v
         where v.entity_type = 'user' and v.entity_id = u.id
         order by coalesce(v.reviewed_at, v.created_at) desc limit 1) = 'resubmission_requested';
