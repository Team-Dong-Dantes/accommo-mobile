// Accreditation rounds and the words used for them.
import type { HistoryItem } from '@/components/shared/ReviewHistory.vue'
import { parseServerTime } from '@/utils/format'
import { permitLabel } from '@/utils/permits'

export interface Round {
  id: string
  round: number
  kind: 'new' | 'resubmission' | 'appeal' | 'renewal' | 'change' | 'permit_update'
  submitted_at: string
  message: string | null
  proposed_changes: Record<string, unknown> | null
  decided_at: string | null
  decision: 'approved' | 'returned' | 'rejected' | null
  flagged_docs: string[] | null
  tags: string[] | null
  note: string | null
}

export const KIND_LABEL: Record<Round['kind'], string> = {
  new: 'Submission',
  resubmission: 'Resubmission',
  appeal: 'Appeal',
  renewal: 'Renewal',
  change: 'Change request',
  permit_update: 'Permit update',
}
export const DECISION_LABEL: Record<string, string> = {
  approved: 'approved',
  returned: 'sent back for changes',
  rejected: 'refused',
}
/** Renewal opens this many days before the term ends (request_renewal). */
export const RENEW_WINDOW_DAYS = 60

export const CHANGE_LABEL: Record<string, string> = {
  name: 'Name',
  accommodation_type: 'Type',
  gender_policy: 'Accepts',
  purok: 'Purok',
  barangay: 'Barangay',
  city: 'City',
  lat: 'Map pin',
  lng: 'Map pin',
}

/** What the component hands its state: its props and emit. */
export interface Seed {
  props: { accommodationId: string; status: string; appealUsed: boolean; accreditationExpiresAt: string | null; docs: { doc_type: string; uploaded_at: string }[] }
  emit: { (e: 'changed'): void; (e: 'docs-changed'): void; (e: 'delete'): void }
}

/** Decided rounds as review-history entries: what was asked, what OSAS said. */
export function roundHistory(rounds: Round[]): HistoryItem[] {
  return rounds
    .filter((r) => r.decided_at)
    .map((r) => ({
      id: r.id,
      title: KIND_LABEL[r.kind],
      verdict: DECISION_LABEL[r.decision ?? ''] ?? '',
      tone: r.decision ?? '',
      when: parseServerTime(r.decided_at!).toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' }),
      lines: [
        r.flagged_docs?.length ? `Flagged: ${r.flagged_docs.map(permitLabel).join(', ')}` : '',
        r.note ? `“${r.note}”` : '',
        r.message ? `You wrote: “${r.message}”` : '',
      ].filter(Boolean),
    }))
}
