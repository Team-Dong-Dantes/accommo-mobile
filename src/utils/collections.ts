// The landlord/landlady's Payments tab (CollectionsPanel.vue), worked out from
// every tenant's ledger (landlord_ledger()) and the payments still waiting on
// them. Pure, so it can be tested without mounting the panel.

import { BILL_TAG, isLateRow, type LedgerRow } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'

export interface CollectionLease {
  id: string
  studentId: string
  studentName: string
  avatarColor: string | null
  avatarUrl: string | null
  roomLabel: string
  accommodationId: string
  accommodationName: string
  status: string
  startDate: string
  /** The move-out day asked for or approved. */
  leaveDate: string | null
  /** Utilities this stay is billed for monthly (own meter or split). */
  metered: UtilityKey[]
}

export interface CollectionPayment {
  id: string
  batchId: string | null
  leaseId: string
  amount: number
  method: string
  status: string
  kind: string
  month: string
  billId: string | null
  description: string | null
  createdAt: string
  promiseDate: string | null
}

export type CollectionLedgerRow = LedgerRow & { leaseId: string }

/** One transfer a student says they made: every row of one batch. */
export interface ToConfirm {
  key: string
  lease: CollectionLease
  /** A row of the batch: the review sheet loads the rest from it. */
  paymentId: string
  amount: number
  method: string
  what: string
  /** Whole days since it was sent. */
  waitDays: number
}

export interface Owing {
  lease: CollectionLease
  amount: number
  what: string
  /** Whole days past the earliest unpaid due date; only set on `late` entries. */
  daysLate?: number
  tag: 'new' | 'leaving' | null
}

export interface Collections {
  /** YYYY-MM-01 of the month the summary is about. */
  month: string
  collected: number
  toConfirm: number
  overdue: number
  toCome: number
  confirm: ToConfirm[]
  late: Owing[]
  coming: Owing[]
  paid: CollectionLease[]
  past: Owing[]
  /** Tenants with a metered utility not billed for this month yet, by utility. */
  unposted: { tenants: number; utilities: UtilityKey[] }
}

const DAY = 24 * 60 * 60 * 1000

function shortMonth(month: string | null): string {
  return month ? new Date(`${month.slice(0, 10)}T00:00:00`).toLocaleDateString('en-PH', { month: 'short' }) : ''
}

function itemName(r: LedgerRow, billUtility: Record<string, UtilityKey>): string {
  if (r.kind === 'rent') return `${shortMonth(r.month)} rent`
  if (r.kind === 'bill') return (BILL_TAG[billUtility[r.billId ?? ''] ?? 'water'] ?? 'Bill').toLowerCase()
  return 'deposit'
}

function joinNames(names: string[]): string {
  const s = names.length > 2 ? `${names.slice(0, 2).join(' + ')} + ${names.length - 2} more` : names.join(' + ')
  return s.charAt(0).toUpperCase() + s.slice(1)
}

function daysBetween(from: string, to: string): number {
  return Math.round((new Date(`${to}T00:00:00`).getTime() - new Date(`${from}T00:00:00`).getTime()) / DAY)
}

/** YYYY-MM-DD of the last day of today's month. */
export function monthEndOf(today: string): string {
  const d = new Date(`${today.slice(0, 7)}-01T00:00:00`)
  d.setMonth(d.getMonth() + 1)
  d.setDate(0)
  return d.toLocaleDateString('en-CA')
}

export { isLateRow }

/** The month at a glance (MonthSummary.vue): its four parts always add up. */
export interface MonthTotals {
  month: string
  collected: number
  toConfirm: number
  overdue: number
  toCome: number
}

