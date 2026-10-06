-- "Request new requirements" changed only users.status, so the account read
-- Needs resubmission while its documents still read Approved — and once the
-- person re-uploaded one file, the others showed Approved again. The request
-- now names the documents (p_docs) and marks them rejected; marking an account
-- verified approves its documents the same way.

drop function public.admin_set_account_status(uuid, public.user_status, text, timestamp with time zone, text[]);

CREATE OR REPLACE FUNCTION public.admin_set_account_status(p_user uuid, p_status user_status, p_reason text DEFAULT NULL::text, p_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_restrictions text[] DEFAULT NULL::text[], p_docs text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid := auth.uid();
  v_user public.users;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_old_restr text[];
  v_restr text[];
  v_added text[];
  v_removed text[];
  v_until_txt text;
begin
  if not public.is_admin(v_me) then
    raise exception 'Only OSAS can change an account''s status.' using errcode = '42501';
  end if;

  select * into v_user from public.users where id = p_user for update;
  if not found then
    raise exception 'That account no longer exists.';
  end if;
  if v_user.role = 'admin' or v_user.is_superadmin then
    raise exception 'Administrator accounts are managed under Settings.';
  end if;
  if not (public.can_edit('accounts')
          or (public.can_edit('verification')
              and v_user.status in ('pending', 'reviewing')
              and p_status in ('pending', 'reviewing', 'verified', 'rejected', 'needs_resubmission')
              and p_until is null and p_restrictions is null)) then
    raise exception 'Your admin access doesn''t include this change.' using errcode = '42501';
  end if;

  select restrictions into v_old_restr from public.account_standing where user_id = p_user;
  v_old_restr := coalesce(v_old_restr, '{}');
  v_restr := coalesce(p_restrictions, v_old_restr);
  v_added := array(select unnest(v_restr) except select unnest(v_old_restr));
  v_removed := array(select unnest(v_old_restr) except select unnest(v_restr));

  if 'apply' = any(v_added) and v_user.role <> 'student' then
    raise exception 'Only a student can be stopped from applying for rooms.';
  end if;
  if 'listings' = any(v_added) and v_user.role <> 'landlord' then
    raise exception 'Only a landlord/landlady has listings to hide.';
  end if;

  if v_reason is null and (
       (p_status in ('suspended', 'rejected', 'needs_resubmission') and p_status is distinct from v_user.status)
       or cardinality(v_added) > 0
     ) then
    raise exception 'Give a reason — the person is told it.';
  end if;

  if p_until is not null then
    if p_status <> 'suspended' then
      raise exception 'An end date only applies to a suspension.';
    end if;
    if p_until <= now() then
      raise exception 'The end date must be in the future.';
    end if;
    if v_user.status not in ('verified', 'suspended') then
      raise exception 'Only a verified account can be suspended until a date.';
    end if;
  end if;

  if p_status is distinct from v_user.status then
    update public.users set status = p_status, updated_at = now() where id = p_user;
  end if;

  -- The documents carry the decision too, or the account says "upload again"
  -- while every file still reads Approved. p_docs names the ones OSAS wants
  -- again; left out, the whole set is sent back.
  if p_status is distinct from v_user.status and p_status in ('rejected', 'needs_resubmission') then
    if p_docs is not null and cardinality(p_docs) = 0 then
      raise exception 'Pick the requirement they need to upload again.';
    end if;
    update public.verification_documents
       set status = 'rejected', verified_at = now(), verified_by = v_me
     where user_id = p_user and (p_docs is null or doc_type = any(p_docs));
  elsif p_status is distinct from v_user.status and p_status = 'verified' and v_user.status <> 'suspended' then
    update public.verification_documents
       set status = 'approved', verified_at = now(), verified_by = v_me
     where user_id = p_user and status <> 'approved';
  end if;

  insert into public.account_standing (user_id, reason, suspended_until, restrictions, updated_by, updated_at)
  values (
    p_user,
    v_reason,
    case when p_status = 'suspended' then p_until end,
    v_restr,
    v_me,
    now()
  )
  on conflict (user_id) do update
    set reason = excluded.reason,
        suspended_until = excluded.suspended_until,
        restrictions = excluded.restrictions,
        updated_by = excluded.updated_by,
        updated_at = excluded.updated_at;

  if 'listings' = any(v_added) then
    update public.accommodations set hidden_from_listings = true where landlord_id = p_user;
  elsif 'listings' = any(v_removed) then
    update public.accommodations set hidden_from_listings = false where landlord_id = p_user;
  end if;

  if p_status is distinct from v_user.status and p_status in ('rejected', 'needs_resubmission', 'verified') then
    insert into public.verification_requests
      (entity_type, entity_id, type, status, reviewed_by, reviewed_at, decision_notes)
    values (
      'user',
      p_user,
      coalesce(
        (select string_agg(case t when 'school_id' then 'School ID' when 'assessment_of_fees' then 'Assessment of fees'
                                  when 'government_id' then 'Government ID' when 'business_permit' then 'Business permit' else t end, ', ')
           from unnest(p_docs) t),
        case when v_user.role = 'landlord' then 'Landlord/Landlady Identity' else 'Enrollment Form / COR' end),
      case p_status when 'verified' then 'approved' when 'needs_resubmission' then 'resubmission_requested' else 'rejected' end,
      v_me,
      now(),
      v_reason
    );
  end if;

  v_until_txt := case when p_until is not null
    then ' until ' || to_char(p_until at time zone 'Asia/Manila', 'Mon FMDD, YYYY')
    else '' end;

  if p_status is distinct from v_user.status then
    insert into public.notifications (user_id, type, title, body, link_url)
    select p_user, 'verification', t.title, t.body, '/profile'
    from (values
      (case p_status
         when 'suspended' then 'Account suspended'
         when 'needs_resubmission' then 'Resubmission requested'
         when 'rejected' then 'Verification rejected'
         when 'verified' then case when v_user.status = 'suspended' then 'Account reactivated' else 'Verification approved' end
       end,
       case p_status
         when 'suspended' then 'OSAS suspended your account' || v_until_txt || '. Reason: ' || v_reason
         when 'needs_resubmission' then 'OSAS needs new requirements from you. Note: ' || v_reason
         when 'rejected' then 'OSAS rejected your requirements. Reason: ' || v_reason
         when 'verified' then case when v_user.status = 'suspended'
           then 'Your account is active again.' || coalesce(' Note: ' || v_reason, '')
           else 'Your account has been verified.' end
       end)
    ) as t(title, body)
    where t.title is not null;
  end if;

  if 'apply' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Room applications paused',
            'OSAS has paused your room applications. Reason: ' || v_reason, '/profile');
  end if;
  if 'apply' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Room applications restored', 'You can apply for rooms again.', '/profile');
  end if;
  if 'listings' = any(v_added) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Listings hidden',
            'OSAS has hidden your accommodations from students. Reason: ' || v_reason, '/profile');
  end if;
  if 'listings' = any(v_removed) then
    insert into public.notifications (user_id, type, title, body, link_url)
    values (p_user, 'system', 'Listings visible again', 'Students can see your accommodations again.', '/profile');
  end if;
end $function$;

revoke all on function public.admin_set_account_status(uuid, public.user_status, text, timestamp with time zone, text[], text[]) from public, anon;
grant all on function public.admin_set_account_status(uuid, public.user_status, text, timestamp with time zone, text[], text[]) to authenticated, service_role;

