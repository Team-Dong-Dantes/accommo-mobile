// Accreditation rounds and the words used for them.

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
