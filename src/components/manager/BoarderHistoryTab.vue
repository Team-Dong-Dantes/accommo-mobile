<template>
  <div class="bh">
    <div class="bh-top">
      <PeriodBar :label="String(year)" :can-prev="year > minYear" :can-next="year < maxYear" @prev="picked = year - 1" @next="picked = year + 1">
        <PropertyPicker v-model="property" :options="propertyOptions" />
      </PeriodBar>
      <div class="bh-stats">
        <div><span>Moved out</span><b>{{ scoped.length }}</b></div>
        <div><span>Avg. stay</span><b>{{ avgStay }}</b></div>
        <div><span>Left owing</span><b :class="{ 'bh-bad': owingCount }">{{ owingCount }}</b></div>
      </div>
    </div>

    <section v-if="groups.length" class="bh-list">
      <template v-for="(g, gi) in groups" :key="g.id">
        <button type="button" class="bh-prop" :class="{ 'bh-prop--next': gi > 0 }" :aria-expanded="isOpen(g.id)" @click="toggle(g.id)">
          <span class="bh-prop-text">
            <span class="bh-prop-name">{{ g.name }}</span>
            <span class="bh-prop-sub">{{ g.count }} past boarder{{ g.count === 1 ? '' : 's' }}</span>
          </span>
          <span v-if="g.owing" class="bh-owing-chip">{{ g.owing }} owing</span>
          <IconifyIcon :icon="isOpen(g.id) ? 'lucide:chevron-up' : 'lucide:chevron-down'" width="18" class="bh-chev" />
        </button>
        <template v-if="isOpen(g.id)">
          <template v-for="room in g.rooms" :key="room.id">
            <div class="bh-room">
              <span class="bh-room-name">{{ room.label }}</span>
              <span v-if="room.now" class="bh-room-note">Now: {{ room.now }}</span>
            </div>
            <button v-for="r in room.rows" :key="r.lease.id" type="button" class="bh-row" @click="openLease(r.lease)">
              <CollectionAvatar :lease="r.lease" class="bh-avatar" />
              <span class="bh-body">
                <span class="bh-name">{{ r.lease.studentName }}</span>
                <span class="bh-sub">{{ periodText(r.lease.startDate, r.lease.endDate) }} · {{ monthsText(r.months) }}</span>
                <span class="bh-pay" :class="{ 'bh-pay--owing': r.owed > 0 }">{{ r.owed > 0 ? `${formatPeso(r.owed)} unpaid` : 'All paid' }}</span>
              </span>
              <span v-if="r.review" class="bh-rated">
                <IconifyIcon icon="lucide:star" width="13" class="bh-star" />{{ r.review.rating }}
              </span>
              <span v-else class="bh-rate">Rate</span>
              <IconifyIcon icon="lucide:chevron-right" width="15" class="bh-chev" />
            </button>
          </template>
        </template>
      </template>
    </section>
    <EmptyState v-else-if="!past.length" variant="compact" icon="lucide:history" title="No past boarders yet" message="Boarders who move out will be listed here." />
    <EmptyState v-else variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different year, property or search." />

    <PastBoarderSheet v-model="sheetOpen" :lease="sheetLease" :rows="sheetRows" :review="sheetLease ? (reviews[sheetLease.id] ?? null) : null" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import PeriodBar from '@/components/shared/PeriodBar.vue'
import PropertyPicker from '@/components/shared/PropertyPicker.vue'
import CollectionAvatar from '@/components/manager/CollectionAvatar.vue'
import PastBoarderSheet from '@/components/manager/PastBoarderSheet.vue'
import { formatPeso } from '@/utils/format'
import { stayRent } from '@/utils/rentGrid'
import { manilaToday, type LedgerRow } from '@/utils/payments'
import type { LandlordMoney, MoneyLease } from '@/api/landlordMoney'
import { stayMonths, monthsText, periodText } from './managerHistory'

// BH-Landlord: everyone who has moved out, by property and room, for one year
// (the year they left). "Left owing" and each row's pay line are the rent still
// unpaid on the stay (stayRent); bills and deposits are not counted here.
const props = defineProps<{
  money: LandlordMoney
  /** The landlord/landlady's own tenant reviews, by lease id. */
  reviews: Record<string, { rating: number; comment: string }>
  query: string
}>()

const today = manilaToday()
const past = computed(() => props.money.leases.filter((l) => l.status === 'ended' || l.status === 'terminated'))
const yearOf = (l: MoneyLease) => Number((l.endDate || l.startDate).slice(0, 4))
const maxYear = computed(() => Math.max(Number(today.slice(0, 4)), ...past.value.map(yearOf)))
const minYear = computed(() => Math.min(maxYear.value, ...past.value.map(yearOf)))
// Opens on the latest year somebody left in, not an empty current year.
const latestLeft = computed(() => (past.value.length ? Math.max(...past.value.map(yearOf)) : maxYear.value))
const picked = ref<number | null>(null)
const year = computed(() => picked.value ?? latestLeft.value)

