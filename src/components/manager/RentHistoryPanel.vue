<template>
  <div class="rh">
    <p v-if="error" class="rh-error" role="alert">{{ error }}</p>
    <template v-else>
      <div class="rh-top">
        <PeriodBar :label="windowLabel" :can-prev="canPrev" :can-next="page > 0" @prev="page++" @next="page--">
          <PropertyPicker v-model="propertyId" :options="propertyOptions" />
        </PeriodBar>
        <!-- The key is drawn with the grid's own cells, so it reads the same as what it explains. -->
        <div class="rh-keyrow">
          <div class="rh-legend">
            <span v-for="k in LEGEND" :key="k"><i class="rh-key" :class="`cell--${k}`"><IconifyIcon v-if="CELL[k].icon" :icon="CELL[k].icon" width="12" /></i>{{ CELL[k].label }}</span>
          </div>
          <label class="rh-past">
            <span>Past<br />boarders</span>
            <q-toggle v-model="showPast" color="primary" dense />
          </label>
        </div>
      </div>

      <p v-if="!loading && !groups.length" class="rh-empty">{{ query.trim() ? 'No boarders or rooms match.' : 'No boarders yet. Rent shows up here once someone moves in.' }}</p>

      <section v-else-if="groups.length" class="rh-grid" aria-label="Rent by room, boarder and month">
        <div class="rh-row rh-head">
          <span>Boarder</span>
          <span v-for="(m, i) in months" :key="m.key" class="c" :class="{ 'c--now': i === 3 }">{{ m.short }}</span>
        </div>
        <template v-for="g in groups" :key="g.id">
          <button type="button" class="rh-prop" :aria-expanded="g.open" @click="toggle(g.id)">
            <span class="rh-prop-text">
              <span class="rh-prop-name">{{ g.name }}</span>
              <span class="rh-prop-stats">{{ g.stats }}</span>
            </span>
            <span v-if="g.unpaid" class="rh-flag">{{ g.unpaid }} unpaid</span>
            <IconifyIcon icon="lucide:chevron-down" width="18" class="rh-chev" :class="{ 'rh-chev--open': g.open }" />
          </button>
          <!-- Slides open/closed; the chevron turns with it (.rh-chev). -->
          <q-slide-transition>
          <div v-if="g.open" class="rh-body">
            <template v-for="room in g.rooms" :key="room.id">
              <div class="rh-room">
                <span class="rh-room-name">{{ room.label }}</span>
                <span class="rh-beds" aria-hidden="true"><i v-for="(on, b) in room.beds" :key="b" :class="{ on }" /></span>
                <span class="rh-room-note">{{ room.note }}</span>
              </div>
              <div v-for="r in room.rows" :key="r.lease.id" class="rh-row rh-person" :class="{ past: r.past }">
                <button type="button" class="rh-who" @click="open(r.lease.id)">
                  <CollectionAvatar :lease="r.lease" small />
                  <span class="rh-who-text">
                    <span class="rh-who-name">{{ r.lease.studentName }}</span>
                    <span class="rh-who-sub">{{ r.sub }}</span>
                  </span>
                </button>
                <button v-for="c in r.cells" :key="c.key" type="button" class="cell" :class="`cell--${c.state}`" :aria-label="c.aria" @click="open(r.lease.id)">
                  <IconifyIcon v-if="CELL[c.state].icon" :icon="CELL[c.state].icon" width="16" />
                </button>
              </div>
            </template>
          </div>
          </q-slide-transition>
          <!-- Always shown, open or closed: the property's takings at a glance. -->
          <div class="rh-row rh-foot">
            <span>Collected</span>
            <span v-for="(t, i) in g.collected" :key="i" class="c" :class="{ 'c--now': i === 3 }">{{ t }}</span>
          </div>
        </template>
      </section>

      <button type="button" class="rh-report" @click="reportOpen = true">
        <span class="rh-report-ico"><IconifyIcon icon="lucide:file-chart-column" width="20" /></span>
        <span class="rh-report-text">
          <span class="rh-report-title">Rent report</span>
          <span class="rh-report-sub">Jan – Dec timeline, print or save as PDF</span>
        </span>
        <IconifyIcon icon="lucide:chevron-right" width="16" />
      </button>
    </template>
    <RentReportSheet v-model="reportOpen" :leases="leases" :ledger="ledger" :properties="properties" :property-id="propertyId" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { fetchLandlordMoney, type MoneyLease, type MoneyRoom } from '@/api/landlordMoney'
