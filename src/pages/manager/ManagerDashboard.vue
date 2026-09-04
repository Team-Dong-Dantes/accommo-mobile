<template>
  <q-page class="dashboard-page">
    <main class="dashboard-shell" aria-label="Accommodation manager dashboard">

      <div v-if="loading" class="dashboard-content" role="status" aria-live="polite">
        <span class="sr-only">Loading your operations dashboard</span>
        <section class="section-block" aria-hidden="true">
          <div class="skeleton-heading">
            <q-skeleton type="text" width="146px" height="28px" />
            <q-skeleton type="text" width="74px" />
          </div>
          <div class="surface queue-skeleton">
            <div v-for="row in 4" :key="row" class="skeleton-row">
              <q-skeleton type="QAvatar" size="40px" />
              <div class="skeleton-lines">
                <q-skeleton type="text" width="64%" />
                <q-skeleton type="text" width="42%" />
              </div>
              <q-skeleton type="text" width="28px" />
            </div>
          </div>
        </section>

        <section class="section-block" aria-hidden="true">
          <q-skeleton type="text" width="128px" height="28px" />
          <div class="operations-grid">
            <q-skeleton v-for="cell in 4" :key="cell" class="operation-skeleton" />
          </div>
        </section>
      </div>

      <section v-else-if="loadError" class="page-state surface" role="alert">
        <span class="state-icon status-danger" aria-hidden="true">
          <IconifyIcon icon="lucide:cloud-alert" />
        </span>
        <h2>Dashboard could not load</h2>
        <p>{{ loadError }}</p>
        <q-btn no-caps unelevated class="state-action" :loading="loading" @click="loadDashboard">
          <IconifyIcon icon="lucide:refresh-cw" class="button-icon" aria-hidden="true" />
          Try again
        </q-btn>
      </section>

      <template v-else>
        <section v-if="accountBlocked" class="page-state surface account-locked" aria-labelledby="account-locked-title">
          <span class="state-icon status-warning" aria-hidden="true">
            <IconifyIcon icon="lucide:shield-alert" />
          </span>
          <h2 id="account-locked-title">Account awaiting OSAS verification</h2>
          <p>Your accommodation manager account is not yet approved by OSAS. You can browse, but actions on Accommo are locked until your documents are verified. Check back after OSAS confirms your accreditation.</p>
          <q-btn no-caps unelevated class="state-action" :loading="loading" @click="loadDashboard">
            <IconifyIcon icon="lucide:refresh-cw" class="button-icon" aria-hidden="true" />
            Refresh status
          </q-btn>
        </section>
        <div v-else class="dashboard-content">

        <section class="manager-briefing" aria-labelledby="dashboard-title">
          <div class="dashboard-intro">
            <div>
              <h1 id="dashboard-title">{{ greeting }}, {{ managerFirstName }}.</h1>
              <p>{{ propertyCountLabel }} · {{ totalRoomCount }} {{ totalRoomCount === 1 ? 'room' : 'rooms' }} under management</p>
            </div>
          </div>

          <div class="portfolio-pulse" aria-labelledby="portfolio-pulse-title">
            <div class="portfolio-pulse__main">
              <span class="portfolio-pulse__eyebrow">Portfolio occupancy</span>
              <strong id="portfolio-pulse-title">{{ totalOccupiedSpaces }}<small> / {{ totalCapacity }} residents</small></strong>
              <div class="portfolio-pulse__meter" aria-hidden="true"><span :style="{ width: `${portfolioOccupancyPercent}%` }" /></div>
              <p>{{ availableSpaces }} spaces currently open</p>
            </div>
            <div class="portfolio-pulse__payments">
              <span>Collected this month</span>
              <strong>{{ peso(paidThisMonth) }}</strong>
              <small :class="{ 'portfolio-pulse__warning': outstandingAmount > 0 }">
                {{ outstandingAmount > 0 ? `${peso(outstandingAmount)} outstanding` : 'No outstanding balance' }}
              </small>
            </div>
          </div>
        </section>

        <section class="section-block attention-section" aria-labelledby="attention-title">
          <div class="section-heading">
            <div>
              <p class="section-kicker">Action queue</p>
              <h2 id="attention-title">Needs your attention</h2>
            </div>
            <span v-if="attentionItems.length" class="attention-total">
              {{ totalAttentionCount }} {{ totalAttentionCount === 1 ? 'item' : 'items' }}
            </span>
          </div>

          <q-list v-if="attentionItems.length" class="surface attention-list" separator>
            <q-item
              v-for="item in attentionItems"
              :key="item.id"
              v-ripple
              clickable
              :to="item.route"
              class="attention-row"
            >
              <q-item-section avatar>
                <span class="queue-icon" :class="`status-${item.tone}`" aria-hidden="true">
                  <IconifyIcon :icon="item.icon" />
                </span>
              </q-item-section>

              <q-item-section>
                <q-item-label class="row-title">{{ item.title }}</q-item-label>
                <q-item-label caption class="row-caption">{{ item.detail }}</q-item-label>
              </q-item-section>

              <q-item-section side class="queue-side">
                <span class="queue-count" :class="`status-${item.tone}`">{{ item.count }}</span>
                <IconifyIcon icon="lucide:chevron-right" class="chevron" aria-hidden="true" />
              </q-item-section>
            </q-item>
          </q-list>

          <div v-else class="surface all-clear" role="status">
            <span class="state-icon status-success" aria-hidden="true">
              <IconifyIcon icon="lucide:circle-check" />
            </span>
            <div>
              <h3>You are all caught up</h3>
              <p>No urgent payment, tenant, support, or accreditation tasks.</p>
            </div>
          </div>
        </section>

        <section class="section-block" aria-labelledby="operations-title">
          <div class="section-heading compact-heading">
            <div>
              <h2 id="operations-title">At a glance</h2>
              <p class="section-description">Room and collection totals across your portfolio.</p>
            </div>
          </div>

          <div class="operations-grid">
            <article v-for="metric in operationMetrics" :key="metric.id" class="operation-card" :class="`operation-card--${metric.id}`">
              <div class="operation-card__top">
                <span class="metric-icon" aria-hidden="true"><IconifyIcon :icon="metric.icon" /></span>
                <span class="operation-card__label">{{ metric.label }}</span>
              </div>
              <strong>{{ metric.value }}</strong>
              <small>{{ metric.detail }}</small>
            </article>
          </div>
        </section>

        <div class="detail-grid">
          <section class="section-block" aria-labelledby="property-health-title">
            <div class="section-heading compact-heading">
              <div>
                <h2 id="property-health-title">Property health</h2>
                <p class="section-description">Occupancy and OSAS standing</p>
              </div>
            </div>

            <q-list v-if="properties.length" class="surface health-list" separator>
              <q-item
                v-for="property in properties"
                :key="property.id"
                v-ripple
                clickable
                :to="`/manager/properties/${property.id}`"
                class="health-row"
              >
                <q-item-section>
                  <div class="health-topline">
                    <q-item-label class="row-title property-name">{{ property.name }}</q-item-label>
                    <span class="status-pill" :class="`status-${property.accreditation.tone}`">
                      {{ property.accreditation.label }}
                    </span>
                  </div>
                  <div class="occupancy-line">
                    <span>{{ property.occupiedPax }} of {{ property.capacity }} spaces occupied</span>
                    <strong>{{ property.occupancyPercent }}%</strong>
                  </div>
                  <q-linear-progress
                    :value="property.occupancyPercent / 100"
                    color="teal-7"
                    track-color="grey-3"
                    rounded
                    size="6px"
                    :aria-label="`${property.name} is ${property.occupancyPercent}% occupied`"
                  />
                  <p class="health-note">{{ property.accreditation.detail }}</p>
                </q-item-section>
                <q-item-section side>
                  <IconifyIcon icon="lucide:chevron-right" class="chevron" aria-hidden="true" />
                </q-item-section>
              </q-item>
            </q-list>

                        <div v-else class="surface section-empty health-empty">
              <IconifyIcon icon="lucide:building-2" aria-hidden="true" />
              <p>No properties yet. Add your first accommodation to see rooms, tenants and accreditation here.</p>
              <q-btn no-caps unelevated dense class="health-add" to="/manager/properties/new">
                <IconifyIcon icon="lucide:plus" class="button-icon" aria-hidden="true" />
                Add accommodation
              </q-btn>
            </div>
          </section>

          <section class="section-block" aria-labelledby="payments-title">
            <div class="section-heading payments-heading">
              <div>
                <h2 id="payments-title">Recent payment activity</h2>
                <p class="section-description">Latest records from your tenants</p>
              </div>
              <q-btn flat no-caps class="view-all-button" to="/manager/payments" aria-label="View all payments">
                View all
                <IconifyIcon icon="lucide:arrow-right" class="button-icon" aria-hidden="true" />
              </q-btn>
            </div>

            <q-list v-if="recentPayments.length" class="surface payment-list" separator>
              <q-item
                v-for="payment in recentPayments"
                :key="payment.id"
                v-ripple
                clickable
                to="/manager/payments"
                class="payment-row"
              >
                <q-item-section avatar>
                  <q-avatar size="40px" class="tenant-avatar">{{ payment.initials }}</q-avatar>
                </q-item-section>
                <q-item-section>
                  <q-item-label class="row-title">{{ payment.name }}</q-item-label>
                  <q-item-label caption class="row-caption">{{ payment.meta }}</q-item-label>
                  <q-item-label v-if="payment.property" caption class="property-caption">
                    {{ payment.property }}
                  </q-item-label>
                </q-item-section>
                <q-item-section side class="payment-side">
                  <strong>{{ payment.amount }}</strong>
                  <span class="status-pill" :class="`status-${payment.tone}`">{{ payment.status }}</span>
                </q-item-section>
              </q-item>
            </q-list>

            <div v-else class="surface section-empty">
              <IconifyIcon icon="lucide:receipt-text" aria-hidden="true" />
              <p>No payment records yet.</p>
            </div>
          </section>
        </div>
      </div>
      </template>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { supabase } from '@/shared/utils/supabase'

