// The words PaymentStatement puts on a stay's items and payments: what an
// item is called, where it stands, how a payment was made and what became of it.
// Reads the statement's own props at call time, so it stays reactive.
import type { Ref } from 'vue'
import { formatDate, formatMonth, formatPesoExact, PAYMENT_METHOD_LABEL } from '@/utils/format'
import { BILL_TAG, type LedgerRow, type StatementItem, type StatementPayment } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'

/** What a payment on the statement carries beyond the ledger's own fields. */
export type StatementPay = StatementPayment & { amount: number; status: string; method: string; createdAt?: string; paidAt?: string | null; rejectionReason?: string; batchId?: string | null }

export function statementLabels<P extends StatementPay>(
  props: { ledger: LedgerRow[]; payments: P[]; billUtility: Record<string, UtilityKey>; depositHeld?: number | undefined },
  landlord: Ref<boolean>,
) {
  function sameItem(a: P, b: P): boolean {
    return a.kind === b.kind && (a.kind === 'bill' ? a.billId === b.billId : a.kind !== 'rent' || a.month.slice(0, 7) === b.month.slice(0, 7))
  }
  function rowOf(p: P): LedgerRow | undefined {
    return props.ledger.find((r) => (p.kind === 'bill' ? r.billId === p.billId : r.kind === p.kind && (p.kind !== 'rent' || r.month?.slice(0, 7) === p.month.slice(0, 7))))
  }
  function batchWhat(p: P): string {
    const rows = props.payments.filter((x) => (p.batchId ? x.batchId === p.batchId : x.id === p.id))
    const names = rows.map((x) => (x.kind === 'bill' ? (BILL_TAG[props.billUtility[x.billId ?? ''] ?? 'water'] ?? 'bill').toLowerCase() : x.kind === 'rent' ? `${formatMonth(x.month).split(' ')[0]} rent` : x.kind))
    return names.length > 1 ? `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}` : names[0] ?? 'it'
  }
  function methodName(m: string): string {
    return m === 'deposit' ? 'deposit' : PAYMENT_METHOD_LABEL[m] ?? m
  }

  function shortName(r: LedgerRow): string {
    if (r.kind === 'rent') return `${formatMonth(r.month).split(' ')[0]} rent`
    if (r.kind === 'bill') return (BILL_TAG[props.billUtility[r.billId ?? ''] ?? 'water'] ?? 'Bill').toLowerCase()
    return 'deposit'
  }
  function itemName(i: StatementItem<P>): string {
    if (i.row.kind === 'rent') return i.advance ? 'Rent · advance' : 'Rent'
    if (i.row.kind === 'bill') return BILL_TAG[props.billUtility[i.row.billId ?? ''] ?? 'water'] ?? 'Utility bill'
    return 'Deposit'
  }
  function itemNote(i: StatementItem<P>): string {
    const r = i.row
    const left = `${formatPesoExact(r.balance)} left`
    if (r.kind === 'deposit' && i.status === 'paid') {
      const held = props.depositHeld ?? 0
      if (held > 0.009) return landlord.value ? `Held · ${formatPesoExact(held)}` : 'Held · pays your last month'
      return 'Used or returned'
    }
    switch (i.status) {
      case 'paid':
        return r.waived > 0.009 && r.confirmed + 0.009 < r.due ? 'Settled · part forgiven' : 'Paid'
      case 'pending':
        return landlord.value ? 'Waiting for your confirmation' : 'Waiting for confirmation'
      case 'overdue':
        return `Overdue since ${formatDate(r.dueDate)}${r.balance + 0.009 < r.due ? ` · ${left}` : ''}`
      case 'partial':
        return `${left} · due ${formatDate(r.dueDate)}`
      default:
        return r.kind === 'rent' && i.advance ? `Due on moving in · ${formatDate(r.dueDate)}` : `Due ${formatDate(r.dueDate)}`
    }
  }
  function payIcon(p: P): string {
    if (p.status === 'rejected') return 'lucide:undo-2'
    if (p.status === 'pending_verification') return 'lucide:hourglass'
    if (p.method === 'cash' || p.method === 'deposit') return 'lucide:banknote'
    return 'lucide:smartphone'
  }
  function payLine(p: P): string {
    const how = p.method === 'deposit' ? 'Paid from the deposit' : `${methodName(p.method)} ${formatPesoExact(p.amount)}`
    switch (p.status) {
      case 'paid':
        return p.method === 'deposit' ? `${how} · ${formatPesoExact(p.amount)}` : `${how} · confirmed ${formatDate(p.paidAt ?? p.createdAt ?? p.month)}`
      case 'pending_verification':
        return `${how} · ${landlord.value ? 'waiting for you' : 'waiting for confirmation'}`
      case 'rejected':
        return `${how} · sent back`
      case 'waived':
        return `${formatPesoExact(p.amount)} forgiven`
      default:
        return how
    }
  }

  return { sameItem, rowOf, batchWhat, methodName, shortName, itemName, itemNote, payIcon, payLine }
}

export function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1)
}
