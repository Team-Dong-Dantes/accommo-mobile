-- The app PIN is gone: no resume lock, no per-action PIN pad, no PIN in
-- registration or Settings. Confirmations that used to fall back to "Are you
-- sure?" for accounts without a PIN are now plain confirmations in the app.
--
-- Apply only after the build without the PIN has shipped. An older build that
-- had a PIN set asks `has_pin` on launch; if that call fails it falls back to its
-- cached "yes" and shows a lock that can no longer be verified.

-- admin_close_account wipes a closed account's PIN. Edit the live definition
-- rather than restating it, so nothing else in the function can drift.
do $$
declare
  v_def text := pg_get_functiondef('public.admin_close_account(uuid, text)'::regprocedure);
begin
  v_def := replace(v_def, E'  delete from public.user_pins where user_id = p_user;\n', '');
  if position('user_pins' in v_def) > 0 then
    raise exception 'admin_close_account still references user_pins';
  end if;
  execute v_def;
end $$;

drop function public.verify_pin(text);
drop function public.clear_pin(text);
drop function public.set_pin(text);
drop function public.has_pin();
drop function public.pin_attempt(text);
drop table public.user_pins;
