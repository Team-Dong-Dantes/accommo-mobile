// Rent-ordering rules, lifted out of StudentStayPage.vue so they can be tested.
//
// These decide what a student is allowed to pay next, and until the database
// grew tg_payment_guard() they were the only thing standing between a tenant
// and a self-marked "paid". They are pure functions of the payment list, so
// there is no reason for them to live inside a 1600-line component.

import { formatMonth } from '@/utils/format'
import { UTILITIES, type UtilityKey, type UtilityTerms } from '@/utils/listings'

/** `description` markers that take a payment out of the monthly rent series. */
export const ADVANCE_TAG = 'Advance payment'
export const DEPOSIT_TAG = 'Security deposit'

/**
 * `description` of a payment made against a utility bill (payments.bill_id).
 * The tag, not the bill link, is what keeps it out of the rent series: a bill
 * deleted after it was paid leaves bill_id null but the tag in place.
 */
export const BILL_TAG: Record<UtilityKey, string> = {
  water: 'Water bill',
  electric: 'Electricity bill',
  wifi: 'Wi-Fi bill',
}

const NON_RENT_TAGS = new Set<string>([ADVANCE_TAG, DEPOSIT_TAG, ...Object.values(BILL_TAG)])

/** A payment's heading: "Advance payment", "Water bill · October 2026", or the rent month. */
export function paymentTitle(p: { description?: string | null; month: string }): string {
  if (p.description === ADVANCE_TAG || p.description === DEPOSIT_TAG) return p.description
  if (p.description && Object.values(BILL_TAG).includes(p.description)) return `${p.description} · ${formatMonth(p.month)}`
  return formatMonth(p.month)
}

/**
 * A bill is settled by a payment that is paid or awaiting verification — the
 * same rule a rent month follows, so a rejected payment leaves it due again.
 */
export function isBillSettled(payments: { status: string }[] | null | undefined): boolean {
  return (payments ?? []).some((p) => p.status === 'paid' || p.status === 'pending_verification')
}

/** Today in Manila as YYYY-MM-DD — what a bill's due_date is compared with. */
export function manilaToday(now: Date = new Date()): string {
  return now.toLocaleDateString('en-CA', { timeZone: 'Asia/Manila' })
}

/** The flat fees that ride on each rent payment. */
export function flatFees(terms: Record<UtilityKey, UtilityTerms>): { key: UtilityKey; label: string; amount: number }[] {
  return UTILITIES.filter((u) => terms[u.key].billing === 'flat_fee' && terms[u.key].flatFee).map((u) => ({
    key: u.key,
    label: u.label,
    amount: terms[u.key].flatFee as number,
  }))
}

/** The fields of a payment row these rules actually read. */
export interface RentPayment {
  month: string
  status: string
  description?: string | null
}

/** A month key, `YYYY-MM`. */
function monthKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/**
 * The one rent month payable right now: the earliest month since the lease
 * started with no `paid` or `pending_verification` row against it.
 *
 * Locking the form to this single value — instead of offering a free month
 * picker — is what makes "pay in order, never skip ahead, never backdate" hold:
 * there is no field left to game. A rejected payment does not count as covered,
 * so its month comes back around.
 *
 * The 240-iteration ceiling is twenty years of a single tenancy; past that the
 * cursor month is returned as-is rather than looping forever.
 */
export function nextRentMonth(leaseStartDate: string, payments: RentPayment[]): string {
  const covered = new Set(
    payments
      .filter((p) => !NON_RENT_TAGS.has(p.description ?? ''))
      .filter((p) => p.status === 'paid' || p.status === 'pending_verification')
      .map((p) => p.month.slice(0, 7)),
  )

  const start = new Date(leaseStartDate)
  if (Number.isNaN(start.getTime())) return ''

  const cursor = new Date(start.getFullYear(), start.getMonth(), 1)
  for (let i = 0; i < 240; i++) {
    const key = monthKey(cursor)
    if (!covered.has(key)) return key
    cursor.setMonth(cursor.getMonth() + 1)
  }
  return monthKey(cursor)
}

// ---- The server's ledger (lease_ledger(), 20261006020000) -------------------
//
// What is owed comes from the database — rent plus flat fees per month, the
// advance and deposit — with confirmed and awaiting-confirmation totals. The
// database refuses any payment that breaks these rules; the helpers below only
// let the form say so before the round trip.

export type LedgerState = 'paid' | 'pending' | 'partial' | 'unpaid' | 'overdue'
export interface LedgerRow {
  kind: 'rent' | 'advance' | 'deposit'
  /** YYYY-MM-DD for rent, null for advance/deposit. */
  month: string | null
  due: number
  confirmed: number
  pending: number
  /** Still to pay: due − confirmed − pending. */
  balance: number
  state: LedgerState
}

export function toLedger(rows: unknown[] | null | undefined): LedgerRow[] {
  return ((rows ?? []) as Record<string, unknown>[]).map((r) => ({
    kind: r.kind as LedgerRow['kind'],
    month: (r.month as string | null) ?? null,
    due: Number(r.due ?? 0),
    confirmed: Number(r.confirmed ?? 0),
    pending: Number(r.pending ?? 0),
    balance: Number(r.balance ?? 0),
    state: r.state as LedgerState,
  }))
}

/** The rent month to pay next: the earliest one with anything left. */
export function nextLedgerRent(ledger: LedgerRow[]): LedgerRow | null {
  return ledger.find((r) => r.kind === 'rent' && r.balance > 0.009) ?? null
}

/**
 * The smallest amount the server accepts for an item: everything left, or —
 * when the landlord/landlady allows partial payments — `pct`% of the amount
 * owed, rounded up to the peso (never more than what is left).
 */
export function minPayment(row: Pick<LedgerRow, 'due' | 'balance'>, allowPartial: boolean, pct: number): number {
  if (!allowPartial) return row.balance
  return Math.min(row.balance, Math.ceil((row.due * pct) / 100))
}

/** A reference as the database stores it: no spaces or dashes, upper case. */
export function normalizeReference(ref: string): string {
  return ref.replace(/[\s-]/g, '').toUpperCase()
}

/** Why a reference would be refused, or null. GCash has 13 digits. */
export function referenceProblem(method: string, ref: string): string | null {
  const r = normalizeReference(ref)
  if (!r) return null
  if (method === 'gcash') return /^[0-9]{13}$/.test(r) ? null : 'A GCash reference number has 13 digits.'
  return /^[A-Z0-9]{6,30}$/.test(r) ? null : 'A reference number is 6 to 30 letters or digits.'
}

/** SHA-256 of a file as hex — the receipt's fingerprint, so one image can't pay twice. */
export async function fileFingerprint(file: Blob): Promise<string | null> {
  try {
    const digest = await crypto.subtle.digest('SHA-256', await file.arrayBuffer())
    return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
  } catch {
    return null // no WebCrypto (very old WebView): the server simply skips the check
  }
}

/**
 * What one tenant pays each month. A "whole room" rate is split evenly across the
 * room's capacity and rounded to the centavo — the same expression guard_lease_writes
 * applies when the lease is written, so a quote can never differ from the lease.
 */
export function tenantMonthlyRent(rent: number, basis: string | null | undefined, capacity: number | null | undefined): number {
  if (basis === 'person') return rent
  return Math.round((rent / Math.max(capacity || 1, 1)) * 100) / 100
}
