// The shapes My Stay reads: the lease, its bills and payments.
import { type UtilityKey, type UtilityTerms } from '@/utils/listings'

export function yesNo(value: boolean | null | undefined): string {
  if (value === null || value === undefined) return ''
  return value ? 'Allowed' : 'Not allowed'
}

// Advance/deposit have no dedicated column on `payments` (only `month`,
// which rent needs and these don't) — tagged via `description` instead of a
// schema change, and excluded from the rent month-sequence by that tag.
// Rules live in utils/payments.ts so they can be tested without mounting this
// 1600-line page. The tags are re-exported names, not new constants.

export interface Lease {
  id: string
  managerId: string
  managerName: string
  managerTitle: string
  managerInitials: string
  managerAvatarUrl: string | null
  replyMinutes: number | null
  accommodationName: string
  roomLabel: string
  /** The accommodation's cover photo, or empty for the monogram. */
  photoUrl: string
  status: 'active' | 'pending' | 'leave_requested' | 'ended' | 'terminated'
  monthlyRent: number
  /** The landlord/landlady's partial-payment terms for this stay. */
  allowPartial: boolean
  partialMinPct: number
  startDate: string
  endDate: string
  /** The move-out day asked for (waiting) or approved (still active). */
  leaveDate: string | null
  roomType: string
  capacity: number | null
  address: string
  amenities: string[]
  utilities: Record<UtilityKey, UtilityTerms>
  rules: { label: string; value: string }[]
  roommateCount: number | null
}
/** A water/electric bill the landlord/landlady posted (utility_bills). */
export interface Bill {
  id: string
  leaseId: string
  utility: UtilityKey
  month: string
  amount: number
  note: string
  dueDate: string
  /** Unpaid past its due date (Manila time). */
  overdue: boolean
  settled: boolean
}
export interface Payment {
  id: string
  leaseId: string
  month: string
  kind: string
  billId: string | null
  amount: number
  status: string
  method: string
  roomLabel: string
  accommodationName: string
  description: string
  txnReference: string
  proofUrl: string
  paidAt: string | null
  verifiedByName: string
  rejectionReason: string
  note: string
  promiseDate: string | null
  receiptNo: string
  createdAt: string
  batchId: string | null
}

