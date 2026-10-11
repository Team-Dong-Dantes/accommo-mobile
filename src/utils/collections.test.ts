import { describe, expect, it } from 'vitest'
import { buildCollections, type CollectionLease, type CollectionLedgerRow, type CollectionPayment } from './collections'

const TODAY = '2026-10-12'
const NOW = new Date('2026-10-12T09:00:00+08:00').getTime()

const lease = (id: string, over: Partial<CollectionLease> = {}): CollectionLease => ({
  id,
  studentId: `s-${id}`,
  studentName: id,
  avatarColor: null,
  avatarUrl: null,
  roomLabel: 'Room 1',
  accommodationId: 'acc',
  accommodationName: 'Casa Verde',
  status: 'active',
  startDate: '2026-08-05',
  leaveDate: null,
  metered: [],
  ...over,
})

const rent = (leaseId: string, over: Partial<CollectionLedgerRow> = {}): CollectionLedgerRow => ({
  leaseId,
  kind: 'rent',
  month: '2026-10-01',
  billId: null,
  dueDate: '2026-10-05',
  due: 1500,
  confirmed: 0,
  waived: 0,
  pending: 0,
  balance: 1500,
  state: 'overdue',
  ...over,
})

const pay = (leaseId: string, over: Partial<CollectionPayment> = {}): CollectionPayment => ({
  id: `p-${leaseId}`,
  batchId: `b-${leaseId}`,
  leaseId,
  amount: 1500,
  method: 'gcash',
  status: 'pending_verification',
  kind: 'rent',
  month: '2026-10-01',
  billId: null,
  description: null,
  createdAt: '2026-10-09T08:00:00+08:00',
  promiseDate: null,
  ...over,
})

describe('buildCollections', () => {
  const leases = [
    lease('paid'),
    lease('late'),
    lease('sent'),
    lease('promised'),
    lease('soon', { status: 'leave_requested' }),
    lease('new', { startDate: '2026-10-20' }),
    lease('gone', { status: 'ended' }),
  ]
  const ledger: CollectionLedgerRow[] = [
    rent('paid', { confirmed: 1500, balance: 0, state: 'paid' }),
    rent('late'),
    rent('sent', { pending: 1500, balance: 0, state: 'pending' }),
    rent('promised', { confirmed: 750, balance: 750 }),
    rent('soon', { dueDate: '2026-10-15', state: 'unpaid' }),
    rent('new', { dueDate: '2026-10-20', state: 'unpaid' }),
    rent('new', { kind: 'deposit', month: null, dueDate: '2026-10-20', state: 'unpaid' }),
    rent('gone', { kind: 'bill', billId: 'bill-1', month: '2026-09-01', dueDate: '2026-09-25', due: 380, balance: 380 }),
  ]
  const payments = [
    pay('sent'),
    pay('promised', { id: 'p-prom', batchId: 'b-prom', amount: 750, status: 'paid', promiseDate: '2026-10-20' }),
  ]
  const c = buildCollections(leases, ledger, payments, { 'bill-1': 'electric' }, new Set(), TODAY, NOW)

  it('puts each tenant in exactly one group', () => {
    expect(c.confirm.map((x) => x.lease.id)).toEqual(['sent'])
    expect(c.late.map((x) => x.lease.id)).toEqual(['late'])
    expect(c.coming.map((x) => x.lease.id).sort()).toEqual(['new', 'promised', 'soon'])
    expect(c.paid.map((l) => l.id)).toEqual(['paid'])
    expect(c.past.map((x) => x.lease.id)).toEqual(['gone'])
  })

  it('keeps a late item with a promise out of Overdue', () => {
    expect(c.coming.find((x) => x.lease.id === 'promised')?.what).toBe('Oct rent · promised by Oct 20')
  })

  it('tags new and leaving tenants, and shows how long a payment waited', () => {
    expect(c.coming.find((x) => x.lease.id === 'new')).toMatchObject({ tag: 'new', amount: 3000 })
    expect(c.coming.find((x) => x.lease.id === 'soon')?.tag).toBe('leaving')
    expect(c.confirm[0]?.waitDays).toBe(3)
  })

  it('sums the month so the bar adds up', () => {
    expect(c.collected).toBe(2250)
    expect(c.toConfirm).toBe(1500)
    expect(c.overdue).toBe(1500)
    expect(c.toCome).toBe(750 + 1500 + 3000)
  })

  it('counts a deposit unpaid past move-in as late, so a boarder is listed once', () => {
    const d = buildCollections(
      [lease('dep')],
      [rent('dep'), rent('dep', { kind: 'deposit', month: null, dueDate: '2026-07-06', state: 'unpaid' })],
      [], {}, new Set(), TODAY, NOW,
    )
    expect(d.late.map((x) => [x.lease.id, x.amount])).toEqual([['dep', 3000]])
    expect(d.coming).toEqual([])
  })

  it('lists a late boarder once, with what comes next still in the total', () => {
    const d = buildCollections(
      [lease('both')],
      [rent('both', { kind: 'deposit', month: null, dueDate: '2026-07-06', state: 'unpaid' }), rent('both', { dueDate: '2026-10-21', state: 'unpaid' })],
      [], {}, new Set(), TODAY, NOW,
    )
    expect(d.late.map((x) => x.lease.id)).toEqual(['both'])
    expect(d.coming).toEqual([])
    expect(d.toCome).toBe(1500)
  })

  it('names the bill a former tenant still owes', () => {
    expect(c.past[0]).toMatchObject({ amount: 380, what: 'Electricity bill' })
  })
})
