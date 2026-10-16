// The rent history grid's cells and a stay's rent tally, from the ledger
// (landlord_ledger()). Same rules as the web rent report (rentYear/rentCell in
// accommo-web features/reports/parts.ts): partial and overdue are both unpaid,
// and a month still ahead is not owed yet.

import type { LedgerRow } from '@/utils/payments'

export type RentCell = 'paid' | 'confirm' | 'unpaid' | 'upcoming' | 'none'

/** YYYY-MM of a ledger row or a YYYY-MM-DD date. */
const key = (s: string | null) => (s ?? '').slice(0, 7)

/** One stay's rent in one month; `month` is YYYY-MM or YYYY-MM-DD, `today` YYYY-MM-DD. */
export function rentCell(rows: LedgerRow[], month: string, today: string): RentCell {
  const r = rows.find((x) => x.kind === 'rent' && key(x.month) === key(month))
  if (!r) return 'none'
  if (r.state === 'paid') return 'paid'
  if (r.state === 'pending') return 'confirm'
  return key(r.month) <= key(today) ? 'unpaid' : 'upcoming'
}

export interface StayRent {
  paidMonths: number
  /** Rent months come due, this one included. */
  totalMonths: number
  unpaid: LedgerRow[]
  unpaidAmount: number
}

/** One stay's rent so far: months paid of months due, and what is still unpaid. */
export function stayRent(rows: LedgerRow[], today: string): StayRent {
  const due = rows.filter((r) => r.kind === 'rent' && key(r.month) <= key(today))
  const unpaid = due.filter((r) => r.state !== 'paid' && r.state !== 'pending')
  return {
    paidMonths: due.filter((r) => r.state === 'paid').length,
    totalMonths: due.length,
    unpaid,
    unpaidAmount: unpaid.reduce((n, r) => n + r.balance, 0),
  }
}
