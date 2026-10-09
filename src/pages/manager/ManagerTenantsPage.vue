<template>
  <q-page class="tp" :class="{ 'page-wide': split }">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <div class="tabs">
          <q-skeleton type="rect" width="88px" height="38px" class="m-sk-tab" />
          <q-skeleton type="rect" width="88px" height="38px" class="m-sk-tab" />
        </div>
        <div v-for="n in 2" :key="n" class="acc">
          <div class="acc-head">
            <q-skeleton type="rect" size="36px" />
            <span class="acc-head-body">
              <q-skeleton type="text" width="55%" height="15px" />
              <q-skeleton type="text" width="35%" height="12px" />
            </span>
          </div>
        </div>
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your tenants" :detail="error" :retry="load" inset />
      </div>

      <EmptyState
        v-else-if="!accommodations.length"
        icon="lucide:users"
        title="No tenants yet"
        message="When a student applies for one of your rooms and you accept them, they show up here grouped by room — empty beds included, plus any applications still waiting on you."
      />

      <div v-else class="stack">
        <div class="m-tabbed">
        <div v-if="!split" class="tabs">
          <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'tenants' }" @click="activeTab = 'tenants'">
            By tenant
          </button>
          <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'payments' }" @click="activeTab = 'payments'">
            Payments
            <span v-if="paymentsNeedingVerification.length" class="tab-dot">{{ paymentsNeedingVerification.length }}</span>
          </button>
        </div>

        <!-- Desktop has the room for both at once, so the tabs go and the same
             two panels sit side by side. The markup is shared: on desktop the
             panels are plain divs, elsewhere the swipeable QTabPanels. -->
        <div :class="split ? 'desk-card' : 'panel'">
        <component :is="panelsIs" v-bind="panelsProps" :class="split ? 'desk-contents' : 'm-panels'">
          <component :is="panelIs" name="tenants" :class="split ? 'desk-col' : 'tab-panel'">
            <template v-if="split">
              <SearchDock
                v-model="query"
                inline
                class="desk-search"
                :filter-count="filter !== 'all' || selectedAccId !== 'all' ? 1 : 0"
                placeholder="Search tenants or rooms"
                search-label="Search tenants"
                @open-filters="filtersOpen = true"
              />
              <h2 class="sec-title">By tenant</h2>
            </template>
            <div class="top-actions">
              <button type="button" class="top-pay-btn" :class="{ 'top-pay-btn--ghost': pickingPayment }" @click="pickingPayment = !pickingPayment">
                <IconifyIcon :icon="pickingPayment ? 'lucide:x' : 'lucide:hand-coins'" width="16" />
                {{ pickingPayment ? 'Cancel' : 'Log a payment' }}
              </button>
              <!-- Walk-in tenants, accepted later by scanning their QR. -->
              <button v-if="!pickingPayment" type="button" class="top-pay-btn top-pay-btn--ghost" @click="addOpen = true">
                <IconifyIcon icon="lucide:user-plus" width="16" />
                Add a student
              </button>
            </div>
            <p v-if="pickingPayment" class="picking-hint">
              <IconifyIcon icon="lucide:pointer" width="14" />
              Tap a tenant below to log their payment.
            </p>

            <section v-for="acc in visibleAccommodations" :key="acc.id" class="acc">
              <button type="button" class="acc-head" @click="toggleAcc(acc.id)">
                <span class="acc-thumb" :class="`acc-thumb--${occupancyTone(accSummary.get(acc.id)?.occupancyPct ?? 0)}`">
                  <img v-if="acc.coverUrl" :src="acc.coverUrl" alt="" />
                  <IconifyIcon v-else icon="lucide:building-2" width="18" />
                </span>
                <span class="acc-head-body">
                  <span class="acc-title-row">
                    <h2 class="acc-title">{{ acc.name }}</h2>
                    <span v-if="accAlertCounts.get(acc.id)" class="acc-badge">{{ accAlertCounts.get(acc.id) }} to review</span>
                  </span>
                  <span class="acc-stats-row">
                    <span class="acc-stats">{{ accStatsLine(acc) }}</span>
                    <span v-if="accTenants.get(acc.id)?.length" class="acc-faces" aria-hidden="true">
                      <span
                        v-for="l in accTenants.get(acc.id)!.slice(0, 4)"
                        :key="l.id"
                        class="acc-face"
                        :class="l.avatarColor ? [`bg-${l.avatarColor}`, 'text-white'] : []"
                      >
                        <img v-if="l.avatarUrl" :src="l.avatarUrl" alt="" @error="l.avatarUrl = null" />
                        <template v-else>{{ initialsOf(l.studentName) }}</template>
                      </span>
                      <span v-if="accTenants.get(acc.id)!.length > 4" class="acc-face acc-face--more">
                        +{{ accTenants.get(acc.id)!.length - 4 }}
                      </span>
                    </span>
                  </span>
                  <!-- How full the property is, readable before you expand it. -->
                  <span class="acc-occ-track">
                    <span
                      class="acc-occ-fill"
                      :style="{ width: (accSummary.get(acc.id)?.occupancyPct ?? 0) + '%' }"
                    />
                  </span>
                </span>
                <IconifyIcon icon="lucide:chevron-down" width="18" class="acc-chevron" :class="{ 'acc-chevron--open': !collapsedAccIds.has(acc.id) }" />
              </button>
              <q-slide-transition>
                <div v-show="!collapsedAccIds.has(acc.id)">
                  <div v-for="room in acc.rooms" :key="room.id" class="room">
                    <div class="room-head">
                      <span class="room-name">{{ room.label }}</span>
                      <!-- One dot per bed: filled, applied for, or open. -->
                      <span v-if="room.capacity" class="room-beds" aria-hidden="true">
                        <i v-for="l in room.leases" :key="l.id" class="bed" :class="l.status === 'pending' ? 'bed--pending' : 'bed--on'" />
                        <i v-for="n in Math.max(0, room.capacity - room.leases.length)" :key="`open-${n}`" class="bed" />
                      </span>
                      <span class="room-occ" :class="{ 'room-occ--full': roomOccupancy(room).full }">
                        {{ roomOccupancy(room).label }}
                      </span>
                    </div>
                    <div v-if="room.leases.length" class="room-list">
                      <div
                        v-for="l in room.leases"
                        :key="l.id"
                        class="lease-row"
                        :class="{ 'lease-row--pending': l.status === 'pending', 'lease-row--leave': l.status === 'leave_requested' }"
                      >
                        <div class="lease-line">
                        <button
                          type="button"
                          class="lease-main"
                          :class="{ 'lease-main--pick': pickingPayment && isPayable(l) }"
                          :disabled="pickingPayment && !isPayable(l)"
                          @click="pickingPayment ? handlePick(l) : router.push(`/manager/tenant/${l.id}`)"
                        >
                          <span class="lease-avatar" :class="l.avatarColor ? [`bg-${l.avatarColor}`, 'text-white'] : []">
                            <img v-if="l.avatarUrl" :src="l.avatarUrl" alt="" class="lease-avatar-img" @error="l.avatarUrl = null" />
                            <template v-else>{{ initialsOf(l.studentName) }}</template>
                          </span>
                          <span class="lease-body">
                            <span class="lease-name">{{ l.studentName }}</span>
                            <span class="lease-sub">{{ leaseSubline(l) }}</span>
                          </span>
                          <!-- Active is the norm here; only the states that need a decision get a chip. -->
                          <span v-if="l.status !== 'active'" class="lease-chip" :class="`lease-chip--${statusColor(LEASE_STATUS, l.status)}`">
                            {{ statusText(LEASE_STATUS, l.status) }}
                          </span>
                        </button>
                        <button
                          v-if="!pickingPayment && l.status !== 'pending'"
                          type="button"
                          class="lease-msg"
                          aria-label="Message tenant"
                          @click="router.push(`/manager/messages?to=${l.studentId}`)"
                        >
                          <IconifyIcon icon="lucide:message-circle" width="15" />
                        </button>
                        </div>
                        <div v-if="!pickingPayment && l.status === 'pending'" class="lease-actions">
                          <button
                            type="button"
                            class="lease-act lease-act--ghost"
                            :disabled="decidingId === l.id"
                            @click="openDecline(l)"
                          >
                            Decline
                          </button>
                          <!-- A student added by hand is accepted by scanning
                               their QR, never with a tap (DB-enforced). -->
                          <template v-if="l.addedByLandlord">
                            <button
                              type="button"
                              class="lease-act"
                              @click="router.push(`/manager/profile/qr-scanner?accept=${l.id}`)"
                            >
                              Scan to accept
                            </button>
                          </template>
                          <button
                            v-else
                            type="button"
                            class="lease-act"
                            :disabled="decidingId === l.id"
                            @click="decideApplication(l, 'active')"
                          >
                            Accept
                          </button>
                        </div>
                      </div>
                    </div>
                    <p v-else class="room-none">No tenants</p>
                  </div>
                </div>
              </q-slide-transition>
            </section>
          </component>

          <component :is="panelIs" name="payments" :class="split ? 'desk-col' : 'tab-panel'">
            <h2 v-if="split" class="sec-title">Payments</h2>
            <div class="pay-summary">
              <div class="pay-stat">
                <span class="pay-stat-value">{{ formatPeso(receivedThisMonth) }}</span>
                <span class="pay-stat-label">Received in {{ thisMonthLabel }}</span>
              </div>
              <div class="pay-stat" :class="{ 'pay-stat--warn': paymentsNeedingVerification.length }">
                <span class="pay-stat-value">{{ paymentsNeedingVerification.length }}</span>
                <span class="pay-stat-label">To verify</span>
              </div>
            </div>

            <section v-if="paymentsNeedingVerification.length" class="pay-section">
              <h2 class="sec-title">Needs verification</h2>
              <div class="group group--warn">
                <button
                  v-for="p in paymentsNeedingVerification"
                  :key="p.id"
                  type="button"
                  class="pay-row"
                  @click="openPaymentDetail(p)"
                >
                  <span class="lease-avatar" :class="avatarClass(p)">
                    <img v-if="avatarOf(p)?.avatarUrl" :src="avatarOf(p)?.avatarUrl ?? ''" alt="" class="lease-avatar-img" />
                    <template v-else>{{ initialsOf(p.studentName) }}</template>
                  </span>
                  <span class="pay-row-body">
                    <span class="pay-row-main">
                      <span class="pay-row-name">{{ p.studentName }}</span>
                      <span class="pay-row-amount">{{ formatPeso(p.amount) }}</span>
                    </span>
                    <span class="pay-row-sub">
                      <span class="pay-row-meta">{{ paySubline(p, true) }}</span>
                      <span class="pay-row-review">
                        Review
                        <IconifyIcon icon="lucide:chevron-right" width="13" />
                      </span>
                    </span>
                  </span>
                </button>
              </div>
            </section>

            <section class="pay-section">
              <div class="sec-head">
                <h2 class="sec-title">History</h2>
                <button type="button" class="sec-link" @click="router.push('/manager/profile/history?tab=payments')">View all</button>
              </div>
              <template v-if="historyByMonth.length">
                <div v-for="g in historyByMonth" :key="g.label" class="pay-month">
                  <div class="pay-month-head">
                    <span>{{ g.label }}</span>
                    <span class="pay-month-total">{{ formatPeso(g.received) }}</span>
                  </div>
                  <div class="group">
                    <button
                      v-for="p in g.rows"
                      :key="p.id"
                      type="button"
                      class="pay-row"
                      @click="openPaymentDetail(p)"
                    >
                      <span class="lease-avatar" :class="avatarClass(p)">
                        <img v-if="avatarOf(p)?.avatarUrl" :src="avatarOf(p)?.avatarUrl ?? ''" alt="" class="lease-avatar-img" />
                        <template v-else>{{ initialsOf(p.studentName) }}</template>
                      </span>
                      <span class="pay-row-body">
                        <span class="pay-row-main">
                          <span class="pay-row-name">{{ p.studentName }}</span>
                          <span class="pay-row-amount" :class="{ 'pay-row-amount--void': p.status === 'rejected' }">{{ formatPeso(p.amount) }}</span>
                        </span>
                        <span class="pay-row-sub">
                          <span class="pay-row-meta">{{ paySubline(p, false) }}</span>
                          <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">{{ statusText(PAYMENT_STATUS, p.status) }}</span>
                        </span>
                      </span>
                    </button>
                  </div>
                </div>
              </template>
              <EmptyState
                v-else
                variant="compact"
                icon="lucide:receipt"
                title="No payments logged yet"
                message="Payments you log for any tenant will show up here."
              />
            </section>
          </component>
        </component>
        </div>
        </div>
      </div>

    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band.
         Outside the pull-to-refresh wrapper on purpose: it transforms its
         content while you pull, which would drag this fixed dock along. -->
    <SearchDock
      v-if="!loading && !error && !split"
      v-model="query"
      :filter-count="filter !== 'all' || selectedAccId !== 'all' ? 1 : 0"
      placeholder="Search tenants or rooms"
      search-label="Search tenants"
      above-nav
      @open-filters="filtersOpen = true"
    />

    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      @clear="filter = 'all'; selectedAccId = 'all'"
    >
      <div v-if="accreditedAccommodations.length > 1" class="sheet-block">
        <span class="sheet-label">Property</span>
        <div class="m-chips">
          <button type="button" class="m-chip" :class="{ 'm-chip--on': selectedAccId === 'all' }" @click="selectedAccId = 'all'">
            All
          </button>
          <button
            v-for="a in accreditedAccommodations"
            :key="a.id"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': selectedAccId === a.id }"
            @click="selectedAccId = a.id"
          >
            {{ a.name }}
          </button>
        </div>
      </div>
      <div class="sheet-block">
        <span class="sheet-label">Status</span>
        <div class="m-chips">
          <button
            v-for="f in FILTERS"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': filter === f.key }"
            @click="filter = f.key"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
    </BottomSheet>

    <!-- A decline the student can act on: the reason reaches them in the
         notification and stays on the lease. -->
    <BottomSheet
      v-model="declineOpen"
      title="Decline application"
      clear-label=""
      done-label=""
    >
      <div class="sheet-block">
        <span class="sheet-label">The student sees this reason</span>
        <textarea v-model="declineReason" class="decline-input" rows="3" placeholder="Why are you declining?" />
      </div>
      <div class="decline-actions">
        <button type="button" class="lease-act lease-act--ghost" @click="declineOpen = false">Cancel</button>
        <button
          type="button"
          class="lease-act"
          :disabled="!declineReason.trim() || Boolean(decidingId)"
          @click="confirmDecline"
        >
          {{ decidingId ? 'Declining…' : 'Decline' }}
        </button>
      </div>
    </BottomSheet>

    <AddStudentSheet v-model="addOpen" @added="refresh" />

    <PaySheet
      v-model="paymentOpen"
      :lease-id="paymentLease?.id ?? ''"
      role="landlord"
      :start-date="paymentLease?.startDate ?? ''"
      :subtitle="paymentLease ? `${paymentLease.studentName}${paymentLease.monthlyRent ? ` · ${formatPeso(paymentLease.monthlyRent)}/mo` : ''}` : ''"
      @submitted="load(true)"
    />

    <PaymentReviewSheet v-model="paymentDetailOpen" :payment="selectedPayment" @changed="load(true)" />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { formatDate, formatMonth, formatPeso, initialsOf, LEASE_STATUS, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'
import { paymentTitle, manilaToday } from '@/utils/payments'
import { useNotify } from '@/utils/notify'
import { confirmAction } from '@/utils/confirmAction'
import { respondToApplication } from '@/utils/applications'
import { resolveAsset, AVATAR, CARD } from '@/utils/cloudinaryUrl'
import { signRows } from '@/utils/upload'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import AddStudentSheet from '@/components/manager/AddStudentSheet.vue'
import PaymentReviewSheet from '@/components/manager/PaymentReviewSheet.vue'
import PaySheet from '@/components/shared/PaySheet.vue'

interface Lease {
  id: string
  status: string
  studentId: string
  studentName: string
  avatarColor: string | null
  avatarUrl: string | null
  startDate: string
  monthlyRent: number
  addedByLandlord: boolean
}
interface Room {
  id: string
  label: string
  capacity: number | null
  leases: Lease[]
}
interface Accommodation {
  id: string
  name: string
  status: string
  coverUrl: string
  rooms: Room[]
}
interface PaymentRow {
  id: string
  month: string
  amount: number
  method: string
  status: string
  accommodationId: string
  accommodationName: string
  roomLabel: string
  studentId: string
  studentName: string
  description: string
  txnReference: string
  proofUrl: string
  paidAt: string | null
  verifiedByName: string
  rejectionReason: string
  note: string
  promiseDate: string | null
  claimedAmount: number | null
  undoReason: string
  receiptNo: string
}

const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Applications' },
  { key: 'active', label: 'Tenants' },
  { key: 'leave_requested', label: 'Leave requests' },
] as const