import type { CollectionLedgerRow } from '@/utils/collections'
import { manilaToday } from '@/utils/payments'
import { rentCell } from '@/utils/rentGrid'
import { errorMessage } from '@/utils/errors'
import { formatPeso, formatPesoExact } from '@/utils/format'
import PeriodBar from '@/components/shared/PeriodBar.vue'
import PropertyPicker from '@/components/shared/PropertyPicker.vue'
import CollectionAvatar from '@/components/manager/CollectionAvatar.vue'
import RentReportSheet from '@/components/manager/RentReportSheet.vue'

// Rent history: four months of rent per boarder, by property and room, from the
// same ledger Monthly rent is built from. Loads on its own and again whenever
// `version` moves (the Tenants page bumps it on every refresh). `query`
// is the page's search box (boarder or room).
const props = defineProps<{ version: number; query: string }>()
const router = useRouter()

const loading = ref(false)
const error = ref('')
const leases = ref<MoneyLease[]>([])
const ledger = ref<CollectionLedgerRow[]>([])
const rooms = ref<MoneyRoom[]>([])
const propertyId = ref('all')
const page = ref(0)
// One property open at a time, none at first, so the list starts as a short overview.
const openId = ref<string | null>(null)
const reportOpen = ref(false)

const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
const CELL: Record<'paid' | 'confirm' | 'unpaid' | 'none', { icon: string; text: string; label: string }> = {
  paid: { icon: 'lucide:check', text: 'paid', label: 'Paid' },
  confirm: { icon: 'lucide:clock', text: 'to confirm', label: 'To confirm' },
  unpaid: { icon: 'lucide:circle-alert', text: 'unpaid', label: 'Unpaid' },
  none: { icon: '', text: 'not staying', label: 'Not staying' },
}
type CellState = keyof typeof CELL
const LEGEND: CellState[] = ['paid', 'confirm', 'unpaid', 'none']
// Off by default: the grid is about who is here now; past boarders are one tap away.
const showPast = ref(false)

const today = computed(() => manilaToday())
const addMonths = (ym: string, n: number) => {
  const d = new Date(Number(ym.slice(0, 4)), Number(ym.slice(5, 7)) - 1 + n, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}
const months = computed(() => {
  const end = addMonths(today.value.slice(0, 7), -4 * page.value)
  return [-3, -2, -1, 0].map((k) => {
    const key = addMonths(end, k)
    const name = MONTH_NAMES[Number(key.slice(5, 7)) - 1]!
    return { key, name, short: name.slice(0, 3), year: key.slice(0, 4) }
  })
})
const windowLabel = computed(() => {
  const [a, , , d] = months.value as [(typeof months.value)[0], unknown, unknown, (typeof months.value)[0]]
  return a.year === d.year ? `${a.short} – ${d.short} ${d.year}` : `${a.short} ${a.year} – ${d.short} ${d.year}`
})
const earliest = computed(() => {
  const ms = ledger.value.filter((r) => r.kind === 'rent' && r.month).map((r) => r.month!.slice(0, 7))
  return ms.length ? ms.reduce((a, b) => (a < b ? a : b)) : today.value.slice(0, 7)
})
const canPrev = computed(() => months.value[0]!.key > earliest.value)

const properties = computed(() => {
  const seen = new Map<string, string>()
  for (const l of leases.value) if (l.accommodationId) seen.set(l.accommodationId, l.accommodationName)
  for (const r of rooms.value) seen.set(r.accommodationId, r.accommodationName)
  return [...seen.entries()].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name))
})
const propertyOptions = computed(() => [{ value: 'all', label: 'All properties' }, ...properties.value.map((p) => ({ value: p.id, label: p.name }))])

const compact = (n: number) => (n >= 1000 ? `₱${(n / 1000).toFixed(1).replace(/\.0$/, '')}k` : formatPeso(n))
const isCurrent = (l: MoneyLease) => l.status === 'active' || l.status === 'leave_requested'

const rowsByLease = computed(() => {
  const m = new Map<string, CollectionLedgerRow[]>()
  for (const r of ledger.value) if (r.kind === 'rent') m.set(r.leaseId, [...(m.get(r.leaseId) ?? []), r])
  return m
})

function personRow(l: MoneyLease) {
  const rows = rowsByLease.value.get(l.id) ?? []
  const cells = months.value.map((m) => {
    const state = rentCell(rows, m.key, today.value)
    const shown: CellState = state === 'upcoming' ? 'none' : state
    return { key: m.key, state: shown, aria: `${l.studentName}, ${m.name}, ${CELL[shown].text}` }
  })
  const since = new Date(`${l.startDate}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })
  const left = new Date(`${(l.leaveDate || l.endDate) ?? ''}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })
  return {
    lease: l,
    cells,
    past: !isCurrent(l),
    sub: isCurrent(l) ? `Since ${since}` : `Moved out ${left}`,
  }
}