type StatusTone = 'danger' | 'warning' | 'success' | 'neutral'

interface AccommodationRecord {
  id: string
  name: string | null
  business_name: string | null
  total_rooms: number | null
  accreditation_status: string | null
  accreditation_expires_at: string | null
}

interface RoomRecord {
  id: string
  accommodation_id: string
  current_pax: number | null
  capacity: number | null
}

interface LeaseRecord {
  id: string
  student_id: string
  room_id: string
  status: string
  leave_requested_at: string | null
}

interface TicketRecord {
  id: string
  status: string
  priority: string
}

interface PaymentRecord {
  id: string
  lease_id: string
  amount: number
  status: string
  month: string
  method: string
  paid_at: string | null
}

interface UserRecord {
  id: string
  full_name: string | null
}

interface AttentionItem {
  id: string
  title: string
  detail: string
  count: number
  icon: string
  tone: StatusTone
  route: string
}

interface PropertyHealth {
  id: string
  name: string
  occupiedPax: number
  capacity: number
  occupancyPercent: number
  accreditation: {
    label: string
    detail: string
    tone: StatusTone
  }
}

interface PaymentActivity {
  id: string
  name: string
  initials: string
  property: string
  meta: string
  amount: string
  status: string
  tone: StatusTone
}

const loading = ref(true)
const loadError = ref<string | null>(null)
const accommodations = ref<AccommodationRecord[]>([])
const rooms = ref<RoomRecord[]>([])
const leases = ref<LeaseRecord[]>([])
const tickets = ref<TicketRecord[]>([])
const payments = ref<PaymentRecord[]>([])
const studentNames = ref<Map<string, string>>(new Map())
const managerName = ref('Manager')
const accountBlocked = ref(false)

