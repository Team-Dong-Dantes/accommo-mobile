// The "Boarders payment timeline" a landlord/landlady prints or shares: one
// property's boarders down the side, January to December across the top, and
// whether each month's rent is paid.
//
// Ported from accommo-web src/features/reports/{document,payments,parts}.ts
// (renderReport's frame and CSS, rentYear/rentCell/unpaidCell, RENT_NOTE, MONTHS,
// yearOptions) so the two agree. Differences, all deliberate: the ISU/OSAS
// letterhead is replaced by the property's own header, the reference is
// ACM-PTL-YYYYMMDD-XXXXXX, the only signatory is "Prepared by", and the mobile
// LedgerRow has no student/room/leaseId, so those are joined from MoneyLease.
// Mobile must not import from the web repo; keep the two in step by hand.

import type { MoneyLease } from '@/api/landlordMoney'
import type { CollectionLedgerRow } from '@/utils/collections'
import { manilaToday } from '@/utils/payments'
import { rentCell } from '@/utils/rentGrid'

export const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
export const RENT_NOTE = '"Pending" is a payment you have not yet confirmed; "—" is a month outside the stay or not yet due.'

export type Paper = 'a4' | 'long'
export type Orientation = 'portrait' | 'landscape'

const PAPER: Record<Paper, { w: number; h: number; css: string }> = {
  a4: { w: 210, h: 297, css: 'A4' },
  long: { w: 215.9, h: 330.2, css: '8.5in 13in' },
}

export function escapeHtml(s: unknown): string {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!)
}
const e = escapeHtml