const property = ref('all')
const propertyOptions = computed(() => [
  { value: 'all', label: 'All properties' },
  ...[...new Map(past.value.map((l) => [l.accommodationId, l.accommodationName])).entries()].map(([value, label]) => ({ value, label })),
])

const rowsByLease = computed(() => {
  const m = new Map<string, LedgerRow[]>()
  for (const r of props.money.ledger) {
    const list = m.get(r.leaseId)
    if (list) list.push(r)
    else m.set(r.leaseId, [r])
  }
  return m
})

const scoped = computed(() => {
  const q = props.query.trim().toLowerCase()
  return past.value.filter(
    (l) =>
      yearOf(l) === year.value &&
      (property.value === 'all' || l.accommodationId === property.value) &&
      (!q || `${l.studentName} ${l.roomLabel}`.toLowerCase().includes(q)),
  )
})

const entries = computed(() =>
  scoped.value.map((lease) => ({
    lease,
    months: stayMonths(lease.startDate, lease.endDate),
    owed: stayRent(rowsByLease.value.get(lease.id) ?? [], today).unpaidAmount,
    review: props.reviews[lease.id] ?? null,
  })),
)
const owingCount = computed(() => entries.value.filter((e) => e.owed > 0).length)
const avgStay = computed(() =>
  entries.value.length ? `${Math.round(entries.value.reduce((n, e) => n + e.months, 0) / entries.value.length)} mo` : '—',
)

const groups = computed(() => {
  const byProp = new Map<string, { id: string; name: string; rooms: Map<string, { id: string; label: string; now: string; rows: typeof entries.value }>; count: number; owing: number }>()
  for (const e of entries.value) {
    const l = e.lease
    let g = byProp.get(l.accommodationId)
    if (!g) byProp.set(l.accommodationId, (g = { id: l.accommodationId, name: l.accommodationName, rooms: new Map(), count: 0, owing: 0 }))
    let room = g.rooms.get(l.roomId)
    if (!room) {
      const now = props.money.leases
        .filter((x) => x.roomId === l.roomId && (x.status === 'active' || x.status === 'leave_requested'))
        .map((x) => x.studentName)
        .join(', ')
      g.rooms.set(l.roomId, (room = { id: l.roomId, label: l.roomLabel, now, rows: [] }))
    }
    room.rows.push(e)
    g.count++
    if (e.owed > 0) g.owing++
  }
  return [...byProp.values()]
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((g) => ({
      ...g,
      rooms: [...g.rooms.values()]
        .sort((a, b) => a.label.localeCompare(b.label, undefined, { numeric: true }))
        .map((r) => ({ ...r, rows: [...r.rows].sort((a, b) => b.lease.endDate.localeCompare(a.lease.endDate)) })),
    }))
})

// First property open, the rest folded; a search opens everything it matched.
const closed = ref<Set<string>>(new Set())
const touched = ref<Set<string>>(new Set())
function isOpen(id: string) {
  if (props.query.trim()) return true
  if (touched.value.has(id)) return !closed.value.has(id)
  return groups.value[0]?.id === id
}
function toggle(id: string) {
  const open = isOpen(id)
  touched.value = new Set(touched.value).add(id)
  const next = new Set(closed.value)
  if (open) next.add(id)
  else next.delete(id)
  closed.value = next
}
watch([year, property], () => {
  touched.value = new Set()
  closed.value = new Set()
})

const sheetOpen = ref(false)
const sheetLease = ref<MoneyLease | null>(null)
const sheetRows = computed(() => (sheetLease.value ? (rowsByLease.value.get(sheetLease.value.id) ?? []) : []))
function openLease(l: MoneyLease) {
  sheetLease.value = l
  sheetOpen.value = true
}
</script>

<style scoped>
.bh {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.bh-top {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.bh-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: 12px;
}
.bh-stats > div {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 10px 12px;
}
.bh-stats > div + div {
  border-left: 1px solid var(--m-border);
}
.bh-stats span {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.bh-stats b {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
}
.bh-stats b.bh-bad {
  color: var(--m-danger);
}
.bh-list {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-left: 0;
  border-right: 0;
  margin: 0 -14px;
}
.bh-prop {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-height: 48px;
  padding: 6px 12px;
  border: 0;
  background: var(--m-surface);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.bh-prop--next {
  border-top: 8px solid var(--m-bg);
}
.bh-prop-text {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.bh-prop-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
}
.bh-prop-sub {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.bh-owing-chip {
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-danger-soft);
  color: var(--m-danger);
  font-size: 10.5px;
  font-weight: 800;
}
.bh-chev {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.bh-room {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border-top: 1px solid var(--m-border);
  background: var(--m-bg);
}
.bh-room-name {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.bh-room-note {
  margin-left: auto;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.bh-row {
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
.bh-avatar {
  width: 36px;
  height: 36px;
  font-size: 12px;
}
.bh-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.bh-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.bh-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.bh-pay {
  color: var(--m-success);
  font-size: 11.5px;
  font-weight: 600;
}
.bh-pay--owing {
  color: var(--m-danger);
}
.bh-rated {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
}
.bh-star {
  color: #f59e0b;
}
.bh-rate {
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10.5px;
  font-weight: 700;
}
</style>