const managerFirstName = computed(() => managerName.value.trim().split(/\s+/)[0] || 'Manager')
const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return 'Good morning'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
})

const propertyCountLabel = computed(() =>
  `${accommodations.value.length} ${accommodations.value.length === 1 ? 'property' : 'properties'}`,
)

const currentMonthBounds = computed(() => {
  const today = new Date()
  return {
    start: new Date(today.getFullYear(), today.getMonth(), 1).getTime(),
    end: new Date(today.getFullYear(), today.getMonth() + 1, 1).getTime(),
  }
})

const paidThisMonth = computed(() =>
  payments.value
    .filter((payment) => {
      if (payment.status !== 'paid' || !payment.paid_at) return false
      const paidAt = new Date(payment.paid_at).getTime()
      return paidAt >= currentMonthBounds.value.start && paidAt < currentMonthBounds.value.end
    })
    .reduce((sum, payment) => sum + Number(payment.amount || 0), 0),
)

const outstandingAmount = computed(() =>
  payments.value
    .filter((payment) => payment.status === 'due' || payment.status === 'overdue')
    .reduce((sum, payment) => sum + Number(payment.amount || 0), 0),
)

const activeLeaseCountByRoom = computed(() => {
  const counts = new Map<string, number>()
  leases.value
    .filter((lease) => lease.status === 'active' || lease.status === 'leave_requested')
    .forEach((lease) => counts.set(lease.room_id, (counts.get(lease.room_id) || 0) + 1))
  return counts
})

function roomPax(room: RoomRecord) {
  return room.current_pax == null
    ? activeLeaseCountByRoom.value.get(room.id) || 0
    : Math.max(Number(room.current_pax) || 0, 0)
}

const occupiedRoomCount = computed(() => rooms.value.filter((room) => roomPax(room) > 0).length)
const totalRoomCount = computed(() => {
  const declared = accommodations.value.reduce(
    (sum, accommodation) => sum + Math.max(Number(accommodation.total_rooms) || 0, 0),
    0,
  )
  return Math.max(declared, rooms.value.length)
})
const availableRoomCount = computed(() => Math.max(totalRoomCount.value - occupiedRoomCount.value, 0))
const totalCapacity = computed(() => rooms.value.reduce((sum, room) => sum + Math.max(Number(room.capacity) || 0, 0), 0))
const totalOccupiedSpaces = computed(() => rooms.value.reduce((sum, room) => sum + roomPax(room), 0))
const availableSpaces = computed(() => Math.max(totalCapacity.value - totalOccupiedSpaces.value, 0))
const portfolioOccupancyPercent = computed(() => totalCapacity.value
  ? Math.min(Math.round((totalOccupiedSpaces.value / totalCapacity.value) * 100), 100)
  : 0)

