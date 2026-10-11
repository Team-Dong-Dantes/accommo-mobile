<template>
  <!-- A stay's money as a statement: the one thing to do now on top, then every
       month in order — rent, the deposit, bills — with each payment shown under
       the item it paid. The student's Payments tab and the landlord/landlady's
       tenant screen both read it; lease_ledger() is the source of every number. -->
  <div class="st">
    <MonthSummary :totals="summary" :verb="landlord ? 'collected' : 'paid'" />

    <!-- The one thing to do now, as the dashboards' priority card. -->
    <DashPriority :task="priority" empty-label="All paid up" :empty-hint="allPaidHint" @go="onGo" />
    <DashTodoList v-if="payAhead" title="Next" :tasks="[payAhead]" :done-count="0" @go="onGo" />

    <button v-if="earlier.length && !showEarlier" type="button" class="st-fold" @click="showEarlier = true">
      <IconifyIcon icon="lucide:check-check" width="16" />
      {{ earlierLabel }} · all settled
      <IconifyIcon icon="lucide:chevron-down" width="16" class="st-fold-chev" />
    </button>

    <section v-for="m in shownMonths" :key="m.month" class="st-month">
      <h3 class="st-month-name">
        {{ formatMonth(m.month).split(' ')[0] }}<span v-if="m.month === thisMonth" class="st-month-now"> · this month</span>
      </h3>
      <div class="st-items">
        <template v-for="i in m.items" :key="i.key">
          <div class="st-item" :class="`st-item--${i.status}`">
            <span class="st-dot" aria-hidden="true"><IconifyIcon v-if="i.status === 'paid'" icon="lucide:check" width="12" /></span>
            <span class="st-item-body">
              <span class="st-item-name">{{ itemName(i) }}</span>
              <span class="st-item-note">{{ itemNote(i) }}</span>
            </span>
            <span class="st-item-amt">{{ formatPesoExact(i.row.due) }}</span>
          </div>
          <button
            v-for="p in i.payments.filter((x) => x.status !== 'withdrawn')"
            :key="p.id"
            type="button"
            class="st-pay"
            :class="`st-pay--${p.status}`"
            @click="emit('open-payment', p)"
          >
            <IconifyIcon :icon="payIcon(p)" width="14" />
            <span class="st-pay-body">{{ payLine(p) }}</span>
            <span class="st-pay-go">{{ p.status === 'pending_verification' && landlord ? 'Review' : 'Details' }}</span>
          </button>
          <div v-if="landlord && actionsFor(i).length" class="st-acts">
            <button v-for="a in actionsFor(i)" :key="a.label" type="button" class="st-link" @click="a.run()">{{ a.label }}</button>
          </div>
        </template>
        <template v-if="m.month === thisMonth && !closed">
          <component
            :is="landlord ? 'button' : 'div'"
            v-for="u in notPostedThisMonth"
            :key="u"
            :type="landlord ? 'button' : undefined"
            class="st-item st-item--unposted"
            @click="landlord && emit('post-bill')"
          >
            <span class="st-dot" aria-hidden="true" />
            <span class="st-item-body">
              <span class="st-item-name">{{ u }}</span>
              <span class="st-item-note">Not posted yet</span>
            </span>
            <span v-if="landlord" class="st-link">Post</span>
            <span v-else class="st-item-amt">—</span>
          </component>
        </template>
      </div>
    </section>

    <button v-if="later.length" type="button" class="st-fold" @click="showLater = !showLater">
      {{ showLater ? 'Hide later months' : `Show ${later.length === 1 ? 'the next month' : `${later.length} later months`}` }}
      <IconifyIcon icon="lucide:chevron-down" width="16" class="st-fold-chev" :class="{ 'st-fold-chev--open': showLater }" />
    </button>
  </div>
</template>

<script setup lang="ts" generic="P extends StatementPayment & { amount: number; status: string; method: string; createdAt?: string; paidAt?: string | null; rejectionReason?: string; batchId?: string | null }">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { formatDate, formatMonth, formatPesoExact, PAYMENT_METHOD_LABEL } from '@/utils/format'
import { BILL_TAG, buildStatement, dueNowRows, isLateRow, manilaToday, type LedgerRow, type StatementItem, type StatementPayment } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'
import { stayMonthSummary } from '@/utils/collections'
import type { Task } from '@/components/shared/dashboard'
import DashPriority from '@/components/shared/DashPriority.vue'
import DashTodoList from '@/components/shared/DashTodoList.vue'
import MonthSummary from '@/components/shared/MonthSummary.vue'

