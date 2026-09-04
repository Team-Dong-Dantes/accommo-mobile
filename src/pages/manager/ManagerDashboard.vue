<template>
  <q-page class="dash q-pb-xl">
    <header class="dash-greeting q-px-md q-pt-md">
      <p class="greeting-eyebrow">{{ greeting }}</p>
      <h1 class="greeting-name">{{ firstName }}</h1>
    </header>

    <!-- Loading -->
    <div v-if="loading" class="q-px-md q-pt-md">
      <q-skeleton type="rect" height="104px" class="skeleton-card q-mb-md" />
      <q-skeleton type="rect" height="140px" class="skeleton-card q-mb-md" />
      <q-skeleton type="rect" height="120px" class="skeleton-card" />
    </div>

    <!-- Load failure -->
    <div v-else-if="error" class="q-px-md q-pt-md">
      <q-card flat bordered class="state-card text-center q-pa-lg">
        <IconifyIcon icon="lucide:cloud-off" width="28" class="text-grey-6" />
        <p class="state-title q-mt-sm">Couldn't load your dashboard</p>
        <p class="state-text">{{ error }}</p>
        <q-btn unelevated rounded color="primary" label="Try again" class="q-mt-sm" @click="load" />
      </q-card>
    </div>

    <!-- No properties yet -->
    <div v-else-if="properties.length === 0" class="q-px-md q-pt-md">
      <EmptyState
        icon="lucide:building-2"
        title="No accommodations yet"
        message="Add your first accommodation to start tracking rooms, tenants and payments."
      >
        <template #actions>
          <q-btn
            unelevated
            rounded
            color="primary"
            label="Add accommodation"
            @click="go('/manager/properties/new')"
          />
        </template>
      </EmptyState>
    </div>

    <template v-else>
      <!-- Occupancy -->
      <section class="q-px-md q-pt-md">
        <q-card flat class="occupancy-card">
          <div class="occ-head">
            <span>Occupancy</span>
            <span class="occ-rate">{{ occupancyRate }}%</span>
          </div>
          <q-linear-progress
            :value="occupancyRate / 100"
            size="8px"
            rounded
            track-color="white"
            color="white"
            class="occ-bar q-mt-sm"
          />
          <div class="occ-meta q-mt-sm">
            {{ occupiedRooms }} of {{ totalRooms }} rooms occupied
            across {{ properties.length }}
            {{ properties.length === 1 ? 'accommodation' : 'accommodations' }}
          </div>
        </q-card>
      </section>

      <!-- Signals -->
      <section class="q-px-md q-pt-md">
        <h2 class="section-title">At a glance</h2>
        <div class="glance-grid">
          <button type="button" class="glance-card" @click="go('/manager/tenants')">
            <span class="glance-value">{{ activeTenants }}</span>
            <span class="glance-label">Active tenants</span>
          </button>
          <button type="button" class="glance-card" @click="go('/manager/payments')">
            <span class="glance-value">{{ formatPeso(collectedThisMonth) }}</span>
            <span class="glance-label">Collected this month</span>
          </button>
          <button
            type="button"
            class="glance-card"
            :class="{ 'glance-card--warn': outstandingCount > 0 }"
            @click="go('/manager/payments')"
          >
            <span class="glance-value">{{ outstandingCount }}</span>
            <span class="glance-label">Unpaid dues</span>
          </button>
          <button
            type="button"
            class="glance-card"
            :class="{ 'glance-card--warn': openTickets > 0 }"
            @click="go('/manager/support')"
          >
            <span class="glance-value">{{ openTickets }}</span>
            <span class="glance-label">Open tickets</span>
          </button>
        </div>
      </section>

      <!-- Needs attention -->
      <section v-if="attention.length > 0" class="q-px-md q-pt-md">
        <h2 class="section-title">Needs attention</h2>
        <q-card flat bordered class="attention-card">
          <button
            v-for="(item, index) in attention"
            :key="item.label"
            type="button"
            class="attention-row"
            :class="{ 'attention-row--divided': index > 0 }"
            @click="go(item.route)"
          >
            <span class="attention-icon" :class="`attention-icon--${item.tone}`">
              <IconifyIcon :icon="item.icon" width="16" />
            </span>
            <span class="attention-text">
              <span class="attention-label">{{ item.label }}</span>
              <span class="attention-hint">{{ item.hint }}</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="text-grey-5" />
          </button>
        </q-card>
      </section>

      <!-- Payment activity -->
      <section class="q-px-md q-pt-md">
        <div class="section-head">
          <h2 class="section-title q-mb-none">Payment activity</h2>
          <q-btn
            flat
            dense
            no-caps
            class="section-action"
            label="View all"
            @click="go('/manager/payments')"
          />
        </div>

        <q-card v-if="recentPayments.length === 0" flat bordered class="quiet-card">
          No payments recorded yet.
        </q-card>

        <q-card v-else flat bordered class="activity-card">
          <div
            v-for="(payment, index) in recentPayments"
            :key="payment.id"
            class="activity-row"
            :class="{ 'activity-row--divided': index > 0 }"
          >
            <div class="activity-main">
              <span class="activity-name">{{ payment.studentName }}</span>
              <span class="activity-meta">{{ formatMonth(payment.month) }}</span>
            </div>
            <div class="activity-right">
              <span class="activity-amount">{{ formatPeso(payment.amount) }}</span>
              <q-badge
                :color="statusColor(PAYMENT_STATUS, payment.status)"
                class="activity-badge"
              >
                {{ statusText(PAYMENT_STATUS, payment.status) }}
              </q-badge>
            </div>
          </div>
        </q-card>
      </section>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import {
  formatPeso,
  formatMonth,
  statusText,
  statusColor,
  PAYMENT_STATUS,
} from '@/utils/format'
import EmptyState from '@/components/shared/EmptyState.vue'