const operationMetrics = computed(() => [
  {
    id: 'collected',
    label: 'Collected',
    value: peso(paidThisMonth.value),
    detail: 'Paid this month',
    icon: 'lucide:wallet-cards',
  },
  {
    id: 'outstanding',
    label: 'Outstanding',
    value: peso(outstandingAmount.value),
    detail: 'Due and overdue',
    icon: 'lucide:receipt',
  },
  {
    id: 'occupied',
    label: 'Occupied rooms',
    value: String(occupiedRoomCount.value),
    detail: `of ${totalRoomCount.value} rooms`,
    icon: 'lucide:door-closed',
  },
  {
    id: 'available',
    label: 'Available rooms',
    value: String(availableRoomCount.value),
    detail: 'Ready for occupancy',
    icon: 'lucide:door-open',
  },
])

const accreditationAttention = computed(() => {
  const now = Date.now()
  const thirtyDaysFromNow = now + 30 * 24 * 60 * 60 * 1000
  let pending = 0
  let expiring = 0
  let expired = 0

  accommodations.value.forEach((accommodation) => {
    const status = (accommodation.accreditation_status || '').toLowerCase()
    const expiry = accommodation.accreditation_expires_at
      ? new Date(accommodation.accreditation_expires_at).getTime()
      : null
    const isExpired = status === 'expired' || (expiry !== null && expiry < now)
    const isExpiring = !isExpired && expiry !== null && expiry <= thirtyDaysFromNow
    const isPending = !isExpired && !isExpiring && ['', 'pending', 'reviewing', 'submitted'].includes(status)

    if (isExpired) expired += 1
    else if (isExpiring) expiring += 1
    else if (isPending) pending += 1
  })

  return { pending, expiring, expired, total: pending + expiring + expired }
})

const attentionItems = computed<AttentionItem[]>(() => {
  const overdue = payments.value.filter((payment) => payment.status === 'overdue')
  const pendingPayments = payments.value.filter((payment) => payment.status === 'pending_verification')
  const leaveRequests = leases.value.filter(
    (lease) =>
      lease.status === 'leave_requested' ||
      (lease.status === 'active' && Boolean(lease.leave_requested_at)),
  )
  const openTickets = tickets.value.filter(
    (ticket) => !['resolved', 'closed', 'cancelled', 'canceled'].includes(ticket.status.toLowerCase()),
  )
  const highPriorityTickets = openTickets.filter((ticket) =>
    ['high', 'urgent', 'critical'].includes(ticket.priority.toLowerCase()),
  )
  const result: AttentionItem[] = []

  if (overdue.length) {
    const amount = overdue.reduce((sum, payment) => sum + Number(payment.amount || 0), 0)
    result.push({
      id: 'overdue',
      title: 'Overdue payments',
      detail: `${peso(amount)} needs collection`,
      count: overdue.length,
      icon: 'lucide:circle-alert',
      tone: 'danger',
      route: '/manager/payments',
    })
  }

  if (pendingPayments.length) {
    const amount = pendingPayments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0)
    result.push({
      id: 'verification',
      title: 'Payments to verify',
      detail: `${peso(amount)} awaiting review`,
      count: pendingPayments.length,
      icon: 'lucide:file-check-2',
      tone: 'warning',
      route: '/manager/payments',
    })
  }

  if (leaveRequests.length) {
    result.push({
      id: 'leave',
      title: 'Leave requests',
      detail: 'Review requested move-out dates',
      count: leaveRequests.length,
      icon: 'lucide:log-out',
      tone: 'warning',
      route: '/manager/tenants',
    })
  }

  if (openTickets.length) {
    result.push({
      id: 'tickets',
      title: 'Open support tickets',
      detail: highPriorityTickets.length
        ? `${highPriorityTickets.length} high priority · ${openTickets.length} open`
        : `${openTickets.length} awaiting resolution`,
      count: openTickets.length,
      icon: 'lucide:wrench',
      tone: highPriorityTickets.length ? 'danger' : 'warning',
      route: '/manager/support',
    })
  }

  if (accreditationAttention.value.total) {
    const parts = [
      accreditationAttention.value.expired ? `${accreditationAttention.value.expired} expired` : '',
      accreditationAttention.value.expiring ? `${accreditationAttention.value.expiring} expiring soon` : '',
      accreditationAttention.value.pending ? `${accreditationAttention.value.pending} pending` : '',
    ].filter(Boolean)
    result.push({
      id: 'accreditation',
      title: 'Accreditation needs attention',
      detail: parts.join(' · '),
      count: accreditationAttention.value.total,
      icon: 'lucide:badge-check',
      tone: accreditationAttention.value.expired ? 'danger' : 'warning',
      route: '/manager/osas-compliance',
    })
  }

  return result
})

