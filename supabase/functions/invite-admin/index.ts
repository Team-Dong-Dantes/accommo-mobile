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

function generateTempPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(14));
  let pwd = '';
  for (const b of bytes) pwd += chars[b % chars.length];
  return pwd + 'A1!';
}

const FALLBACK_APP_URL = 'https://accommo.vercel.app';

/**
 * Where the invited admin lands after clicking the email link.
 *
 * Derived from the caller's Origin because the invite is always sent from the
 * admin console itself — that makes it correct in production and on a local
 * dev server with no extra configuration. Without an explicit redirectTo,
 * Supabase falls back to the project's Site URL, which sent invited admins to
 * whatever that happened to be set to.
 *
 * The target must also be listed under Authentication -> URL Configuration ->
 * Redirect URLs, or Supabase silently ignores it and uses the Site URL anyway.
 */
function redirectTarget(req: Request): string {
  const origin = req.headers.get('origin');
  const base = origin && /^https?:\/\//.test(origin) ? origin : FALLBACK_APP_URL;
  return `${base}/onboarding`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE) {
      return fail('Missing Supabase environment variables.');
    }

    const authHeader = req.headers.get('Authorization') ?? '';

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const { data: authData } = await userClient.auth.getUser();
    const userId = authData.user?.id;
    if (!userId) return fail('Unauthorized');

    const { data: me, error: meErr } = await userClient
      .from('users')
      .select('is_superadmin')
      .eq('id', userId)
      .single();
    if (meErr || !me?.is_superadmin) {
      return fail('Only the main admin can invite administrators.');
    }

    const body = await req.json().catch(() => ({}));
    const email = String(body.email ?? '').trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return fail('A valid email is required.');
    }

    // The invited admin sets their real display name during onboarding, so we
    // only use a placeholder here to satisfy the NOT NULL column.
    const full_name = String(body.full_name ?? '').trim() || email;

    const serviceClient = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false },
    });

    const redirectTo = redirectTarget(req);

    // If the email is already a registered user, handle it gracefully instead
    // of surfacing a cryptic "already registered" error.
    const { data: existing } = await serviceClient
      .from('users')
      .select('id, role, is_superadmin, onboarding_complete')
      .eq('email', email)
      .maybeSingle();
    if (existing) {
      if (existing.is_superadmin) {
        return fail('That account is the main admin and cannot be re-invited.');
      }
      if (existing.role === 'admin') {
        // An admin who never accepted their invite is a resend, not a no-op.
        // Bailing out with "Already an administrator" left a pending admin with
        // no way to ever get a working link, because the row already says admin.
        if (!existing.onboarding_complete) {
          const { error: resendErr } = await serviceClient.auth.admin.inviteUserByEmail(
            email,
            { data: { full_name }, redirectTo },
          );
          if (!resendErr) {
            return json({ id: existing.id, resent: true, message: 'Invitation resent to ' + email });
          }
        }
        return json({ already_admin: true, id: existing.id, message: 'Already an administrator.' });
      }
      // Promote an existing non-admin (student / accommodation manager) to administrator.
      const { error: updErr } = await userClient
        .from('users')
        .update({ role: 'admin', is_superadmin: false, onboarding_complete: true })
        .eq('id', existing.id);
      if (updErr) return fail(updErr.message);
      return json({ promoted: true, id: existing.id, message: 'Added as administrator.' });
    }

    let newId: string | null = null;
    let temporary_password: string | null = null;

    // Send the invite email. This can hit the email rate limit, so we fall back
    // to creating the account directly (no email) with a one-time password.
    //
    // Nothing may touch this user's one-time token afterwards. The previous
    // version followed this call with admin.generateLink({ type: 'invite' }) to
    // show a copyable link in the UI — that issues a *new* token and overwrites
    // the stored one, so the token already sitting in the delivered email no
    // longer matched and every invite arrived pre-expired (otp_expired,
    // "Email link is invalid or has expired"). You can have a working emailed
    // link or a copyable generated link, never both: it is one single-use token.
    const { data: invite, error: inviteErr } = await serviceClient.auth.admin.inviteUserByEmail(
      email,
      { data: { full_name }, redirectTo },
    );

    if (inviteErr) {
      const tmp = generateTempPassword();
      const { data: created, error: createErr } = await serviceClient.auth.admin.createUser({
        email,
        password: tmp,
        email_confirm: true,
        user_metadata: { full_name },
      });
      if (createErr) return fail(createErr.message);
      newId = created?.user?.id ?? null;
      temporary_password = tmp;
    } else {
      newId = invite.user?.id ?? null;
    }

    if (!newId) return fail('Invitation failed: no user returned.');

    const initials = full_name
      .split(/\s+/)
      .map((p) => p[0])
      .slice(0, 2)
      .join('')
      .toUpperCase();

    let updErr: { message: string } | null = null;
    for (let i = 0; i < 5; i++) {
      const res = await userClient
        .from('users')
        .update({ role: 'admin', full_name, initials, status: 'pending', is_superadmin: false, onboarding_complete: false })
        .eq('id', newId);
      if (!res.error) break;
      updErr = res.error;
      await new Promise((r) => setTimeout(r, 300));
    }
    if (updErr) return fail(updErr.message);

    return json({ id: newId, invite_link: null, temporary_password });
  } catch (e) {
    return fail(e instanceof Error ? e.message : String(e));
  }
});
