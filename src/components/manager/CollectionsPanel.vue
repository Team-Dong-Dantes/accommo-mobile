<template>
  <!-- Tenants → Payments, built from the app's own parts: the dashboard's
       teal hero and stat strip, its "Needs attention" list, and the By boarder
       tab's flat sections (grey band header, edge-to-edge rows, small pills). -->
  <div class="cp">
    <div v-if="loading && !col" class="cp-center"><q-spinner size="26px" color="primary" /></div>
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
        <MonthSummary :totals="col">
          <template #action>
            <button v-if="properties.length > 1" type="button" class="cp-prop" @click="propsOpen = true">
              {{ propertyName }}
              <IconifyIcon icon="lucide:chevron-down" width="14" />
            </button>
          </template>
        </MonthSummary>
      </div>

      <DashTodoList v-if="tasks.length" class="cp-inset cp-todo" title="Needs attention" :tasks="tasks" :done-count="0" @go="onTask" />

      <!-- Each group is a flat section like a property on the By boarder tab. -->
      <section v-if="col.confirm.length" class="cp-block">
        <div class="room-head">
          <span class="room-name">Confirm these</span>
          <span class="cp-count cp-count--info">{{ col.confirm.length }}</span>
          <span class="room-occ">Boarder says they paid</span>
        </div>
        <div v-for="c in col.confirm" :key="c.key" class="lease-row">
          <button type="button" class="lease-main" @click="review(c.paymentId)">
            <CollectionAvatar :lease="c.lease" />
            <span class="lease-body">
              <span class="lease-name">{{ c.lease.studentName }}</span>
              <span class="lease-sub">{{ c.what }} · {{ PAYMENT_METHOD_LABEL[c.method] ?? c.method }} · {{ c.lease.roomLabel }}</span>
            </span>
            <span class="cp-side">
              <span class="cp-amt">{{ formatPeso(c.amount) }}</span>
              <span class="lease-chip" :class="c.waitDays >= 3 ? 'lease-chip--orange' : 'lease-chip--blue'">{{ waitLabel(c.waitDays) }}</span>
            </span>
          </button>
        </div>
      </section>

      <section v-if="col.late.length" class="cp-block">
        <div class="room-head">
          <span class="room-name">Overdue</span>
          <span class="cp-count cp-count--late">{{ col.late.length }}</span>
        </div>
        <div v-for="o in col.late" :key="o.lease.id" class="lease-row">
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
      </section>

      <section v-if="col.coming.length" class="cp-block">
        <div class="room-head">
          <span class="room-name">Still to come</span>
          <span class="cp-count">{{ col.coming.length }}</span>
        </div>
        <div v-for="o in col.coming" :key="o.lease.id" class="lease-row">
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
      </section>

      <section v-if="col.paid.length" class="cp-block">
        <div class="room-head">
          <span class="room-name">Paid</span>
          <span class="cp-count cp-count--ok">{{ col.paid.length }}</span>
          <button type="button" class="room-link" @click="router.push('/manager/profile/history?tab=payments')">All records</button>
        </div>
        <div class="lease-row">
          <button type="button" class="lease-main" @click="router.push('/manager/profile/history?tab=payments')">
            <span class="acc-faces">
              <CollectionAvatar v-for="l in col.paid.slice(0, 4)" :key="l.id" :lease="l" small />
              <span v-if="col.paid.length > 4" class="acc-face--more">+{{ col.paid.length - 4 }}</span>
            </span>
            <span class="lease-body">
              <span class="lease-name">{{ allIn ? `Everyone's paid for ${formatMonth(col.month).split(' ')[0]}` : 'Everyone else is paid up' }}</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="cp-chev" />
          </button>
        </div>
      </section>

      <section v-if="col.past.length" class="cp-block">
        <div class="room-head">
          <span class="room-name">From past stays</span>
          <span class="cp-count">{{ col.past.length }}</span>
        </div>
        <div v-for="o in col.past" :key="o.lease.id" class="lease-row">
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

    <BottomSheet v-model="propsOpen" title="Show payments for" clear-label="" done-label="">
      <div class="mx-radio-list" role="radiogroup" aria-label="Property">
        <button
          v-for="p in [{ id: 'all', name: 'All properties' }, ...properties]"
          :key="p.id"
          type="button"
          role="radio"
          class="mx-radio"
          :class="{ 'mx-radio--on': propertyId === p.id }"
          :aria-checked="propertyId === p.id"
          @click="propertyId = p.id; propsOpen = false"
        >
          <span class="mx-radio-dot" />
          <span class="lease-body">
            <span>{{ p.name }}</span>
            <span class="lease-sub">{{ propertyLine(p.id) }}</span>
          </span>
        </button>
      </div>
    </BottomSheet>

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
import { errorMessage } from '@/utils/errors'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'
import { formatMonth, formatPeso, PAYMENT_METHOD_LABEL } from '@/utils/format'
import { manilaToday, toLedger } from '@/utils/payments'
import { isBilledMonthly, UTILITIES, type UtilityKey } from '@/utils/listings'
import { buildCollections, type CollectionLease, type CollectionLedgerRow, type CollectionPayment } from '@/utils/collections'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import DashTodoList from '@/components/shared/DashTodoList.vue'
import MonthSummary from '@/components/shared/MonthSummary.vue'
import type { Task } from '@/components/shared/dashboard'
import CollectionAvatar from '@/components/manager/CollectionAvatar.vue'
import PaymentReviewSheet from '@/components/manager/PaymentReviewSheet.vue'
import LogPaymentSheet from '@/components/manager/LogPaymentSheet.vue'
import PostBillsSheet from '@/components/manager/PostBillsSheet.vue'
import PayoutDialog from '@/components/manager/PayoutDialog.vue'