const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const myId = ref('')
const accommodations = ref<Accommodation[]>([])
const activeTab = ref<'tenants' | 'payments'>('tenants')
// `?tab=payments` (the dashboard's "Verify payments" item). Watched, not read
// once: this screen is kept alive, so a later visit reuses the same instance.
const route = useRoute()
watch(
  () => route.query.tab,
  (tab) => {
    if (tab === 'payments') activeTab.value = 'payments'
  },
  { immediate: true },
)
// Desktop has the room for both panels at once (see useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(activeTab)
const payments = ref<PaymentRow[]>([])
const query = ref('')
const filter = ref<(typeof FILTERS)[number]['key']>('all')
const filtersOpen = ref(false)
const selectedAccId = ref('all')

const collapsedAccIds = ref(new Set<string>())
function toggleAcc(id: string) {
  const next = new Set(collapsedAccIds.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  collapsedAccIds.value = next
}

// Counts pending applications + leave requests regardless of the current
// search/status filter, so the badge still flags what needs attention even
// when a property is collapsed or filtered out of view.
const accAlertCounts = computed(() => {
  const map = new Map<string, number>()
  for (const acc of accommodations.value) {
    let count = 0
    for (const room of acc.rooms) {
      for (const l of room.leases) {
        if (l.status === 'pending' || l.status === 'leave_requested') count++
      }
    }
    map.set(acc.id, count)
  }
  return map
})

// Room count + occupied-tenant count per property, for the header subline —
// also unfiltered, so it always reads as the property's real total.
const accSummary = computed(() => {
  const map = new Map<string, { rooms: number; tenants: number; occupancyPct: number }>()
  for (const acc of accommodations.value) {
    let tenants = 0
    let capacity = 0
    for (const room of acc.rooms) {
      capacity += room.capacity ?? 0
      for (const l of room.leases) {
        if (l.status === 'active' || l.status === 'leave_requested') tenants++
      }
    }
    map.set(acc.id, { rooms: acc.rooms.length, tenants, occupancyPct: capacity ? Math.min(100, (tenants / capacity) * 100) : 0 })
  }
  return map
})

// Who lives in each property, for the stacked faces in its header — unfiltered
// like the counts above, so searching never makes a property look emptier.
const accTenants = computed(() => {
  const map = new Map<string, Lease[]>()
  for (const acc of accommodations.value) {
    map.set(acc.id, acc.rooms.flatMap((room) => room.leases.filter(isPayable)))
  }
  return map
})

// Accredited properties are the live ones. One whose accreditation lapsed
// (expired permit, suspension) still has the tenants who moved in before, and
// their stays and payments still need managing, so it stays while anyone lives there.
const accreditedAccommodations = computed(() => accommodations.value.filter(
  (acc) => acc.status === 'accredited' || acc.rooms.some((room) => room.leases.length > 0),
))

const visibleAccommodations = computed(() => {
  const q = query.value.trim().toLowerCase()
  return accreditedAccommodations.value
    .filter((acc) => selectedAccId.value === 'all' || acc.id === selectedAccId.value)
    .map((acc) => ({
      ...acc,
      rooms: acc.rooms
        .map((room) => ({
          ...room,
          leases: room.leases.filter((l) => {
            if (filter.value !== 'all' && l.status !== filter.value) return false
            if (!q) return true
            return (
              l.studentName.toLowerCase().includes(q) ||
              room.label.toLowerCase().includes(q) ||
              acc.name.toLowerCase().includes(q)
            )
          }),
        }))
        .filter((room) => (filter.value === 'all' && !q ? true : room.leases.length > 0)),
    }))
    .filter((acc) => acc.rooms.length > 0)
})

// Payments view — tracks only what's actually been logged (this app's own
// data notes flag `payments` as too sparse to infer who hasn't paid from a
// missing row, so there's no "unpaid"/overdue view here, only real records).
const visiblePayments = computed(() =>
  selectedAccId.value === 'all' ? payments.value : payments.value.filter((p) => p.accommodationId === selectedAccId.value),
)
const paymentsNeedingVerification = computed(() => visiblePayments.value.filter((p) => p.status === 'pending_verification'))
const recentPayments = computed(() => visiblePayments.value.filter((p) => p.status !== 'pending_verification'))

// The summary strip counts only payments marked paid — a record, never an
// expectation, for the same sparseness reason as above.
const thisMonth = computed(() => manilaToday().slice(0, 7))
const thisMonthLabel = computed(() => formatMonth(`${thisMonth.value}-01`).split(' ')[0])
const receivedThisMonth = computed(() =>
  visiblePayments.value.filter((p) => p.status === 'paid' && p.month.startsWith(thisMonth.value)).reduce((sum, p) => sum + p.amount, 0),
)

// History under a header per month. Rows already arrive newest month first.
const historyByMonth = computed(() => {
  const groups: { label: string; received: number; rows: PaymentRow[] }[] = []
  for (const p of recentPayments.value) {
    const label = formatMonth(p.month)
    let g = groups[groups.length - 1]
    if (g?.label !== label) groups.push((g = { label, received: 0, rows: [] }))
    g.rows.push(p)
    if (p.status === 'paid') g.received += p.amount
  }
  return groups
})

// Payments carry no avatar of their own; borrow it from the tenant's lease.
const leaseByStudent = computed(() => {
  const map = new Map<string, Lease>()
  for (const acc of accommodations.value) for (const room of acc.rooms) for (const l of room.leases) map.set(l.studentId, l)
  return map
})
function avatarOf(p: PaymentRow) {
  return leaseByStudent.value.get(p.studentId)
}
function avatarClass(p: PaymentRow) {
  const color = avatarOf(p)?.avatarColor
  return color ? [`bg-${color}`, 'text-white'] : []
}

// Under a month header the rent month is already said, so only a non-rent
// tag (advance, deposit, a bill) is worth repeating on the row.
function paySubline(p: PaymentRow, withMonth: boolean): string {
  const title = paymentTitle(p)
  const what = withMonth ? title : title !== formatMonth(p.month) ? p.description : ''
  return [what, PAYMENT_METHOD_LABEL[p.method] || p.method, `${p.roomLabel} · ${p.accommodationName}`].filter(Boolean).join(' · ')
}

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
      return
    }
    myId.value = user.id

    // Accommodations and leases both key only off the landlord/landlady's id, so they go
    // out together; rooms and payments each need an id list from this wave and
    // follow in the second one below.
    const [
      { data: accRows, error: accError },
      { data: leaseRows, error: leaseError },
    ] = await Promise.all([
      supabase
        .from('accommodations')
        .select('id,name,status,accommodation_images(url,sort_order)')
        .eq('landlord_id', user.id),
      supabase
        .from('leases')
        .select('id,status,room_id,student_id,start_date,monthly_rent,added_by_landlord,users!leases_student_id_fkey(full_name,avatar_color,avatar_url)')
        .eq('landlord_id', user.id)
        .neq('status', 'rejected'),
    ])
    if (accError) throw accError
    if (leaseError) throw leaseError

    const accIds = (accRows ?? []).map((a) => a.id)
    // Every stay, ended ones included: a former tenant can still pay what they
    // owe, and that payment has to show up (and be confirmable) here. Only
    // current stays go on the room grid.
    const leaseIds = (leaseRows ?? []).map((l) => l.id)
    const currentLeases = (leaseRows ?? []).filter((l) => ['active', 'pending', 'leave_requested'].includes(l.status))

    // Second wave: rooms key off the accommodation ids, payments off the lease
    // ids. Both id lists are known now, so the two go out together instead of
    // one after the other with all the row-shaping work in between. Either is
    // skipped when its id list is empty rather than round-tripping for nothing.
    let roomRows: { id: string; label: string | null; room_number: string | null; capacity: number | null; accommodation_id: string }[] = []
    let paymentRows: {
      id: string
      month: string
      amount: number
      method: string
      status: string
      lease_id: string
      description: string | null
      txn_reference: string | null
      proof_url: string | null
      paid_at: string | null
      rejection_reason: string | null
      note: string | null
      promise_date: string | null
      claimed_amount: number | null
      undo_reason: string | null
      receipt_no: string | null
      verified_by_user: { full_name: string | null } | null
    }[] = []
    const [roomsResult, paymentsResult] = await Promise.all([
      accIds.length
        ? supabase
            .from('rooms')
            .select('id,label,room_number,capacity,accommodation_id')
            .in('accommodation_id', accIds)
        : null,
      leaseIds.length
        ? supabase
            .from('payments')
            .select(
              'id,month,amount,method,status,lease_id,description,txn_reference,proof_url,paid_at,rejection_reason,note,promise_date,claimed_amount,undo_reason,receipt_no,verified_by_user:users!payments_verified_by_fkey(full_name)',
            )
            .in('lease_id', leaseIds)
            .order('month', { ascending: false })
        : null,
    ])
    if (roomsResult?.error) throw roomsResult.error
    roomRows = roomsResult?.data ?? []
    if (paymentsResult?.error) throw paymentsResult.error
    paymentRows = (paymentsResult?.data ?? []) as unknown as typeof paymentRows
    await signRows('payments', paymentRows, 'proof_url')

    const leasesByRoom = new Map<string, Lease[]>()
    for (const l of currentLeases) {
      const student = l.users as unknown as { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
      const list = leasesByRoom.get(l.room_id) ?? []
      list.push({
        id: l.id,
        status: l.status,
        studentId: l.student_id,
        studentName: student?.full_name || 'A student',
        avatarColor: student?.avatar_color ?? null,
        avatarUrl: student?.avatar_url ? resolveAsset(student.avatar_url, AVATAR) : null,
        startDate: l.start_date,
        monthlyRent: Number(l.monthly_rent ?? 0),
        addedByLandlord: l.added_by_landlord,
      })
      leasesByRoom.set(l.room_id, list)
    }

    accommodations.value = (accRows ?? []).map((acc) => {
      const cover = [...((acc.accommodation_images ?? []) as { url: string; sort_order: number | null }[])].sort(
        (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
      )[0]
      return {
        id: acc.id,
        name: acc.name?.trim() || 'Unnamed accommodation',
        status: acc.status,
        coverUrl: cover?.url ? resolveAsset(cover.url, CARD) : '',
        rooms: roomRows
          .filter((r) => r.accommodation_id === acc.id)
          .map((r) => ({
            id: r.id,
            label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
            capacity: r.capacity,
            leases: leasesByRoom.get(r.id) ?? [],
          })),
      }
    })
    // Closed by default — a landlord/landlady opens the properties they're checking,
    // rather than scrolling past every room in every property up front. Only
    // on the real first load: a silent (realtime-triggered) refresh must not
    // collapse whatever the landlord/landlady already has open.
    if (!silent) collapsedAccIds.value = new Set(accommodations.value.map((acc) => acc.id))

    const roomInfoById = new Map(roomRows.map((r) => [r.id, r]))
    const accNameById = new Map((accRows ?? []).map((a) => [a.id, a.name?.trim() || 'Unnamed accommodation']))
    const leaseInfo = new Map<string, { studentId: string; studentName: string; roomLabel: string; accommodationId: string; accommodationName: string }>()
    for (const l of leaseRows ?? []) {
      const student = l.users as unknown as { full_name: string | null } | null
      const room = roomInfoById.get(l.room_id)
      const accId = room?.accommodation_id ?? ''
      leaseInfo.set(l.id, {
        studentId: l.student_id,
        studentName: student?.full_name || 'A student',
        roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room'),
        accommodationId: accId,
        accommodationName: accNameById.get(accId) || 'Accommodation',
      })
    }

    payments.value = paymentRows.map((p) => {
      const info = leaseInfo.get(p.lease_id)
      return {
        id: p.id,
        month: p.month,
        amount: Number(p.amount),
        method: p.method,
        status: p.status,
        accommodationId: info?.accommodationId ?? '',
        accommodationName: info?.accommodationName ?? 'Accommodation',
        roomLabel: info?.roomLabel ?? 'Room',
        studentId: info?.studentId ?? '',
        studentName: info?.studentName ?? 'A student',
        description: p.description || '',
        txnReference: p.txn_reference || '',
        proofUrl: p.proof_url || '',
        paidAt: p.paid_at,
        verifiedByName: p.verified_by_user?.full_name || '',
        rejectionReason: p.rejection_reason || '',
        note: p.note || '',
        promiseDate: p.promise_date,
        claimedAmount: p.claimed_amount == null ? null : Number(p.claimed_amount),
        undoReason: p.undo_reason || '',
        receiptNo: p.receipt_no || '',
      }
    })
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

// Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so the
// database pushes lease changes here instead of the page re-asking on every
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return.
const { refresh } = useLiveData({
  key: 'manager-tenants',
  load,
  // leases/payments are not in the realtime publication; every payment and
  // lease event notifies this user, so their notifications are the signal.
  watch: (uid) => [
    { table: 'leases', filter: `landlord_id=eq.${uid}` },
    { table: 'notifications', filter: `user_id=eq.${uid}` },
  ],
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}

// Rent is stated as expected from leases.monthly_rent, not a collection/arrears
// status — the payments table is too sparse against active leases to build that on.
function leaseSubline(l: Lease): string {
  if (l.status === 'pending' && l.addedByLandlord) return `Awaiting QR check · move-in ${formatDate(l.startDate)}`
  if (l.status === 'pending') return `Requested move-in ${formatDate(l.startDate)}`
  const rent = l.monthlyRent ? `${formatPeso(l.monthlyRent)}/mo` : 'Rent not set'
  return `Since ${formatDate(l.startDate)} · ${rent}`
}

function accStatsLine(acc: Accommodation): string {
  const sum = accSummary.value.get(acc.id)
  const rooms = sum?.rooms ?? acc.rooms.length
  const tenants = sum?.tenants ?? 0
  const parts = [`${rooms} room${rooms === 1 ? '' : 's'}`, `${tenants} tenant${tenants === 1 ? '' : 's'}`]
  if (sum?.occupancyPct) parts.push(`${Math.round(sum.occupancyPct)}% full`)
  return parts.join(' · ')
}

function roomOccupancy(room: { leases: Lease[]; capacity: number | null }) {
  if (!room.capacity) return { label: `${room.leases.length} tenant${room.leases.length === 1 ? '' : 's'}`, full: false }
  const open = room.capacity - room.leases.length
  return open > 0 ? { label: `${open} open`, full: false } : { label: 'Full', full: true }
}

// Colors the property thumbnail's ring by how full it is — a fully rented
// property is good news, so high occupancy reads green, not red.
function occupancyTone(pct: number) {
  if (pct >= 90) return 'green'
  if (pct >= 50) return 'amber'
  return 'grey'
}

const decidingId = ref('')
const addOpen = ref(false)

const declineOpen = ref(false)
const declineReason = ref('')
const declineTarget = ref<{ lease: Lease } | null>(null)

function openDecline(l: Lease) {
  declineTarget.value = { lease: l }
  declineReason.value = ''
  declineOpen.value = true
}

async function confirmDecline() {
  if (!declineTarget.value) return
  const { lease } = declineTarget.value
  await decideApplication(lease, 'rejected', declineReason.value.trim())
  declineOpen.value = false
  declineTarget.value = null
  declineReason.value = ''
}

async function decideApplication(l: Lease, decision: 'active' | 'rejected', reason?: string) {
  if (decision === 'active' && !(await confirmAction({ title: 'Accept this application?', message: 'They become the tenant of this room.' }))) return
  if (decidingId.value) return
  decidingId.value = l.id
  try {
    await respondToApplication(l.id, decision, reason)
    if (decision === 'rejected') {
      for (const acc of accommodations.value) {
        for (const room of acc.rooms) room.leases = room.leases.filter((r) => r.id !== l.id)
      }
    } else {
      l.status = 'active'
    }
    notify.success(decision === 'active' ? 'Application accepted.' : 'Application declined.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this application.'))
  } finally {
    decidingId.value = ''
  }
}

const paymentDetailOpen = ref(false)
const selectedPayment = ref<PaymentRow | null>(null)
function openPaymentDetail(p: PaymentRow) {
  selectedPayment.value = p
  paymentDetailOpen.value = true
}

// Lets a landlord/landlady log a payment from the top of the page: tapping the top
// button turns the list itself into the picker — payable rows highlight,
// everything else (decide/message actions, navigation) is disabled until
// a tenant is tapped or picking is cancelled.
const pickingPayment = ref(false)
function isPayable(l: Lease) {
  return l.status === 'active' || l.status === 'leave_requested'
}
function handlePick(l: Lease) {
  if (!isPayable(l)) return
  pickingPayment.value = false
  openLogPayment(l)
}

const paymentOpen = ref(false)
const paymentLease = ref<Lease | null>(null)
function openLogPayment(l: Lease) {
  paymentLease.value = l
  paymentOpen.value = true
}


</script>

<style scoped>
.tp {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 14px;
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
  margin: 0 var(--m-page-gutter);
}
.card {
  margin: 8px var(--m-page-gutter);
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}

/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */

/* Filter sheet */
.decline-input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 14px;
  resize: none;
}
.decline-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
.top-actions {
  display: flex;
  gap: 8px;
}
.top-pay-btn {
  display: flex;
  flex: 1;
  min-height: 44px;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.top-pay-btn--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-ink);
}
.picking-hint {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: -4px 2px 0;
  color: var(--m-muted);
  font-size: 12px;
  text-align: center;
}

