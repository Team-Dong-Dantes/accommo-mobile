<template>
  <!-- Tenants → Monthly rent: a month stepper and property pill, the month's
       hero bar, four tiles that choose the list below, then the rows. The rest
       (tasks, past-stay debts, payout) is the app's own parts, unchanged. -->
  <div class="cp">
    <!-- The loaded layout's shape: the month hero, then one flat section of rows. -->
    <template v-if="loading && !col">
      <div class="cp-inset"><q-skeleton type="rect" height="120px" class="cp-sk" /></div>
      <section class="cp-block">
        <div class="room-head"><q-skeleton type="text" width="90px" height="14px" /></div>
        <div v-for="n in 3" :key="n" class="lease-row">
          <span class="lease-main cp-static">
            <q-skeleton type="circle" size="36px" />
            <span class="lease-body">
              <q-skeleton type="text" width="55%" height="15px" />
              <q-skeleton type="text" width="35%" height="12px" />
            </span>
          </span>
        </div>
      </section>
    </template>
    <ErrorCard v-else-if="error" title="Couldn't load payments" :detail="error" :retry="load" inset />

    <EmptyState
      v-else-if="col && !leases.length"
      variant="compact"
      icon="lucide:receipt"
      title="No payments to track yet"
      message="Once you accept a boarder, what they owe and what they've paid shows up here."
    />

    <template v-else-if="col">
      <div class="cp-inset">
        <PeriodBar :label="formatMonth(viewMonth)" :can-prev="viewMonth > earliestMonth" :can-next="viewMonth < thisMonth" @prev="step(-1)" @next="step(1)">
          <PropertyPicker v-model="propertyId" :options="propertyOptions" />
        </PeriodBar>

        <div class="cp-hero">
          <span class="cp-big">{{ formatPeso(col.collected) }}</span>
          <span class="cp-of">of {{ formatPeso(expected) }} collected</span>
        </div>
        <StackBar
          :segments="[
            { value: col.collected, tone: 'success' },
            { value: col.toConfirm, tone: 'info' },
            { value: col.overdue, tone: 'danger' },
            { value: col.toCome, tone: 'border' },
          ]"
          :label="`${formatPeso(col.collected)} collected, ${formatPeso(col.toConfirm)} to confirm, ${formatPeso(col.overdue)} overdue, ${formatPeso(col.toCome)} still to come`"
        />

        <div class="cp-tiles" role="radiogroup" aria-label="Show">
          <button
            v-for="t in tiles"
            :key="t.key"
            type="button"
            role="radio"
            class="cp-tile"
            :class="{ 'cp-tile--on': shownTile === t.key }"
            :aria-checked="shownTile === t.key"
            @click="picked = t.key"
          >
            <span class="cp-tile-top">
              <i class="cp-dot" :style="{ background: `var(--m-${t.count ? t.tone : 'border'})` }" />{{ t.label }}
              <span class="cp-tile-n">{{ t.count }}</span>
            </span>
            <span class="cp-tile-amt" :style="{ color: t.count ? `var(--m-${t.tone})` : 'var(--m-muted)' }">{{ formatPeso(t.amount) }}</span>
          </button>
        </div>
      </div>

      <!-- Set-up tasks (e.g. "Add where boarders send money") sit right under the tiles. -->
      <DashTodoList v-if="tasks.length" class="cp-inset cp-todo" title="" :tasks="tasks" :done-count="0" @go="onTask" />

      <!-- Waiting on the landlord/landlady: one card per transfer. -->
      <div v-if="shownTile === 'confirm'" class="cp-inset cp-cards">
        <div class="cp-list-head"><b>To confirm</b><span>Boarder says they paid</span></div>
        <article v-for="c in shown.confirm" :key="c.key" class="cp-card">
          <div class="cp-card-top">
            <CollectionAvatar :lease="c.lease" />
            <span class="lease-body">
              <span class="lease-name">{{ c.lease.studentName }}</span>
              <span class="lease-sub">{{ c.what }} · {{ PAYMENT_METHOD_LABEL[c.method] ?? c.method }} · {{ c.lease.roomLabel }}</span>
            </span>
            <span class="cp-side">
              <span class="cp-amt cp-amt--lg">{{ formatPeso(c.amount) }}</span>
              <span class="lease-chip" :class="c.waitDays >= 3 ? 'lease-chip--orange' : 'lease-chip--blue'">{{ waitLabel(c.waitDays) }}</span>
            </span>
          </div>
          <button type="button" class="cp-view" @click="review(c.paymentId)">
            <IconifyIcon icon="lucide:eye" width="16" />
            View payment
          </button>
        </article>
        <p v-if="!shown.confirm.length" class="cp-none">{{ nothingLine }}</p>
      </div>

      <section v-else-if="shownTile === 'late'" class="cp-block">
        <div class="room-head">
          <span class="room-name">Overdue</span>
          <span class="cp-count cp-count--late">{{ shown.late.length }}</span>
        </div>
        <div v-for="o in shown.late" :key="o.lease.id" class="lease-row">
          <div class="lease-line">
            <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${o.lease.id}`)">
              <CollectionAvatar :lease="o.lease" />
              <span class="lease-body">
                <span class="lease-name">{{ o.lease.studentName }}</span>
                <span class="lease-sub cp-late">{{ o.what }} · {{ o.lease.roomLabel }}</span>
              </span>
              <span v-if="o.tag === 'leaving'" class="lease-chip lease-chip--orange">{{ leavingLabel(o.lease) }}</span>
              <span class="cp-amt cp-late">{{ formatPeso(o.amount) }}</span>
            </button>
          </div>
          <div class="lease-actions">
            <button type="button" class="lease-act lease-act--ghost" @click="router.push(`/manager/messages?to=${o.lease.studentId}`)">Remind</button>
            <button type="button" class="lease-act" @click="logFor(o.lease)">Log payment</button>
          </div>
        </div>
        <p v-if="!shown.late.length" class="cp-none">{{ nothingLine }}</p>
      </section>

      <section v-else-if="shownTile === 'coming'" class="cp-block">
        <div class="room-head">
          <span class="room-name">Still to come</span>
          <span class="cp-count">{{ shown.coming.length }}</span>
        </div>
        <div v-for="o in shown.coming" :key="o.lease.id" class="lease-row">
          <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${o.lease.id}`)">
            <CollectionAvatar :lease="o.lease" />
            <span class="lease-body">
              <span class="lease-name">{{ o.lease.studentName }}</span>
              <span class="lease-sub">{{ o.what }} · {{ o.lease.roomLabel }}</span>
            </span>
            <span v-if="o.tag === 'new'" class="lease-chip lease-chip--green">New</span>
            <span v-else-if="o.tag === 'leaving'" class="lease-chip lease-chip--orange">{{ leavingLabel(o.lease) }}</span>
            <span class="cp-amt">{{ formatPeso(o.amount) }}</span>
          </button>
        </div>
        <p v-if="!shown.coming.length" class="cp-none">{{ nothingLine }}</p>
      </section>

      <section v-else class="cp-block">
        <div class="room-head">
          <span class="room-name">Paid</span>
          <span class="cp-count cp-count--ok">{{ shown.paid.length }}</span>
          <button type="button" class="room-link" @click="router.push('/manager/profile/history?tab=payments')">All records</button>
        </div>
        <div v-for="l in shown.paid" :key="l.id" class="lease-row">
          <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${l.id}`)">
            <CollectionAvatar :lease="l" />
            <span class="lease-body">
              <span class="lease-name">{{ l.studentName }}</span>
              <span class="lease-sub">{{ allIn ? `Paid for ${formatMonth(col.month).split(' ')[0]}` : 'Paid up' }} · {{ l.roomLabel }}</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="cp-chev" />
          </button>
        </div>
        <p v-if="!shown.paid.length" class="cp-none">{{ nothingLine }}</p>
      </section>


      <section v-if="shown.past.length" class="cp-block">
        <div class="room-head">
          <span class="room-name">From past stays</span>
          <span class="cp-count">{{ shown.past.length }}</span>
        </div>
        <div v-for="o in shown.past" :key="o.lease.id" class="lease-row">
          <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${o.lease.id}`)">
            <CollectionAvatar :lease="o.lease" />
            <span class="lease-body">
              <span class="lease-name">{{ o.lease.studentName }}</span>
              <span class="lease-sub">Moved out · {{ o.what }}</span>
            </span>
            <span class="cp-amt">{{ formatPeso(o.amount) }}</span>
          </button>
        </div>
      </section>

      <section v-if="payout" class="cp-block">
        <div class="room-head">
          <span class="room-name">Where boarders pay</span>
          <button type="button" class="room-link" @click="payoutOpen = true">Edit</button>
        </div>
        <div class="lease-row">
          <div class="lease-main cp-static">
            <span class="step-icon"><IconifyIcon icon="lucide:smartphone" width="15" /></span>
            <span class="lease-body">
              <span class="lease-name">{{ payoutWays }}</span>
              <span class="lease-sub">{{ payoutLine }}</span>
            </span>
          </div>
        </div>
      </section>
    </template>

    <PaymentReviewSheet v-model="reviewOpen" :payment-id="reviewId" @changed="changed" />
    <LogPaymentSheet
      v-model="logOpen"
      :lease-id="logLease?.id ?? ''"
      :start-date="logLease?.startDate"
      :subtitle="logLease ? `From ${logLease.studentName} · ${logLease.roomLabel}` : ''"
      @submitted="changed"
    />
    <PostBillsSheet v-model="billsOpen" @posted="changed" />
    <PayoutDialog v-model="payoutOpen" @update:model-value="(v) => !v && loadPayout()" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { fetchLandlordMoney } from '@/api/landlordMoney'
