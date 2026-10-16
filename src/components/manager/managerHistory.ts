// Small pure helpers shared by the landlord/landlady History tabs.

export interface Review {
  id: string
  rating: number
  comment: string
  createdAt: string
  /** "You" for reviews about the landlord/landlady, else the property's name. */
  source: string
  kind: 'user' | 'property'
}

/** A finished payment (paid, forgiven or rejected) — what the Payments tab lists. */
export interface PayRow {
  id: string
  leaseId: string
  amount: number
  status: string
  method: string
  description: string | null
  month: string
  /** paid_at, else created_at. */
  at: string
}

export type DateFilter = 'all' | '30d' | '90d' | 'year'

export const END_LABEL: Record<string, string> = {
  terminated: 'Terminated',
  leave_approved: 'Moved out',
  stay_ended: 'Lease ended',
  ended: 'Lease ended',
}

/** Whole months of a stay (30.44-day steps, as stayProgress), at least 1. */
export function stayMonths(start: string, end: string): number {
  const days = (Date.parse(`${end}T00:00:00`) - Date.parse(`${start}T00:00:00`)) / 864e5
  return Math.max(1, Math.round(days / 30.44))
}

export function monthsText(n: number): string {
  return `${n} month${n === 1 ? '' : 's'}`
}

export function withinDateFilter(iso: string, key: DateFilter): boolean {
  if (key === 'all') return true
  const then = new Date(iso).getTime()
  if (key === '30d') return Date.now() - then <= 30 * 86400000
  if (key === '90d') return Date.now() - then <= 90 * 86400000
  return new Date(iso).getFullYear() === new Date().getFullYear()
}

/** "Aug 2025 – May 2026" */
export function periodText(start: string, end: string): string {
  const f = (d: string) => new Date(`${d}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' })
  return `${f(start)} – ${f(end)}`
}
