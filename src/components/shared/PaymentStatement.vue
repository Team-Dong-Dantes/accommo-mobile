<template>
  <!-- A stay's money as a statement: what is due now on top, then every month
       in order — rent, the deposit, bills — each marked paid, awaiting
       confirmation, due or upcoming. Tap an item for the payments made toward
       it. The student's Payments tab and the landlord/landlady's tenant screen
       both read it; the ledger (lease_ledger) is the source of every number. -->
  <div class="st">
    <div class="st-card" :class="`st-card--${tone}`">
      <span class="st-card-label">{{ cardLabel }}</span>
      <span class="st-card-amt">{{ formatPesoExact(dueTotal) }}</span>
      <span class="st-card-sub">{{ cardSub }}</span>
      <span v-if="pendingTotal > 0.009" class="st-card-pending">
        <IconifyIcon icon="lucide:hourglass" width="13" />
        {{ formatPesoExact(pendingTotal) }} {{ landlord ? 'waiting for your confirmation' : 'waiting for confirmation' }}
      </span>
      <div v-if="canPay || (landlord && toReview.length)" class="st-card-actions">
        <button v-if="landlord && toReview.length" type="button" class="st-btn" @click="emit('open-payment', toReview[0]!)">
          Review {{ toReview.length === 1 ? 'payment' : `${toReview.length} payments` }}
        </button>
        <button
          v-if="canPay && owesAnything"
          type="button"
          class="st-btn st-btn--pay"
          :class="{ 'st-btn--ghost': landlord && toReview.length }"
          @click="emit('pay')"
        >
          <IconifyIcon icon="lucide:wallet" width="16" />
          {{ landlord ? 'Log a payment' : dueTotal > 0.009 ? `Pay ${formatPesoExact(dueTotal)}` : 'Pay ahead' }}
        </button>
      </div>
    </div>

    <button v-if="earlier.length && !showEarlier" type="button" class="st-fold" @click="showEarlier = true">
      <IconifyIcon icon="lucide:check-check" width="15" />
      {{ earlier.length === 1 ? '1 earlier month' : `${earlier.length} earlier months` }} · all settled
      <IconifyIcon icon="lucide:chevron-down" width="15" class="st-fold-chev" />
    </button>

    <section v-for="m in shownMonths" :key="m.month" class="st-month">
      <h3 class="st-month-name">
        {{ formatMonth(m.month) }}<span v-if="m.month === thisMonth" class="st-month-now"> · this month</span>
      </h3>
      <div class="st-items">
        <div v-for="i in m.items" :key="i.key" class="st-item" :class="`st-item--${i.status}`">
          <button type="button" class="st-item-main" :aria-expanded="openKey === i.key" @click="openKey = openKey === i.key ? '' : i.key">
            <span class="st-dot" aria-hidden="true"><IconifyIcon v-if="i.status === 'paid'" icon="lucide:check" width="11" /></span>
            <span class="st-item-body">
              <span class="st-item-name">{{ itemName(i) }}</span>
              <span class="st-item-note">{{ itemNote(i) }}</span>
            </span>
            <span class="st-item-amt">{{ formatPesoExact(i.row.due) }}</span>
            <IconifyIcon icon="lucide:chevron-down" width="15" class="st-item-chev" :class="{ 'st-item-chev--open': openKey === i.key }" />
          </button>
          <div v-if="openKey === i.key" class="st-more">
            <button v-for="p in i.payments" :key="p.id" type="button" class="st-pay" @click="emit('open-payment', p)">
              <IconifyIcon icon="lucide:receipt" width="14" class="st-pay-icon" />
              <span class="st-pay-body">
                {{ PAYMENT_METHOD_LABEL[p.method] || p.method }} · {{ formatPesoExact(p.amount) }}
              </span>
              <span class="st-chip" :class="`st-chip--${statusColor(PAYMENT_STATUS, p.status)}`">{{ statusText(PAYMENT_STATUS, p.status) }}</span>
            </button>
            <p v-if="!i.payments.length" class="st-more-none">No payments toward this yet.</p>
            <div v-if="landlord && (i.row.balance > 0.009 || removable(i))" class="st-more-actions">
              <button v-if="i.row.balance > 0.009" type="button" class="st-link" @click="emit('forgive', i.row)">
                Forgive {{ formatPesoExact(i.row.balance) }}
              </button>
              <button v-if="removable(i)" type="button" class="st-link st-link--danger" @click="emit('remove-bill', i.row.billId!)">
                Remove bill
              </button>
            </div>
          </div>
        </div>
        <template v-if="m.month === thisMonth && !closed">
          <component
            :is="landlord ? 'button' : 'div'"
            v-for="u in notPostedThisMonth"
            :key="u"
            :type="landlord ? 'button' : undefined"
            class="st-item st-item--unposted"
            @click="landlord && emit('post-bill')"
          >
            <span class="st-item-main">
              <span class="st-dot" aria-hidden="true" />
              <span class="st-item-body">
                <span class="st-item-name">{{ u }}</span>
                <span class="st-item-note">{{ landlord ? 'Not posted yet · tap to post' : 'Not posted yet' }}</span>
              </span>
              <span class="st-item-amt">—</span>
            </span>
          </component>
        </template>
      </div>
    </section>

    <button v-if="later.length" type="button" class="st-fold" @click="showLater = !showLater">
      {{ showLater ? 'Hide later months' : `Show ${later.length === 1 ? 'the next month' : `${later.length} later months`}` }}
      <IconifyIcon icon="lucide:chevron-down" width="15" class="st-fold-chev" :class="{ 'st-item-chev--open': showLater }" />
    </button>
  </div>