import { errorMessage } from '@/utils/errors'
import { formatMonth, formatPeso, PAYMENT_METHOD_LABEL } from '@/utils/format'
import { manilaToday } from '@/utils/payments'
import { UTILITIES, type UtilityKey } from '@/utils/listings'
import { monthCollections, type Collections, type CollectionLease, type CollectionLedgerRow, type CollectionPayment } from '@/utils/collections'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import PeriodBar from '@/components/shared/PeriodBar.vue'
import PropertyPicker from '@/components/shared/PropertyPicker.vue'
import StackBar from '@/components/shared/StackBar.vue'
import DashTodoList from '@/components/shared/DashTodoList.vue'
import type { Task } from '@/components/shared/dashboard'
import CollectionAvatar from '@/components/manager/CollectionAvatar.vue'
import PaymentReviewSheet from '@/components/manager/PaymentReviewSheet.vue'
import LogPaymentSheet from '@/components/manager/LogPaymentSheet.vue'
import PostBillsSheet from '@/components/manager/PostBillsSheet.vue'
import PayoutDialog from '@/components/manager/PayoutDialog.vue'

// Loads on its own, and again whenever `version` moves (the Tenants page bumps
// it on every refresh), so the page above it doesn't carry any payment state.
// `query` is the page's search box: it narrows the rows, not the totals.
const props = defineProps<{ version: number; query: string }>()
const emit = defineEmits<{ changed: []; count: [n: number] }>()
const router = useRouter()

