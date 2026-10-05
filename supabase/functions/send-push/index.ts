// Delivers one notification row to its recipient's devices through FCM.
//
// Called only by the notification_push trigger (pg_net), never by a client, so
// it is deployed without JWT verification and instead checks the shared secret
// the trigger reads from Vault. The trigger has already applied the user's push
// preference and looked up their tokens; this only sends, and forgets tokens
// FCM says are dead.

// Base64 of the Firebase service-account JSON (base64 so no shell mangles it).
const SA = JSON.parse(atob(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '')) as {
  project_id: string;
  client_email: string;
  private_key: string;
};

const b64url = (data: string | Uint8Array) =>
  btoa(typeof data === 'string' ? data : String.fromCharCode(...data))
    .replace(/=+$/, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

let cached: { token: string; until: number } | null = null;

/** An OAuth access token for FCM, from a self-signed service-account JWT. */
async function accessToken(): Promise<string> {
  if (cached && cached.until > Date.now()) return cached.token;

  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: SA.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = SA.private_key.replace(/-----[^-]+-----|\s/g, '');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`)),
  );

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${b64url(sig)}`,
    }),
  });
  const json = await res.json();
  if (!json.access_token) throw new Error(`FCM auth failed: ${JSON.stringify(json)}`);
  // Refresh a few minutes early so a send never races the expiry.
  cached = { token: json.access_token, until: Date.now() + (json.expires_in - 300) * 1000 };
  return cached.token;
}

/** Compares in time that does not depend on where the strings first differ. */
function sameSecret(given: string | null, expected: string | undefined): boolean {
  if (!given || !expected) return false;
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < b.length; i++) diff |= (a[i] ?? 0) ^ b[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  if (!sameSecret(req.headers.get('x-push-secret'), Deno.env.get('PUSH_SECRET'))) {
    return new Response('Forbidden', { status: 403 });
  }

  const n = await req.json();
  const tokens: string[] = Array.isArray(n.tokens) ? n.tokens : [];
  const auth = await accessToken();

  // FCM data values must all be strings; the app reads these to route the tap.
  const data: Record<string, string> = {};
  for (const k of ['id', 'type', 'link_url', 'ref_id']) if (n[k]) data[k] = String(n[k]);

  const dead: string[] = [];
  let sent = 0;
  await Promise.all(tokens.map(async (token) => {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${SA.project_id}/messages:send`, {
      method: 'POST',
      headers: { authorization: `Bearer ${auth}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: String(n.title ?? ''), body: String(n.body ?? '') },
          data,
          // The channel src/utils/push.ts creates; on a device without it yet,
          // Android falls back to FCM's default channel.
          android: { priority: 'high', notification: { channel_id: 'accommo' } },
        },
      }),
    });
    if (res.ok) return void sent++;
    const err = await res.text();
    // The app was uninstalled or the token rotated: it will never work again.
    if (res.status === 404 || err.includes('UNREGISTERED')) dead.push(token);
    else console.error('FCM send failed', res.status, err);
  }));

  if (dead.length) {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
    const service = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
      auth: { persistSession: false },
    });
    await service.from('push_tokens').delete().in('token', dead);
  }

  return new Response(JSON.stringify({ sent, dead: dead.length, failed: tokens.length - sent - dead.length }), {
    headers: { 'content-type': 'application/json' },
  });
});
