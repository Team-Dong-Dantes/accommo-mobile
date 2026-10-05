// "Forgot password?" on the OSAS console's sign-in page. Only admin accounts
// get a reset e-mail — students and landlords/landladies reset from the mobile
// app — and the reply is the same either way, so the page can't be used to find
// out which addresses belong to admins. An admin with two-factor still has to
// enter their code after following the link (the console's router checks it
// before the reset page).
//
// The link goes to ADMIN_APP_URL, never to the caller's Origin. Anyone can call
// this, and outside a browser the Origin header is whatever the caller types —
// including the localhost and LAN addresses the CORS list allows for
// development — so building the link from it let a stranger send a real admin
// a genuine reset e-mail whose token landed on a machine of their choosing.
import { preflight, reply } from '../_shared/http.ts';

const APP_URL = (Deno.env.get('ADMIN_APP_URL') ?? 'https://accommo.vercel.app').replace(/\/+$/, '');

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  const done = () => reply(req, 200, {});

  try {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!SUPABASE_URL || !SERVICE_ROLE) return reply(req, 500, { error: 'Missing Supabase environment variables.' });

    const body = await req.json().catch(() => ({}));
    const email = String(body.email ?? '').trim().toLowerCase();
    if (!email) return done();

    const service = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
    // Anyone can call this, so cap it per address before touching users.
    // Same silent reply when over the cap, for the same reason as above.
    const { data: allowed } = await service.rpc('rate_limit_hit', { p_key: `admin-reset:${email}`, p_max: 3, p_window: 3600 });
    if (allowed === false) return done();
    const { data: admin } = await service
      .from('users')
      .select('id')
      .eq('email', email)
      .eq('role', 'admin')
      .neq('status', 'suspended')
      .maybeSingle();
    if (!admin) return done();

    const { error } = await service.auth.resetPasswordForEmail(email, { redirectTo: `${APP_URL}/auth/reset-password` });
    if (error) console.error('request-admin-reset: send failed', error.message);
    return done();
  } catch (e) {
    return reply(req, 500, { error: e instanceof Error ? e.message : String(e) });
  }
});