interface PropertyRow {
  id: string
  name: string
  accreditationStatus: string | null
}

interface PaymentRow {
  id: string
  amount: number
  month: string
  status: string
  studentName: string
}

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const properties = ref<PropertyRow[]>([])
const totalRooms = ref(0)
const occupiedRooms = ref(0)
const activeTenants = ref(0)
const leaveRequests = ref(0)
const openTickets = ref(0)
const recentPayments = ref<PaymentRow[]>([])
const collectedThisMonth = ref(0)
const outstandingCount = ref(0)

const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return 'Good morning'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
})

const occupancyRate = computed(() =>
  totalRooms.value === 0 ? 0 : Math.round((occupiedRooms.value / totalRooms.value) * 100),
)

// Accreditation that is not yet approved is the manager's compliance work.
const pendingAccreditation = computed(
  () => properties.value.filter((p) => p.accreditationStatus !== 'approved').length,
)

const attention = computed(() => {
  const items: {
    icon: string
    label: string
    hint: string
    route: string
    tone: 'warn' | 'danger'
  }[] = []

  if (leaveRequests.value > 0) {
    items.push({
      icon: 'lucide:door-open',
      label: `${leaveRequests.value} leave ${leaveRequests.value === 1 ? 'request' : 'requests'}`,
      hint: 'Waiting on your decision',
      route: '/manager/tenants',
      tone: 'warn',
    })
  }
  if (outstandingCount.value > 0) {
    items.push({
      icon: 'lucide:wallet-cards',
      label: `${outstandingCount.value} unpaid ${outstandingCount.value === 1 ? 'due' : 'dues'}`,
      hint: 'Rent not yet settled',
      route: '/manager/payments',
      tone: 'danger',
    })
  }
  if (pendingAccreditation.value > 0) {
    items.push({
      icon: 'lucide:shield-check',
      label: `${pendingAccreditation.value} ${pendingAccreditation.value === 1 ? 'accommodation' : 'accommodations'} not accredited`,
      hint: 'Check OSAS compliance',
      route: '/manager/osas-compliance',
      tone: 'warn',
    })
  }
  return items
})

function go(path: string) {
  void router.push(path)
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: profile } = await supabase
      .from('users')
      .select('full_name')
      .eq('id', user.id)
      .maybeSingle()
    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'

    // NOTE: the DB calls a manager's accommodation a "property", and the owning
    // column is landlord_id. Both are schema-level names — do not rename.
    const { data: propertyRows, error: propertyError } = await supabase
      .from('properties')
      .select('id, name, accreditation_status')
      .eq('landlord_id', user.id)

    if (propertyError) throw propertyError

    properties.value = (propertyRows || []).map((p) => ({
      id: p.id,
      name: p.name,
      accreditationStatus: p.accreditation_status,
    }))

    if (properties.value.length === 0) {
      totalRooms.value = 0
      occupiedRooms.value = 0
      recentPayments.value = []
      return
    }

    const propertyIds = properties.value.map((p) => p.id)

    const { data: roomRows, error: roomError } = await supabase
      .from('rooms')
      .select('id, status')
      .in('property_id', propertyIds)
    if (roomError) throw roomError

    totalRooms.value = roomRows?.length ?? 0
    occupiedRooms.value = (roomRows || []).filter((r) => r.status === 'occupied').length

    const { data: leaseRows, error: leaseError } = await supabase
      .from('leases')
      .select('id, status, student_id')
      .eq('landlord_id', user.id)
      .in('status', ['active', 'leave_requested'])
    if (leaseError) throw leaseError

    activeTenants.value = leaseRows?.length ?? 0
    leaveRequests.value = (leaseRows || []).filter((l) => l.status === 'leave_requested').length

    const { count: ticketCount } = await supabase
      .from('tickets')
      .select('*', { count: 'exact', head: true })
      .eq('landlord_id', user.id)
      .neq('status', 'resolved')
    openTickets.value = ticketCount || 0

    const leaseIds = (leaseRows || []).map((l) => l.id)
    if (leaseIds.length === 0) {
      recentPayments.value = []
      return
    }

    const { data: paymentRows, error: paymentError } = await supabase
      .from('payments')
      .select('id, amount, month, status, paid_at, lease_id, leases(users(full_name))')
      .in('lease_id', leaseIds)
      .order('month', { ascending: false })
      .limit(20)
    if (paymentError) throw paymentError

    const rows = paymentRows || []

    outstandingCount.value = rows.filter(
      (p) => p.status === 'due' || p.status === 'overdue',
    ).length

    const thisMonth = new Date().toISOString().slice(0, 7)
    collectedThisMonth.value = rows
      .filter((p) => p.status === 'paid' && String(p.month || '').startsWith(thisMonth))
      .reduce((total, p) => total + Number(p.amount || 0), 0)

    recentPayments.value = rows.slice(0, 5).map((p) => {
      const lease = p.leases as unknown as { users: { full_name: string } | null } | null
      return {
        id: p.id,
        amount: Number(p.amount || 0),
        month: p.month,
        status: p.status,
        studentName: lease?.users?.full_name || 'Tenant',
      }
    })
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.dash { background: var(--m-bg); }

