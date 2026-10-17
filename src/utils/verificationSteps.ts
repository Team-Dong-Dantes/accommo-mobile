// The dashboards' verification hero (D-SE1..3, D-LE1..3): "Step x of 3" derived
// from what is already known, not stored. Steps: account made → requirements
// sent → OSAS verified. Pure, so it can be tested without mounting a page.

export interface VerificationInput {
  role: 'student' | 'manager'
  /** users.status */
  status: string
  /** Latest verification_documents.uploaded_at, null when nothing was sent. */
  docsSentAt: string | null
  profileComplete: boolean
}

export interface VerificationSteps {
  done: number
  total: 3
  /** Requirements are with OSAS and nothing is asked of the user. */
  inReview: boolean
  next: { label: string; route: string } | null
}

export function verificationSteps({ role, status, docsSentAt, profileComplete }: VerificationInput): VerificationSteps {
  if (status === 'verified') return { done: 3, total: 3, inReview: false, next: null }
  // Sent back or refused: what was sent no longer counts.
  const sentBack = status === 'needs_resubmission' || status === 'rejected'
  const sent = !!docsSentAt && !sentBack
  const osas = role === 'manager' ? '/manager/osas?tab=mine' : '/student/support'
  const support = role === 'manager' ? '/manager/support' : '/student/support'
  const done = sent ? 2 : 1
  if (status === 'suspended') return { done, total: 3, inReview: false, next: { label: 'Contact OSAS', route: support } }
  if (!profileComplete) return { done, total: 3, inReview: false, next: { label: 'Complete your profile', route: `/${role}/profile/complete` } }
  if (!sent) return { done, total: 3, inReview: false, next: { label: sentBack ? 'Re-upload requirements' : 'Upload requirements', route: osas } }
  return { done, total: 3, inReview: true, next: null }
}