/* One connected card — the header and its rooms share this border/radius
   instead of floating as separate boxes with a gap between them. */
.acc {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.acc-head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 0;
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
/* Sits under the stats line inside the header, so the property's fullness
   reads as part of its summary rather than a strip across the card. */
.acc-occ-track {
  display: block;
  height: 4px;
  margin-top: 7px;
  border-radius: 999px;
  background: var(--m-border);
  overflow: hidden;
}
.acc-occ-fill {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--m-primary);
  transition: width 0.3s ease;
}
.acc-thumb {
  display: grid;
  width: 46px;
  height: 46px;
  flex: 0 0 46px;
  place-items: center;
  overflow: hidden;
  border: 2px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.acc-thumb--green {
  border-color: var(--m-success);
}
.acc-thumb--amber {
  border-color: var(--m-warning);
}
.acc-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.acc-head-body {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 0;
}
.acc-title-row {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 8px;
}
.acc-title {
  min-width: 0;
  margin: 0;
  line-height: 1.3;
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.acc-stats-row {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-top: 1px;
}
.acc-stats {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.acc-faces {
  display: flex;
  flex: 0 0 auto;
  padding-left: 6px;
}
.acc-face {
  display: grid;
  width: 24px;
  height: 24px;
  margin-left: -6px;
  place-items: center;
  overflow: hidden;
  border: 2px solid var(--m-surface);
  border-radius: 50%;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 8.5px;
  font-weight: 800;
}
.acc-face img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.acc-face--more {
  background: var(--m-bg);
  color: var(--m-muted);
}
.acc-badge {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10.5px;
  font-weight: 800;
  white-space: nowrap;
}
.acc-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
  transition: transform 0.2s ease;
}
.acc-chevron--open {
  transform: rotate(180deg);
}
.room {
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--m-border);
}
.room-head {
  display: flex;
  align-items: center;
  gap: 10px;
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
.room-beds {
  display: flex;
  flex-wrap: wrap;
  gap: 3px;
}
.bed {
  width: 8px;
  height: 8px;
  border: 1.5px solid var(--m-muted);
  border-radius: 50%;
  opacity: 0.55;
}
.bed--on {
  border-color: var(--m-primary);
  background: var(--m-primary);
  opacity: 1;
}
.bed--pending {
  border-color: var(--m-warning);
  background: var(--m-warning-soft);
  opacity: 1;
}
.room-occ {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 3px;
  margin-left: auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 11px;
  font-weight: 700;
}
.room-occ--full {
  background: var(--m-bg);
  color: var(--m-muted);
}
.room-none {
  margin: 0;
  padding: 12px;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
.room-list {
  display: flex;
  flex-direction: column;
}
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
/* Rows waiting on a decision carry a warning edge, so they stand out in a
   room of settled tenants without shouting. */
.lease-row--pending,
.lease-row--leave {
  box-shadow: inset 3px 0 var(--m-warning);
}
.lease-row--pending {
  padding-bottom: 10px;
  background: var(--m-warning-soft);
}
.room-list > .lease-row:first-child {
  border-top: 0;
}
.lease-main {
  display: flex;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 10px;
  padding: 4px 0;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  transition: background-color 0.15s ease, opacity 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.lease-main:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
/* While picking a tenant to log a payment for, payable rows highlight so
   they're easy to spot against the rest of the (disabled) list. */
.lease-main--pick {
  padding: 6px 8px;
  margin: 0 -8px;
  background: var(--m-primary-soft);
}
.lease-actions {
  display: flex;
  gap: 8px;
  /* Lines the buttons up under the name, past the avatar. */
  padding-left: 46px;
}
.lease-actions .lease-act {
  flex: 1;
  min-height: 36px;
  font-size: 12.5px;
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
.lease-act:disabled {
  opacity: 0.6;
}
.lease-act--ghost {
  background: var(--m-surface);
  color: var(--m-text);
  border: 1px solid var(--m-border);
}
.lease-msg {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 50%;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.lease-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}
.lease-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
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
  color: var(--m-muted);
  font-size: 11.5px;
}
.lease-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.lease-chip--teal {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.lease-chip--amber,
.lease-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.lease-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.lease-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}



/* Same underline-tab convention used elsewhere in the app (e.g. the tenant
   profile's Overview/Payments/History tabs) — reused here, not reinvented. */
/* Same rounded-top pill tabs feeding into a bordered panel as
   accommodation detail's own tabs (just without the frosted-glass-over-photo
   colors, since there's no hero image behind these). */
/* No gap here (unlike .stack) — the -2px overlap below needs the tabs and
   panel to actually touch, which a flex gap on their shared parent would
   otherwise add back in on top of. */
/* QPullToRefresh wraps the page body in two plain <div>s of its own, which
   land between the q-page and .stack and break the flex chain the bottom-flush
   panel needs — .stack's flex:1 measures against a block box that just hugs its
   content, so the card stops wherever the content happens to end. Passing the
   chain through them costs nothing: neither div clips or scrolls. */
:deep(.q-pull-to-refresh),
:deep(.q-pull-to-refresh__content) {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
}
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  /* -2px, not -1px: an exact 1px overlap can round the wrong way at
     fractional device-pixel ratios (real phones, not desktop @1x) and leave
     a hairline gap of page background under the active tab. The active
     tab's background already equals the panel's, so the extra 1px of
     overlap is invisible — it just guarantees full coverage. */
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
}
.tab-dot {
  display: inline-grid;
  min-width: 16px;
  height: 16px;
  margin-left: 6px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  font-size: 9.5px;
  font-weight: 800;
}
/* Its own card, distinct from .stack's background — the active tab's
   background matches this, so the -1px overlap above fuses them with no
   visible seam, while the unselected tab still shows the border. */
.panel {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  margin: 0 calc(var(--m-page-gutter) * -1);
  /* The dock-clearance reserve lives here, not on .stack — this way the
     card's own background still stretches to the true bottom of the page
     instead of stopping short with a gap of plain page background. */
  padding: 14px 0 126px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
/* The panel has no side padding, so the lists run edge to edge as flat
   sections; only the loose controls and headings keep an inset. */
.panel :is(.acc, .group) {
  border-right: 0;
  border-left: 0;
  border-radius: 0;
}
/* Flat properties butt together, split by a page-coloured band instead of
   .tab-panel's 14px gap, which read as an empty white row between borders. */
.panel .acc + .acc {
  margin-top: -14px;
  border-top: 8px solid var(--m-bg);
}
.panel :is(.top-actions, .picking-hint, .pay-summary, .sec-title, .sec-head, .pay-month-head) {
  margin-right: 12px;
  margin-left: 12px;
}
.panel .sec-head .sec-title {
  margin: 0;
}

.pay-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pay-summary {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 8px;
}
.pay-stat {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.pay-stat-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.pay-stat-label {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.pay-stat--warn {
  border-color: transparent;
  background: var(--m-warning-soft);
}
.pay-stat--warn .pay-stat-value,
.pay-stat--warn .pay-stat-label {
  color: var(--m-warning);
}
.pay-month {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.pay-month + .pay-month {
  margin-top: 6px;
}
.pay-month-head {
  display: flex;
  justify-content: space-between;
  padding: 0 2px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.pay-month-total {
  font-variant-numeric: tabular-nums;
}
.sec-title {
  margin: 0;
  line-height: 1.3;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.sec-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
}
.sec-head .sec-title {
  padding: 0;
}
.sec-link {
  flex: 0 0 auto;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.pay-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .pay-row:first-child {
  border-top: 0;
}
.group--warn > .pay-row {
  box-shadow: inset 3px 0 var(--m-warning);
}
.pay-row-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.pay-row-main,
.pay-row-sub {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.pay-row-name {
  min-width: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pay-row-amount {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.pay-row-amount--void {
  color: var(--m-muted);
  text-decoration: line-through;
}
.pay-row-meta {
  min-width: 0;
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pay-chip {
  flex: 0 0 auto;
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.pay-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-chip--amber,
.pay-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-row-review {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 1px;
  padding: 2px 6px 2px 9px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 700;
}
</style>
