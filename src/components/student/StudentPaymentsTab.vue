<template>
  <div class="pt">
    <template v-if="payments.length">
      <section class="pt-year" :aria-label="String(year)">
        <div class="pt-bar">
          <button type="button" class="pt-nav" aria-label="Previous year" :disabled="yi >= years.length - 1" @click="yi++">
            <IconifyIcon icon="lucide:chevron-left" width="18" />
          </button>
          <span class="pt-label">{{ year }}</span>
          <button type="button" class="pt-nav" aria-label="Next year" :disabled="yi <= 0" @click="yi--">
            <IconifyIcon icon="lucide:chevron-right" width="18" />
          </button>
          <span class="pt-gap" />
          <button type="button" class="pt-pill" @click="sheet = true">
            {{ STATUS_FILTERS.find((f) => f.key === status)?.label }}
            <IconifyIcon icon="lucide:chevron-down" width="14" />
          </button>
        </div>
        <div class="pt-total">
          <span class="pt-big">{{ formatPesoExact(yearTotal) }}</span>
          <span class="pt-of">paid in {{ year }}</span>
        </div>
      </section>

      <section v-if="groups.length" class="pt-groups">
        <template v-for="g in groups" :key="g.id">
          <button type="button" class="pt-stay" :aria-expanded="isOpen(g)" @click="toggle(g)">
            <span class="pt-stay-text">
              <span class="pt-stay-top">
                <span class="pt-stay-name">{{ g.name }}</span>
                <span v-if="g.current" class="pt-current">Current stay</span>
              </span>
              <span class="pt-stay-sub">{{ g.sub }}</span>
            </span>
            <span v-if="!g.current && g.owed !== null" class="pt-settled" :class="{ 'pt-settled--bad': g.owed > 0.009 }">
              {{ g.owed > 0.009 ? `${formatPesoExact(g.owed)} unpaid` : 'Settled' }}
            </span>
            <IconifyIcon :icon="isOpen(g) ? 'lucide:chevron-up' : 'lucide:chevron-down'" width="16" class="pt-chev" />
          </button>
          <template v-if="isOpen(g)">
            <template v-for="m in g.months" :key="m.month">
              <div class="pt-month">{{ m.label }}</div>
              <button v-for="p in m.rows" :key="p.id" type="button" class="pt-row" @click="openReceipt(p.id)">
                <span class="pt-ico"><IconifyIcon :icon="iconOf(p)" width="17" /></span>
                <span class="pt-text">
                  <span class="pt-rtitle">{{ titleOf(p) }}</span>
                  <span class="pt-rsub">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }} · {{ shortDate(p.paidAt || p.createdAt) }}</span>
                </span>
                <span class="pt-side">
                  <span class="pt-amt" :class="{ 'pt-amt--void': p.status === 'rejected' }">{{ formatPesoExact(p.amount) }}</span>
                  <span class="pt-chip" :class="{ 'pt-chip--bad': p.status === 'rejected' }">{{ PAYMENT_STATUS[p.status]?.text ?? p.status }}</span>
                </span>
                <IconifyIcon icon="lucide:chevron-right" width="15" class="pt-chev" />
              </button>
            </template>
          </template>
        </template>
      </section>
      <EmptyState v-else variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search, year or status." />
    </template>
    <EmptyState v-else variant="compact" icon="lucide:receipt" title="No payments yet" message="Rent you have paid will be recorded here. Anything still waiting is in My Stay." />

    <BottomSheet v-model="sheet" title="Status" clear-label="" done-label="Done">
      <div class="m-chips">
        <button v-for="f in STATUS_FILTERS" :key="f.key" type="button" class="m-chip" :class="{ 'm-chip--on': status === f.key }" @click="status = f.key">
          {{ f.label }}
        </button>
      </div>
    </BottomSheet>
    <PaymentReceiptSheet v-model="receiptOpen" :payment-id="receiptId" />
  </div>
</template>

<script lang="ts">
// A finished payment (paid, forgiven or rejected). Anything still waiting stays
// in My Stay, so History is only the record.
export interface PaymentRow {
  id: string
  leaseId: string
  month: string
  amount: number
  status: string
  method: string
  kind: string
  description: string
  paidAt: string | null
  createdAt: string
  name: string
  room: string
  leaseStatus: string
  leaseStart: string
  leaseEnd: string
}
</script>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import PaymentReceiptSheet from '@/components/shared/PaymentReceiptSheet.vue'
import { formatDate, formatMonth, parseServerTime, PAYMENT_METHOD_LABEL, PAYMENT_STATUS, formatPesoExact } from '@/utils/format'
import { ADVANCE_TAG, DEPOSIT_TAG, BILL_TAG } from '@/utils/payments'
import { period } from '@/utils/profile'

// Payments (H-Student): year by year, grouped by stay, newest month first.
// `owed` is the left-to-pay on each finished stay (lease_ledger), for its
// Settled chip; `expand` opens one stay's group (the stay sheet's link).
const props = defineProps<{ payments: PaymentRow[]; owed: Record<string, number>; query: string; expand: string | null }>()

const STATUS_FILTERS = [
  { key: 'all', label: 'All statuses' },
  { key: 'paid', label: 'Paid' },
  { key: 'waived', label: 'Forgiven' },
  { key: 'rejected', label: 'Rejected' },
] as const
const status = ref<(typeof STATUS_FILTERS)[number]['key']>('all')
const sheet = ref(false)

