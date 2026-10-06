import { describe, expect, it } from 'vitest'
import { ADVANCE_TAG, BILL_TAG, DEPOSIT_TAG, flatFees, isBillSettled, manilaToday, minPayment, nextLedgerRent, nextRentMonth, paymentTitle, referenceProblem, tenantMonthlyRent, toLedger, type RentPayment } from './payments'

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

  // A water bill for March is not March's rent.
  it('ignores utility bill payments', () => {
    const rows: RentPayment[] = [{ month: '2026-03-01', status: 'paid', description: BILL_TAG.water }]
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

describe('isBillSettled', () => {
  it('is due with no payment, or only rejected/withdrawn ones', () => {
    expect(isBillSettled([], 500)).toBe(false)
    expect(isBillSettled(null, 500)).toBe(false)
    expect(isBillSettled([{ status: 'rejected', amount: 500 }, { status: 'withdrawn', amount: 500 }], 500)).toBe(false)
  })

  it('is settled once paid, awaiting and forgiven parts cover it', () => {
    expect(isBillSettled([{ status: 'paid', amount: 200 }], 500)).toBe(false)
    expect(isBillSettled([{ status: 'paid', amount: 200 }, { status: 'pending_verification', amount: '100' }, { status: 'waived', amount: 200 }], 500)).toBe(true)
  })
})

describe('paymentTitle', () => {
  it('names advance, deposit, bills and rent months', () => {
    expect(paymentTitle({ description: ADVANCE_TAG, month: '2026-03-01' })).toBe(ADVANCE_TAG)
    expect(paymentTitle({ description: BILL_TAG.electric, month: '2026-03-01' })).toMatch(/^Electricity bill · March/)
    expect(paymentTitle({ description: '', month: '2026-03-01' })).toMatch(/^March/)
  })
})

describe('flatFees', () => {
  it('keeps only flat-fee utilities with an amount', () => {
    const fees = flatFees({
      water: { billing: 'flat_fee', flatFee: 150 },
      electric: { billing: 'own_meter', flatFee: null },
      wifi: { billing: 'not_available', flatFee: null },
    })
    expect(fees).toEqual([{ key: 'water', label: 'Water', amount: 150 }])
  })
})

describe('manilaToday', () => {
  // 17:30 UTC is already the next day in Manila (UTC+8).
  it('rolls over at Manila midnight, not UTC', () => {
    expect(manilaToday(new Date('2026-10-01T17:30:00Z'))).toBe('2026-10-02')
    expect(manilaToday(new Date('2026-10-01T15:30:00Z'))).toBe('2026-10-01')
  })
})

describe('ledger helpers', () => {
  const row = (balance: number, due = 2500) => ({ due, balance })
  it('minPayment: everything left without partial, pct of due with it', () => {
    expect(minPayment(row(2500), false, 50)).toBe(2500)
    expect(minPayment(row(2500), true, 50)).toBe(1250)
    expect(minPayment(row(800), true, 50)).toBe(800)
    expect(minPayment(row(733.33, 733.33), true, 50)).toBe(367)
  })
  it('referenceProblem: GCash is 13 digits, others 6-30 alphanumerics', () => {
    expect(referenceProblem('gcash', '1234 567 890 123')).toBeNull()
    expect(referenceProblem('gcash', '12345')).toMatch(/13 digits/)
    expect(referenceProblem('bank', 'ab-12 34')).toBeNull()
    expect(referenceProblem('maya', '123')).toMatch(/6 to 30/)
    expect(referenceProblem('cash', '')).toBeNull()
  })
  it('nextLedgerRent: earliest rent month with a balance', () => {
    const l = toLedger([
      { kind: 'advance', month: null, due: 2500, confirmed: 2500, pending: 0, balance: 0, state: 'paid' },
      { kind: 'rent', month: '2026-09-01', due: 2500, confirmed: 2500, pending: 0, balance: 0, state: 'paid' },
      { kind: 'rent', month: '2026-10-01', due: 2500, confirmed: 1250, pending: 0, balance: 1250, state: 'partial' },
      { kind: 'rent', month: '2026-11-01', due: 2500, confirmed: 0, pending: 0, balance: 2500, state: 'unpaid' },
    ])
    expect(nextLedgerRent(l)?.month).toBe('2026-10-01')
  })
})

describe('tenantMonthlyRent', () => {
  it('splits a whole-room rate across capacity, to the centavo', () => {
    expect(tenantMonthlyRent(2800, 'room', 2)).toBe(1400)
    expect(tenantMonthlyRent(2200, 'room', 3)).toBe(733.33)
  })
  it('leaves per-person and single rooms alone', () => {
    expect(tenantMonthlyRent(1500, 'person', 4)).toBe(1500)
    expect(tenantMonthlyRent(3500, 'room', 1)).toBe(3500)
    expect(tenantMonthlyRent(3500, 'room', null)).toBe(3500)
  })
})
