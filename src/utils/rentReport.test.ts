import { describe, expect, it } from 'vitest'
import type { MoneyLease } from '@/api/landlordMoney'
import type { CollectionLedgerRow } from '@/utils/collections'
import { escapeHtml, rentReportBody, renderRentReport, reportReference, reportStays, type RentReportOptions } from './rentReport'

const lease = (id: string, name: string, room: string, status = 'active'): MoneyLease => ({
  id, studentId: id, studentName: name, avatarColor: null, avatarUrl: null, roomLabel: room, accommodationId: 'a', accommodationName: 'Casa',
  status, startDate: '2026-01-01', leaveDate: null, metered: [], roomId: room, monthlyRent: 2500, endDate: '2026-12-31', endedReason: null,
})
const row = (leaseId: string, month: string, state: CollectionLedgerRow['state'], balance = 0): CollectionLedgerRow => ({
  leaseId, kind: 'rent', month, billId: null, dueDate: month, due: 2500, confirmed: state === 'paid' ? 2500 : 0, waived: 0, pending: 0, balance, state,
})
const leases = [lease('1', 'Zed <b>', 'Room 10'), lease('2', 'Ana', 'Room 2'), lease('3', 'Bea', 'Room 2', 'ended')]
const ledger = [
  row('1', '2026-09-01', 'paid'), row('1', '2026-10-01', 'overdue', 2500),
  row('2', '2026-09-01', 'paid'), row('2', '2026-10-01', 'pending'),
  row('3', '2026-08-01', 'paid'),
]
const base: RentReportOptions = {
  property: { name: 'Casa <Dolores>', type: 'Boarding house', address: 'Echague' }, landlord: { name: 'Rosa', phone: '0917', title: 'Landlady' },
  leases, ledger, year: '2026', groupBy: 'room', former: true, owing: false, amounts: true, paper: 'a4', orientation: 'landscape',
  today: '2026-10-16', at: new Date('2026-10-15T07:00:00Z'),
}

describe('rent report', () => {
  it('escapes names and the property', () => {
    expect(escapeHtml(`<a href="x">&'`)).toBe('&lt;a href=&quot;x&quot;&gt;&amp;&#39;')
    const html = renderRentReport(base)
    expect(html).toContain('Zed &lt;b&gt;')
    expect(html).toContain('Casa &lt;Dolores&gt;')
    expect(html).not.toContain('Zed <b>')
  })
  it('groups by room in natural order', () => {
    expect(reportStays(base).map((s) => s.lease.studentName)).toEqual(['Ana', 'Bea', 'Zed <b>'])
    const { bodyHtml } = rentReportBody(base)
    expect(bodyHtml).toContain('Room 2 (2)')
    expect(bodyHtml.indexOf('Room 2 (2)')).toBeLessThan(bodyHtml.indexOf('Room 10 (1)'))
  })
  it('marks former boarders and can hide them', () => {
    expect(rentReportBody(base).bodyHtml).toContain('former')
    const r = rentReportBody({ ...base, former: false })
    expect(r.count).toBe(2)
    expect(r.bodyHtml).not.toContain('former')
  })
  it('counts unpaid months and amount', () => {
    const { bodyHtml } = rentReportBody(base)
    expect(bodyHtml).toContain('1 mo<br><small>₱2,500</small>')
    expect(bodyHtml).toContain('1 with an unpaid month')
    expect(reportStays({ ...base, owing: true }).map((s) => s.lease.id)).toEqual(['1'])
  })
  it('shows a dash outside the stay and for pending/paid labels', () => {
    const { bodyHtml } = rentReportBody(base)
    expect(bodyHtml).toContain('<td class="c">—</td>')
    expect(bodyHtml).toContain('Pending')
  })
  it('empty year and reference', () => {
    expect(rentReportBody({ ...base, year: '2020' }).bodyHtml).toContain('No boarder has rent on file for 2020.')
    expect(reportReference('PTL', base.at, '3f9a1c-xx')).toBe('ACM-PTL-20261015-3F9A1C')
  })
})