const yearOf = (p: PaymentRow) => Number(p.month.slice(0, 4))
const years = computed(() => [...new Set(props.payments.map(yearOf))].sort((a, b) => b - a))
const yi = ref(0)
const year = computed(() => years.value[yi.value] ?? new Date().getFullYear())
const yearTotal = computed(() => props.payments.filter((p) => yearOf(p) === year.value && p.status === 'paid').reduce((n, p) => n + p.amount, 0))

const titleOf = (p: PaymentRow) => {
  if (p.description === ADVANCE_TAG || p.description === DEPOSIT_TAG || Object.values(BILL_TAG).includes(p.description)) return p.description
  return `${formatMonth(p.month).split(' ')[0]} rent`
}
const iconOf = (p: PaymentRow) =>
  p.description === DEPOSIT_TAG ? 'lucide:shield'
    : p.description === ADVANCE_TAG ? 'lucide:calendar'
      : p.description === BILL_TAG.water ? 'lucide:droplet'
        : p.description === BILL_TAG.wifi ? 'lucide:wifi'
          : p.description === BILL_TAG.electric ? 'lucide:zap'
            : 'lucide:house'
const shortDate = (iso: string) => parseServerTime(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })

const groups = computed(() => {
  const q = props.query.trim().toLowerCase()
  const byLease = new Map<string, PaymentRow[]>()
  for (const p of props.payments) byLease.set(p.leaseId, [...(byLease.get(p.leaseId) ?? []), p])
  const out = []
  for (const [id, all] of byLease) {
    const first = all[0]!
    const rows = all
      .filter((p) => yearOf(p) === year.value && (status.value === 'all' || p.status === status.value))
      .filter((p) => !q || `${titleOf(p)} ${PAYMENT_METHOD_LABEL[p.method] || p.method} ${p.name}`.toLowerCase().includes(q))
    if (!rows.length) continue
    const current = first.leaseStatus === 'active' || first.leaseStatus === 'leave_requested'
    const paid = formatPesoExact(all.filter((p) => p.status === 'paid').reduce((n, p) => n + p.amount, 0))
    const months = new Map<string, PaymentRow[]>()
    for (const p of rows.sort((a, b) => b.month.localeCompare(a.month) || b.createdAt.localeCompare(a.createdAt))) {
      months.set(p.month, [...(months.get(p.month) ?? []), p])
    }
    out.push({
      id,
      name: first.name,
      current,
      start: first.leaseStart,
      owed: props.owed[id] ?? null,
      sub: `${first.room} · ${current ? `since ${formatDate(first.leaseStart)}` : period(first.leaseStart, first.leaseEnd).replace(' — ', ' – ')} · ${paid} paid`,
      months: [...months].map(([month, r]) => ({ month, label: formatMonth(month).split(' ')[0]!, rows: r })),
    })
  }
  return out.sort((a, b) => Number(b.current) - Number(a.current) || b.start.localeCompare(a.start))
})

// A stay's group is open when it is the current one, unless the student closed
// it, and shut otherwise unless they opened it; a search opens everything it hits.
const flipped = ref<Record<string, boolean>>({})
const isOpen = (g: { id: string; current: boolean }) => !!props.query.trim() || (flipped.value[g.id] ? !g.current : g.current)
const toggle = (g: { id: string; current: boolean }) => (flipped.value = { ...flipped.value, [g.id]: !flipped.value[g.id] })
watch(
  () => props.expand,
  (id) => {
    const g = id ? groups.value.find((x) => x.id === id) : null
    if (g && !isOpen(g)) toggle(g)
  },
  { immediate: true },
)

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
  margin-top: -6px;
}
.pt-year {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pt-bar {
  display: flex;
  align-items: center;
  gap: 2px;
}
.pt-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
}
.pt-nav {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-text);
  cursor: pointer;
}
.pt-nav:first-child {
  margin-left: -8px;
}
.pt-nav:disabled {
  color: var(--m-border);
  cursor: default;
}
.pt-gap {
  flex: 1;
}
.pt-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  min-height: 32px;
  padding: 0 10px 0 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
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
.pt-groups {
  display: flex;
  flex-direction: column;
  margin: 0 -14px;
  border-top: 1px solid var(--m-border);
  border-bottom: 1px solid var(--m-border);
}
.pt-stay {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-height: 48px;
  padding: 6px 12px;
  border: 0;
  border-top: 8px solid var(--m-bg);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.pt-stay:first-child {
  border-top: 0;
}
.pt-stay-text {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.pt-stay-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pt-stay-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
}
.pt-current {
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 10.5px;
  font-weight: 800;
}
.pt-stay-sub {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.pt-settled {
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 10.5px;
  font-weight: 800;
}
.pt-settled--bad {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pt-chev {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.pt-month {
  padding: 8px 12px;
  border-top: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
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
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.pt-ico {
  display: grid;
  flex: 0 0 36px;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pt-text {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.pt-rtitle {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.pt-rsub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.pt-side {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.pt-amt {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pt-amt--void {
  color: var(--m-muted);
  text-decoration: line-through;
}
.pt-chip {
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 10.5px;
  font-weight: 700;
}
.pt-chip--bad {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
</style>
