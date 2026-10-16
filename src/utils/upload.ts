import { supabase } from '@/utils/supabase'

// Cloudinary client-side upload helper — mobile.
//
// Mirrors the web app's Cloudinary setup (accommo-web/src/utils/cloudinary.ts)
// so every file/image in the app is stored in Cloudinary instead of Supabase
// Storage. Every upload is signed by the `doc-access` edge function, so the API
// secret never reaches the client. Public photos used to go through an unsigned
// preset, which anyone who read its name out of the bundle could upload to.

const MAX_FILE_SIZE = 5 * 1024 * 1024 // 5MB
const ALLOWED_IMAGE = ['image/jpeg', 'image/png', 'image/webp']
const ALLOWED_ALL = [...ALLOWED_IMAGE, 'application/pdf']

export interface CloudinaryUploadResult {
  publicId: string;
  /** Optimized, ready-to-use URL (auto format + auto quality for images). */
  url: string;
  /** Original secure URL. */
  secureUrl: string;
  width: number | null;
  height: number | null;
  format: string;
  bytes: number;
}

/** Appends Cloudinary auto-optimization params (auto format + auto quality). */
function optimizeUrl(rawUrl: string): string {
  return rawUrl.replace(
    /(https:\/\/res\.cloudinary\.com\/[^/]+\/(?:image)\/upload\/)/,
    (m) => `${m}f_auto,q_auto/`,
  )
}

function validateFile(file: File): string | null {
  if (file.size > MAX_FILE_SIZE) {
    return 'File size must be less than 5MB.'
  }
  if (!ALLOWED_ALL.includes(file.type)) {
    return 'Only JPEG, PNG, WebP images and PDF files are allowed.'
  }
  return null
}

/**
 * Confirms the bytes match the type the file claims.
 *
 * `file.type` comes from the browser's guess at the extension, so a renamed
 * `.exe` announces itself as `image/png` and sails through validateFile(). This
 * is a UX guard, not a security boundary — the real boundary is the signature's
 * allowed_formats, which Cloudinary checks. What it does buy is that a student
 * who picks the wrong file is told so here, rather than after the upload
 * succeeds and the document viewer renders nothing.
 */
async function sniffMismatch(file: File): Promise<string | null> {
  const head = new Uint8Array(await file.slice(0, 12).arrayBuffer())
  const startsWith = (...bytes: number[]) => bytes.every((b, i) => head[i] === b)

  const actual =
    startsWith(0xff, 0xd8, 0xff) ? 'image/jpeg'
    : startsWith(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a) ? 'image/png'
    // RIFF....WEBP
    : startsWith(0x52, 0x49, 0x46, 0x46) && head[8] === 0x57 && head[9] === 0x45
      && head[10] === 0x42 && head[11] === 0x50 ? 'image/webp'
    : startsWith(0x25, 0x50, 0x44, 0x46) ? 'application/pdf'
    : null

  if (actual === null) {
    return 'That file is not a JPEG, PNG, WebP or PDF.'
  }
  if (actual !== file.type) {
    return `That file is named like a ${file.type.split('/')[1]?.toUpperCase()} but its contents are ${actual.split('/')[1]?.toUpperCase()}. Re-save it and try again.`
  }
  return null
}

/**
 * A filename no other upload will reuse.
 *
 * The old unsigned preset derived public_id from the uploaded filename, so the
 * name decided the Cloudinary asset. capturePhoto() names every camera
 * shot `photo.jpeg`, which meant each new photo OVERWROTE the last one and
 * returned the identical URL — three chat messages sent across three days all
 * stored `/v1789079624/photo.jpg`, and every one of them displayed whichever
 * image had been uploaded last (or the browser's cached copy of it).
 *
 * Gallery uploads had the same hazard whenever two files shared a name.
 * Renaming here fixes every caller at once and does not depend on how the
 * preset happens to be configured.
 */
function uniqueUploadName(file: File): string {
  const dot = file.name.lastIndexOf('.')
  const ext = dot > 0 ? file.name.slice(dot) : ''
  const stem = (dot > 0 ? file.name.slice(0, dot) : file.name).replace(/[^a-zA-Z0-9_-]/g, '') || 'upload'
  const nonce = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
  return `${stem}-${nonce}${ext}`
}