const totalAttentionCount = computed(() =>
  attentionItems.value.reduce((sum, item) => sum + item.count, 0),
)

const properties = computed<PropertyHealth[]>(() =>
  accommodations.value.map((accommodation) => {
    const propertyRooms = rooms.value.filter((room) => room.accommodation_id === accommodation.id)
    const occupiedPax = propertyRooms.reduce((sum, room) => sum + roomPax(room), 0)
    const capacity = propertyRooms.reduce(
      (sum, room) => sum + Math.max(Number(room.capacity) || 1, 1),
      0,
    )
    return {
      id: accommodation.id,
      name: accommodation.business_name || accommodation.name || 'Accommodation',
      occupiedPax,
      capacity,
      occupancyPercent: capacity ? Math.min(Math.round((occupiedPax / capacity) * 100), 100) : 0,
      accreditation: accreditationPresentation(accommodation),
    }
  }),
)

const recentPayments = computed<PaymentActivity[]>(() => {
  const leaseById = new Map(leases.value.map((lease) => [lease.id, lease]))
  const roomById = new Map(rooms.value.map((room) => [room.id, room]))
  const accommodationById = new Map(accommodations.value.map((item) => [item.id, item]))

  return [...payments.value]
    .sort((a, b) => paymentTimestamp(b) - paymentTimestamp(a))
    .slice(0, 5)
    .map((payment) => {
      const lease = leaseById.get(payment.lease_id)
      const room = lease ? roomById.get(lease.room_id) : undefined
      const accommodation = room ? accommodationById.get(room.accommodation_id) : undefined
      const name = (lease && studentNames.value.get(lease.student_id)) || 'Tenant payment'
      const status = paymentStatusPresentation(payment.status)
      return {
        id: payment.id,
        name,
        initials: initialsOf(name),
        property: accommodation?.business_name || accommodation?.name || '',
        meta: `${paymentDateLabel(payment)} · ${methodLabel(payment.method)}`,
        amount: peso(Number(payment.amount || 0)),
        status: status.label,
        tone: status.tone,
      }
    })
})

function initialsOf(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return 'LL'
  if (parts.length === 1) return (parts[0] || 'LL').slice(0, 2).toUpperCase()
  return `${parts[0]?.[0] || ''}${parts[parts.length - 1]?.[0] || ''}`.toUpperCase()
}

function peso(value: number) {
  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    maximumFractionDigits: 0,
  }).format(value)
}

function formatDate(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Date unavailable'
  return date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
}

function paymentTimestamp(payment: PaymentRecord) {
  if (payment.paid_at) {
    const timestamp = new Date(payment.paid_at).getTime()
    if (!Number.isNaN(timestamp)) return timestamp
  }
  const monthTimestamp = new Date(payment.month).getTime()
  return Number.isNaN(monthTimestamp) ? 0 : monthTimestamp
}

function paymentDateLabel(payment: PaymentRecord) {
  if (payment.paid_at) return formatDate(payment.paid_at)
  return payment.month || 'Payment date unavailable'
}

function methodLabel(method: string) {
  return (method || 'Method unavailable')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase())
}

function paymentStatusPresentation(status: string): { label: string; tone: StatusTone } {
  const presentations: Record<string, { label: string; tone: StatusTone }> = {
    paid: { label: 'Paid', tone: 'success' },
    overdue: { label: 'Overdue', tone: 'danger' },
    pending_verification: { label: 'Pending review', tone: 'warning' },
    due: { label: 'Due', tone: 'neutral' },
  }
  return presentations[status] || {
    label: status ? methodLabel(status) : 'Unknown',
    tone: 'neutral',
  }
}

function accreditationPresentation(accommodation: AccommodationRecord) {
  const status = (accommodation.accreditation_status || '').toLowerCase()
  const expiry = accommodation.accreditation_expires_at
    ? new Date(accommodation.accreditation_expires_at).getTime()
    : null
  const now = Date.now()
  const soon = now + 30 * 24 * 60 * 60 * 1000

  if (status === 'rejected' || status === 'delisted') {
    return { label: methodLabel(status), detail: 'Action is required with OSAS', tone: 'danger' as const }
  }
  if (status === 'expired' || (expiry !== null && expiry < now)) {
    return { label: 'Expired', detail: 'Renew accreditation with OSAS', tone: 'danger' as const }
  }
  if (expiry !== null && expiry <= soon) {
    return {
      label: 'Expiring',
      detail: `Accreditation expires ${formatDate(accommodation.accreditation_expires_at || '')}`,
      tone: 'warning' as const,
    }
  }
  if (['pending', 'reviewing', 'submitted', ''].includes(status)) {
    return {
      label: status === 'reviewing' ? 'In review' : 'Pending',
      detail: 'Accreditation is awaiting completion',
      tone: 'warning' as const,
    }
  }
  if (status === 'accredited' || status === 'active' || status === 'approved') {
    return {
      label: 'Accredited',
      detail: accommodation.accreditation_expires_at
        ? `Valid until ${formatDate(accommodation.accreditation_expires_at)}`
        : 'Accreditation is active',
      tone: 'success' as const,
    }
  }
  return { label: methodLabel(status), detail: 'Check accreditation details', tone: 'neutral' as const }
}