</template>

<script setup lang="ts" generic="P extends StatementPayment & { amount: number; status: string; method: string }">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { formatDate, formatMonth, formatPesoExact, PAYMENT_METHOD_LABEL, PAYMENT_STATUS, statusColor, statusText } from '@/utils/format'
import { BILL_TAG, buildStatement, dueNowRows, manilaToday, type LedgerRow, type StatementItem, type StatementPayment } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'

const props = defineProps<{
  ledger: LedgerRow[]
  payments: P[]
  startDate: string
  role: 'student' | 'landlord'
  /** An ended or terminated stay: only its rent and bills are left to settle. */
  closed: boolean
  /** Pay (student) or Log a payment (landlord/landlady) is offered. */
  canPay: boolean
  billUtility: Record<string, UtilityKey>
  /** Utilities billed monthly on this stay, by label ("Water bill"). */
  metered?: { key: UtilityKey; label: string }[]
}>()
const emit = defineEmits<{
  pay: []
  'open-payment': [payment: P]
  forgive: [row: LedgerRow]
  'remove-bill': [billId: string]
  'post-bill': []
}>()

const landlord = computed(() => props.role === 'landlord')
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
  statement.value.filter(
    (m) => (showEarlier.value || !earlier.value.includes(m)) && (showLater.value || !later.value.includes(m)),
  ),
)
const openKey = ref('')

const dueRows = computed(() => dueNowRows(props.ledger, today, props.closed))
const dueTotal = computed(() => dueRows.value.reduce((s, r) => s + r.balance, 0))
const overdue = computed(() => dueRows.value.some((r) => r.state === 'overdue'))
const pendingTotal = computed(() => props.ledger.reduce((s, r) => s + r.pending, 0))
const owesAnything = computed(() => props.ledger.some((r) => r.balance > 0.009 && (!props.closed || r.kind === 'rent' || r.kind === 'bill')))
const toReview = computed(() => props.payments.filter((p) => p.status === 'pending_verification'))

const tone = computed(() => (overdue.value ? 'overdue' : dueTotal.value > 0.009 ? 'due' : 'clear'))
const cardLabel = computed(() => {
  if (props.closed) return dueTotal.value > 0.009 ? 'Left to settle on this stay' : 'This stay is settled'
  if (overdue.value) return 'Overdue'
  return dueTotal.value > 0.009 ? 'Due now' : 'All paid up'
})

function shortName(r: LedgerRow): string {
  if (r.kind === 'rent') return `${shortMonth(r.month)} rent`
  if (r.kind === 'bill') return (BILL_TAG[props.billUtility[r.billId ?? ''] ?? 'water'] ?? 'Bill').toLowerCase()
  return 'deposit'
}
const cardSub = computed(() => {
  const rows = dueRows.value
  if (rows.length) {
    const names = rows.slice(0, 3).map(shortName)
    const more = rows.length > 3 ? ` + ${rows.length - 3} more` : ''
    const first = rows.map((r) => r.dueDate ?? '').filter(Boolean).sort()[0]
    const when = props.closed || !first ? '' : ` · ${overdue.value ? 'overdue since' : 'due'} ${formatDate(first)}`
    return `${capitalize(names.join(' + '))}${more}${when}`
  }
  const next = props.ledger
    .filter((r) => r.balance > 0.009)
    .sort((a, b) => (a.dueDate ?? '').localeCompare(b.dueDate ?? ''))[0]
  if (next) return `Next: ${shortName(next)} · ${formatPesoExact(next.balance)} due ${formatDate(next.dueDate)}`
  return pendingTotal.value > 0.009 ? 'Everything else is paid.' : 'Nothing is owed on this stay.'
})

