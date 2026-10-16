<template>
  <div class="pt">
    <section class="pt-hero" :aria-label="String(year)">
      <PeriodBar :label="String(year)" :can-prev="year > minYear" :can-next="year < maxYear" @prev="picked = year - 1" @next="picked = year + 1">
        <PropertyPicker v-model="property" :options="propertyOptions" />
      </PeriodBar>
      <div class="pt-total">
        <span class="pt-big">{{ formatPesoExact(received) }}</span>
        <span class="pt-of">received in {{ year }}</span>
      </div>
      <button type="button" class="pt-link" @click="router.push('/manager/tenants?tab=history')">
        See it by room in Rent history
        <IconifyIcon icon="lucide:chevron-right" width="14" />
      </button>
    </section>

    <section v-if="months.length" class="pt-list">
      <template v-for="(m, mi) in months" :key="m.key">
        <div class="pt-month" :class="{ 'pt-month--next': mi > 0 }">
          <span class="pt-month-name">{{ m.label }}</span>
          <span class="pt-month-total">{{ formatPesoExact(m.total) }} received</span>
        </div>
        <button v-for="p in m.rows" :key="p.id" type="button" class="pt-row" @click="openReceipt(p.id)">
          <CollectionAvatar :lease="p.lease" class="pt-avatar" />
          <span class="pt-body">
            <span class="pt-name">{{ p.lease.studentName }}</span>
            <span class="pt-sub">{{ p.sub }}</span>
          </span>
          <span class="pt-side">
            <span class="pt-amount" :class="{ 'pt-amount--void': p.status === 'rejected' }">{{ formatPesoExact(p.amount) }}</span>
            <span class="pt-chip" :class="`pt-chip--${statusColor(PAYMENT_STATUS, p.status)}`">{{ statusText(PAYMENT_STATUS, p.status) }}</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="pt-chev" />
        </button>
      </template>
    </section>
    <EmptyState v-else-if="!rows.length" variant="compact" icon="lucide:receipt" title="No payments yet" message="Payments you receive or log against a boarder will be listed here." />
    <EmptyState v-else variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different year, property, search or filter." />

    <PaymentReceiptSheet v-model="receiptOpen" :payment-id="receiptId" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import PeriodBar from '@/components/shared/PeriodBar.vue'
import PropertyPicker from '@/components/shared/PropertyPicker.vue'
import PaymentReceiptSheet from '@/components/shared/PaymentReceiptSheet.vue'
import CollectionAvatar from '@/components/manager/CollectionAvatar.vue'
import { PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor, formatPesoExact } from '@/utils/format'
import { manilaToday } from '@/utils/payments'
import type { MoneyLease } from '@/api/landlordMoney'
import type { PayRow } from './managerHistory'

// H-Landlord: finished payments only (paid, forgiven, rejected) — whatever is
// still waiting lives on Monthly rent. Grouped by the month it came in, with
// "received" counting paid rows only (a forgiven or rejected one is no money).
const props = defineProps<{
  payments: PayRow[]
  leases: MoneyLease[]
  query: string
  status: 'all' | 'paid' | 'waived' | 'rejected'
}>()
const router = useRouter()

const leaseById = computed(() => new Map(props.leases.map((l) => [l.id, l])))
// Manila calendar day of when it happened, YYYY-MM-DD.
const dayOf = (iso: string) => manilaToday(new Date(iso))
const rows = computed(() =>
  props.payments.flatMap((p) => {
    const lease = leaseById.value.get(p.leaseId)
    return lease ? [{ ...p, lease, day: dayOf(p.at) }] : []
  }),
)

const thisYear = Number(manilaToday().slice(0, 4))
const years = computed(() => rows.value.map((r) => Number(r.day.slice(0, 4))))
const maxYear = computed(() => Math.max(thisYear, ...years.value))
const minYear = computed(() => Math.min(maxYear.value, ...years.value))
const picked = ref<number | null>(null)
const year = computed(() => picked.value ?? (years.value.length ? Math.max(...years.value) : thisYear))

const property = ref('all')
const propertyOptions = computed(() => [
  { value: 'all', label: 'All properties' },
  ...[...new Map(props.leases.map((l) => [l.accommodationId, l.accommodationName])).entries()].map(([value, label]) => ({ value, label })),
])

const inYear = computed(() =>
  rows.value.filter((r) => Number(r.day.slice(0, 4)) === year.value && (property.value === 'all' || r.lease.accommodationId === property.value)),
)
const received = computed(() => inYear.value.filter((r) => r.status === 'paid').reduce((n, r) => n + r.amount, 0))

const TAGS = new Set(['Advance payment', 'Security deposit', 'Water bill', 'Electricity bill', 'Wi-Fi bill'])
function what(p: { description: string | null; month: string }) {
  if (p.description && TAGS.has(p.description)) return p.description
  return `${new Date(p.month).toLocaleDateString('en-PH', { month: 'long' })} rent`
}
const shortDay = (d: string) => new Date(`${d}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })

const months = computed(() => {
  const q = props.query.trim().toLowerCase()
  const out = inYear.value
    .filter((r) => props.status === 'all' || r.status === props.status)
    .map((r) => ({
      id: r.id,
      lease: r.lease,
      amount: r.amount,
      status: r.status,
      day: r.day,
      sub: [what(r), r.lease.roomLabel, PAYMENT_METHOD_LABEL[r.method] ?? r.method, shortDay(r.day)].join(' · '),
    }))
    .filter((r) => !q || `${r.lease.studentName} ${r.sub}`.toLowerCase().includes(q))
    .sort((a, b) => b.day.localeCompare(a.day))
  const byMonth = new Map<string, typeof out>()
  for (const r of out) byMonth.set(r.day.slice(0, 7), [...(byMonth.get(r.day.slice(0, 7)) ?? []), r])
  return [...byMonth.entries()].map(([key, list]) => ({
    key,
    label: new Date(`${key}-01T00:00:00`).toLocaleDateString('en-PH', { month: 'long' }),
    total: list.filter((r) => r.status === 'paid').reduce((n, r) => n + r.amount, 0),
    rows: list,
  }))
})

const receiptOpen = ref(false)
const receiptId = ref<string | null>(null)
function openReceipt(id: string) {
  receiptId.value = id
  receiptOpen.value = true
}
</script>

<style scoped>
.pt {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.pt-hero {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pt-total {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px 8px;
}
.pt-big {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 30px;
  font-weight: 700;
  letter-spacing: -0.03em;
}
.pt-of {
  color: var(--m-muted);
  font-size: 14px;
}
.pt-link {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  align-self: flex-start;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
}
.pt-list {
  display: flex;
  flex-direction: column;
  margin: 0 -14px;
  border-top: 1px solid var(--m-border);
  border-bottom: 1px solid var(--m-border);
}
.pt-month {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--m-bg);
}
.pt-month--next {
  border-top: 1px solid var(--m-border);
}
.pt-month-name {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pt-month-total {
  margin-left: auto;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.pt-row {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 10px 8px 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  font: inherit;
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.pt-avatar {
  width: 36px;
  height: 36px;
  font-size: 12px;
}
.pt-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.pt-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.pt-sub {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pt-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.pt-amount {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pt-amount--void {
  color: var(--m-muted);
  text-decoration: line-through;
}
.pt-chip {
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.pt-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pt-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pt-chev {
  flex: 0 0 auto;
  color: var(--m-muted);
}
</style>