const loading = ref(false)
const error = ref('')
const leases = ref<CollectionLease[]>([])
const ledger = ref<CollectionLedgerRow[]>([])
const payments = ref<CollectionPayment[]>([])
const billUtility = ref<Record<string, UtilityKey>>({})
const billed = ref(new Set<string>())
const propertyId = ref('all')

const today = computed(() => manilaToday())
const thisMonth = computed(() => `${today.value.slice(0, 7)}-01`)
// The month on screen; null until the arrows move it, so it follows the date.
const stepped = ref<string | null>(null)
const viewMonth = computed(() => stepped.value ?? thisMonth.value)
// Back as far as the first rent anyone was ever billed.
const earliestMonth = computed(() => {
  const first = ledger.value.map((r) => (r.dueDate ?? '').slice(0, 7)).filter(Boolean).sort()[0]
  return first && `${first}-01` < thisMonth.value ? `${first}-01` : thisMonth.value
})
function step(by: number) {
  const d = new Date(`${viewMonth.value}T00:00:00`)
  d.setMonth(d.getMonth() + by)
  const next = `${d.toLocaleDateString('en-CA').slice(0, 7)}-01`
  stepped.value = next >= thisMonth.value ? null : next < earliestMonth.value ? earliestMonth.value : next
  picked.value = null
}

