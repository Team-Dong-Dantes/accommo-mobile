import { describe, expect, it } from 'vitest'
import { ADVANCE_TAG, DEPOSIT_TAG, nextRentMonth, type RentPayment } from './payments'

const rent = (month: string, status: string): RentPayment => ({ month, status, description: '' })

describe('nextRentMonth', () => {
  const START = '2026-03-15'

  it('starts at the lease start month when nothing has been paid', () => {
    expect(nextRentMonth(START, [])).toBe('2026-03')
  })

  it('walks forward over consecutive paid months', () => {
    const paid = [rent('2026-03-01', 'paid'), rent('2026-04-01', 'paid')]
    expect(nextRentMonth(START, paid)).toBe('2026-05')
  })

  // The rule the whole single-value design exists to enforce: you cannot skip
  // ahead. A payment for May does not unlock June while March is outstanding.
  it('returns the earliest gap, not the month after the latest payment', () => {
    const paid = [rent('2026-05-01', 'paid'), rent('2026-06-01', 'paid')]
    expect(nextRentMonth(START, paid)).toBe('2026-03')
  })

  it('treats a payment awaiting verification as covering its month', () => {
    expect(nextRentMonth(START, [rent('2026-03-01', 'pending_verification')])).toBe('2026-04')
  })

  it('reopens a month whose payment was rejected', () => {
    const rows = [rent('2026-03-01', 'rejected'), rent('2026-04-01', 'paid')]
    expect(nextRentMonth(START, rows)).toBe('2026-03')
  })

  it('ignores an unpaid due row — being billed is not being paid', () => {
    expect(nextRentMonth(START, [rent('2026-03-01', 'due')])).toBe('2026-03')
  })

  // Advance and deposit are one-offs tagged in `description`; they must not be
  // mistaken for the rent series or they would skip a month of rent.
  it('does not let an advance or deposit cover a rent month', () => {
    const rows: RentPayment[] = [
      { month: '2026-03-01', status: 'paid', description: ADVANCE_TAG },
      { month: '2026-03-01', status: 'paid', description: DEPOSIT_TAG },
    ]
    expect(nextRentMonth(START, rows)).toBe('2026-03')
  })

  it('rolls over the year boundary', () => {
    const paid = [rent('2026-11-01', 'paid'), rent('2026-12-01', 'paid')]
    expect(nextRentMonth('2026-11-01', paid)).toBe('2027-01')
  })

  it('pads single-digit months to two digits', () => {
    expect(nextRentMonth('2026-01-05', [])).toBe('2026-01')
  })

  it('returns empty for an unparseable start date rather than throwing', () => {
    expect(nextRentMonth('not a date', [])).toBe('')
  })
})