const props = defineProps<{
  ledger: LedgerRow[]
  payments: P[]
  startDate: string
  role: 'student' | 'landlord'
  /** An ended or terminated stay: only its rent and bills are left to settle. */
  closed: boolean
  /** Pay (student) or Log payment (landlord/landlady) is offered. */
  canPay: boolean
  billUtility: Record<string, UtilityKey>
  /** Utilities billed monthly on this stay, by label ("Water bill"). */
  metered?: { key: UtilityKey; label: string }[]
  /** "landlady" — how the student's landlord/landlady is named. */
  who?: string
  /** The deposit still held, and whether the landlord/landlady may use it now. */
  depositHeld?: number
  depositUsable?: boolean
}>()
const emit = defineEmits<{
  pay: []
  'open-payment': [payment: P]
  forgive: [row: LedgerRow]
  'fix-bill': [billId: string]
  'post-bill': []
  resubmit: [payment: P]
  withdraw: [payment: P]
  message: []
  'use-deposit': []
}>()

const landlord = computed(() => props.role === 'landlord')
const who = computed(() => props.who || 'landlord/landlady')
const today = manilaToday()
const thisMonth = `${today.slice(0, 7)}-01`
const nextMonth = (() => {
  const d = new Date(`${thisMonth}T00:00:00`)
  d.setMonth(d.getMonth() + 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`
})()

const statement = computed(() => buildStatement(props.ledger, props.payments, props.startDate, today))
// Settled months before this one fold away; months after next wait behind a
// toggle. A closed stay shows everything it has.
const earlier = computed(() => (props.closed ? [] : statement.value.filter((m) => m.month < thisMonth && m.settled)))
const later = computed(() => (props.closed ? [] : statement.value.filter((m) => m.month > nextMonth)))
const showEarlier = ref(false)
const showLater = ref(false)
const shownMonths = computed(() =>
  statement.value.filter((m) => (showEarlier.value || !earlier.value.includes(m)) && (showLater.value || !later.value.includes(m))),
)
const earlierLabel = computed(() => {
  const names = earlier.value.map((m) => formatMonth(m.month).split(' ')[0])
  return names.length <= 2 ? names.reverse().join(' and ') : `${names.length} earlier months`
})

const dueRows = computed(() => dueNowRows(props.ledger, today, props.closed))
const dueTotal = computed(() => dueRows.value.reduce((s, r) => s + r.balance, 0))
const overdue = computed(() => dueRows.value.some((r) => isLateRow(r, today)))
// Accepted, not moved in: everything due falls on the move-in date.
const moveIn = computed(() => props.startDate > today || (dueRows.value.length > 0 && dueRows.value.every((r) => r.dueDate === props.startDate) && props.startDate >= today))
const pendingTotal = computed(() => props.ledger.reduce((s, r) => s + r.pending, 0))
const toReview = computed(() => props.payments.filter((p) => p.status === 'pending_verification'))
const next = computed(() => props.ledger.filter((r) => r.balance > 0.009 && r.kind !== 'deposit').sort((a, b) => (a.dueDate ?? '').localeCompare(b.dueDate ?? ''))[0] ?? null)

const dueLabel = computed(() => {
  if (props.closed) return 'Left to settle on this stay'
  if (overdue.value) return 'Overdue'
  if (moveIn.value) return `Before ${landlord.value ? 'they move' : 'you move'} in · ${formatDate(props.startDate)}`
  return landlord.value ? 'Owes you' : 'Due now'
})
// The card's title is what is owed; how late (or when due) sits in its corner.
const dueNames = computed(() => {
  const rows = dueRows.value
  const more = rows.length > 3 ? ` + ${rows.length - 3} more` : ''
  return `${capitalize(rows.slice(0, 3).map(shortName).join(' + '))}${more}`
})
const dueWhen = computed(() => {
  const late = dueRows.value.filter((r) => isLateRow(r, today)).map((r) => r.dueDate ?? '').sort()[0]
  if (late) {
    const days = Math.max(1, Math.round((new Date(`${today}T00:00:00`).getTime() - new Date(`${late}T00:00:00`).getTime()) / 86400000))
    return `${days} day${days === 1 ? '' : 's'} late`
  }
  const first = dueRows.value.map((r) => r.dueDate ?? '').sort()[0]
  return first ? `Due ${formatDate(first)}` : ''
})
const waitingSub = computed(() => {
  const p = toReview.value[0]
  if (!p) return ''
  const sent = p.createdAt ? ` · sent ${formatDate(p.createdAt)}` : ''
  return `${methodName(p.method)} for ${batchWhat(p)}${sent}.${landlord.value ? '' : ` You'll be told once it's confirmed.`}`
})

// The newest transfer sent back whose items still have something owed.
const sentBack = computed(() => {
  const rejected = props.payments.filter((p) => p.status === 'rejected')
  if (!rejected.length) return null
  const byBatch = new Map<string, P[]>()
  for (const p of rejected) byBatch.set(p.batchId ?? p.id, [...(byBatch.get(p.batchId ?? p.id) ?? []), p])
  const batches = [...byBatch.values()].sort((a, b) => (b[0]!.createdAt ?? '').localeCompare(a[0]!.createdAt ?? ''))
  const latest = batches[0]!
  const first = latest[0]!
  const row = rowOf(first)
  if (!row || row.balance <= 0.009) return null
  // Already sent again (waiting or confirmed) since: nothing to fix.
  if (props.payments.some((p) => p.status !== 'rejected' && p.status !== 'withdrawn' && sameItem(p, first) && (p.createdAt ?? '') > (first.createdAt ?? ''))) return null
  const twice = batches.filter((b) => b.some((p) => sameItem(p, first))).length >= 2
  const reason = first.rejectionReason ?? ''
  const [head, ...rest] = reason.split('\n')
  return {
    payment: first,
    total: latest.reduce((s, p) => s + p.amount, 0),
    what: batchWhat(first),
    twice,
    reason,
    reasonTitle: rest.length ? head : '',
    reasonText: rest.length ? rest.join(' ') : head,
  }
})

// An ended stay has only rent and bills left to settle; its deposit is the
// landlord/landlady's to handle, so it stays out of the numbers.
const summary = computed(() => stayMonthSummary(props.closed ? props.ledger.filter((r) => r.kind !== 'deposit') : props.ledger, today))

const priority = computed<Task | null>(() => {
  const base = { when: '', rank: 0 }
  const sb = sentBack.value
  if (sb && !landlord.value) {
    const quote = sb.reasonText ? `“${sb.reasonText}”` : ''
    return sb.twice
      ? { ...base, id: 'sent-back', icon: 'lucide:undo-2', tone: 'danger', kind: 'Sent back again', label: `Your ${formatPesoExact(sb.total)} payment came back again`, hint: `${quote} Best to sort it out with your ${who.value} first.`.trim(), action: `Message your ${who.value}`, route: 'message' }
      : { ...base, id: 'sent-back', icon: 'lucide:undo-2', tone: 'danger', kind: `Sent back by your ${who.value}`, label: sb.reasonTitle || `Your ${formatPesoExact(sb.total)} payment was sent back`, hint: [quote, `${methodName(sb.payment.method)} ${formatPesoExact(sb.total)} for ${sb.what}`].filter(Boolean).join(' · '), action: 'Fix and send again', route: 'resubmit' }
  }
  if (dueTotal.value > 0.009) {
    const waiting = pendingTotal.value > 0.009 ? `${formatPesoExact(pendingTotal.value)} ${landlord.value ? 'is waiting for your confirmation' : 'is waiting for confirmation'}.` : ''
    return {
      ...base,
      id: 'due',
      icon: overdue.value ? 'lucide:circle-alert' : moveIn.value ? 'lucide:key-round' : 'lucide:wallet',
      tone: overdue.value ? 'danger' : moveIn.value ? 'info' : 'warn',
      kind: dueLabel.value,
      label: dueNames.value,
      when: dueWhen.value,
      hint: waiting || (landlord.value ? 'Log it when the money reaches you.' : `Your ${who.value} confirms once it arrives.`),
      action: props.canPay ? (landlord.value ? 'Log payment' : `Pay ${formatPesoExact(dueTotal.value)}`) : '',
      route: 'pay',
    }
  }
  if (pendingTotal.value > 0.009) {
    return {
      ...base,
      id: 'waiting',
      icon: 'lucide:hourglass',
      tone: 'info',
      kind: landlord.value ? 'Waiting for you' : `Waiting for your ${who.value}`,
      label: `${formatPesoExact(pendingTotal.value)} sent${toReview.value[0] ? ` by ${methodName(toReview.value[0].method)}` : ''}`,
      hint: waitingSub.value,
      action: landlord.value ? 'Review' : 'See what you sent',
      route: 'open-pending',
    }
  }
  return null
})
// Nothing owed now: the next item, as a to-do row with "Pay ahead".
const payAhead = computed<Task | null>(() => {
  if (landlord.value || !props.canPay || props.closed || priority.value || !next.value) return null
  return { id: 'ahead', icon: 'lucide:calendar', tone: 'info', kind: 'Rent', label: `${capitalize(shortName(next.value))} · ${formatPesoExact(next.value.balance)}`, hint: `Due ${formatDate(next.value.dueDate)} · you can pay ahead`, when: '', action: 'Pay ahead', route: 'pay', rank: 0 }
})
const allPaidHint = computed(() => {
  if (props.closed || !next.value) return 'Nothing is owed on this stay.'
  return landlord.value ? `Next: ${shortName(next.value)} · ${formatPesoExact(next.value.balance)} on ${formatDate(next.value.dueDate)}.` : 'Nothing is owed right now.'
})
function onGo(route: string) {
  if (route === 'pay') emit('pay')
  else if (route === 'message') emit('message')
  else if (route === 'resubmit' && sentBack.value) emit('resubmit', sentBack.value.payment)
  else if (route === 'open-pending' && toReview.value[0]) emit('open-payment', toReview.value[0])
}

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
// The landlord/landlady's per-item actions: forgive what is left, correct a
// bill, use the deposit at the end of the stay.
function actionsFor(i: StatementItem<P>): { label: string; run: () => void }[] {
  const out: { label: string; run: () => void }[] = []
  const r = i.row
  if (r.kind === 'bill' && r.billId) out.push({ label: 'Correct', run: () => emit('fix-bill', r.billId as string) })
  if (r.kind !== 'deposit' && r.balance > 0.009 && i.status !== 'pending' && (r.dueDate ?? '') <= today) out.push({ label: `Forgive ${formatPesoExact(r.balance)}…`, run: () => emit('forgive', r) })
  if (r.kind === 'deposit' && props.depositUsable && (props.depositHeld ?? 0) > 0.009) out.push({ label: 'Use the deposit', run: () => emit('use-deposit') })
  return out
}

const notPostedThisMonth = computed(() =>
  (props.metered ?? [])
    .filter((u) => !props.ledger.some((r) => r.kind === 'bill' && r.month?.slice(0, 7) === thisMonth.slice(0, 7) && props.billUtility[r.billId ?? ''] === u.key))
    .map((u) => BILL_TAG[u.key]),
)
function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1)
}
</script>

<style scoped>
.st {
  display: flex;
  flex-direction: column;
  gap: 18px;
}
/* The dashboard's to-do rows sit on the page background; in a white panel
   they take the background colour so they still read as cards. Its header is
   an <h2>, which otherwise takes Quasar's 3.75rem line-height. */
.st :deep(.step) {
  background: var(--m-bg);
}
.st :deep(.sec-title) {
  line-height: 1.3;
}
.st-fold {
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 8px;
  padding: 0 4px;
  border: 0;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.st-fold-chev {
  margin-left: auto;
  transition: transform 0.15s ease;
}
.st-fold-chev--open {
  transform: rotate(180deg);
}
.st-month {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.st-month-name {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.st-month-now {
  color: var(--m-primary-dark);
  letter-spacing: 0;
  text-transform: none;
}
.st-items {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.st-item {
  display: flex;
  width: 100%;
  min-height: 56px;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
}
.st-items > * + .st-item {
  border-top: 1px solid var(--m-border);
}
button.st-item {
  border-right: 0;
  border-bottom: 0;
  border-left: 0;
  background: none;
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.st-dot {
  display: inline-flex;
  width: 20px;
  height: 20px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--m-border);
  border-radius: 50%;
  color: #fff;
}
.st-item--paid .st-dot {
  border-color: var(--m-success);
  background: var(--m-success);
}
.st-item--pending .st-dot {
  border-color: var(--m-info);
  background: var(--m-info-soft);
}
.st-item--overdue .st-dot {
  border-color: var(--m-danger);
  background: var(--m-danger-soft);
}
.st-item--partial .st-dot,
.st-item--due .st-dot {
  border-color: var(--m-warning);
}
.st-item--unposted .st-dot {
  border-style: dashed;
}
.st-item-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.st-item-name {
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
}
.st-item-note {
  color: var(--m-muted);
  font-size: 12.5px;
}
.st-item--overdue .st-item-note {
  color: var(--m-danger);
  font-weight: 600;
}
.st-item--pending .st-item-note {
  color: var(--m-info);
  font-weight: 600;
}
.st-item--paid .st-item-amt,
.st-item--unposted .st-item-name {
  color: var(--m-muted);
}
.st-item-amt {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.st-pay {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 8px;
  margin-top: -6px;
  padding: 0 14px 10px 46px;
  border: 0;
  background: none;
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  text-align: left;
}
.st-pay--rejected {
  color: var(--m-danger);
  font-weight: 600;
}
.st-pay--pending_verification {
  color: var(--m-info);
  font-weight: 600;
}
.st-pay-body {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.st-pay-go {
  flex: 0 0 auto;
  color: var(--m-primary-dark);
  font-weight: 700;
}
.st-acts {
  display: flex;
  gap: 16px;
  margin-top: -6px;
  padding: 0 14px 10px 46px;
}
.st-link {
  min-height: 32px;
  padding: 0;
  border: 0;
  background: none;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.st-link--danger {
  color: var(--m-danger);
}
</style>
