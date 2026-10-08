// The main admin's controls over other administrators: withdraw a pending
// invite (deletes the account), remove admin access (keeps the account), set a
// temporary password, or clear a lost two-factor device.
// Was deployed from outside this repository until 2026-09-26; this is that
// source, moved onto the shared CORS/reply helpers.
import { preflight, reply } from '../_shared/http.ts';
import { generateTempPassword } from '../_shared/password.ts';


Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  const json = (status: number, body: Record<string, unknown>) => reply(req, status, body);

  try {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE) {
      return json(500, { error: 'Missing Supabase environment variables.' });
    }

    const authHeader = req.headers.get('Authorization') ?? '';

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const { data: authData } = await userClient.auth.getUser();
    const callerId = authData.user?.id;
    if (!callerId) return json(401, { error: 'Unauthorized' });

    const { data: me, error: meErr } = await userClient
      .from('users')
      .select('is_superadmin')
      .eq('id', callerId)
      .single();
    if (meErr || !me?.is_superadmin) {
      return json(403, { error: 'Only the main admin can manage administrators.' });
    }
    // Reading your own row is allowed before the second factor, so the flag
    // above proves only the password. mfa_ok() is the rule is_admin() uses:
    // with an authenticator enrolled, the session must have passed the code.
    const { data: mfaOk } = await userClient.rpc('mfa_ok', { p_uid: callerId });
    if (mfaOk !== true) {
      return json(403, { error: 'Enter your authentication code before managing administrators.' });
    }

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? '');
    const target_id = String(body.target_id ?? '');
    if (!['revoke_invite', 'remove_admin', 'set_temp_password', 'reset_mfa'].includes(action) || !target_id) {
      return json(400, { error: 'Invalid request.' });
    }

    const serviceClient = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false },
    });

    const { data: target, error: tErr } = await serviceClient
      .from('users')
      .select('id, role, is_superadmin, onboarding_complete, email')
      .eq('id', target_id)
      .single();
    if (tErr || !target) return json(404, { error: 'Target account not found.' });
    if (target.is_superadmin) return json(403, { error: 'The main admin cannot be modified this way.' });
    if (target.id === callerId) return json(403, { error: 'You cannot modify your own account here.' });
    // Administrators only. Students and landlords/landladies have manage-user,
    // which keeps OSAS's own rules (assert_admin_over) and signs them out; this
    // used to delete, reset or re-password any of them too.
    if (target.role !== 'admin') return json(403, { error: 'That account is not an administrator.' });

    const audit = async (name: string, after: Record<string, unknown>) => {
      const { error } = await serviceClient.from('audit_logs').insert({
        actor_id: callerId, action: name, entity_type: 'users', entity_id: target_id, after_json: after,
      });
      if (error) console.error('manage-admin: audit write failed', name, target_id, error.message);
    };

    // An admin who forgot their password. Their other sessions are not signed
    // out (admin_sign_out_everywhere refuses admin targets); for a compromised
    // account, Remove admin is the tool.
    if (action === 'set_temp_password') {
      const password = generateTempPassword();
      const { error } = await serviceClient.auth.admin.updateUserById(target_id, { password });
      if (error) return json(400, { error: error.message });
      await audit('account.temp_password', {});
      return json(200, { action, temporary_password: password });
    }

    // An admin who lost their authenticator: clear it so they can sign in with
    // their password and set two-factor up again.
    if (action === 'reset_mfa') {
      const { data: factors, error: listErr } = await serviceClient.auth.admin.mfa.listFactors({ userId: target_id });
      if (listErr) return json(400, { error: listErr.message });
      for (const f of factors?.factors ?? []) {
        const { error } = await serviceClient.auth.admin.mfa.deleteFactor({ id: f.id, userId: target_id });
        if (error) return json(400, { error: error.message });
      }
      await audit('account.mfa_reset', { factors: factors?.factors?.length ?? 0 });
      return json(200, { action });
    }

    if (action === 'revoke_invite') {
      // Pending invite: delete the account entirely (auth + public row). An
      // admin who has accepted is removed with remove_admin instead, which
      // keeps their account and its history.
      if (target.onboarding_complete) {
        return json(409, { error: 'This administrator already accepted the invite. Remove their access instead.' });
      }
      const { error: rowErr } = await serviceClient.from('users').delete().eq('id', target_id);
      if (rowErr) return json(400, { error: rowErr.message });
      const { error: delErr } = await serviceClient.auth.admin.deleteUser(target_id);
      if (delErr) return json(400, { error: delErr.message });
      await audit('admin.invite_revoked', { email: target.email });
      return json(200, { action });
    }

    // remove_admin — revoke admin access but keep the account. It used to keep
    // its old status as a student with no student record; now it starts over
    // the way admin_change_role leaves an account: unregistered, so their next
    // sign-in picks a role and registers, and signed out everywhere now.
    const { error: updErr } = await userClient
      .from('users')
      .update({ role: 'student', is_superadmin: false, status: 'pending', registered_at: null })
      .eq('id', target_id);
    if (updErr) return json(400, { error: updErr.message });
    await userClient.from('admin_access').delete().eq('user_id', target_id);
    await userClient.rpc('admin_sign_out_everywhere', { p_user: target_id });
    await audit('admin.removed', { role: 'student' });
    return json(200, { action });
  } catch (e) {
    return json(500, { error: e instanceof Error ? e.message : String(e) });
  }
});