/** One stay's month: paid toward this month, waiting, late, and still due by month end. */
export function stayMonthSummary(ledger: LedgerRow[], today: string): MonthTotals {
  const month = `${today.slice(0, 7)}-01`
  const end = monthEndOf(today)
  const t: MonthTotals = { month, collected: 0, toConfirm: 0, overdue: 0, toCome: 0 }
  for (const r of ledger) {
    if ((r.dueDate ?? '') >= month && (r.dueDate ?? '') <= end) t.collected += r.confirmed
    t.toConfirm += r.pending
    if (r.balance <= 0.009) continue
    if (isLateRow(r, today)) t.overdue += r.balance
    else if ((r.dueDate ?? '') <= end) t.toCome += r.balance
  }
  return t
}

export function buildCollections(
  leases: CollectionLease[],
  ledger: CollectionLedgerRow[],
  payments: CollectionPayment[],
  billUtility: Record<string, UtilityKey>,
  billedThisMonth: Set<string>,
  today: string,
  now: number = Date.now(),
  /** YYYY-MM-01 the summary is about; today's month unless monthCollections asks for another. */
  forMonth?: string,
): Collections {
  const month = forMonth ?? `${today.slice(0, 7)}-01`
  const monthEnd = monthEndOf(month)
  const current = (l: CollectionLease) => l.status === 'active' || l.status === 'leave_requested'
  const byLease = new Map(leases.map((l) => [l.id, l]))
  const rowsOf = (id: string) => ledger.filter((r) => r.leaseId === id)

  // A promise to pay the rest that hasn't come due yet keeps a late item out of "Overdue".
  const promised = new Map<string, string>()
  for (const p of payments) {
    if (!p.promiseDate || p.promiseDate < today || (p.status !== 'paid' && p.status !== 'pending_verification')) continue
    const was = promised.get(p.leaseId)
    if (!was || p.promiseDate > was) promised.set(p.leaseId, p.promiseDate)
  }

  // 1. Waiting on the landlord/landlady: one entry per transfer.
  const batches = new Map<string, CollectionPayment[]>()
  for (const p of payments) {
    if (p.status !== 'pending_verification') continue
    const key = p.batchId ?? p.id
    batches.set(key, [...(batches.get(key) ?? []), p])
  }
  const confirm: ToConfirm[] = []
  for (const [key, rows] of batches) {
    const lease = byLease.get(rows[0]!.leaseId)
    if (!lease) continue
    const names = rows.map((p) =>
      p.kind === 'bill' ? itemName({ kind: 'bill', billId: p.billId } as LedgerRow, billUtility)
        : p.kind === 'rent' ? `${shortMonth(p.month)} rent` : p.kind,
    )
    const sent = Math.min(...rows.map((p) => new Date(p.createdAt).getTime()))
    confirm.push({
      key,
      lease,
      paymentId: rows[0]!.id,
      amount: rows.reduce((s, p) => s + p.amount, 0),
      method: rows[0]!.method,
      what: joinNames(names),
      waitDays: Math.max(0, Math.floor((now - sent) / DAY)),
    })
  }
  confirm.sort((a, b) => b.waitDays - a.waitDays)

  // 2–3. What current tenants still owe, as late or still to come this month.
  const late: Owing[] = []
  const coming: Owing[] = []
  let collected = 0
  let toConfirm = 0
  let overdue = 0
  let toCome = 0
  for (const lease of leases.filter(current)) {
    const rows = rowsOf(lease.id)
    for (const r of rows) {
      if ((r.dueDate ?? '') >= month && (r.dueDate ?? '') <= monthEnd) collected += r.confirmed
      toConfirm += r.pending
    }
    const promise = promised.get(lease.id)
    const isLate = (r: CollectionLedgerRow) => isLateRow(r, today)
    const lateRows = rows.filter((r) => isLate(r) && r.balance > 0.009)
    const soonRows = rows.filter((r) => !isLate(r) && r.balance > 0.009 && (r.dueDate ?? '') <= monthEnd)
    const tag: Owing['tag'] = lease.startDate > today ? 'new' : lease.status === 'leave_requested' || lease.leaveDate ? 'leaving' : null

    if (lateRows.length && !promise) {
      const amount = lateRows.reduce((s, r) => s + r.balance, 0)
      const first = lateRows.map((r) => r.dueDate ?? '').sort()[0] ?? today
      const days = daysBetween(first, today)
      late.push({ lease, amount, tag, daysLate: days, what: `${joinNames(lateRows.map((r) => itemName(r, billUtility)))} · ${days} day${days === 1 ? '' : 's'} late` })
      overdue += amount
    }
    const comingRows = promise ? [...lateRows, ...soonRows] : soonRows
    if (comingRows.length) {
      const amount = comingRows.reduce((s, r) => s + r.balance, 0)
      const first = comingRows.map((r) => r.dueDate ?? '').sort()[0] ?? today
      const when = promise
        ? `promised by ${new Date(`${promise}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })}`
        : tag === 'new'
          ? `moves in ${new Date(`${lease.startDate}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })}`
          : `due ${new Date(`${first}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })}`
      const names = tag === 'new' && comingRows.some((r) => r.kind === 'deposit') ? ['advance + deposit'] : comingRows.map((r) => itemName(r, billUtility))
      // A boarder is listed once: already late, they stay under Overdue, and
      // what else falls due this month only adds to the Still-to-come total.
      if (!late.some((o) => o.lease.id === lease.id)) coming.push({ lease, amount, tag, what: `${joinNames(names)} · ${when}` })
      toCome += amount
    }
  }

  const listed = new Set([...confirm.map((c) => c.lease.id), ...late.map((o) => o.lease.id), ...coming.map((o) => o.lease.id)])
  const paid = leases.filter((l) => current(l) && l.startDate <= (today < monthEnd ? today : monthEnd) && !listed.has(l.id))

  // 4. Stays that have ended with rent or bills left.
  const past: Owing[] = []
  for (const lease of leases.filter((l) => !current(l))) {
    const rows = rowsOf(lease.id).filter((r) => (r.kind === 'rent' || r.kind === 'bill') && r.balance > 0.009)
    if (!rows.length) continue
    past.push({ lease, amount: rows.reduce((s, r) => s + r.balance, 0), tag: null, what: joinNames(rows.map((r) => itemName(r, billUtility))) })
  }

  // 5. Metered utilities not billed yet this month (from the 20th).
  const unpostedUtils = new Set<UtilityKey>()
  let unpostedTenants = 0
  if (Number(today.slice(8, 10)) >= 20) {
    for (const lease of leases.filter((l) => current(l) && l.startDate <= today)) {
      const missing = lease.metered.filter((u) => !billedThisMonth.has(`${lease.id}:${u}`))
      if (missing.length) unpostedTenants++
      missing.forEach((u) => unpostedUtils.add(u))
    }
  }

  return {
    month,
    collected,
    toConfirm,
    overdue,
    toCome,
    confirm,
    late: late.sort((a, b) => b.amount - a.amount),
    coming,
    paid,
    past,
    unposted: { tenants: unpostedTenants, utilities: [...unpostedUtils] },
  }
}

/**
 * The same summary for one month, for the Monthly rent tab's month stepper.
 * Today's month is the live inbox, so it keeps everything still open (an
 * earlier month's unpaid rent is still owed); any other month is limited to
 * the rows that fell due in it and the payments made toward it. Past months
 * have nothing "still to come": whatever is unpaid has already gone late.
 */
export function monthCollections(
  leases: CollectionLease[],
  ledger: CollectionLedgerRow[],
  payments: CollectionPayment[],
  month: string,
  today: string,
  billUtility: Record<string, UtilityKey> = {},
  billedThisMonth: Set<string> = new Set(),
  now: number = Date.now(),
): Collections {
  const ym = month.slice(0, 7)
  if (ym === today.slice(0, 7)) return buildCollections(leases, ledger, payments, billUtility, billedThisMonth, today, now)
  return buildCollections(
    leases,
    ledger.filter((r) => (r.dueDate ?? '').slice(0, 7) === ym),
    payments.filter((p) => p.month.slice(0, 7) === ym),
    billUtility,
    billedThisMonth,
    today,
    now,
    `${ym}-01`,
  )
}