// Loads on its own, and again whenever `version` moves (the Tenants page bumps
// it on every refresh), so the page above it doesn't carry any payment state.
const props = defineProps<{ version: number }>()
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
const propsOpen = ref(false)

const properties = computed(() => {
  const seen = new Map<string, string>()
  for (const l of leases.value) if (l.accommodationId) seen.set(l.accommodationId, l.accommodationName)
  return [...seen.entries()].map(([id, name]) => ({ id, name }))
})
const propertyName = computed(() => properties.value.find((p) => p.id === propertyId.value)?.name ?? 'All properties')

function collectionsFor(id: string) {
  const ls = id === 'all' ? leases.value : leases.value.filter((l) => l.accommodationId === id)
  const ids = new Set(ls.map((l) => l.id))
  return buildCollections(ls, ledger.value.filter((r) => ids.has(r.leaseId)), payments.value.filter((p) => ids.has(p.leaseId)), billUtility.value, billed.value, manilaToday())
}
const col = computed(() => (leases.value.length || !loading.value ? collectionsFor(propertyId.value) : null))
const expected = computed(() => (col.value ? col.value.collected + col.value.toConfirm + col.value.overdue + col.value.toCome : 0))
const allIn = computed(() => !!col.value && expected.value > 0 && col.value.toConfirm + col.value.overdue + col.value.toCome < 0.01)
// Things to set up or do, as rows of the dashboard's "Needs attention" list.
const tasks = computed<Task[]>(() => {
  const out: Task[] = []
  if (payoutLoaded.value && !payout.value) {
    out.push({ id: 'payout', icon: 'lucide:smartphone', kind: 'Payments', label: 'Add where boarders send money', hint: 'GCash, Maya or bank. Until then they are told to ask you.', when: '', action: 'Add details', route: 'payout', tone: 'warn', rank: 0 })
  }
  if (col.value?.unposted.tenants) {
    out.push({ id: 'bills', icon: 'lucide:zap', kind: 'Bills', label: `Post ${formatMonth(col.value.month).split(' ')[0]} bills`, hint: unpostedLine.value, when: '', action: 'Post bills', route: 'bills', tone: 'warn', rank: 1 })
  }
  return out
})
function onTask(route: string) {
  if (route === 'payout') payoutOpen.value = true
  else if (route === 'bills') billsOpen.value = true
}
function propertyLine(id: string): string {
  const c = collectionsFor(id)
  const exp = c.collected + c.toConfirm + c.overdue + c.toCome
  return `${formatPeso(c.collected)} of ${formatPeso(exp)}${c.confirm.length ? ` · ${c.confirm.length} to confirm` : ''}`
}
const unpostedLine = computed(() => {
  const u = col.value?.unposted
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
    const { data: auth } = await authUser()
    const me = auth?.user?.id
    if (!me) throw new Error('Not signed in.')
    const [{ data: leaseRows, error: e1 }, { data: ledgerRows, error: e2 }] = await Promise.all([
      supabase
        .from('leases')
        .select('id,status,student_id,start_date,leave_date,water_billing,electric_billing,wifi_billing,users!leases_student_id_fkey(full_name,avatar_color,avatar_url),rooms(label,room_number,accommodation_id,accommodations(name))')
        .eq('landlord_id', me)
        .in('status', ['active', 'leave_requested', 'ended', 'terminated']),
      supabase.rpc('landlord_ledger'),
    ])
    if (e1) throw e1
    if (e2) throw e2
    const ids = (leaseRows ?? []).map((l) => l.id)
    const today = manilaToday()
    const [{ data: payRows, error: e3 }, { data: billRows, error: e4 }] = await Promise.all([
      ids.length
        ? supabase
            .from('payments')
            .select('id,batch_id,lease_id,amount,method,status,kind,month,bill_id,description,created_at,promise_date')
            .in('lease_id', ids)
            .or(`status.eq.pending_verification,promise_date.gte.${today}`)
        : Promise.resolve({ data: [], error: null }),
      ids.length ? supabase.from('utility_bills').select('id,lease_id,utility,month').in('lease_id', ids) : Promise.resolve({ data: [], error: null }),
    ])
    if (e3) throw e3
    if (e4) throw e4

    leases.value = (leaseRows ?? []).map((l) => {
      const u = l.users as unknown as { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
      const room = l.rooms as unknown as { label: string | null; room_number: string | null; accommodation_id: string; accommodations: { name: string | null } | null } | null
      const billing: Record<UtilityKey, string | null> = { water: l.water_billing, electric: l.electric_billing, wifi: l.wifi_billing }
      return {
        id: l.id,
        studentId: l.student_id,
        studentName: u?.full_name || 'A student',
        avatarColor: u?.avatar_color ?? null,
        avatarUrl: u?.avatar_url ? resolveAsset(u.avatar_url, AVATAR) : null,
        roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room'),
        accommodationId: room?.accommodation_id ?? '',
        accommodationName: room?.accommodations?.name?.trim() || 'Accommodation',
        status: l.status,
        startDate: l.start_date,
        leaveDate: l.leave_date,
        metered: UTILITIES.filter((x) => isBilledMonthly(billing[x.key])).map((x) => x.key),
      }
    })
    ledger.value = (ledgerRows ?? []).map((r) => ({ ...toLedger([r])[0]!, leaseId: r.lease_id }))
    payments.value = (payRows ?? []).map((p) => ({
      id: p.id,
      batchId: p.batch_id,
      leaseId: p.lease_id,
      amount: Number(p.amount),
      method: p.method,
      status: p.status,
      kind: p.kind,
      month: p.month,
      billId: p.bill_id,
      description: p.description,
      createdAt: p.created_at,
      promiseDate: p.promise_date,
    }))
    billUtility.value = Object.fromEntries((billRows ?? []).map((b) => [b.id, b.utility as UtilityKey]))
    const thisMonth = `${today.slice(0, 7)}-01`
    billed.value = new Set((billRows ?? []).filter((b) => b.month === thisMonth).map((b) => `${b.lease_id}:${b.utility}`))
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
watch(() => collectionsFor('all').confirm.length, (n) => emit('count', n), { immediate: true })

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
.cp-center {
  display: flex;
  justify-content: center;
  padding: 40px 0;
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

/* The mockup's property pill. */
.cp-prop {
  display: inline-flex;
  min-height: 32px;
  align-items: center;
  gap: 4px;
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

/* The By boarder tab's stacked faces. */
.acc-faces {
  display: flex;
  flex: 0 0 auto;
}
.acc-faces > :not(:first-child) {
  margin-left: -8px;
}
.acc-face--more {
  display: inline-grid;
  width: 30px;
  height: 30px;
  margin-left: -8px;
  place-items: center;
  border: 2px solid var(--m-surface);
  border-radius: 50%;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 10.5px;
  font-weight: 700;
}
.acc-faces :deep(.ca--small) {
  border-color: var(--m-surface);
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
</style>
