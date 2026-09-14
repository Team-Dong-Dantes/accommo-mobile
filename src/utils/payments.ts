// Rent-ordering rules, lifted out of StudentStayPage.vue so they can be tested.
//
// These decide what a student is allowed to pay next, and until the database
// grew tg_payment_guard() they were the only thing standing between a tenant
// and a self-marked "paid". They are pure functions of the payment list, so
// there is no reason for them to live inside a 1600-line component.

/** `description` markers that take a payment out of the monthly rent series. */
export const ADVANCE_TAG = 'Advance payment'
export const DEPOSIT_TAG = 'Security deposit'

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
      .filter((p) => p.description !== ADVANCE_TAG && p.description !== DEPOSIT_TAG)
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
