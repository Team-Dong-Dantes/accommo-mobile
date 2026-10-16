import { describe, expect, it } from 'vitest'
import type { LedgerRow } from './payments'
import { rentCell, stayRent } from './rentGrid'

const row = (month: string, state: LedgerRow['state'], balance = 0): LedgerRow => ({
  kind: 'rent', month, billId: null, dueDate: month, due: 3000, confirmed: 0, waived: 0, pending: 0, balance, state,
})
const rows = [row('2026-08-01', 'paid'), row('2026-09-01', 'overdue', 3000), row('2026-10-01', 'pending'), row('2026-11-01', 'unpaid', 3000)]
const today = '2026-10-16'

describe('rentCell', () => {
  it('maps each state', () => {
    expect(rentCell(rows, '2026-08', today)).toBe('paid')
    expect(rentCell(rows, '2026-09-01', today)).toBe('unpaid')
    expect(rentCell(rows, '2026-10', today)).toBe('confirm')
    expect(rentCell(rows, '2026-11', today)).toBe('upcoming')
  })
  it('is none outside the stay', () => {
    expect(rentCell(rows, '2026-07', today)).toBe('none')
  })
})

describe('stayRent', () => {
  it('counts paid of due and sums what is unpaid, ignoring future months', () => {
    const s = stayRent(rows, today)
    expect(s).toMatchObject({ paidMonths: 1, totalMonths: 3, unpaidAmount: 3000 })
    expect(s.unpaid).toHaveLength(1)
  })
})