async function loadDashboard() {
  loading.value = true
  loadError.value = null
  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) throw new Error('Please sign in again to view your dashboard.')

    const user = authData.user
    const [profileResult, accommodationResult] = await Promise.all([
      supabase.from('users').select('id, full_name, status').eq('id', user.id).maybeSingle(),
      (supabase as any)
        .from('accommodations')
        .select('id, name, business_name, total_rooms, accreditation_status, accreditation_expires_at')
        .eq('accommodation_manager_id', user.id)
        .order('name'),
    ])

    if (profileResult.error) throw profileResult.error
    if (accommodationResult.error) throw accommodationResult.error

    const accountStatus = (profileResult.data as { status?: string | null } | null)?.status ?? 'unverified'
    accountBlocked.value = accountStatus.toLowerCase() !== 'verified'

    managerName.value = profileResult.data?.full_name || 'Manager'

    // OSAS must have verified the manager account (users.status='verified') before the
    // account becomes usable. DB/RLS is the backstop; here we gate the landing surface.
    if (accountBlocked.value) {
      rooms.value = []
      leases.value = []
      tickets.value = []
      payments.value = []
      studentNames.value = new Map()
      return
    }

    accommodations.value = (accommodationResult.data || []) as AccommodationRecord[]

    if (!accommodations.value.length) {
      rooms.value = []
      leases.value = []
      tickets.value = []
      payments.value = []
      studentNames.value = new Map()
      return
    }

    const accommodationIds = accommodations.value.map((accommodation) => accommodation.id)
    const [roomResult, leaseResult, ticketResult] = await Promise.all([
      (supabase as any)
        .from('rooms')
        .select('id, accommodation_id, current_pax, capacity')
        .in('accommodation_id', accommodationIds),
      (supabase as any)
        .from('leases')
        .select('id, student_id, room_id, status, leave_requested_at')
        .eq('accommodation_manager_id', user.id),
      (supabase as any)
        .from('tickets')
        .select('id, status, priority')
        .eq('accommodation_manager_id', user.id),
    ])

    if (roomResult.error) throw roomResult.error
    if (leaseResult.error) throw leaseResult.error
    if (ticketResult.error) throw ticketResult.error

    rooms.value = (roomResult.data || []) as RoomRecord[]
    leases.value = (leaseResult.data || []) as LeaseRecord[]
    tickets.value = (ticketResult.data || []) as TicketRecord[]

    const leaseIds = leases.value.map((lease) => lease.id)
    if (!leaseIds.length) {
      payments.value = []
      studentNames.value = new Map()
      return
    }

    const paymentResult = await (supabase as any)
      .from('payments')
      .select('id, lease_id, amount, status, month, method, paid_at')
      .in('lease_id', leaseIds)

    if (paymentResult.error) throw paymentResult.error
    payments.value = (paymentResult.data || []) as PaymentRecord[]

    const studentIds = Array.from(new Set(leases.value.map((lease) => lease.student_id).filter(Boolean)))
    if (studentIds.length) {
      const studentResult = await supabase.from('users').select('id, full_name').in('id', studentIds)
      if (studentResult.error) throw studentResult.error
      studentNames.value = new Map(
        ((studentResult.data || []) as UserRecord[])
          .filter((student) => Boolean(student.full_name))
          .map((student) => [student.id, student.full_name || '']),
      )
    } else {
      studentNames.value = new Map()
    }
  } catch (error) {
    console.error('loadDashboard error:', error)
    loadError.value = 'We could not retrieve your latest operations data. Check your connection and try again.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void loadDashboard()
})
</script>

<style scoped>
.dashboard-page {
  min-height: 100%;
  background: var(--m-bg);
  color: var(--m-text);
}

.dashboard-shell {
  width: 100%;
  max-width: 960px;
  margin: 0 auto;
  padding: max(var(--m-space-3), env(safe-area-inset-top)) var(--m-page-gutter)
    max(112px, calc(var(--m-space-8) + env(safe-area-inset-bottom)));
}