async function performUpload(file: File): Promise<CloudinaryUploadResult> {
  const validationError = validateFile(file)
  if (validationError) throw new Error(validationError)
  const sniffError = await sniffMismatch(file)
  if (sniffError) throw new Error(sniffError)
  // Every public upload is a photo; PDFs only ever go up as private documents.
  if (!ALLOWED_IMAGE.includes(file.type)) throw new Error('Only JPEG, PNG and WebP images can be used here.')

  const { data: params, error } = await supabase.functions.invoke('doc-access', {
    body: { action: 'public-upload-params' },
  })
  if (error) throw error

  const form = new FormData()
  // The third argument sets the filename Cloudinary sees — see uniqueUploadName.
  form.append('file', file, uniqueUploadName(file))
  form.append('api_key', params.apiKey)
  form.append('timestamp', String(params.timestamp))
  form.append('public_id', params.publicId)
  form.append('allowed_formats', params.allowedFormats)
  form.append('signature', params.signature)

  const endpoint = `https://api.cloudinary.com/v1_1/${params.cloudName}/image/upload`

  const withTimeout = new Promise<CloudinaryUploadResult>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Upload timed out. Please try again.')), 60000)
    fetch(endpoint, { method: 'POST', body: form })
      .then(async (response) => {
        if (!response.ok) {
          const body = await response.text().catch(() => '')
          throw new Error(`Cloudinary upload failed (${response.status}): ${body || response.statusText}`)
        }
        return response.json()
      })
      .then((json) => {
        clearTimeout(timer)
        resolve({
          publicId: json.public_id,
          url: optimizeUrl(json.secure_url || json.url || ''),
          secureUrl: json.secure_url || json.url || '',
          width: json.width ?? null,
          height: json.height ?? null,
          format: json.format ?? file.type,
          bytes: json.bytes ?? file.size,
        })
      })
      .catch((err) => {
        clearTimeout(timer)
        reject(err)
      })
  })

  return withTimeout
}

/** Uploads one or more files / images to Cloudinary. */
export async function uploadToCloudinary(
  files: File | File[],
  _folder?: string,
): Promise<CloudinaryUploadResult[]> {
  const list = Array.isArray(files) ? files : [files]
  return Promise.all(list.map((file) => performUpload(file)))
}

/**
 * Legacy/central upload entry point. Keeps the previous signature used by the
 * rest of the app (ManagerOsas, PropertyDetail, StudentPayments,
 * StudentProfile, stores, AddPropertyWizard, …). Returns the Cloudinary URL.
 *
 * @param file    the File to upload (image or PDF)
 * @param _userId kept for signature parity (paths no longer used on Supabase)
 * @param _docType kept for signature parity (used as a hint only)
 */
export async function uploadDocument(
  file: File,
  _userId: string,
  _docType: string,
): Promise<string> {
  const result = await performUpload(file)
  return result.url || result.secureUrl
}

/**
 * Uploads a new profile photo and stores it where the app already looks.
 *
 * Written to two places: the auth user's metadata (what MainLayout reads for
 * your own chrome/profile, unchanged from before) and `users.avatar_url` —
 * without the latter, nobody else can ever see this photo, since a client can
 * only read its own session's auth metadata, never another user's. The
 * accommo:avatar-change event refreshes the bottom-nav avatar without
 * waiting for a reload.
 */
export async function uploadAvatar(file: File, userId: string): Promise<string> {
  if (!ALLOWED_IMAGE.includes(file.type)) {
    throw new Error('An avatar must be a JPEG, PNG or WebP image.')
  }

  const result = await performUpload(file)
  const url = result.url || result.secureUrl

  const { error } = await supabase.auth.updateUser({ data: { avatar_url: url } })
  if (error) throw error

  const { error: dbError } = await supabase.from('users').update({ avatar_url: url }).eq('id', userId)
  if (dbError) throw dbError

  window.dispatchEvent(new CustomEvent('accommo:avatar-change', { detail: { url } }))
  return url
}

/**
 * Uploads a new profile cover photo to `users.cover_url`. Unlike the avatar it
 * never appears in the app chrome, so there is no auth-metadata copy to keep.
 */
export async function uploadCover(file: File, userId: string): Promise<string> {
  if (!ALLOWED_IMAGE.includes(file.type)) {
    throw new Error('A cover photo must be a JPEG, PNG or WebP image.')
  }

  const result = await performUpload(file)
  const url = result.url || result.secureUrl

  const { error } = await supabase.from('users').update({ cover_url: url }).eq('id', userId)
  if (error) throw error
  return url
}