const key = (s: string | null) => (s ?? '').slice(0, 7)
const peso = (n: number) => `₱${n.toLocaleString('en-PH', { maximumFractionDigits: 2 })}`
const day = (d: Date) => d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'Asia/Manila' })
const dayTime = (d: Date) => d.toLocaleString('en-PH', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Manila' })

/** "ACM-PTL-20261015-3F9A1C": the report code, the day it was made, a record id when there is one. */
export function reportReference(code: string, at: Date, recordId?: string): string {
  const ymd = manilaToday(at).replace(/-/g, '')
  return `ACM-${code}-${ymd}${recordId ? `-${recordId.replace(/-/g, '').slice(0, 6).toUpperCase()}` : ''}`
}

/** Whether the stay is still going (a boarder who has asked to leave is still a current boarder). */
export const isCurrent = (l: Pick<MoneyLease, 'status'>) => l.status === 'active' || l.status === 'leave_requested'

/** This year, then every other year with rent on file, newest first. */
export function yearOptions(ledger: CollectionLedgerRow[], today: string): { value: string; label: string }[] {
  const now = today.slice(0, 4)
  const years = [...new Set(ledger.filter((r) => r.kind === 'rent').map((r) => key(r.month).slice(0, 4)).filter((y) => y && y !== now))].sort().reverse()
  return [{ value: now, label: `${now} (this year)` }, ...years.map((y) => ({ value: y, label: y }))]
}

export interface RentStay {
  lease: MoneyLease
  rows: CollectionLedgerRow[]
  /** January to December; undefined where the stay had no rent that month. */
  months: (CollectionLedgerRow | undefined)[]
  /** Months come due and not covered (partial and overdue are both unpaid). */
  unpaid: CollectionLedgerRow[]
}

/** Each stay's rent over one calendar year, for the given leases. */
export function rentYear(leases: MoneyLease[], ledger: CollectionLedgerRow[], year: string, today: string): RentStay[] {
  const out: RentStay[] = []
  for (const lease of leases) {
    const rows = ledger.filter((r) => r.leaseId === lease.id && r.kind === 'rent' && key(r.month).startsWith(`${year}-`))
    if (!rows.length) continue
    const months = MONTHS.map((_, i) => rows.find((r) => key(r.month) === `${year}-${String(i + 1).padStart(2, '0')}`))
    out.push({ lease, rows, months, unpaid: rows.filter((r) => rentCell(rows, r.month ?? '', today) === 'unpaid') })
  }
  return out
}

export interface RentReportOptions {
  property: { name: string; type: string; address: string }
  landlord: { name: string; phone: string; title: string }
  /** Only this property's stays. */
  leases: MoneyLease[]
  ledger: CollectionLedgerRow[]
  year: string
  groupBy: 'room' | ''
  former: boolean
  owing: boolean
  amounts: boolean
  paper: Paper
  orientation: Orientation
  today: string
  at: Date
}

/** The stays a report lists, in the order it lists them. */
export function reportStays(o: Pick<RentReportOptions, 'leases' | 'ledger' | 'year' | 'groupBy' | 'former' | 'owing' | 'today'>): RentStay[] {
  const list = rentYear(o.leases, o.ledger, o.year, o.today)
    .filter((s) => o.former || isCurrent(s.lease))
    .filter((s) => !o.owing || s.unpaid.length)
    .sort((a, b) => a.lease.studentName.localeCompare(b.lease.studentName))
  // Room 2 before Room 10.
  if (o.groupBy === 'room') list.sort((a, b) => a.lease.roomLabel.localeCompare(b.lease.roomLabel, 'en', { numeric: true }))
  return list
}

function cell(s: RentStay, i: number, o: RentReportOptions): string {
  const r = s.months[i]
  const c = r ? rentCell(s.rows, r.month ?? '', o.today) : 'none'
  if (!r || (c !== 'paid' && c !== 'confirm' && c !== 'unpaid')) return '<td class="c">—</td>'
  const amount = o.amounts ? `<br><small>${c === 'unpaid' ? `${peso(r.balance)} left` : peso(r.confirmed + r.pending)}</small>` : ''
  return `<td class="c">${c === 'unpaid' ? '<b>Unpaid</b>' : c === 'paid' ? 'Paid' : 'Pending'}${amount}</td>`
}

function unpaidCell(s: RentStay, amounts: boolean): string {
  if (!s.unpaid.length) return '<td class="n">—</td>'
  return `<td class="n">${s.unpaid.length} mo${amounts ? `<br><small>${peso(s.unpaid.reduce((n, r) => n + r.balance, 0))}</small>` : ''}</td>`
}

/** The report body: scope line, the ruled table, and the count note. */
export function rentReportBody(o: RentReportOptions): { count: number; bodyHtml: string } {
  const list = reportStays(o)
  const byRoom = o.groupBy === 'room'
  const head = ['No.', 'Boarder', ...MONTHS, 'Unpaid']
  const heading = (s: RentStay, i: number) =>
    byRoom && s.lease.roomLabel !== list[i - 1]?.lease.roomLabel
      ? `<tr class="grp"><td colspan="${head.length}">${e(s.lease.roomLabel)} (${list.filter((x) => x.lease.roomLabel === s.lease.roomLabel).length})</td></tr>`
      : ''
  // The room is already the heading when grouped by it.
  const sub = (l: MoneyLease) => [!byRoom && l.roomLabel, !isCurrent(l) && 'former'].filter(Boolean).join(' · ')
  const rows = list
    .map(
      (s, i) => `${heading(s, i)}<tr><td class="c">${i + 1}</td>
      <td><b>${e(s.lease.studentName)}</b>${sub(s.lease) ? `<br><small>${e(sub(s.lease))}</small>` : ''}</td>
      ${MONTHS.map((_, m) => cell(s, m, o)).join('')}${unpaidCell(s, o.amounts)}</tr>`,
    )
    .join('')
  const table = rows
    ? `<table class="grid list"><thead><tr>${head.map((h) => `<th>${e(h)}</th>`).join('')}</tr></thead><tbody>${rows}</tbody></table>`
    : `<p class="none">${e(`No boarder has rent on file for ${o.year}.`)}</p>`
  const owing = list.filter((s) => s.unpaid.length).length
  const scope = [`January – December ${o.year}`, 'Rent', o.former ? 'including former boarders' : 'current boarders', o.owing && 'only boarders with an unpaid month'].filter(Boolean).join(' · ')
  return {
    count: list.length,
    bodyHtml:
      `<p class="scope">${e(scope)}</p>` +
      table +
      (list.length ? `<p class="note">${list.length} boarder${list.length === 1 ? '' : 's'} · ${owing} with an unpaid month. ${RENT_NOTE}</p>` : ''),
  }
}

/** The whole printable document. */
export function renderRentReport(o: RentReportOptions): string {
  const ref = reportReference('PTL', o.at)
  const paper = PAPER[o.paper]
  const landscape = o.orientation === 'landscape'
  const pageW = landscape ? paper.h : paper.w
  const contentW = pageW - 20 // 10 mm side margins
  const place = [o.property.type, o.property.address].filter(Boolean).join(' · ')
  const who = [o.landlord.name, o.landlord.phone].filter(Boolean).join(' · ')
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>${e(ref)} — Boarders Payment Timeline</title>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; color: #000; font: 10.5pt/1.35 Arial, Helvetica, sans-serif; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .page { width: ${contentW}mm; margin: 0 auto; }
  .lh { text-align: center; font-family: 'Times New Roman', Times, serif; line-height: 1.2; }
  .lh-name { font-size: 17pt; font-weight: bold; letter-spacing: .04em; text-transform: uppercase; }
  .lh-place { font-size: 11pt; }
  .lh-who { margin-top: 3px; font-size: 10pt; }
  .rule { height: 6px; margin: 8px 0 14px; border-top: 3px solid #000; border-bottom: 1px solid #000; }
  .docmeta { display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 9.5pt; }
  .title { margin: 0; font-family: 'Times New Roman', Times, serif; font-size: 14pt; font-weight: bold; letter-spacing: .04em; text-align: center; }
  .subtitle { margin: 2px 0 6px; font-size: 9.5pt; font-style: italic; text-align: center; }
  .scope { margin: 0 0 10px; font-size: 9.5pt; text-align: center; }
  table { width: 100%; border-collapse: collapse; }
  .grid th, .grid td { padding: 4px 6px; border: 0.75pt solid #000; text-align: left; vertical-align: top; }
  .grid thead th { background: #d9e8dc; font-size: 9pt; font-weight: bold; text-transform: uppercase; }
  .list { font-size: 9.5pt; }
  .list thead th { font-size: 8.5pt; }
  .grid thead { display: table-header-group; }
  .grid tr { page-break-inside: avoid; }
  .grp td { background: #f2f2f2; font-weight: bold; }
  .c { text-align: center !important; white-space: nowrap; }
  .n { text-align: right !important; white-space: nowrap; font-variant-numeric: tabular-nums; }
  .none { margin: 0; padding: 6px 8px; border: 0.75pt solid #000; font-style: italic; }
  .note { margin: 6px 0 0; font-size: 8.5pt; font-style: italic; }
  .sign { max-width: 80mm; margin-top: 30px; page-break-inside: avoid; }
  .sign-lbl { margin-bottom: 30px; }
  .sign-name { display: block; padding: 0 4px; border-bottom: 1px solid #000; font-weight: bold; text-align: center; text-transform: uppercase; }
  .sign-role { font-size: 9.5pt; text-align: center; }
  .sign-date { margin-top: 10px; font-size: 9.5pt; }
  .foot { position: fixed; left: 0; right: 0; bottom: 0; display: flex; justify-content: space-between; width: ${contentW}mm; margin: 0 auto; padding-top: 3px; border-top: 0.75pt solid #000; font-size: 8pt; }
  @page { size: ${paper.css} ${landscape ? 'landscape' : 'portrait'}; margin: 12mm 10mm 16mm; }
  @media print { html { zoom: 1 !important; } }
  @media screen {
    body { background: #d9d9d9; }
    .page { margin: 16px auto; padding: 12mm 10mm 18mm; width: ${pageW}mm; min-height: ${landscape ? paper.w : paper.h}mm; background: #fff; box-shadow: 0 1px 6px rgba(0,0,0,.25); }
    .foot { display: none; }
  }
</style></head><body>
<div class="page">
  <header class="lh">
    <div class="lh-name">${e(o.property.name)}</div>
    ${place ? `<div class="lh-place">${e(place)}</div>` : ''}
    ${who ? `<div class="lh-who">${e(o.landlord.title)}: ${e(who)}</div>` : ''}
  </header>
  <div class="rule"></div>
  <div class="docmeta"><span>Reference no.: <b>${e(ref)}</b></span><span>Date: <b>${e(day(o.at))}</b></span></div>
  <p class="title">BOARDERS PAYMENT TIMELINE</p>
  <p class="subtitle">Rent record of ${e(o.property.name)}</p>
  ${rentReportBody(o).bodyHtml}
  <div class="sign">
    <div class="sign-lbl">Prepared by:</div>
    <div class="sign-name">${e(o.landlord.name)}&nbsp;</div>
    <div class="sign-role">${e(o.landlord.title)}, ${e(o.property.name)}</div>
    <div class="sign-date">Date: ${e(day(o.at))}</div>
  </div>
</div>
<div class="foot"><span>${e(o.property.name)} · ${e(ref)}</span><span>Generated through Accommo, ${e(dayTime(o.at))}</span></div>
</body></html>`
}
