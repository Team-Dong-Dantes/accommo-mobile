// Signed access to sensitive Cloudinary documents (identity, enrolment, permits).
//
// Why this exists: Cloudinary's default `upload` delivery type serves assets at
// unauthenticated URLs, so the link itself is the credential — anyone who ever
// sees one can read a student's school ID or a manager's government ID forever,
// and a later rejection revokes nothing. Documents are therefore uploaded with
// delivery type `authenticated`, which needs a signature computed from the API
// secret. That secret must never reach client code, so both the upload params
// and the read URLs are signed here.
//
// Photos, avatars and listing images are NOT routed through this function: they
// are meant to be public and keep using the unsigned preset.
//
// Authorization deliberately reuses RLS instead of re-implementing it. The
// caller's own JWT is used to select the document row; if the policies do not
// return it, the caller is not entitled to the file. That keeps this function
// from becoming an oracle that signs any public_id on request, and it cannot
// drift out of step with the table policies.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const CLOUD = Deno.env.get('CLOUDINARY_CLOUD_NAME')!
const KEY = Deno.env.get('CLOUDINARY_API_KEY')!
const SECRET = Deno.env.get('CLOUDINARY_API_SECRET')!

const DOC_TABLES = ['verification_documents', 'accommodation_documents'] as const
type DocTable = (typeof DOC_TABLES)[number]

/** Reference we store in file_url: cld:<resource_type>:<type>:<format>:<public_id> */
const CLD_PREFIX = 'cld:'
const UPLOAD_FOLDER = 'accommo/docs'
const VIEW_TTL_SECONDS = 300

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  })

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

async function sha1Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(input))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

/** Cloudinary api_sign_request: sorted non-empty k=v pairs, then the secret. */
function signParams(params: Record<string, string | number | undefined>): Promise<string> {
  const canonical = Object.keys(params)
    .sort()
    .filter((k) => params[k] !== undefined && params[k] !== null && params[k] !== '')
    .map((k) => `${k}=${params[k]}`)
    .join('&')
  return sha1Hex(canonical + SECRET)
}

function parseRef(ref: string) {
  // cld:image:authenticated:png:accommo/docs/abc — public_id may contain ':'
  const parts = ref.slice(CLD_PREFIX.length).split(':')
  const [resourceType, type, format, ...rest] = parts
  return {
    // The ref is a value the client wrote into its own row, so none of it is
    // trusted for anything but naming the asset. `resource_type` and `type` are
    // pinned to the two shapes this function ever uploads rather than echoed
    // back: whatever the row claims, it does not get to pick a delivery type.
    // The public_id is pinned by trg_lock_document_ref in the database, which is
    // the half that actually decides whose file this is.
    resourceType: resourceType === 'raw' ? 'raw' : 'image',
    type: 'authenticated',
    format: format || '',
    publicId: rest.join(':'),
  }
}

async function privateDownloadUrl(ref: string) {
  const { resourceType, type, format, publicId } = parseRef(ref)
  const params: Record<string, string | number> = {
    timestamp: Math.floor(Date.now() / 1000),
    public_id: publicId,
    format,
    type,
    expires_at: Math.floor(Date.now() / 1000) + VIEW_TTL_SECONDS,
  }
  const signature = await signParams(params)
  const query = new URLSearchParams({ ...params, signature, api_key: KEY } as Record<string, string>)
  return `https://api.cloudinary.com/v1_1/${CLOUD}/${resourceType}/download?${query}`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Not signed in.' }, 401)

  // Caller-scoped client: every read below is subject to the caller's RLS.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: auth } = await supabase.auth.getUser()
  if (!auth?.user) return json({ error: 'Not signed in.' }, 401)

  let body: { action?: string; table?: string; id?: string; resourceType?: string }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Invalid JSON body.' }, 400)
  }

  // Params for a signed, type=authenticated upload straight to Cloudinary. The
  // client never sees the secret, only a one-shot signature.
  if (body.action === 'upload-params') {
    const resourceType = body.resourceType === 'raw' ? 'raw' : 'image'
    const timestamp = Math.floor(Date.now() / 1000)
    const folder = `${UPLOAD_FOLDER}/${auth.user.id}`
    const signature = await signParams({ folder, timestamp, type: 'authenticated' })
    return json({ cloudName: CLOUD, apiKey: KEY, timestamp, folder, type: 'authenticated', resourceType, signature })
  }

  // A short-lived URL for one document row the caller is allowed to read.
  if (body.action === 'view') {
    if (!DOC_TABLES.includes(body.table as DocTable)) return json({ error: 'Unknown document table.' }, 400)
    if (!body.id) return json({ error: 'Missing document id.' }, 400)

    const { data, error } = await supabase
      .from(body.table as DocTable)
      .select('file_url')
      .eq('id', body.id)
      .maybeSingle()
    // RLS decides: no row means this caller may not see this document.
    if (error) return json({ error: error.message }, 400)
    if (!data?.file_url) return json({ error: 'Not found.' }, 404)

    const ref = data.file_url as string
    // Rows written before documents moved to authenticated delivery hold a plain
    // URL. Nothing to sign — hand it back so old records still open.
    if (!ref.startsWith(CLD_PREFIX)) return json({ url: ref, legacy: true })
    return json({ url: await privateDownloadUrl(ref), expiresIn: VIEW_TTL_SECONDS })
  }

  return json({ error: 'Unknown action.' }, 400)
})
