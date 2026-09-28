-- The two account actions that reach furthest.
--
--   * admin_change_role() — a student who becomes a landlord/landlady (or back).
--     users has one role, so this is not "both at once": it resets their
--     registration to the new role. registered_at goes back to null, which the
--     mobile guard already answers by sending them to /register/role, and they
--     register and upload that role's requirements through the normal flow
--     under the sign-in they already have. Refused while they have a live
--     lease or own any accommodation — those belong to the old role.
--
--   * admin_close_account() — the main admin only. Anonymizes; never deletes.
--     leases.student_id and leases.landlord_id cascade on delete, so deleting
--     the person would erase the other party's lease and payment history.
--     Instead their identifying data is cleared, every sign-in method removed
--     (so the same Google account or e-mail can register afresh later), and
--     the row stays as "Closed account" for everyone else's records.
--     ponytail: files they uploaded stay in Cloudinary; destroy them with the
--     credentials doc-access holds if that is ever required.

begin;

alter table public.users add column if not exists closed_at timestamptz;

create or replace function public.admin_change_role(p_user uuid, p_role public.user_role, p_reason text)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth'
as $fn$
declare
  v_user public.users;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform public.assert_admin_over(p_user);
  if p_role not in ('student', 'landlord') then
    raise exception 'An account can only become a student or a landlord/landlady here.';
  end if;
  if v_reason is null then
    raise exception 'Give a reason — the person is told it.';
  end if;

  select * into v_user from public.users where id = p_user for update;
  if v_user.role = p_role then
    raise exception 'They already have that role.';
  end if;
  if v_user.closed_at is not null then
    raise exception 'This account is closed.';
  end if;
  if exists (select 1 from public.leases
              where (student_id = p_user or landlord_id = p_user)
                and status in ('active', 'pending', 'leave_requested')) then
    raise exception 'They have a current stay or application. It has to end first.';
  end if;
  if exists (select 1 from public.accommodations where landlord_id = p_user) then
    raise exception 'They still own accommodations. Those have to be removed or transferred first.';
  end if;

  update public.users
     set role = p_role,
         -- Where a brand-new signup starts, so registration behaves exactly as it
         -- does the first time (a landlord/landlady is held until OSAS approves).
         status = 'pending',
         registered_at = null,
         updated_at = now()
   where id = p_user;
  update public.student_profiles set osas_verified_at = null where user_id = p_user;

  -- Restrictions belonged to the old role; a fresh registration starts clean.
  insert into public.account_standing (user_id, reason, restrictions, updated_by, updated_at)
  values (p_user, v_reason, '{}', auth.uid(), now())
  on conflict (user_id) do update
    set reason = excluded.reason, suspended_until = null, restrictions = '{}',
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  -- Signed out, so their next sign-in is routed to the new registration.
  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;

  insert into public.notifications (user_id, type, title, body, link_url)
  values (p_user, 'verification', 'Your account role was changed',
          'OSAS changed your account to ' || case when p_role = 'student' then 'a student' else 'a landlord/landlady' end
          || '. Sign in again to finish registering. Reason: ' || v_reason, '/profile');
end $fn$;

create or replace function public.admin_close_account(p_user uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth'
as $fn$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform public.assert_admin_over(p_user);
  if not public.current_is_superadmin() then
    raise exception 'Only the main admin can close an account.' using errcode = '42501';
  end if;
  if v_reason is null then
    raise exception 'Give a reason for closing the account.';
  end if;
  if (select closed_at from public.users where id = p_user) is not null then
    raise exception 'This account is already closed.';
  end if;
  if exists (select 1 from public.leases
              where (student_id = p_user or landlord_id = p_user)
                and status in ('active', 'pending', 'leave_requested')) then
    raise exception 'They have a current stay or application. It has to end first.';
  end if;
  if exists (select 1 from public.accommodations where landlord_id = p_user and status = 'accredited') then
    raise exception 'They have accredited accommodations. Delist them first.';
  end if;

  -- Sign-in: nothing left to sign in with, and the address is free again.
  delete from auth.identities where user_id = p_user;
  delete from auth.sessions where user_id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;
  update auth.users
     set email = 'closed+' || p_user::text || '@accommo.invalid',
         phone = null,
         encrypted_password = '',
         raw_user_meta_data = '{}'::jsonb,
         banned_until = now() + interval '100 years'
   where id = p_user;

  -- Personal data. The row stays so leases, payments and ratings still point somewhere.
  update public.users
     set full_name = 'Closed account',
         initials = 'CA',
         phone = '+639000000000',
         sex = null,
         date_of_birth = null,
         avatar_url = null,
         status = 'suspended',
         closed_at = now(),
         updated_at = now()
   where id = p_user;
  update public.student_profiles
     set student_id = null, school_id_url = null, assessment_of_fees_url = null,
         emergency_contact_json = null, extracted_name = null, extracted_school_id = null,
         qr_code_token = null, osas_verified_at = null
   where user_id = p_user;
  update public.landlord_profiles
     set government_id_url = null, extracted_name = null, extracted_gov_id = null
   where user_id = p_user;
  delete from public.verification_documents where user_id = p_user;
  delete from public.notifications where user_id = p_user;
  delete from public.user_pins where user_id = p_user;

  insert into public.account_standing (user_id, reason, restrictions, updated_by, updated_at)
  values (p_user, v_reason, '{}', auth.uid(), now())
  on conflict (user_id) do update
    set reason = excluded.reason, suspended_until = null, restrictions = '{}',
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  -- users, student_profiles, landlord_profiles and verification_documents are
  -- audited with their old values, so the audit trail held a copy of everything
  -- just cleared — including what these very updates replaced. Last, so it also
  -- catches the rows written above. The trail keeps what changed and when.
  update public.audit_logs
     set before_json = before_json - array[
           'email', 'phone', 'full_name', 'initials', 'date_of_birth', 'avatar_url', 'sex',
           'student_id', 'school_id_url', 'assessment_of_fees_url', 'emergency_contact_json',
           'extracted_name', 'extracted_school_id', 'qr_code_token',
           'government_id_url', 'extracted_gov_id', 'file_url', 'filename'],
         after_json = after_json - array[
           'email', 'phone', 'full_name', 'initials', 'date_of_birth', 'avatar_url', 'sex',
           'student_id', 'school_id_url', 'assessment_of_fees_url', 'emergency_contact_json',
           'extracted_name', 'extracted_school_id', 'qr_code_token',
           'government_id_url', 'extracted_gov_id', 'file_url', 'filename']
   where entity_type in ('users', 'student_profiles', 'landlord_profiles', 'verification_documents')
     and (entity_id = p_user::text
          or before_json ->> 'user_id' = p_user::text
          or after_json ->> 'user_id' = p_user::text);

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_json, created_at)
  values (auth.uid(), 'account.closed', 'users', p_user::text, jsonb_build_object('reason', v_reason), now());
end $fn$;

revoke all on function public.admin_change_role(uuid, public.user_role, text) from public, anon;
revoke all on function public.admin_close_account(uuid, text) from public, anon;
grant execute on function public.admin_change_role(uuid, public.user_role, text) to authenticated;
grant execute on function public.admin_close_account(uuid, text) to authenticated;

commit;
