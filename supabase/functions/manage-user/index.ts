// OSAS's account actions that only auth's admin API can do: changing the
// sign-in e-mail and setting a temporary password. Everything else OSAS does to
// an account is plain SQL (admin_set_account_status, admin_sign_out_everywhere,
// admin_disconnect_google) and never needs the service role.
//
// Authorization is the same guard those SQL functions use —
// assert_admin_over(), called as the signed-in admin — so the rule "an admin,
// acting on a student or landlord/landlady" lives in one place.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: Record<string, unknown>) {
  return new Response(JSON.stringify({ ok: true, ...body }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function fail(message: string) {
  return new Response(JSON.stringify({ ok: false, error: message }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/** The same rule as signup (handle_auth_user_sync). */
const ALLOWED_DOMAINS = ['gmail.com', 'isu.edu.ph'];

function generateTempPassword(): string {
  // No look-alikes (0/O, 1/l/I), since it is read out or written down at the desk.
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(10));
  let pwd = '';
  for (const b of bytes) pwd += chars[b % chars.length];
  return pwd;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE) return fail('Missing Supabase environment variables.');

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
      auth: { persistSession: false },
    });
    const { data: authData } = await userClient.auth.getUser();
    const actorId = authData.user?.id;
    if (!actorId) return fail('Unauthorized');

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? '');
    const targetId = String(body.target_id ?? '');
    if (!targetId) return fail('No account given.');

    const { error: guardErr } = await userClient.rpc('assert_admin_over', { p_user: targetId });
    if (guardErr) return fail(guardErr.message);

    const service = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    const audit = (name: string, after: Record<string, unknown>, before: Record<string, unknown> | null = null) =>
      service.from('audit_logs').insert({
        actor_id: actorId,
        action: name,
        entity_type: 'users',
        entity_id: targetId,
        before_json: before,
        after_json: after,
      });

    if (action === 'change_email') {
      const email = String(body.email ?? '').trim().toLowerCase();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return fail('Enter a valid e-mail address.');
      if (!ALLOWED_DOMAINS.includes(email.split('@')[1] ?? '')) {
        return fail('Accommo accounts must use a @gmail.com or @isu.edu.ph address.');
      }
      const { data: taken } = await service.from('users').select('id').eq('email', email).neq('id', targetId).maybeSingle();
      if (taken) return fail('Another account already uses that e-mail.');

      const { data: before } = await service.from('users').select('email').eq('id', targetId).single();
      // Confirmed on the spot: OSAS is changing it with the person in front of them.
      const { error } = await service.auth.admin.updateUserById(targetId, { email, email_confirm: true });
      if (error) return fail(error.message);
      // handle_auth_user_sync carries the new address onto public.users.
      await audit('account.email_changed', { email }, { email: before?.email ?? null });
      await service.from('notifications').insert({
        user_id: targetId,
        type: 'system',
        title: 'Sign-in e-mail changed',
        body: `OSAS changed the e-mail you sign in with to ${email}.`,
        link_url: '/profile',
        source: 'osas',
      });
      return json({ email });
    }

    if (action === 'set_temp_password') {
      const password = generateTempPassword();
      const { error } = await service.auth.admin.updateUserById(targetId, { password });
      if (error) return fail(error.message);
      // Whoever had the old password — or the lost phone — is signed out.
      await userClient.rpc('admin_sign_out_everywhere', { p_user: targetId });
      await audit('account.temp_password', {});
      return json({ temporary_password: password });
    }

    return fail('Unknown action.');
  } catch (e) {
    return fail(e instanceof Error ? e.message : String(e));
  }
});
