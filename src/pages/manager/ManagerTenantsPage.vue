<template>
  <q-page class="tp">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <div class="tabs">
          <q-skeleton type="rect" width="88px" height="38px" class="sk-tab" />
          <q-skeleton type="rect" width="88px" height="38px" class="sk-tab" />
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
        <q-card flat bordered class="card">
          <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
          <p class="err-title">Couldn't load your tenants</p>
          <p class="err-sub">{{ error }}</p>
          <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load()" />
        </q-card>
      </div>

      <EmptyState
        v-else-if="!accommodations.length"
        icon="lucide:users"
        title="No tenants yet"
        message="When a student applies for one of your rooms and you accept them, they show up here grouped by room — empty beds included, plus any applications still waiting on you."
      />

      <div v-else class="stack">
        <div class="tabbed">
        <div class="tabs">
          <button type="button" class="tab" :class="{ 'tab--on': activeTab === 'tenants' }" @click="activeTab = 'tenants'">
            By tenant
          </button>
          <button type="button" class="tab" :class="{ 'tab--on': activeTab === 'payments' }" @click="activeTab = 'payments'">
            Payments
            <span v-if="paymentsNeedingVerification.length" class="tab-dot">{{ paymentsNeedingVerification.length }}</span>
          </button>
        </div>

        <div class="panel">
        <q-tab-panels v-model="activeTab" animated swipeable class="panels">
          <q-tab-panel name="tenants" class="tab-panel">
            <button type="button" class="sheet-done top-pay-btn" @click="pickingPayment = !pickingPayment">
              <IconifyIcon :icon="pickingPayment ? 'lucide:x' : 'lucide:receipt'" width="16" />
              {{ pickingPayment ? 'Cancel' : 'Log a payment' }}
            </button>
            <p v-if="pickingPayment" class="picking-hint">Tap a tenant below to log their payment.</p>

            <section v-for="acc in visibleAccommodations" :key="acc.id" class="acc">
              <button type="button" class="acc-head" @click="toggleAcc(acc.id)">
                <span class="acc-thumb" :class="`acc-thumb--${occupancyTone(accSummary.get(acc.id)?.occupancyPct ?? 0)}`">
                  <img v-if="acc.coverUrl" :src="acc.coverUrl" alt="" />
                  <IconifyIcon v-else icon="lucide:building-2" width="17" />
                </span>
                <span class="acc-head-body">
                  <h2 class="acc-title">{{ acc.name }}</h2>
                  <span class="acc-stats">
                    <span class="acc-stat"><IconifyIcon icon="lucide:door-open" width="11" />{{ accSummary.get(acc.id)?.rooms ?? acc.rooms.length }}</span>
                    <span class="acc-stat"><IconifyIcon icon="lucide:users" width="11" />{{ accSummary.get(acc.id)?.tenants ?? 0 }}</span>
                  </span>
                </span>
                <span v-if="accAlertCounts.get(acc.id)" class="acc-badge">{{ accAlertCounts.get(acc.id) }}</span>
                <IconifyIcon :icon="collapsedAccIds.has(acc.id) ? 'lucide:chevron-down' : 'lucide:chevron-up'" width="16" class="acc-chevron" />
              </button>
              <div class="acc-occ-track"><span class="acc-occ-fill" :style="{ width: (accSummary.get(acc.id)?.occupancyPct ?? 0) + '%' }" /></div>
              <q-slide-transition>
                <div v-show="!collapsedAccIds.has(acc.id)">
                  <div v-for="room in acc.rooms" :key="room.id" class="room">
                    <div class="room-head">
                      <span class="room-name">{{ room.label }}</span>
                      <span class="room-occ" :class="{ 'room-occ--full': roomOccupancy(room).full }">
                        <IconifyIcon icon="lucide:bed" width="12" />
                        {{ roomOccupancy(room).label }}
                      </span>
                    </div>
                    <div v-if="room.leases.length" class="room-list">
                      <div v-for="l in room.leases" :key="l.id" class="lease-row">
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
                          <span class="lease-chip" :class="`lease-chip--${statusColor(LEASE_STATUS, l.status)}`">
                            {{ statusText(LEASE_STATUS, l.status) }}
                          </span>
                        </button>
                        <div v-if="!pickingPayment && l.status === 'pending'" class="lease-actions">
                          <button
                            type="button"
                            class="lease-act lease-act--ghost"
                            :disabled="decidingId === l.id"
                            @click="decideApplication(l, room.label, 'rejected')"
                          >
                            Decline
                          </button>
                          <button
                            type="button"
                            class="lease-act"
                            :disabled="decidingId === l.id"
                            @click="decideApplication(l, room.label, 'active')"
                          >
                            Accept
                          </button>
                        </div>
                        <button
                          v-else-if="!pickingPayment"
                          type="button"
                          class="lease-msg"
                          aria-label="Message tenant"
                          @click="router.push(`/manager/messages?to=${l.studentId}`)"
                        >
                          <IconifyIcon icon="lucide:message-circle" width="15" />
                        </button>
                      </div>
                    </div>
                    <p v-else class="room-none">No tenants</p>
                  </div>
                </div>
              </q-slide-transition>
            </section>
          </q-tab-panel>

          <q-tab-panel name="payments" class="tab-panel">
            <section v-if="paymentsNeedingVerification.length" class="pay-section">
              <h2 class="sec-title">Needs verification</h2>
              <div class="group">
                <div v-for="p in paymentsNeedingVerification" :key="p.id" class="pay-row">
                  <button type="button" class="pay-row-tap" @click="openPaymentDetail(p)">
                    <div class="pay-row-main">
                      <span class="pay-row-month">{{ p.studentName }}</span>
                      <span class="pay-row-amount">{{ formatPeso(p.amount) }}</span>
                    </div>
                    <div class="pay-row-sub">
                      <span class="pay-row-method">{{ p.roomLabel }} · {{ p.accommodationName }} · {{ formatMonth(p.month) }}</span>
                      <span class="pay-row-review">
                        Tap to review
                        <IconifyIcon icon="lucide:chevron-right" width="13" />
                      </span>
                    </div>
                  </button>
                </div>
              </div>
            </section>

            <section class="pay-section">
              <div class="sec-head">
                <h2 class="sec-title">History</h2>
                <button type="button" class="sec-link" @click="router.push('/manager/profile/history?tab=payments')">View all</button>
              </div>
              <div v-if="recentPayments.length" class="group">
                <button
                  v-for="p in recentPayments"
                  :key="p.id"
                  type="button"
                  class="pay-row pay-row--tap"
                  @click="openPaymentDetail(p)"
                >
                  <div class="pay-row-main">
                    <span class="pay-row-month">{{ p.studentName }}</span>
                    <span class="pay-row-amount">{{ formatPeso(p.amount) }}</span>
                  </div>
                  <div class="pay-row-sub">
                    <span class="pay-row-method">{{ p.roomLabel }} · {{ p.accommodationName }} · {{ formatMonth(p.month) }} · {{ PAYMENT_METHOD_LABEL[p.method] || p.method }}</span>
                    <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">{{ statusText(PAYMENT_STATUS, p.status) }}</span>
                  </div>
                </button>
              </div>
              <EmptyState
                v-else
                variant="compact"
                icon="lucide:receipt"
                title="No payments logged yet"
                message="Payments you log for any tenant will show up here."
              />
            </section>
          </q-tab-panel>
        </q-tab-panels>
        </div>
        </div>
      </div>

    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band.
         Outside the pull-to-refresh wrapper on purpose: it transforms its
         content while you pull, which would drag this fixed dock along. -->
    <div v-if="!loading && !error" class="dock">
      <button
        type="button"
        class="dock-btn"
        :class="{ 'dock-btn--on': filter !== 'all' || selectedAccId !== 'all' }"
        aria-label="Filters"
        @click="filtersOpen = true"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
        <span v-if="filter !== 'all' || selectedAccId !== 'all'" class="dock-dot">1</span>
      </button>
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input
          v-model="query"
          class="dock-input"
          type="search"
          placeholder="Search tenants or rooms"
          aria-label="Search tenants"
        />
      </div>
    </div>

    <q-dialog v-model="filtersOpen" position="bottom">
      <div class="sheet">
        <div class="sheet-head">
          <h2 class="sheet-title">Filters</h2>
          <button type="button" class="sheet-clear" @click="filter = 'all'; selectedAccId = 'all'">Reset</button>
        </div>
        <div v-if="accreditedAccommodations.length > 1" class="sheet-block">
          <span class="sheet-label">Property</span>
          <div class="chips">
            <button type="button" class="chip" :class="{ 'chip--on': selectedAccId === 'all' }" @click="selectedAccId = 'all'">
              All
            </button>
            <button
              v-for="a in accreditedAccommodations"
              :key="a.id"
              type="button"
              class="chip"
              :class="{ 'chip--on': selectedAccId === a.id }"
              @click="selectedAccId = a.id"
            >
              {{ a.name }}
            </button>
          </div>
        </div>
        <div class="sheet-block">
          <span class="sheet-label">Status</span>
          <div class="chips">
            <button
              v-for="f in FILTERS"
              :key="f.key"
              type="button"
              class="chip"
              :class="{ 'chip--on': filter === f.key }"
              @click="filter = f.key"
            >
              {{ f.label }}
            </button>
          </div>
        </div>
        <button type="button" class="sheet-done" @click="filtersOpen = false">Done</button>
      </div>
    </q-dialog>

    <q-dialog v-model="paymentOpen" position="bottom">
      <q-card class="pay-sheet">
        <h3 class="pay-title">Log a payment{{ paymentLease ? ` — ${paymentLease.studentName}` : '' }}</h3>
        <label class="pay-field">
          <span class="pay-label">Month</span>
          <input v-model="paymentForm.month" type="month" class="pay-input" />
        </label>
        <label class="pay-field">
          <span class="pay-label">Amount</span>
          <input v-model.number="paymentForm.amount" type="number" min="0" step="0.01" class="pay-input" />
        </label>
        <label class="pay-field">
          <span class="pay-label">Method</span>
          <select v-model="paymentForm.method" class="pay-input">
            <option value="cash">Cash</option>
            <option value="gcash">GCash</option>
            <option value="maya">Maya</option>
            <option value="bank">Bank transfer</option>
            <option value="others">Other</option>
          </select>
        </label>
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="pay-submit"
          :loading="logging"
          label="Log payment"
          @click="submitPayment"
        />
      </q-card>
    </q-dialog>

    <q-dialog v-model="paymentDetailOpen" position="bottom">
      <q-card v-if="selectedPayment" class="pay-detail-sheet">
        <h3 class="pay-detail-title">{{ formatMonth(selectedPayment.month) }}</h3>
        <span class="pay-detail-chip" :class="`pay-detail-chip--${statusColor(PAYMENT_STATUS, selectedPayment.status)}`">
          {{ statusText(PAYMENT_STATUS, selectedPayment.status) }}
        </span>

        <div class="group">
          <div class="pay-detail-rule">
            <span class="pay-detail-rule-label">Amount</span>
            <span class="pay-detail-rule-value">{{ formatPeso(selectedPayment.amount) }}</span>
          </div>
          <div class="pay-detail-rule">
            <span class="pay-detail-rule-label">Method</span>
            <span class="pay-detail-rule-value">{{ PAYMENT_METHOD_LABEL[selectedPayment.method] || selectedPayment.method }}</span>
          </div>
          <div class="pay-detail-rule">
            <span class="pay-detail-rule-label">Tenant</span>
            <span class="pay-detail-rule-value">{{ selectedPayment.studentName }}</span>
          </div>
          <div class="pay-detail-rule">
            <span class="pay-detail-rule-label">Stay</span>
            <span class="pay-detail-rule-value">{{ selectedPayment.roomLabel }} · {{ selectedPayment.accommodationName }}</span>
          </div>
          <div v-if="selectedPayment.txnReference" class="pay-detail-rule">
            <span class="pay-detail-rule-label">Reference number</span>
            <span class="pay-detail-rule-value">{{ selectedPayment.txnReference }}</span>
          </div>
          <div v-if="selectedPayment.verifiedByName" class="pay-detail-rule">
            <span class="pay-detail-rule-label">Reviewed by</span>
            <span class="pay-detail-rule-value">
              {{ selectedPayment.verifiedByName }}{{ selectedPayment.paidAt ? ` · ${formatDate(selectedPayment.paidAt)}` : '' }}
            </span>
          </div>
        </div>

        <template v-if="selectedPayment.status === 'rejected' && selectedPayment.rejectionReason">
          <p class="pay-detail-label">Rejection reason</p>
          <p class="pay-detail-text">{{ selectedPayment.rejectionReason }}</p>
        </template>

        <template v-if="selectedPayment.description">
          <p class="pay-detail-label">Note</p>
          <p class="pay-detail-text">{{ selectedPayment.description }}</p>
        </template>

        <template v-if="selectedPayment.proofUrl">
          <p class="pay-detail-label">Proof of payment</p>
          <img :src="resolveAsset(selectedPayment.proofUrl)" alt="Proof of payment" class="pay-detail-proof-img" />
        </template>

        <template v-if="selectedPayment.status === 'pending_verification'">
          <div v-if="rejectingId === selectedPayment.id" class="pay-reject-form">
            <label class="pay-detail-label">
              Reason
              <textarea v-model="rejectReason" class="pay-reject-textarea" rows="2" placeholder="Why is this being rejected?" />
            </label>
            <div class="pay-reject-actions">
              <button type="button" class="pay-reject-cancel" @click="rejectingId = ''">Cancel</button>
              <button
                type="button"
                class="pay-reject-confirm"
                :disabled="verifying === selectedPayment.id || !rejectReason.trim()"
                @click="rejectPayment(selectedPayment.id)"
              >
                {{ verifying === selectedPayment.id ? 'Rejecting…' : 'Confirm reject' }}
              </button>
            </div>
          </div>
          <div v-else class="pay-detail-actions">
            <button
              type="button"
              class="sheet-done"
              :disabled="verifying === selectedPayment.id"
              @click="verifyPayment(selectedPayment.id); paymentDetailOpen = false"
            >
              {{ verifying === selectedPayment.id ? 'Verifying…' : 'Mark verified' }}
            </button>
            <button type="button" class="pay-reject-btn" @click="rejectingId = selectedPayment.id; rejectReason = ''">
              Reject
            </button>
          </div>
        </template>

        <q-btn unelevated rounded no-caps color="primary" class="pay-detail-close" label="Close" @click="paymentDetailOpen = false" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { formatDate, formatMonth, formatPeso, initialsOf, LEASE_STATUS, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import { respondToApplication } from '@/utils/applications'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import EmptyState from '@/components/shared/EmptyState.vue'

interface Lease {
  id: string
  status: string
  studentId: string
  studentName: string
  avatarColor: string | null
  avatarUrl: string | null
  startDate: string
  monthlyRent: number
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
const payments = ref<PaymentRow[]>([])
const verifying = ref('')
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

// Only accredited properties are actually live/rented out to students — one
// still in review (or delisted) has no real tenants to manage here.
const accreditedAccommodations = computed(() => accommodations.value.filter((acc) => acc.status === 'accredited'))

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

    // Accommodations and leases both key only off the manager's id, so they go
    // out together; rooms and payments each need an id list from this wave and
    // follow in the second one below.
    const [
      { data: accRows, error: accError },
      { data: leaseRows, error: leaseError },
    ] = await Promise.all([
      supabase
        .from('accommodations')
        .select('id,name,status,accommodation_images(url,sort_order)')
        .eq('accommodation_manager_id', user.id),
      supabase
        .from('leases')
        .select('id,status,room_id,student_id,start_date,monthly_rent,users!leases_student_id_fkey(full_name,avatar_color,avatar_url)')
        .eq('accommodation_manager_id', user.id)
        .in('status', ['active', 'pending', 'leave_requested']),
    ])
    if (accError) throw accError
    if (leaseError) throw leaseError

    const accIds = (accRows ?? []).map((a) => a.id)
    const leaseIds = (leaseRows ?? []).map((l) => l.id)

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
              'id,month,amount,method,status,lease_id,description,txn_reference,proof_url,paid_at,rejection_reason,verified_by_user:users!payments_verified_by_fkey(full_name)',
            )
            .in('lease_id', leaseIds)
            .order('month', { ascending: false })
        : null,
    ])
    if (roomsResult?.error) throw roomsResult.error
    roomRows = roomsResult?.data ?? []
    if (paymentsResult?.error) throw paymentsResult.error
    paymentRows = (paymentsResult?.data ?? []) as unknown as typeof paymentRows

    const leasesByRoom = new Map<string, Lease[]>()
    for (const l of leaseRows ?? []) {
      const student = l.users as unknown as { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
      const list = leasesByRoom.get(l.room_id) ?? []
      list.push({
        id: l.id,
        status: l.status,
        studentId: l.student_id,
        studentName: student?.full_name || 'A student',
        avatarColor: student?.avatar_color ?? null,
        avatarUrl: student?.avatar_url ? resolveAsset(student.avatar_url) : null,
        startDate: l.start_date,
        monthlyRent: Number(l.monthly_rent ?? 0),
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
        coverUrl: cover?.url ? resolveAsset(cover.url) : '',
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
    // Closed by default — a manager opens the properties they're checking,
    // rather than scrolling past every room in every property up front. Only
    // on the real first load: a silent (realtime-triggered) refresh must not
    // collapse whatever the manager already has open.
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
  watch: (uid) => [{ table: 'leases', filter: `accommodation_manager_id=eq.${uid}` }],
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
  if (l.status === 'pending') return `Requested move-in ${formatDate(l.startDate)}`
  const rent = l.monthlyRent ? `${formatPeso(l.monthlyRent)}/mo` : 'Rent not set'
  return l.status === 'leave_requested' ? `Leave requested · ${rent}` : `Since ${formatDate(l.startDate)} · ${rent}`
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

async function decideApplication(l: Lease, roomLabel: string, decision: 'active' | 'rejected') {
  if (decidingId.value) return
  decidingId.value = l.id
  try {
    await respondToApplication(l.id, l.studentId, roomLabel, decision)
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

// Lets a manager log a payment from the top of the page: tapping the top
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
const logging = ref(false)
const paymentForm = reactive({
  month: new Date().toISOString().slice(0, 7),
  amount: 0,
  method: 'cash' as 'cash' | 'gcash' | 'maya' | 'bank' | 'others',
})

function openLogPayment(l: Lease) {
  paymentLease.value = l
  paymentForm.month = new Date().toISOString().slice(0, 7)
  paymentForm.amount = l.monthlyRent
  paymentForm.method = 'cash'
  paymentOpen.value = true
}

async function submitPayment() {
  if (logging.value || !paymentLease.value) return
  logging.value = true
  try {
    const { error: insertError } = await supabase.from('payments').insert({
      lease_id: paymentLease.value.id,
      month: `${paymentForm.month}-01`,
      amount: paymentForm.amount,
      method: paymentForm.method,
      status: 'paid',
      paid_at: new Date().toISOString(),
      verified_by: myId.value,
    })
    if (insertError) throw insertError
    paymentOpen.value = false
    notify.success('Payment logged.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not log this payment.'))
  } finally {
    logging.value = false
  }
}

async function verifyPayment(paymentId: string) {
  if (verifying.value) return
  verifying.value = paymentId
  try {
    const paidAt = new Date().toISOString()
    const { error: updateError } = await supabase
      .from('payments')
      .update({ status: 'paid', paid_at: paidAt, verified_by: myId.value })
      .eq('id', paymentId)
    if (updateError) throw updateError
    const row = payments.value.find((p) => p.id === paymentId)
    if (row) {
      row.status = 'paid'
      row.paidAt = paidAt
      row.verifiedByName = 'You'
      if (row.studentId) {
        void createNotification(row.studentId, 'Payment verified', `Your payment for ${row.roomLabel} was marked as paid.`, 'payment', '/student/payments')
      }
    }
    notify.success('Payment verified.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not verify this payment.'))
  } finally {
    verifying.value = ''
  }
}

const rejectingId = ref('')
const rejectReason = ref('')

async function rejectPayment(paymentId: string) {
  const reason = rejectReason.value.trim()
  if (verifying.value || !reason) return
  verifying.value = paymentId
  try {
    const { error: updateError } = await supabase
      .from('payments')
      .update({ status: 'rejected', rejection_reason: reason, verified_by: myId.value })
      .eq('id', paymentId)
    if (updateError) throw updateError
    const row = payments.value.find((p) => p.id === paymentId)
    if (row) {
      row.status = 'rejected'
      row.rejectionReason = reason
      row.verifiedByName = 'You'
      if (row.studentId) {
        void createNotification(row.studentId, 'Payment rejected', `Your payment for ${row.roomLabel} was rejected. Reason: ${reason}`, 'payment', '/student/payments')
      }
    }
    notify.success('Payment rejected.')
    rejectingId.value = ''
    paymentDetailOpen.value = false
  } catch (e) {
    notify.error(errorMessage(e, 'Could not reject this payment.'))
  } finally {
    verifying.value = ''
  }
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
.sk-tab {
  border-radius: 10px 10px 0 0;
}

.card {
  margin: 8px var(--m-page-gutter);
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
}

/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */
.dock {
  position: fixed;
  bottom: 68px;
  left: var(--m-page-gutter);
  right: var(--m-page-gutter);
  z-index: 60;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dock-field {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 8px;
  height: 44px;
  padding: 0 14px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
}
.dock-field:focus-within {
  border-color: var(--m-primary);
}
.dock-icon {
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input::placeholder {
  color: var(--m-muted);
  opacity: 0.85;
}
.dock-input:focus {
  outline: none;
}
.dock-btn {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 50%;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.dock-btn--on {
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.dock-dot {
  position: absolute;
  top: -2px;
  right: -2px;
  display: grid;
  min-width: 17px;
  height: 17px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}

/* Filter sheet */
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 14px;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.sheet-clear {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.sheet-block {
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.sheet-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.chip {
  padding: 6px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.sheet-done {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.pay-detail-actions {
  display: flex;
  gap: 8px;
}
.pay-detail-actions .sheet-done {
  flex: 1;
}
.pay-reject-btn {
  flex: 0 0 auto;
  min-height: 48px;
  padding: 0 18px;
  border: 1px solid var(--m-danger);
  border-radius: 999px;
  background: var(--m-danger-soft);
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.pay-reject-form {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pay-reject-textarea {
  display: block;
  width: 100%;
  min-height: 60px;
  margin-top: 4px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  resize: vertical;
}
.pay-reject-actions {
  display: flex;
  gap: 8px;
}
.pay-reject-cancel {
  flex: 0 0 auto;
  min-height: 44px;
  padding: 0 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pay-reject-confirm {
  flex: 1;
  min-height: 44px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pay-reject-confirm:disabled {
  opacity: 0.6;
}
.top-pay-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}
.picking-hint {
  margin: -6px 2px 0;
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
  gap: 10px;
  padding: 9px 12px;
  border: 0;
  background: var(--m-bg);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
/* A real bar sitting below the header card, not folded into it — shows
   how full the property is before you even expand its rooms. */
.acc-occ-track {
  height: 6px;
  background: var(--m-border);
  overflow: hidden;
}
.acc-occ-fill {
  display: block;
  height: 100%;
  background: var(--m-primary);
}
.acc-thumb {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
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
.acc-title {
  margin: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.acc-stats {
  display: flex;
  align-items: center;
  gap: 8px;
}
.acc-stat {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
}
.acc-badge {
  display: grid;
  min-width: 17px;
  height: 17px;
  flex: 0 0 auto;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}
.acc-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.room {
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--m-border);
}
.room-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 9px 12px;
  background: var(--m-bg);
}
.room-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.room-occ {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 3px;
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
  align-items: center;
  gap: 6px;
  padding: 6px 8px 6px 12px;
  border-top: 1px solid var(--m-border);
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
  flex: 0 0 auto;
  gap: 6px;
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
  background: var(--m-bg);
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

.pay-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.pay-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.pay-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.pay-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.pay-submit {
  min-height: 48px;
  font-weight: 700;
}

.pay-detail-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.pay-detail-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.pay-detail-chip {
  align-self: flex-start;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.pay-detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-detail-chip--amber,
.pay-detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-detail-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.pay-detail-rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .pay-detail-rule:first-child {
  border-top: 0;
}
.pay-detail-rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.pay-detail-rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}
.pay-detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.pay-detail-proof-img {
  width: 100%;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
.pay-detail-close {
  min-height: 46px;
  font-weight: 700;
}

/* Same underline-tab convention used elsewhere in the app (e.g. the tenant
   profile's Overview/Payments/History tabs) — reused here, not reinvented. */
/* Same rounded-top pill tabs feeding into a bordered panel as
   accommodation detail's own tabs (just without the frosted-glass-over-photo
   colors, since there's no hero image behind these). */
/* No gap here (unlike .stack) — the -2px overlap below needs the tabs and
   panel to actually touch, which a flex gap on their shared parent would
   otherwise add back in on top of. */
.tabbed {
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
.tab {
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-bottom: none;
  border-radius: 10px 10px 0 0;
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  transition: background-color 0.15s ease, color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  background: var(--m-surface);
  color: var(--m-primary-dark);
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
  padding: 14px 14px 126px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.panels {
  background: transparent;
}
.panels :deep(.q-tab-panel) {
  padding: 0;
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.pay-section {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-title {
  margin: 0;
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
  flex-direction: column;
  gap: 4px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .pay-row:first-child {
  border-top: 0;
}
/* .pay-row-tap: the tappable inner area in "Needs verification" rows, kept
   separate from the row's own "Mark verified" button (a button can't nest
   inside another button). .pay-row--tap: the "History" row is its own
   button since it has no other action to keep separate from. */
.pay-row-tap,
.pay-row--tap {
  display: flex;
  flex-direction: column;
  gap: 4px;
  width: 100%;
  border: 0;
  background: transparent;
  padding: 0;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.pay-row--tap {
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .pay-row--tap:first-child {
  border-top: 0;
}
.pay-row-main,
.pay-row-sub {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.pay-row-month,
.pay-row-amount {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.pay-row-method {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
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
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 700;
}
</style>