const properties = computed(() => {
  const seen = new Map<string, string>()
  for (const l of leases.value) if (l.accommodationId) seen.set(l.accommodationId, l.accommodationName)
  return [...seen.entries()].map(([id, name]) => ({ id, name }))
})
const propertyOptions = computed(() => [{ value: 'all', label: 'All properties' }, ...properties.value.map((p) => ({ value: p.id, label: p.name }))])

function collectionsFor(id: string, month: string = viewMonth.value) {
  const ls = id === 'all' ? leases.value : leases.value.filter((l) => l.accommodationId === id)
  const ids = new Set(ls.map((l) => l.id))
  return monthCollections(ls, ledger.value.filter((r) => ids.has(r.leaseId)), payments.value.filter((p) => ids.has(p.leaseId)), month, today.value, billUtility.value, billed.value)
}
const col = computed(() => (leases.value.length || !loading.value ? collectionsFor(propertyId.value) : null))
// Today's month across every property: the tab badge and the bills nag.
const live = computed(() => (leases.value.length ? collectionsFor('all', thisMonth.value) : null))
const expected = computed(() => (col.value ? col.value.collected + col.value.toConfirm + col.value.overdue + col.value.toCome : 0))
const allIn = computed(() => !!col.value && expected.value > 0 && col.value.toConfirm + col.value.overdue + col.value.toCome < 0.01)

// The four tiles are radios: the one picked chooses the list. With no pick it
// opens on what needs doing first.
type Tile = 'confirm' | 'late' | 'paid' | 'coming'
const picked = ref<Tile | null>(null)
const tiles = computed(() => {
  const c = col.value
  if (!c) return []
  return [
    { key: 'confirm' as Tile, label: 'To confirm', count: c.confirm.length, amount: c.toConfirm, tone: 'info' },
    { key: 'late' as Tile, label: 'Overdue', count: c.late.length, amount: c.overdue, tone: 'danger' },
    { key: 'paid' as Tile, label: 'Paid', count: c.paid.length, amount: c.collected, tone: 'success' },
    { key: 'coming' as Tile, label: 'Still to come', count: c.coming.length, amount: c.toCome, tone: 'muted' },
  ]
})
const shownTile = computed<Tile>(() => picked.value ?? tiles.value.find((t) => t.key !== 'paid' && t.count)?.key ?? 'paid')
const nothingLine = computed(() => ({ confirm: 'Nothing waiting on you.', late: 'Nobody is late.', coming: 'Nothing else due this month.', paid: 'Nobody has paid yet.' })[shownTile.value])

// The search box narrows the rows, never the hero or tiles above them.
const shown = computed<Collections>(() => {
  const c = col.value as Collections
  const q = props.query.trim().toLowerCase()
  if (!q) return c
  const hit = (l: CollectionLease) => [l.studentName, l.roomLabel, l.accommodationName].some((t) => t.toLowerCase().includes(q))
  return { ...c, confirm: c.confirm.filter((x) => hit(x.lease)), late: c.late.filter((x) => hit(x.lease)), coming: c.coming.filter((x) => hit(x.lease)), paid: c.paid.filter(hit), past: c.past.filter((x) => hit(x.lease)) }
})

