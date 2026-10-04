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
// The same goes for payment proofs (bank/e-wallet receipts), chat photos,
// concern photos and support-ticket photos. Avatars and listing images are NOT
// routed through this function: they are meant to be public and keep using the
// unsigned preset.
//
// Authorization deliberately reuses RLS instead of re-implementing it. The
// caller's own JWT is used to select the document row; if the policies do not
// return it, the caller is not entitled to the file. That keeps this function
// from becoming an oracle that signs any public_id on request, and it cannot
// drift out of step with the table policies.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { preflight, reply } from '../_shared/http.ts'

const CLOUD = Deno.env.get('CLOUDINARY_CLOUD_NAME')!
const KEY = Deno.env.get('CLOUDINARY_API_KEY')!
const SECRET = Deno.env.get('CLOUDINARY_API_SECRET')!

/** Every table holding private file references, and the column that holds them. */
const PRIVATE_COLUMNS: Record<string, string> = {
  verification_documents: 'file_url',
  accommodation_documents: 'file_url',
  payments: 'proof_url',
  messages: 'attachment_url',
  concerns: 'photo_url',
  tickets: 'photo_urls',
  ticket_messages: 'attachment_urls',
}

/** Reference we store in file_url: cld:<resource_type>:<type>:<format>:<public_id> */
const CLD_PREFIX = 'cld:'
const UPLOAD_FOLDER = 'accommo/docs'
const VIEW_TTL_SECONDS = 300


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
  const pre = preflight(req)
  if (pre) return pre
  if (req.method !== 'POST') return reply(req, 405, { error: 'POST only' })

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return reply(req, 401, { error: 'Not signed in.' })

  // Caller-scoped client: every read below is subject to the caller's RLS.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: auth } = await supabase.auth.getUser()
  if (!auth?.user) return reply(req, 401, { error: 'Not signed in.' })

  let body: { action?: string; table?: string; id?: string; ref?: string; resourceType?: string }
  try {
    body = await req.json()
  } catch {
    return reply(req, 400, { error: 'Invalid JSON body.' })
  }

  // Params for a signed, type=authenticated upload straight to Cloudinary. The
  // client never sees the secret, only a one-shot signature.
  if (body.action === 'upload-params') {
    const resourceType = body.resourceType === 'raw' ? 'raw' : 'image'
    const timestamp = Math.floor(Date.now() / 1000)
    const folder = `${UPLOAD_FOLDER}/${auth.user.id}`
    const signature = await signParams({ folder, timestamp, type: 'authenticated' })
    return reply(req, 200, { cloudName: CLOUD, apiKey: KEY, timestamp, folder, type: 'authenticated', resourceType, signature })
  }

  // A short-lived URL for one file on one row the caller is allowed to read.
  // Array columns (ticket photos) also name which element with `ref`; it has to
  // be one the row actually holds, so a readable row can't sign anything else.
  if (body.action === 'view') {
    const column = PRIVATE_COLUMNS[body.table ?? '']
    if (!column) return reply(req, 400, { error: 'Unknown document table.' })
    if (!body.id) return reply(req, 400, { error: 'Missing document id.' })

    const { data, error } = await supabase
      .from(body.table!)
      .select(column)
      .eq('id', body.id)
      .maybeSingle()
    // RLS decides: no row means this caller may not see this file.
    if (error) return reply(req, 400, { error: error.message })

    const stored = (data as Record<string, unknown> | null)?.[column]
    const ref = Array.isArray(stored)
      ? (stored.includes(body.ref) ? body.ref : undefined)
      : (typeof stored === 'string' && (!body.ref || body.ref === stored) ? stored : undefined)
    if (!ref) return reply(req, 404, { error: 'Not found.' })

    // Who at OSAS opened an identity document or a permit, and when. Written
    // with the caller's own client: audit_logs only takes inserts from OSAS, so
    // a landlord/landlady or student opening their own file is simply not
    // recorded, and a refused insert must never block the file.
    if (body.table === 'verification_documents' || body.table === 'accommodation_documents') {
      await supabase.from('audit_logs').insert({
        action: 'document.view',
        actor_id: auth.user.id,
        entity_type: body.table,
        entity_id: body.id,
      }).then(() => undefined, () => undefined)
    }

    // Rows written before files moved to authenticated delivery hold a plain
    // URL. Nothing to sign — hand it back so old records still open.
    if (!ref.startsWith(CLD_PREFIX)) return reply(req, 200, { url: ref, legacy: true })
    return reply(req, 200, { url: await privateDownloadUrl(ref), expiresIn: VIEW_TTL_SECONDS })
  }

  return reply(req, 400, { error: 'Unknown action.' })
})