const groups = computed(() => {
  const q = props.query.trim().toLowerCase()
  const out: {
    id: string; name: string; stats: string; unpaid: number; open: boolean; collected: string[]
    rooms: { id: string; label: string; beds: boolean[]; note: string; rows: ReturnType<typeof personRow>[] }[]
  }[] = []
  const visible = properties.value.filter((p) => propertyId.value === 'all' || p.id === propertyId.value)
  const nowKey = months.value[3]!.key
  visible.forEach((p) => {
    const propRooms = rooms.value.filter((r) => r.accommodationId === p.id).sort((a, b) => a.label.localeCompare(b.label, 'en', { numeric: true }))
    const propLeases = leases.value.filter((l) => l.accommodationId === p.id)
    const shown = propRooms.map((room) => {
      const here = propLeases.filter((l) => l.roomId === room.id)
      const rows = here
        .map(personRow)
        // A past boarder only shows in the months they were there.
        .filter((r) => !r.past || (showPast.value && r.cells.some((c) => c.state !== 'none')))
        .filter((r) => !q || r.lease.studentName.toLowerCase().includes(q) || room.label.toLowerCase().includes(q))
        .sort((a, b) => Number(a.past) - Number(b.past) || a.lease.studentName.localeCompare(b.lease.studentName))
      const occupied = here.filter(isCurrent).length
      const open = Math.max(0, room.capacity - occupied)
      return {
        id: room.id,
        label: room.label,
        beds: Array.from({ length: room.capacity }, (_, i) => i < occupied),
        note: `${formatPeso(room.monthlyRent)}/mo${open ? ` · ${open} open` : ''}`,
        rows,
      }
    }).filter((r) => !q || r.rows.length)
    if (q && !shown.length) return
    const current = propLeases.filter(isCurrent)
    const monthRows = propLeases.flatMap((l) => (rowsByLease.value.get(l.id) ?? []).filter((r) => (r.month ?? '').startsWith(nowKey)))
    const collected = monthRows.reduce((n, r) => n + r.confirmed, 0)
    const expected = monthRows.reduce((n, r) => n + r.due, 0)
    const unpaid = shown.flatMap((r) => r.rows).filter((r) => r.cells.some((c) => c.state === 'unpaid')).length
    out.push({
      id: p.id,
      name: p.name,
      stats: `${propRooms.length} room${propRooms.length === 1 ? '' : 's'} · ${current.length} boarder${current.length === 1 ? '' : 's'} · ${formatPesoExact(collected)} of ${formatPesoExact(expected)} in ${months.value[3]!.short}`,
      unpaid,
      // A search opens everything it matched.
      open: !!q || openId.value === p.id,
      collected: months.value.map((m) => compact(propLeases.reduce(
        (n, l) => n + (rowsByLease.value.get(l.id) ?? []).filter((r) => (r.month ?? '').startsWith(m.key)).reduce((k, r) => k + r.confirmed, 0),
        0,
      ))),
      rooms: shown,
    })
  })
  return out
})

function toggle(id: string) {
  openId.value = openId.value === id ? null : id
}
function open(leaseId: string) {
  void router.push(`/manager/tenant/${leaseId}`)
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const m = await fetchLandlordMoney()
    leases.value = m.leases
    ledger.value = m.ledger
    rooms.value = m.rooms
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}
watch(() => props.version, () => void load(), { immediate: true })
watch(propertyId, () => { page.value = 0 })
</script>