.eyebrow,
.section-kicker {
  margin: 0 0 var(--m-space-1);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.section-description {
  margin: var(--m-space-1) 0 0;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}

.attention-row:focus-visible,
.health-row:focus-visible,
.payment-row:focus-visible,
.view-all-button:focus-visible,
.state-action:focus-visible {
  outline: 2px solid var(--m-primary);
  outline-offset: 2px;
}

.dashboard-content,
.section-block {
  display: grid;
  gap: var(--m-space-3);
}

.dashboard-content {
  gap: var(--m-space-6);
}

.manager-briefing {
  overflow: hidden;
  border-radius: 14px;
  background: #0e2e2a;
  color: #eaf4f1;
}

.dashboard-intro {
  padding: var(--m-space-4);
}

.dashboard-intro h1 {
  margin: 0;
  color: #eaf4f1;
  font-family: var(--m-font-display);
  font-size: clamp(24px, 7vw, 32px);
  font-weight: 700;
  letter-spacing: -0.04em;
  line-height: 1.05;
  text-wrap: balance;
}

.dashboard-intro > div > p:last-child {
  margin: var(--m-space-2) 0 0;
  color: rgba(234, 244, 241, .7);
  font-family: var(--m-font-mono);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: .025em;
}

.portfolio-pulse {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(128px, .7fr);
  border-top: 1px solid rgba(234, 244, 241, .14);
  background: #0b2421;
  color: #eaf4f1;
}

.portfolio-pulse__main,
.portfolio-pulse__payments {
  display: grid;
  align-content: center;
  padding: var(--m-space-4);
}

.portfolio-pulse__main {
  gap: 6px;
}

.portfolio-pulse__eyebrow,
.portfolio-pulse__payments span {
  color: color-mix(in srgb, #fff 70%, transparent);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .07em;
  text-transform: uppercase;
}

.portfolio-pulse__main strong {
  font-family: var(--m-font-display);
  font-size: clamp(24px, 7vw, 32px);
  font-weight: 700;
  letter-spacing: -.045em;
  line-height: 1;
}

.portfolio-pulse__main strong small {
  color: color-mix(in srgb, #fff 72%, transparent);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0;
}

.portfolio-pulse__main p,
.portfolio-pulse__payments small {
  margin: 0;
  color: color-mix(in srgb, #fff 75%, transparent);
  font-size: 11px;
  line-height: 1.35;
}

.portfolio-pulse__meter {
  height: 5px;
  overflow: hidden;
  border-radius: 999px;
  background: color-mix(in srgb, #fff 20%, transparent);
}

.portfolio-pulse__meter span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: #fff;
}

.portfolio-pulse__payments {
  gap: 6px;
  border-left: 1px solid color-mix(in srgb, #fff 22%, transparent);
}

.portfolio-pulse__payments strong {
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -.025em;
}

.portfolio-pulse__payments .portfolio-pulse__warning {
  color: #fde68a;
}

.surface {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: 12px;
  background: var(--m-surface);
}

.section-heading {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--m-space-3);
}

.section-heading h2,
.page-state h2 {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.025em;
}

.compact-heading {
  align-items: flex-start;
}

.attention-total {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
}

.attention-row,
.health-row,
.payment-row {
  min-height: 68px;
  padding: var(--m-space-3);
  color: var(--m-text);
}

.attention-row :deep(.q-item__section--avatar) {
  min-width: 52px;
}

.queue-icon,
.state-icon,
.metric-icon {
  display: grid;
  place-items: center;
}

.queue-icon {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  font-size: 20px;
}

.row-title {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
  line-height: 1.35;
}

.row-caption,
.property-caption {
  margin-top: 2px;
  color: var(--m-muted) !important;
  font-size: 12px;
  line-height: 1.4;
}

.property-caption {
  font-size: 11px;
}

.queue-side {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: var(--m-space-2);
  padding-left: var(--m-space-2);
}

.queue-count {
  min-width: 24px;
  padding: 3px 7px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 800;
  line-height: 1.5;
  text-align: center;
}

.chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 18px;
}

.status-danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

.status-warning {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}

.status-success {
  background: var(--m-success-soft);
  color: var(--m-success);
}

.status-neutral,
.neutral-icon {
  background: var(--m-bg);
  color: var(--m-text);
}

.all-clear {
  display: flex;
  align-items: center;
  gap: var(--m-space-3);
  padding: var(--m-space-4);
}

.all-clear .state-icon {
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  border-radius: 50%;
  font-size: 21px;
}

.all-clear h3 {
  margin: 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 800;
}

.all-clear p {
  margin: 3px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.4;
}

.operations-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--m-space-2);
}

.operation-card {
  position: relative;
  display: grid;
  min-height: 126px;
  align-content: space-between;
  overflow: hidden;
  padding: var(--m-space-4);
  border: 1px solid var(--m-border);
  border-radius: 10px;
  background: var(--m-surface);
}

.operation-card__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--m-space-2);
}

