// The dashboard's money: the rent card, the most overdue boarder, unpaid bills
// and each property's rent, all from the same buildCollections the Payments tab
// uses so the numbers cannot disagree with it.
import type { LandlordMoney } from '@/api/landlordMoney'
import { buildCollections, type Collections } from '@/utils/collections'
import { BILL_TAG, manilaToday } from '@/utils/payments'
import type { Property } from '@/components/manager/property'

export interface Rent { collected: number; coming: number; late: number; total: number }
export interface LateAction { studentId: string; name: string; days: number; amount: number; property: string }

export interface RentSummary {
  rent: Rent
  confirmCount: number
  lateAction: LateAction | null
  unpaidBills: { amount: number; sub: string }
  propRent: Record<string, { paid: number; due: number; dot: boolean }>
}

export const shortDate = (iso: string) => new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })

export function lateOf(col: Collections): LateAction | null {
  const o = [...col.late].sort((a, b) => (b.daysLate ?? 0) - (a.daysLate ?? 0))[0]
  if (!o) return null
  return {
    studentId: o.lease.studentId,
    name: o.lease.studentName.split(' ')[0] || 'A boarder',
    days: o.daysLate ?? 0,
    amount: o.amount,
    property: o.lease.accommodationName,
  }
}

/** Everything the rent card and property cards show; zeros when the read failed. */
export function rentSummary(money: LandlordMoney | null, properties: Property[]): RentSummary {
  const out: RentSummary = {
    rent: { collected: 0, coming: 0, late: 0, total: 0 },
    confirmCount: 0,
    lateAction: null,
    unpaidBills: { amount: 0, sub: 'All paid' },
    propRent: {},
  }
  if (money) {
    const day = manilaToday()
    const col = buildCollections(money.leases, money.ledger, money.payments, money.billUtility, money.billed, day)
    out.rent = {
      collected: col.collected,
      coming: col.toConfirm + col.toCome,
      late: col.overdue,
      total: col.collected + col.toConfirm + col.toCome + col.overdue,
    }
    out.confirmCount = col.confirm.length
    out.lateAction = lateOf(col)

    // Bill rows with something left to pay, on stays that are still running.
    const current = new Set(money.leases.filter((l) => l.status === 'active' || l.status === 'leave_requested').map((l) => l.id))
    const bills = money.ledger
      .filter((r) => r.kind === 'bill' && r.balance > 0.009 && current.has(r.leaseId))
      .sort((a, b) => (a.dueDate ?? '').localeCompare(b.dueDate ?? ''))
    const first = bills[0]
    out.unpaidBills = {
      amount: bills.reduce((n, r) => n + r.balance, 0),
      sub: first
        ? `${(BILL_TAG[money.billUtility[first.billId ?? ''] ?? 'water'] ?? 'Bill').replace(' bill', '')}${first.dueDate ? ` · due ${shortDate(first.dueDate)}` : ''}`
        : 'All paid',
    }

    const per: RentSummary['propRent'] = {}
    for (const p of properties) {
      const ids = new Set(money.leases.filter((l) => l.accommodationId === p.id).map((l) => l.id))
      const c = buildCollections(
        money.leases.filter((l) => ids.has(l.id)),
        money.ledger.filter((r) => ids.has(r.leaseId)),
        money.payments.filter((x) => ids.has(x.leaseId)),
        money.billUtility,
        money.billed,
        day,
      )
      per[p.id] = {
        paid: c.collected,
        due: c.collected + c.toConfirm + c.toCome + c.overdue,
        dot: c.late.length > 0 || c.confirm.length > 0 || p.expired > 0,
      }
    }
    out.propRent = per
  }
  return out
}