<style scoped>
.rh { display: flex; flex-direction: column; gap: 14px; padding-bottom: 8px; }
.rh-error, .rh-empty { margin: 0 12px; color: var(--m-muted); font-size: 13px; }
.rh-error { color: var(--m-danger); }
.rh-top { display: flex; flex-direction: column; gap: 10px; margin: 0 12px; }
.rh-keyrow { display: flex; align-items: center; gap: 12px; }
/* Two by two, so the toggle fits beside it on a phone. */
.rh-legend { display: grid; flex: 1; min-width: 0; grid-template-columns: repeat(2, max-content); gap: 6px 14px; color: var(--m-text); font-size: 12px; font-weight: 600; }
.rh-legend span { display: inline-flex; align-items: center; gap: 6px; white-space: nowrap; }
/* Not `.lg`: that is Quasar's large-screen-only visibility class and hid every swatch. */
.rh-key { display: grid; width: 20px; height: 20px; box-sizing: border-box; place-items: center; border-radius: 6px; }
.rh-past { display: flex; flex: 0 0 auto; align-items: center; gap: 8px; padding-left: 12px; border-left: 1px solid var(--m-border); color: var(--m-ink); font-size: 12px; font-weight: 600; line-height: 1.2; text-align: right; cursor: pointer; }
.rh-grid { display: flex; flex-direction: column; border-top: 1px solid var(--m-border); border-bottom: 1px solid var(--m-border); background: var(--m-surface); }
.rh-row { display: grid; grid-template-columns: minmax(0, 1fr) repeat(4, 46px); align-items: center; padding: 6px 12px; }
.rh-head { padding: 8px 12px; color: var(--m-muted); font-size: 11.5px; font-weight: 800; letter-spacing: 0.02em; text-transform: uppercase; }
.c { text-align: center; }
.c--now { color: var(--m-primary-dark); }
.rh-prop { display: flex; align-items: center; gap: 8px; width: 100%; min-height: 48px; padding: 6px 12px; border: 0; border-top: 8px solid var(--m-bg); background: var(--m-surface); font: inherit; text-align: left; cursor: pointer; }
.rh-prop-text { display: flex; flex: 1; min-width: 0; flex-direction: column; }
.rh-prop-name { color: var(--m-ink); font-family: var(--m-font-display); font-size: 15px; font-weight: 700; }
.rh-prop-stats { color: var(--m-muted); font-size: 12px; font-weight: 600; }
.rh-flag { padding: 2px 8px; border-radius: 999px; background: var(--m-danger-soft); color: var(--m-danger); font-size: 10.5px; font-weight: 800; }
.rh-chev { color: var(--m-muted); transition: transform 0.3s; }
.rh-body { display: flex; flex-direction: column; }
.rh-chev--open { transform: rotate(180deg); }
.rh-room { display: flex; align-items: center; gap: 10px; padding: 8px 12px; border-top: 1px solid var(--m-border); background: var(--m-bg); }
.rh-room-name { color: var(--m-ink); font-size: 12.5px; font-weight: 800; letter-spacing: 0.02em; text-transform: uppercase; }
.rh-beds { display: flex; gap: 3px; }
.rh-beds i { width: 8px; height: 8px; box-sizing: border-box; border: 1.5px solid var(--m-muted); border-radius: 50%; opacity: 0.55; }
.rh-beds i.on { border-color: var(--m-primary); background: var(--m-primary); opacity: 1; }
.rh-room-note { margin-left: auto; color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.rh-person { border-top: 1px solid var(--m-border); }
.rh-who { display: flex; align-items: center; gap: 10px; min-width: 0; min-height: 44px; padding: 0; border: 0; background: transparent; font: inherit; text-align: left; cursor: pointer; }
.rh-who-text { display: flex; min-width: 0; flex-direction: column; }
.rh-who-name { overflow: hidden; color: var(--m-ink); font-size: 13.5px; font-weight: 700; text-overflow: ellipsis; white-space: nowrap; }
.rh-who-sub { color: var(--m-muted); font-size: 11.5px; }
.past .rh-who-name { color: var(--m-muted); }
.past :deep(.ca) { background: var(--m-muted); color: #fff; filter: grayscale(1); }
.cell { display: grid; width: 38px; height: 38px; box-sizing: border-box; place-items: center; justify-self: center; border: 0; border-radius: 10px; background: transparent; cursor: pointer; }
.cell--paid { background: var(--m-success-soft); color: var(--m-success); }
.cell--confirm { background: var(--m-info-soft); color: var(--m-info); }
.cell--unpaid { background: var(--m-danger-soft); color: var(--m-danger); }
.cell--none { border: 1px dashed var(--m-border); color: var(--m-muted); }
.rh-foot { padding: 8px 12px; border-top: 1px solid var(--m-border); background: var(--m-bg); font-size: 11.5px; font-weight: 700; }
.rh-foot span:first-child { color: var(--m-muted); }
.rh-foot .c { color: var(--m-ink); }
.rh-foot .c--now { color: var(--m-primary-dark); }
.rh-report { display: flex; align-items: center; gap: 12px; margin: 0 12px; padding: 12px; border: 1px solid var(--m-border); border-radius: 16px; background: var(--m-surface); color: var(--m-muted); font: inherit; text-align: left; cursor: pointer; }
.rh-report-ico { display: grid; width: 40px; height: 40px; flex: 0 0 40px; place-items: center; border-radius: 12px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.rh-report-text { display: flex; min-width: 0; flex: 1; flex-direction: column; }
.rh-report-title { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.rh-report-sub { font-size: 12px; }
</style>