/* -------------------------------------------------------------------------- */
/* Sensitive documents: Cloudinary `authenticated` delivery                    */
/* -------------------------------------------------------------------------- */
//
// Identity documents, enrolment records and accommodation permits must not sit at
// a public URL — with the default `upload` delivery type the link itself is the
// credential, readable by anyone who ever sees it and unaffected by a later
// rejection. These upload with delivery type `authenticated` and are read back
// through short-lived signed URLs.
//
// Both signatures come from the `doc-access` edge function, because computing
// them needs the Cloudinary API secret and that must never reach client code.
// Payment proofs, chat photos, concern photos and support-ticket photos go the
// same way — they show receipts, rooms and people. Avatars and listing images
// deliberately stay public, signed through the same function (public-upload-params).

/** What we store in file_url: cld:<resource_type>:<type>:<format>:<public_id> */
export type DocumentRef = string;

export type DocumentTable = 'verification_documents' | 'accommodation_documents';

/** Every table whose file column holds private refs; mirrors doc-access. */
export type PrivateFileTable = DocumentTable | 'payments' | 'messages' | 'concerns' | 'tickets' | 'ticket_messages';

/** Uploads a document to Cloudinary with authenticated delivery; returns the ref to store. */
export async function uploadSecureDocument(file: File): Promise<DocumentRef> {
  const validationError = validateFile(file)
  if (validationError) throw new Error(validationError)
  const sniffError = await sniffMismatch(file)
  if (sniffError) throw new Error(sniffError)

  const isPdf = file.type === 'application/pdf'
  const { data: params, error } = await supabase.functions.invoke('doc-access', {
    body: { action: 'upload-params', resourceType: isPdf ? 'raw' : 'image' },
  })
  if (error) throw error

  const form = new FormData()
  // Unique for the same reason as the public path: two students photographing a
  // school ID both hand over a file called `photo.jpeg`. The filename is not one
  // of the signed parameters, so renaming cannot invalidate the signature.
  form.append('file', file, uniqueUploadName(file))
  form.append('api_key', params.apiKey)
  form.append('timestamp', String(params.timestamp))
  form.append('public_id', params.publicId)
  form.append('allowed_formats', params.allowedFormats)
  form.append('type', params.type)
  form.append('signature', params.signature)

  const endpoint = `https://api.cloudinary.com/v1_1/${params.cloudName}/${params.resourceType}/upload`
  const response = await fetch(endpoint, { method: 'POST', body: form })
  const json = await response.json()
  if (!response.ok) {
    throw new Error(`Upload failed (${response.status}): ${json?.error?.message || response.statusText}`)
  }
  return ['cld', params.resourceType, json.type || 'authenticated', json.format || '', json.public_id].join(':')
}

/**
 * Short-lived signed URL for one document row. Authorization happens inside the
 * function via this caller's own RLS, so a row you cannot select yields nothing.
 * Returns '' when the document is missing or not permitted.
 */
export async function secureDocUrl(
  table: PrivateFileTable,
  id: string | null | undefined,
  ref?: string,
): Promise<string> {
  if (!id) return ''
  const { data, error } = await supabase.functions.invoke('doc-access', {
    body: { action: 'view', table, id, ref },
  })
  if (error) return ''
  return (data?.url as string) || ''
}

export interface ScanDoc { url: string; pdf: boolean }

/**
 * The school ID and assessment of fees of a student this landlord/landlady
 * just QR-scanned. The server only answers within 30 minutes of the scan; a
 * missing file, or no recent scan, comes back as null.
 */
export async function scannedStudentDocs(
  studentId: string,
): Promise<{ schoolId: ScanDoc | null; assessmentOfFees: ScanDoc | null } | null> {
  const { data, error } = await supabase.functions.invoke('doc-access', {
    body: { action: 'scan-docs', id: studentId },
  })
  if (error || !data) return null
  return { schoolId: data.schoolId ?? null, assessmentOfFees: data.assessmentOfFees ?? null }
}

/** One stored value: a private ref gets signed, anything else passes through. */
export async function signRef(table: PrivateFileTable, id: string, value: string | null | undefined): Promise<string> {
  if (!value) return ''
  return value.startsWith('cld:') ? secureDocUrl(table, id, value) : value
}

/**
 * Swaps each row's private file refs in `column` for short-lived signed links,
 * in place — a string or an array of strings. Plain URLs from before files went
 * private are left as they are. Call it right after the rows are fetched.
 */
export async function signRows<R extends { id: string }>(
  table: PrivateFileTable,
  rows: R[] | null | undefined,
  column: keyof R & string,
): Promise<void> {
  await Promise.all((rows ?? []).map(async (row) => {
    const value = row[column] as unknown
    const signed = Array.isArray(value)
      ? await Promise.all(value.map((v: string) => signRef(table, row.id, v)))
      : typeof value === 'string' ? await signRef(table, row.id, value) : value;
    (row as Record<string, unknown>)[column] = signed
  }))
}