function itemName(i: StatementItem<P>): string {
  if (i.row.kind === 'rent') return i.advance ? 'Rent · advance' : 'Rent'
  if (i.row.kind === 'bill') return BILL_TAG[props.billUtility[i.row.billId ?? ''] ?? 'water'] ?? 'Utility bill'
  return 'Deposit'
}
function itemNote(i: StatementItem<P>): string {
  const r = i.row
  const left = `${formatPesoExact(r.balance)} left`
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
/** A bill nobody has paid toward can still be taken back (guard_utility_bills). */
function removable(i: StatementItem<P>): boolean {
  return i.row.kind === 'bill' && !i.payments.some((p) => p.status !== 'rejected' && p.status !== 'withdrawn')
}

const notPostedThisMonth = computed(() =>
  (props.metered ?? [])
    .filter((u) => !props.ledger.some((r) => r.kind === 'bill' && r.month?.slice(0, 7) === thisMonth.slice(0, 7) && props.billUtility[r.billId ?? ''] === u.key))
    .map((u) => BILL_TAG[u.key]),
)

function shortMonth(m: string | null): string {
  return m ? new Date(`${m.slice(0, 10)}T00:00:00`).toLocaleDateString('en-PH', { month: 'short' }) : ''
}
function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1)
}
</script>

<style scoped>
.st {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.st-card {
  display: flex;
  flex-direction: column;
  gap: 3px;
  padding: 16px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.st-card--due {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
}
.st-card--overdue {
  border-color: var(--m-danger);
  background: var(--m-danger-soft);
}
.st-card-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.st-card--overdue .st-card-label {
  color: var(--m-danger);
}
.st-card-amt {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.st-card-sub {
  color: var(--m-text);
  font-size: 13px;
}
.st-card-pending {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-top: 4px;
  color: var(--m-info);
  font-size: 12.5px;
  font-weight: 700;
}
.st-card-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}
.st-btn {
  display: inline-flex;
  min-height: 44px;
  flex: 1 1 auto;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.st-card--overdue .st-btn--pay:not(.st-btn--ghost) {
  background: var(--m-danger);
}
.st-btn--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-ink);
}

.st-fold {
  display: flex;
  min-height: 40px;
  align-items: center;
  gap: 6px;
  padding: 0 4px;
  border: 0;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.st-fold-chev {
  margin-left: auto;
}

.st-month {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.st-month-name {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.st-month-now {
  color: var(--m-primary-dark);
  text-transform: none;
}
.st-items {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.st-item + .st-item {
  border-top: 1px solid var(--m-border);
}
button.st-item {
  display: block;
  width: 100%;
  padding: 0;
  border-right: 0;
  border-bottom: 0;
  border-left: 0;
  background: none;
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.st-item-main {
  display: flex;
  width: 100%;
  min-height: 56px;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  border: 0;
  background: none;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.st-dot {
  display: inline-flex;
  width: 18px;
  height: 18px;
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
  font-size: 14px;
  font-weight: 700;
}
.st-item-note {
  color: var(--m-muted);
  font-size: 12px;
}
.st-item--overdue .st-item-note {
  color: var(--m-danger);
  font-weight: 700;
}
.st-item--pending .st-item-note {
  color: var(--m-info);
  font-weight: 600;
}
.st-item--paid .st-item-amt,
.st-item--unposted .st-item-amt,
.st-item--unposted .st-item-name {
  color: var(--m-muted);
}
.st-item-amt {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.st-item-chev {
  flex: 0 0 auto;
  color: var(--m-muted);
  transition: transform 0.15s ease;
}
.st-item-chev--open {
  transform: rotate(180deg);
}

.st-more {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 0 12px 12px 42px;
}
.st-pay {
  display: flex;
  min-height: 40px;
  align-items: center;
  gap: 8px;
  padding: 0 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.st-pay-icon {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.st-pay-body {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.st-chip {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
}
.st-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.st-chip--amber,
.st-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.st-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.st-more-none {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.st-more-actions {
  display: flex;
  gap: 14px;
}
.st-link {
  min-height: 36px;
  padding: 0;
  border: 0;
  background: none;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
}
.st-link--danger {
  color: var(--m-danger);
}
</style>