.dash-greeting { padding-bottom: 2px; }
.greeting-eyebrow { margin: 0; color: var(--m-muted); font-size: 13px; font-weight: 600; }
.greeting-name {
  margin: 2px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.section-title { margin: 0 0 var(--m-space-2); color: var(--m-ink); font-size: 15px; font-weight: 700; letter-spacing: -0.01em; }
.section-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--m-space-2); }
.section-action { color: var(--m-primary-dark); font-weight: 700; }

.skeleton-card, .state-card, .quiet-card { border-radius: var(--m-radius); }
.state-title { margin: var(--m-space-2) 0 0; font-weight: 700; color: var(--m-ink); }
.state-text { margin: 4px 0 0; color: var(--m-muted); font-size: 13px; }
.quiet-card { padding: var(--m-space-4); color: var(--m-muted); font-size: 13px; background: var(--m-surface); }

/* Occupancy */
.occupancy-card { padding: var(--m-space-4); border-radius: var(--m-radius); background: var(--m-primary); color: #fff; }
.occ-head { display: flex; align-items: baseline; justify-content: space-between; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; opacity: 0.92; }
.occ-rate { font-family: var(--m-font-display); font-size: 28px; letter-spacing: -0.02em; opacity: 1; text-transform: none; }
.occ-bar { opacity: 0.9; }
.occ-meta { font-size: 13px; opacity: 0.92; }

/* Glance */
.glance-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: var(--m-space-3); }
.glance-card {
  display: flex;
  min-height: 76px;
  flex-direction: column;
  justify-content: center;
  gap: 2px;
  padding: var(--m-space-4);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.glance-card:active { transform: scale(0.97); }
.glance-card--warn { border-color: color-mix(in srgb, var(--m-warning) 40%, var(--m-border)); background: var(--m-warning-soft); }
.glance-value { color: var(--m-ink); font-family: var(--m-font-display); font-size: 20px; font-weight: 700; letter-spacing: -0.02em; }
.glance-label { color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Attention */
.attention-card { border-radius: var(--m-radius); background: var(--m-surface); overflow: hidden; }
.attention-row {
  display: flex;
  width: 100%;
  min-height: 60px;
  align-items: center;
  gap: var(--m-space-3);
  padding: var(--m-space-3) var(--m-space-4);
  border: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.attention-row--divided { border-top: 1px solid var(--m-border); }
.attention-icon { display: grid; width: 32px; height: 32px; flex: 0 0 32px; place-items: center; border-radius: var(--m-radius-sm); }
.attention-icon--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.attention-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.attention-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.attention-label { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.attention-hint { color: var(--m-muted); font-size: 12px; }

/* Activity */
.activity-card { border-radius: var(--m-radius); background: var(--m-surface); overflow: hidden; }
.activity-row { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); padding: var(--m-space-3) var(--m-space-4); }
.activity-row--divided { border-top: 1px solid var(--m-border); }
.activity-main { display: flex; min-width: 0; flex-direction: column; gap: 1px; }
.activity-name { color: var(--m-ink); font-size: 14px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.activity-meta { color: var(--m-muted); font-size: 12px; }
.activity-right { display: flex; flex: 0 0 auto; flex-direction: column; align-items: flex-end; gap: 4px; }
.activity-amount { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.activity-badge { border-radius: 999px; padding: 2px 8px; font-size: 10px; font-weight: 700; }

@media (prefers-reduced-motion: reduce) {
  .glance-card { transition: none; }
}
</style>