.metric-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 17px;
}

.operation-card--collected .metric-icon { background: var(--m-success-soft); color: var(--m-success); }
.operation-card--outstanding .metric-icon { background: var(--m-danger-soft); color: var(--m-danger); }
.operation-card--available .metric-icon { background: var(--m-info-soft); color: var(--m-info); }

.operation-card__label {
  min-width: 0;
  overflow: hidden;
  color: var(--m-muted);
  font-family: var(--m-font-mono);
  font-size: 9px;
  font-weight: 600;
  letter-spacing: .045em;
  text-align: right;
  text-overflow: ellipsis;
  text-transform: uppercase;
  white-space: nowrap;
}

.operation-card strong {
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: clamp(19px, 5vw, 24px);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.035em;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.operation-card > span:not(.metric-icon) {
  margin-top: var(--m-space-2);
  color: var(--m-text);
  font-size: 12px;
  font-weight: 750;
}

.operation-card small {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 10px;
  line-height: 1.35;
}

.detail-grid {
  display: grid;
  gap: var(--m-space-6);
}

.health-row {
  min-height: 116px;
  padding: var(--m-space-4);
}

.health-topline,
.occupancy-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--m-space-3);
}

.property-name {
  min-width: 0;
  white-space: normal;
}

.status-pill {
  display: inline-flex;
  min-height: 24px;
  flex: 0 0 auto;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  line-height: 1.2;
  white-space: nowrap;
}

.occupancy-line {
  margin: var(--m-space-3) 0 var(--m-space-2);
  color: var(--m-muted);
  font-size: 11px;
}

.occupancy-line strong {
  color: var(--m-ink);
  font-size: 11px;
}

.health-note {
  margin: var(--m-space-2) 0 0;
  color: var(--m-muted);
  font-size: 11px;
  line-height: 1.4;
}

.payments-heading {
  align-items: flex-start;
}

.view-all-button {
  min-width: 44px;
  min-height: 44px;
  margin: -8px -8px 0 0;
  border-radius: 8px;
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}

.button-icon {
  margin-left: 6px;
  font-size: 17px;
}

.payment-row {
  min-height: 76px;
}

.payment-row :deep(.q-item__section--avatar) {
  min-width: 52px;
}

.tenant-avatar {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 11px;
  font-weight: 800;
}

.payment-side {
  align-items: flex-end;
  gap: 5px;
  padding-left: var(--m-space-2);
}

.payment-side strong {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 800;
}

.section-empty {
  display: flex;
  min-height: 104px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--m-space-2);
  padding: var(--m-space-4);
  color: var(--m-muted);
  font-size: 22px;
}

.section-empty p {
  margin: 0;
  font-size: 12px;
}

.page-state {
  display: flex;
  min-height: 320px;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  padding: var(--m-space-6);
}

.page-state .state-icon {
  width: 48px;
  height: 48px;
  margin-bottom: var(--m-space-4);
  border-radius: 12px;
  font-size: 24px;
}

.page-state p {
  max-width: 480px;
  margin: var(--m-space-2) 0 var(--m-space-5);
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.55;
}

.state-action {
  min-height: 44px;
  padding: 0 var(--m-space-4);
  border-radius: 8px;
  background: var(--m-primary-dark);
  color: white;
  font-size: 13px;
  font-weight: 800;
}

.state-action .button-icon {
  margin: 0 7px 0 0;
}

.skeleton-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.queue-skeleton {
  padding: 0 var(--m-space-3);
}

.skeleton-row {
  display: grid;
  min-height: 68px;
  grid-template-columns: 40px 1fr 28px;
  align-items: center;
  gap: var(--m-space-3);
  border-bottom: 1px solid var(--m-border);
}

.skeleton-row:last-child {
  border-bottom: 0;
}

.skeleton-lines {
  display: grid;
  gap: 2px;
}

.operation-skeleton {
  height: 132px;
  border-radius: 12px;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  clip-path: inset(50%);
  white-space: nowrap;
}

@media (min-width: 720px) {
  .dashboard-shell {
    padding-right: var(--m-page-gutter);
    padding-left: var(--m-page-gutter);
  }

  .operation-card {
    min-height: 122px;
  }

  .detail-grid {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    align-items: start;
  }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
  }
}

/* ---- Inline empty state for a manager with no properties ---- */
.health-empty { display: flex; align-items: center; flex-direction: column; gap: var(--m-space-3); padding: var(--m-space-6); text-align: center; }
.health-empty svg { color: var(--m-muted); opacity: .7; }
.health-empty p { margin: 0; color: var(--m-muted); font-size: 13px; line-height: 1.5; }
.health-add { min-height: 40px; border-radius: var(--m-radius-sm); font-weight: 750; }

</style>
