// "Forgot password?" on the OSAS console's sign-in page. Only admin accounts
// get a reset e-mail — students and landlords/landladies reset from the mobile
// app — and the reply is the same either way, so the page can't be used to find
// out which addresses belong to admins. An admin with two-factor still has to
// enter their code after following the link (the console's router checks it
// before the reset page).
import { allowedOrigin, preflight, reply } from '../_shared/http.ts';

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
    // The link goes back to whichever console asked, never to an address from the body.
    const origin = allowedOrigin(req);
    if (!email || !origin) return done();

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

    const { error } = await service.auth.resetPasswordForEmail(email, { redirectTo: `${origin}/auth/reset-password` });
    if (error) console.error('request-admin-reset: send failed', error.message);
    return done();
  } catch (e) {
    return reply(req, 500, { error: e instanceof Error ? e.message : String(e) });
  }
});
