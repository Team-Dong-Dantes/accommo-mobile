// The one way a permit file reaches OSAS.
//
// The wizard, the OSAS screen and the accommodation's own "Replace" button each
// used to upload permits their own way: the wizard stored no expiry date (so
// the nightly permit sweep never fired for those listings), nothing checked
// that a photo was legible, and a 12-megapixel phone shot went up whole over
// mobile data. Every path now goes through prepare → upload → save here.
import { supabase } from '@/utils/supabase'
import { uploadSecureDocument } from '@/utils/upload'
import { manilaToday } from '@/utils/payments'

export const PERMIT_TYPES = [
  { key: 'sanitary_permit', label: 'Sanitary permit' },
  { key: 'fire_safety', label: 'Fire safety permit' },
  { key: 'business_permit', label: 'Business permit' },
  { key: 'building_permit', label: 'Building permit' },
] as const

export type PermitType = (typeof PERMIT_TYPES)[number]['key']

export function permitLabel(type: string): string {
  return PERMIT_TYPES.find((p) => p.key === type)?.label ?? type.replace(/_/g, ' ')
}

/** Below this on the short side, the small print on a permit is unreadable. */
export const MIN_SHORT_SIDE = 1000
/** Above this on the long side, the extra pixels only cost upload time. */
export const MAX_LONG_SIDE = 2000

/** A photo too small for OSAS to read. */
export function isTooSmall(width: number, height: number): boolean {
  return Math.min(width, height) < MIN_SHORT_SIDE
}

/** The size to shrink a photo to, or null when it is already small enough. */
export function shrinkTarget(width: number, height: number): { width: number; height: number } | null {
  const long = Math.max(width, height)
  if (long <= MAX_LONG_SIDE) return null
  const scale = MAX_LONG_SIDE / long
  return { width: Math.round(width * scale), height: Math.round(height * scale) }
}

/**
 * Whether a new version of a permit may be uploaded. Mirrors the database's
 * permit_replacement_open (migration 20261003010000), which has the final say:
 * on an accredited or delisted listing only a permit within 30 days of expiry
 * (or past it, or undated), or one OSAS flagged, may be replaced.
 */
export function permitReplaceOpen(
  status: string,
  expiresAt: string | null | undefined,
  flagged: boolean,
  today = new Date(),
): boolean {
  if (status !== 'accredited' && status !== 'delisted') return true
  if (!expiresAt || flagged) return true
  const soon = new Date(today)
  soon.setDate(soon.getDate() + 30)
  return expiresAt < manilaToday(soon)
}

/** "Oct 25, 2027" — a permit's date. Parsed as a calendar day, so no timezone shift. */
export function permitDate(date: string): string {
  return new Date(`${date.slice(0, 10)}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
}

/** An expiry date a permit may be saved with: given, real, and not already past. */
export function expiryProblem(value: string, today = new Date()): string | null {
  if (!value) return 'Add the expiry date printed on the permit.'
  const date = new Date(`${value}T23:59:59`)
  if (Number.isNaN(date.getTime())) return 'That is not a date.'
  if (date < today) return 'That permit has already expired. Upload the renewed one.'
  return null
}

export async function sha256Hex(blob: Blob): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', await blob.arrayBuffer())
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function imageSize(file: File): Promise<{ width: number; height: number; bitmap: ImageBitmap }> {
  const bitmap = await createImageBitmap(file)
  return { width: bitmap.width, height: bitmap.height, bitmap }
}

async function shrink(bitmap: ImageBitmap, target: { width: number; height: number }, name: string): Promise<File> {
  const canvas = document.createElement('canvas')
  canvas.width = target.width
  canvas.height = target.height
  canvas.getContext('2d')!.drawImage(bitmap, 0, 0, target.width, target.height)
  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.85))
  if (!blob) throw new Error('Could not prepare that photo. Try another one.')
  return new File([blob], name.replace(/\.[^.]+$/, '') + '.jpg', { type: 'image/jpeg' })
}

export interface UploadedPermit {
  /** The private file reference to store in accommodation_documents.file_url. */
  ref: string
  /** SHA-256 of the file as picked, for OSAS's reused-permit check. */
  sha256: string
}

/**
 * Checks, shrinks and uploads one permit file. PDFs pass straight through;
 * photos must be legible and are shrunk to at most MAX_LONG_SIDE. Throws an
 * Error whose message is fit to show.
 */
export async function uploadPermitFile(file: File): Promise<UploadedPermit> {
  // Hashed as picked, before any shrinking: the same photo submitted twice is
  // the same bytes, whatever this device's canvas makes of it.
  const sha256 = await sha256Hex(file)
  let toSend = file
  if (file.type.startsWith('image/')) {
    const { width, height, bitmap } = await imageSize(file)
    try {
      if (isTooSmall(width, height)) {
        throw new Error(
          `That photo is ${width}×${height}, too small for OSAS to read. Take it closer, or upload the PDF.`,
        )
      }
      const target = shrinkTarget(width, height)
      if (target) toSend = await shrink(bitmap, target, file.name || 'permit.jpg')
    } finally {
      bitmap.close()
    }
  }
  const ref = await uploadSecureDocument(toSend)
  return { ref, sha256 }
}

/**
 * Saves an uploaded permit as the next version of its type. On a live listing
 * the database opens a permit_update round for OSAS (tg_permit_needs_review);
 * the listing stays visible meanwhile.
 */
export async function savePermitVersion(
  accommodationId: string,
  docType: string,
  uploaded: UploadedPermit,
  expiresAt: string,
): Promise<void> {
  const { data: latest, error: readError } = await supabase
    .from('accommodation_documents')
    .select('version')
    .eq('accommodation_id', accommodationId)
    .eq('doc_type', docType)
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (readError) throw readError
  const { error } = await supabase.from('accommodation_documents').insert({
    accommodation_id: accommodationId,
    doc_type: docType,
    file_url: uploaded.ref,
    file_sha256: uploaded.sha256,
    expires_at: expiresAt,
    version: (latest?.version ?? 0) + 1,
  })
  if (error) throw error
}