// Things to set up or do, as rows of the dashboard's "Needs attention" list.
const tasks = computed<Task[]>(() => {
  const out: Task[] = []
  if (payoutLoaded.value && !payout.value) {
    out.push({ id: 'payout', icon: 'lucide:smartphone', kind: 'Payments', label: 'Add where boarders send money', hint: 'GCash, Maya or bank. Until then they are told to ask you.', when: '', action: 'Add details', route: 'payout', tone: 'warn', rank: 0 })
  }
  if (live.value?.unposted.tenants) {
    out.push({ id: 'bills', icon: 'lucide:zap', kind: 'Bills', label: `Post ${formatMonth(live.value.month).split(' ')[0]} bills`, hint: unpostedLine.value, when: '', action: 'Post bills', route: 'bills', tone: 'warn', rank: 1 })
  }
  return out
})
function onTask(route: string) {
  if (route === 'payout') payoutOpen.value = true
  else if (route === 'bills') billsOpen.value = true
}
const unpostedLine = computed(() => {
  const u = live.value?.unposted
  if (!u) return ''
  const names = UTILITIES.filter((x) => u.utilities.includes(x.key)).map((x) => x.label.toLowerCase())
  return `${names.join(' and ').replace(/^./, (s) => s.toUpperCase())} · ${u.tenants} boarder${u.tenants === 1 ? '' : 's'}`
})
function leavingLabel(l: CollectionLease): string {
  return l.leaveDate ? `Leaving ${new Date(`${l.leaveDate}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })}` : 'Leaving'
}
function waitLabel(days: number): string {
  return days <= 0 ? 'Today' : `${days} day${days === 1 ? '' : 's'}`
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const m = await fetchLandlordMoney()
    leases.value = m.leases
    ledger.value = m.ledger
    payments.value = m.payments
    billUtility.value = m.billUtility
    billed.value = m.billed
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

// Where tenants send money (landlord_payout), for the strip at the bottom.
const payout = ref<{ gcash_number: string | null; maya_number: string | null; bank_name: string | null; bank_account_number: string | null } | null>(null)
const payoutLoaded = ref(false)
const payoutOpen = ref(false)
async function loadPayout() {
  const { data: auth } = await authUser()
  const { data } = await supabase
    .from('landlord_payout')
    .select('gcash_number,maya_number,bank_name,bank_account_number')
    .eq('landlord_id', auth?.user?.id ?? '')
    .maybeSingle()
  payout.value = data && (data.gcash_number || data.maya_number || data.bank_account_number) ? data : null
  payoutLoaded.value = true
}
const mask = (n: string) => `${n.slice(0, 4)} ••• ${n.slice(-4)}`
const payoutWays = computed(() => {
  const p = payout.value
  if (!p) return ''
  const ways = [p.gcash_number && 'GCash', p.maya_number && 'Maya', p.bank_account_number && (p.bank_name || 'bank'), 'cash'].filter(Boolean) as string[]
  return ways.length > 1 ? `${ways.slice(0, -1).join(', ')} or ${ways[ways.length - 1]}` : ways[0]!
})
const payoutLine = computed(() => {
  const p = payout.value
  if (!p) return ''
  return [p.gcash_number && `GCash ${mask(p.gcash_number)}`, p.maya_number && `Maya ${mask(p.maya_number)}`, p.bank_account_number && `${p.bank_name || 'Bank'} ${mask(p.bank_account_number)}`]
    .filter(Boolean)
    .join(' · ')
})

watch(() => props.version, () => { void load(); void loadPayout() }, { immediate: true })
// Payments waiting on the landlord/landlady, across every property: the tab's badge.
watch(() => collectionsFor('all', thisMonth.value).confirm.length, (n) => emit('count', n), { immediate: true })

const reviewOpen = ref(false)
const reviewId = ref<string | null>(null)
function review(id: string) {
  reviewId.value = id
  reviewOpen.value = true
}
const logOpen = ref(false)
const logLease = ref<CollectionLease | null>(null)
function logFor(l: CollectionLease) {
  logLease.value = l
  logOpen.value = true
}
const billsOpen = ref(false)
function changed() {
  void load()
  emit('changed')
}
</script>

<style scoped>
/* Sits in the Tenants panel, which has no side padding: loose controls keep
   the panel's 12px inset, list sections run edge to edge (ManagerTenantsPage). */
.cp {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.cp-sk {
  border-radius: var(--m-radius);
}
.cp-inset {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0 12px;
}
:global(.shell-tablet) .cp-inset {
  margin: 0;
}
/* The dashboard's todo rows sit on the page background; in this white panel
   they take the background colour so they still read as cards. */
.cp-todo :deep(.step) {
  background: var(--m-bg);
}
/* An <h2>: without a line-height it takes Quasar's 3.75rem one. */
.cp-todo :deep(.sec-title) {
  line-height: 1.3;
}


/* ManagerTenantsPage's flat property section: a page-coloured band between
   sections, a grey header band, rows split by hairlines. */
.cp-block {
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--m-border);
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
}
.cp-block + .cp-block {
  margin-top: -14px;
  border-top: 8px solid var(--m-bg);
}
.room-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--m-bg);
}
.room-name {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.room-occ {
  margin-left: auto;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.room-link {
  margin-left: auto;
  padding: 0;
  border: 0;
  background: none;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
}
.cp-count {
  display: inline-grid;
  min-width: 18px;
  height: 18px;
  place-items: center;
  padding: 0 5px;
  border-radius: 999px;
  background: var(--m-border);
  color: var(--m-text);
  font-size: 10.5px;
  font-weight: 800;
}
.cp-count--info { background: var(--m-info-soft); color: var(--m-info); }
.cp-count--late { background: var(--m-danger-soft); color: var(--m-danger); }
.cp-count--ok { background: var(--m-success-soft); color: var(--m-success); }

.lease-row {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 6px 8px 6px 12px;
  border-top: 1px solid var(--m-border);
}
.lease-line {
  display: flex;
  align-items: center;
  gap: 6px;
}
.lease-main {
  display: flex;
  width: 100%;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 10px;
  padding: 4px 0;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.cp-static {
  cursor: default;
}
.lease-main :deep(.ca) {
  width: 36px;
  height: 36px;
  font-size: 12px;
  font-weight: 800;
}
.lease-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.lease-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.lease-sub {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cp-late {
  color: var(--m-danger);
}
.lease-sub.cp-late {
  font-weight: 600;
}
.cp-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.cp-amt {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.cp-chev {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.lease-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.lease-chip--orange { background: var(--m-warning-soft); color: var(--m-warning); }
.lease-chip--blue { background: var(--m-info-soft); color: var(--m-info); }
.lease-chip--green { background: var(--m-success-soft); color: var(--m-success); }
.lease-actions {
  display: flex;
  gap: 8px;
  /* Under the name, past the avatar. */
  padding-left: 46px;
}
.lease-act {
  flex: 0 0 auto;
  padding: 6px 11px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 11.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.lease-act--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-text);
}

/* DashTodoList's round icon. */
.step-icon {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

/* The month hero: the big collected figure over the stacked bar. */
.cp-hero {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px 8px;
  margin-top: 6px;
}
.cp-big {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 34px;
  font-weight: 700;
  letter-spacing: -0.03em;
}
.cp-of {
  color: var(--m-muted);
  font-size: 14px;
}
.cp-tiles {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 6px;
}
.cp-tile {
  display: flex;
  min-height: 64px;
  flex-direction: column;
  gap: 2px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: 12px;
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
/* A 2px ring would shift the text, so the padding gives up the extra pixel. */
.cp-tile--on {
  padding: 9px 11px;
  border: 2px solid var(--m-info);
  background: var(--m-info-soft);
}
.cp-tile-top {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--m-text);
  font-size: 12px;
  font-weight: 700;
}
.cp-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.cp-tile-n {
  margin-left: auto;
  color: var(--m-ink);
  font-weight: 800;
}
.cp-tile-amt {
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.cp-cards {
  gap: 14px;
}
.cp-list-head {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.cp-list-head b {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.cp-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.cp-card-top {
  display: flex;
  align-items: center;
  gap: 10px;
}
.cp-card-top :deep(.ca) {
  width: 36px;
  height: 36px;
  font-size: 12px;
  font-weight: 800;
}
.cp-amt--lg {
  font-family: var(--m-font-display);
  font-size: 15px;
}
.cp-view {
  display: flex;
  min-height: 40px;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 1px solid var(--m-primary);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.cp-none {
  margin: 0;
  padding: 14px 12px;
  color: var(--m-muted);
  font-size: 13px;
  text-align: center;
}
</style>
