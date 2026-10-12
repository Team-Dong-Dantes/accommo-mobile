-- A cover photo on a person's profile, next to the avatar. Public Cloudinary
-- URL like avatar_url; readable by anyone who can already read the row.

alter table public.users add column cover_url text;

-- Column grants (20261005010000): a users column is invisible to clients until
-- granted.
grant select (cover_url) on public.users to authenticated;

-- users_full keeps its columns and order; the new one goes on the end.
create or replace view public.users_full with (security_invoker = false) as
  select u.id, u.email, u.phone, u.role, u.status, u.full_name, u.initials, u.avatar_color, u.sex,
         u.email_verified_at, u.created_at, u.updated_at, u.last_login_at, u.is_superadmin,
         u.onboarding_complete, u.notification_prefs, u.avatar_url, u.registered_at,
         u.terms_accepted_at, u.privacy_accepted_at, u.reviewing_by, u.reviewing_at, u.closed_at,
         u.login_alerts,
         case when u.id = (select auth.uid()) or (select public.is_admin((select auth.uid())))
              then u.date_of_birth end as date_of_birth,
         u.cover_url
    from public.users u
   where u.id = (select auth.uid())
      or (select public.is_admin((select auth.uid())))
      or exists (select 1 from public.leases l
                  where l.status in ('pending', 'active', 'leave_requested')
                    and ((l.student_id = (select auth.uid()) and l.landlord_id = u.id)
                      or (l.landlord_id = (select auth.uid()) and l.student_id = u.id)));

-- Closing an account wipes the cover with the avatar. Edit the live definition
-- rather than restating it, so nothing else in the function can drift.
do $$
declare
  v_def text := pg_get_functiondef('public.admin_close_account(uuid, text)'::regprocedure);
begin
  v_def := replace(v_def, E'avatar_url = null,\n', E'avatar_url = null,\n         cover_url = null,\n');
  v_def := replace(v_def, '''avatar_url'', ''sex'',', '''avatar_url'', ''cover_url'', ''sex'',');
  if position('cover_url = null' in v_def) = 0 or position('''cover_url''' in v_def) = 0 then
    raise exception 'admin_close_account did not take the cover_url edits';
  end if;
  execute v_def;
end $$;
