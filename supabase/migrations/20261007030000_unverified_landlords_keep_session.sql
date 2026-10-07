-- A landlord/landlady uses the app while OSAS verifies them; only adding
-- accommodations, rooms and facilities waits (the *_insert_verified policies).
-- tg_revoke_on_unverify still banned the account and deleted its sessions the
-- moment registration finished as 'pending', which signed them straight out.
-- Drop that branch from the live definition, and lift any ban it already set.
do $$
declare
  v_def text := pg_get_functiondef('public.tg_revoke_on_unverify()'::regprocedure);
  v_branch text := E'  if awaiting_review and (became_registered or new.status is distinct from old.status)\n     and new.registered_at is not null then\n    update auth.users set banned_until = now() + interval ''100 years'' where id = new.id;\n    delete from auth.sessions where user_id = new.id;\n    delete from auth.refresh_tokens where user_id = new.id::text;\n    return new;\n  end if;\n\n';
begin
  if position(v_branch in v_def) = 0 then
    raise exception 'tg_revoke_on_unverify: the awaiting-review ban branch was not found';
  end if;
  v_def := replace(v_def, v_branch, '');
  v_def := replace(v_def, E'  became_registered boolean := old.registered_at is null and new.registered_at is not null;\n', '');
  v_def := replace(v_def, E'  awaiting_review boolean := new.role = ''landlord'' and new.status = ''pending'';\n', '');
  if position('awaiting_review' in v_def) > 0 or position('became_registered' in v_def) > 0 then
    raise exception 'tg_revoke_on_unverify: leftover references to the removed branch';
  end if;
  execute v_def;
end $$;

update auth.users a
   set banned_until = null
  from public.users u
 where u.id = a.id
   and u.role = 'landlord'
   and u.status = 'pending'
   and a.banned_until > now();
