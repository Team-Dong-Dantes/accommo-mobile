// The OSAS page's property half: a landlord/landlady's accommodations, the
// newest version of each permit, every accreditation round (what OSAS flagged
// when it last sent one back, and the review history), and the short-lived
// links that open the files.

import { computed, ref, watch } from 'vue'
import { supabase } from '@/utils/supabase'
import { parseServerTime } from '@/utils/format'
import { since } from '@/utils/notifications'
import { secureDocUrl } from '@/utils/upload'
import { permitDate, permitReplaceOpen } from '@/utils/permits'
import { roundHistory, type Round } from '@/components/manager/accreditation/model'
import type { RequirementItem } from '@/components/shared/RequirementCards.vue'

export const DOC_TYPES = ['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] as const
export const DOC_TYPE_LABEL: Record<string, string> = {
  sanitary_permit: 'Sanitary permit',
  fire_safety: 'Fire safety certificate',
  business_permit: 'Business permit',
  building_permit: 'Building permit',
}

export interface Accommodation {
  id: string
  name: string
  /** "Barangay, City" — how listings show an address. */
  place: string
  status: string
}

export function useOsasPermits() {
  const accommodations = ref<Accommodation[]>([])
  const selectedId = ref('')
  const permitRows = ref<{ id: string; accommodation_id: string; doc_type: string; file_url: string; expires_at: string | null; uploaded_at: string; version: number }[]>([])
  /** Per sent-back accommodation: the permits OSAS flagged, and when it decided. */
  const sentBack = ref<Record<string, { docs: string[]; decidedAt: number }>>({})
  const rounds = ref<(Round & { accommodation_id: string })[]>([])

  const selected = computed(() => accommodations.value.find((a) => a.id === selectedId.value))
  const history = computed(() => roundHistory(rounds.value.filter((r) => r.accommodation_id === selectedId.value)))

  // Property permits have no per-file approval: a tone is expiry-derived unless
  // OSAS flagged the permit when sending the listing back. Replacement locks once
  // the listing is accredited (permitReplaceOpen).
  const docs = computed<RequirementItem[]>(() =>
    DOC_TYPES.map((type) => {
      const label = DOC_TYPE_LABEL[type] ?? type
      const row = permitRows.value.find((d) => d.accommodation_id === selectedId.value && d.doc_type === type)
      if (!row) return { type, label, statusLabel: 'Not submitted', tone: 'idle', when: '', fileUrl: '', verified: false }
      const link = signed.value[row.id]
      // OSAS's verdict outranks the date: a permit it flagged when sending the
      // listing back needs a new file, however far off its expiry is.
      const flag = sentBack.value[selectedId.value]
      const flagged = Boolean(flag?.docs.includes(type) && parseServerTime(row.uploaded_at).getTime() <= flag.decidedAt)
      // Locked once accredited unless expiring or flagged; shown as "Verified".
      const locked = !permitReplaceOpen(selected.value?.status ?? '', row.expires_at, flagged)
      const base = { type, label, fileUrl: link?.url ?? '', fileLoading: !link, verified: locked }
      if (flagged) {
        return { ...base, statusLabel: 'Needs resubmission', tone: 'danger', when: 'OSAS asked for a new file' }
      }
      // Expiry is required on upload now, so a null one only happens on a
      // legacy row from before that — flag it rather than reading as settled.
      if (!row.expires_at) return { ...base, statusLabel: 'No expiration set', tone: 'warn', when: `Uploaded ${since(row.uploaded_at)}` }
      const now = Date.now()
      const soon = now + 30 * 24 * 60 * 60 * 1000
      const t = new Date(row.expires_at).getTime()
      if (t < now) return { ...base, statusLabel: 'Expired', tone: 'danger', when: `Expired ${permitDate(row.expires_at)}` }
      if (t < soon) return { ...base, statusLabel: 'Expiring soon', tone: 'warn', when: `Expires ${permitDate(row.expires_at)}` }
      return { ...base, statusLabel: 'Valid', tone: 'good', when: `Expires ${permitDate(row.expires_at)}` }
    }),
  )

  /**
   * Every accommodation's latest permits, fetched in one query, so switching
   * between boarding houses needs no round trip for statuses or dates. Only the
   * file links are fetched per accommodation (signPermits), since each one is a
   * call to the doc-access function.
   */
  async function loadPermits() {
    const ids = accommodations.value.map((a) => a.id)
    if (!ids.length) {
      permitRows.value = []
      return
    }
    const [{ data, error: docError }, { data: roundData, error: roundError }] = await Promise.all([
      supabase
        .from('accommodation_documents')
        .select('id, accommodation_id, doc_type, file_url, expires_at, uploaded_at, version')
        .in('accommodation_id', ids)
        .order('version', { ascending: false }),
      supabase
        .from('accreditation_rounds')
        .select('id, accommodation_id, round, kind, submitted_at, message, proposed_changes, decided_at, decision, flagged_docs, tags, note')
        .in('accommodation_id', ids)
        .order('round', { ascending: false }),
    ])
    if (docError) throw docError
    if (roundError) throw roundError
    rounds.value = (roundData ?? []) as typeof rounds.value

    // Sent back for revision, or a permit update sent back on a live listing.
    const flagStatus = new Map(accommodations.value.map((a) => [a.id, ['needs_revision', 'accredited', 'delisted'].includes(a.status)]))
    // Newest send-back per accommodation only; rounds come newest first.
    const flags: typeof sentBack.value = {}
    for (const r of rounds.value) {
      if (r.decision !== 'returned' || !flagStatus.get(r.accommodation_id)) continue
      if (flags[r.accommodation_id] || !r.decided_at) continue
      flags[r.accommodation_id] = { docs: r.flagged_docs ?? [], decidedAt: parseServerTime(r.decided_at).getTime() }
    }
    sentBack.value = flags

    const seen = new Set<string>()
    permitRows.value = (data ?? []).filter((d) => {
      const key = `${d.accommodation_id}:${d.doc_type}`
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
  }

  // doc-access links live 5 minutes; reuse one for 4 so it never expires on screen.
  const SIGNED_FOR_MS = 4 * 60 * 1000
  const signed = ref<Record<string, { url: string; at: number }>>({})

  /** Signs the selected accommodation's files that have no fresh link yet. */
  async function signPermits(accommodationId: string) {
    const now = Date.now()
    await Promise.all(
      permitRows.value
        .filter((d) => d.accommodation_id === accommodationId && !(now - (signed.value[d.id]?.at ?? 0) < SIGNED_FOR_MS))
        .map(async (d) => {
          // Permits use Cloudinary authenticated delivery: file_url holds a ref,
          // so each one is signed for this viewer.
          const url = await secureDocUrl('accommodation_documents', d.id)
          signed.value = { ...signed.value, [d.id]: { url, at: Date.now() } }
        }),
    )
  }

  watch(selectedId, (id) => {
    if (id) void signPermits(id)
  })

  return { accommodations, selectedId, selected, docs, history, loadPermits, signPermits }
}
