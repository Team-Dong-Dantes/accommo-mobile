// CORS and JSON replies shared by every edge function.
//
// Only Accommo's own front ends may call these from a browser: the OSAS console
// and the mobile web build on Vercel (plus their preview deployments), the
// Android app's WebView (https://localhost), and local development.

const ALLOWED_ORIGINS = [
  /^https:\/\/accommo(-app)?(-[a-z0-9-]+)?\.vercel\.app$/,
  /^https?:\/\/localhost(:\d+)?$/,
  /^capacitor:\/\/localhost$/,
  /^http:\/\/(127\.0\.0\.1|192\.168\.\d{1,3}\.\d{1,3})(:\d+)?$/,
]

/** The caller's Origin when it is one of ours, otherwise null. */
export function allowedOrigin(req: Request): string | null {
  const origin = req.headers.get('origin') ?? ''
  return ALLOWED_ORIGINS.some((re) => re.test(origin)) ? origin : null
}

export function corsHeaders(req: Request): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': allowedOrigin(req) ?? 'https://accommo.vercel.app',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  }
}

/** Preflight reply, or null when this is not a preflight. */
export function preflight(req: Request): Response | null {
  return req.method === 'OPTIONS' ? new Response('ok', { headers: corsHeaders(req) }) : null
}

/** A JSON reply. Failures carry a real status and `{ error }`. */
export function reply(req: Request, status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(status < 400 ? { ok: true, ...body } : body), {
    status,
    headers: { ...corsHeaders(req), 'Content-Type': 'application/json' },
  })
}
