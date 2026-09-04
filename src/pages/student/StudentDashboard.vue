<template>
  <q-page class="dash q-pb-xl">
    <!-- Greeting -->
    <header class="dash-greeting q-px-md q-pt-md">
      <p class="greeting-eyebrow">{{ greeting }}</p>
      <h1 class="greeting-name">{{ firstName }}</h1>
    </header>

    <!-- Loading -->
    <div v-if="loading" class="q-px-md q-pt-md">
      <q-skeleton type="rect" height="120px" class="skeleton-card q-mb-md" />
      <q-skeleton type="rect" height="88px" class="skeleton-card q-mb-md" />
      <q-skeleton type="rect" height="140px" class="skeleton-card" />
    </div>

    <!-- Load failure -->
    <div v-else-if="error" class="q-px-md q-pt-md">
      <q-card flat bordered class="state-card text-center q-pa-lg">
        <IconifyIcon icon="lucide:cloud-off" width="28" class="text-grey-6" />
        <p class="state-title q-mt-sm">Couldn't load your dashboard</p>
        <p class="state-text">{{ error }}</p>
        <q-btn
          unelevated
          rounded
          color="primary"
          label="Try again"
          class="q-mt-sm"
          @click="load"
        />
      </q-card>
    </div>

    <!-- No active stay -->
    <div v-else-if="!lease" class="q-px-md q-pt-md">
      <EmptyState
        icon="lucide:house-plus"
        title="No accommodation yet"
        message="Once a manager accepts your application, your stay, dues and payments all show up here."
      >
        <template #actions>
          <q-btn
            unelevated
            rounded
            color="primary"
            label="Find a room"
            @click="go('/student/discover')"
          />
        </template>
      </EmptyState>
    </div>

    <!-- Briefing -->
    <template v-else>
      <!-- Dues attention -->
      <section v-if="duePayment" class="q-px-md q-pt-md">
        <q-card
          flat
          class="due-card"
          :class="isOverdue ? 'due-card--overdue' : 'due-card--due'"
        >
          <div class="due-head">
            <IconifyIcon
              :icon="isOverdue ? 'lucide:triangle-alert' : 'lucide:calendar-clock'"
              width="18"
            />
            <span>{{ isOverdue ? 'Payment overdue' : 'Payment due' }}</span>
          </div>
          <div class="due-amount">{{ formatPeso(duePayment.amount) }}</div>
          <div class="due-meta">for {{ formatMonth(duePayment.month) }}</div>
          <q-btn
            unelevated
            rounded
            no-caps
            class="due-action q-mt-sm"
            :color="isOverdue ? 'red-8' : 'primary'"
            label="Pay now"
            @click="go('/student/payments')"
          />
        </q-card>
      </section>

      <!-- Current stay -->
      <section class="q-px-md q-pt-md">
        <h2 class="section-title">Your stay</h2>
        <q-card flat bordered class="stay-card">
          <div class="stay-head">
            <div class="stay-identity">
              <div class="stay-property">{{ lease.propertyName }}</div>
              <div class="stay-room">{{ roomLabel }}</div>
            </div>
            <q-badge
              :color="statusColor(LEASE_STATUS, lease.status)"
              class="stay-badge"
            >
              {{ statusText(LEASE_STATUS, lease.status) }}
            </q-badge>
          </div>

          <q-separator class="q-my-sm" />

          <div class="stay-grid">
            <div class="stay-cell">
              <span class="cell-label">Monthly rent</span>
              <span class="cell-value">{{ formatPeso(lease.monthlyRent) }}</span>
            </div>
            <div class="stay-cell">
              <span class="cell-label">Started</span>
              <span class="cell-value">{{ formatDate(lease.startDate) }}</span>
            </div>
            <div class="stay-cell">
              <span class="cell-label">Until</span>
              <span class="cell-value">{{ formatDate(lease.endDate) }}</span>
            </div>
          </div>

          <q-btn
            flat
            no-caps
            dense
            class="stay-link"
            label="View stay details"
            icon-right="lucide:chevron-right"
            @click="go('/student/stay')"
          />
        </q-card>
      </section>

      <!-- At a glance -->
      <section class="q-px-md q-pt-md">
        <h2 class="section-title">At a glance</h2>
        <div class="glance-grid">
          <q-card flat bordered class="glance-card">
            <span class="glance-value">{{ formatPeso(paidThisYear) }}</span>
            <span class="glance-label">Paid to date</span>
          </q-card>
          <q-card flat bordered class="glance-card">
            <span class="glance-value">{{ outstandingCount }}</span>
            <span class="glance-label">
              {{ outstandingCount === 1 ? 'Unpaid due' : 'Unpaid dues' }}
            </span>
          </q-card>
        </div>
      </section>
    </template>

    <!-- Quick links: always available -->
    <section class="q-px-md q-pt-md">
      <h2 class="section-title">Shortcuts</h2>
      <div class="links-grid">
        <button
          v-for="link in quickLinks"
          :key="link.route"
          type="button"
          class="link-tile"
          @click="go(link.route)"
        >
          <span class="link-icon"><IconifyIcon :icon="link.icon" width="18" /></span>
          <span class="link-label">{{ link.label }}</span>
        </button>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import {
  formatPeso,
  formatDate,
  formatMonth,
  statusText,
  statusColor,
  LEASE_STATUS,
} from '@/utils/format'
import EmptyState from '@/components/shared/EmptyState.vue'

interface StaySummary {
  id: string
  status: string
  startDate: string
  endDate: string
  monthlyRent: number
  propertyName: string
  roomNumber: string | null
  roomLabel: string | null
}

interface DueSummary {
  id: string
  amount: number
  month: string
  status: string
}

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const lease = ref<StaySummary | null>(null)
const payments = ref<DueSummary[]>([])

const quickLinks = [
  { icon: 'lucide:search', label: 'Discover', route: '/student/discover' },
  { icon: 'lucide:wallet-cards', label: 'Payments', route: '/student/payments' },
  { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/student/concerns' },
  { icon: 'lucide:shield-check', label: 'OSAS', route: '/student/support' },
] as const

const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return 'Good morning'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
})

const roomLabel = computed(() => {
  if (!lease.value) return ''
  const { roomNumber, roomLabel: label } = lease.value
  if (roomNumber && label) return `Room ${roomNumber} · ${label}`
  if (roomNumber) return `Room ${roomNumber}`
  return label || 'Room'
})

// The soonest unpaid due drives the attention card; overdue outranks due.
const duePayment = computed<DueSummary | null>(() => {
  const unpaid = payments.value.filter(
    (p) => p.status === 'due' || p.status === 'overdue',
  )
  if (unpaid.length === 0) return null
  const overdue = unpaid.filter((p) => p.status === 'overdue')
  const pool = overdue.length > 0 ? overdue : unpaid
  return [...pool].sort((a, b) => a.month.localeCompare(b.month))[0] ?? null
})

const isOverdue = computed(() => duePayment.value?.status === 'overdue')

const outstandingCount = computed(
  () => payments.value.filter((p) => p.status === 'due' || p.status === 'overdue').length,
)

const paidThisYear = computed(() =>
  payments.value
    .filter((p) => p.status === 'paid')
    .reduce((total, p) => total + Number(p.amount || 0), 0),
)

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

    // Active stay: a lease that has not ended. leave_requested still counts as
    // living there until the manager approves it.
    const { data: leaseRow, error: leaseError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, rooms(room_number, label, monthly_rent, properties(name))',
      )
      .eq('student_id', user.id)
      .in('status', ['active', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (leaseError) throw leaseError

    if (!leaseRow) {
      lease.value = null
      payments.value = []
      return
    }

    const room = leaseRow.rooms as unknown as
      | {
          room_number: string | null
          label: string | null
          monthly_rent: number | null
          properties: { name: string } | null
        }
      | null

    lease.value = {
      id: leaseRow.id,
      status: leaseRow.status,
      startDate: leaseRow.start_date,
      endDate: leaseRow.end_date,
      monthlyRent: Number(leaseRow.monthly_rent ?? room?.monthly_rent ?? 0),
      propertyName: room?.properties?.name || 'Your accommodation',
      roomNumber: room?.room_number ?? null,
      roomLabel: room?.label ?? null,
    }

    const { data: paymentRows, error: paymentError } = await supabase
      .from('payments')
      .select('id, amount, month, status')
      .eq('lease_id', leaseRow.id)
      .order('month', { ascending: false })

    if (paymentError) throw paymentError

    payments.value = (paymentRows || []).map((p) => ({
      id: p.id,
      amount: Number(p.amount || 0),
      month: p.month,
      status: p.status,
    }))
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
.greeting-eyebrow {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 600;
}
.greeting-name {
  margin: 2px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.section-title {
  margin: 0 0 var(--m-space-2);
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
}

.skeleton-card, .state-card { border-radius: var(--m-radius); }
.state-title { margin: var(--m-space-2) 0 0; font-weight: 700; color: var(--m-ink); }
.state-text { margin: 4px 0 0; color: var(--m-muted); font-size: 13px; }

/* Dues */
.due-card {
  padding: var(--m-space-4);
  border-radius: var(--m-radius);
  color: #fff;
}
.due-card--due { background: var(--m-primary); }
.due-card--overdue { background: var(--m-danger); }
.due-head {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 700;
  opacity: 0.92;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.due-amount {
  margin-top: 6px;
  font-family: var(--m-font-display);
  font-size: 30px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.due-meta { font-size: 13px; opacity: 0.9; }
.due-action { background: #fff !important; color: var(--m-ink) !important; min-height: 40px; }

/* Stay */
.stay-card { padding: var(--m-space-4); border-radius: var(--m-radius); background: var(--m-surface); }
.stay-head { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--m-space-2); }
.stay-property { color: var(--m-ink); font-size: 16px; font-weight: 700; letter-spacing: -0.01em; }
.stay-room { margin-top: 2px; color: var(--m-muted); font-size: 13px; }
.stay-badge { border-radius: 999px; padding: 4px 10px; font-size: 11px; font-weight: 700; }
.stay-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--m-space-2); }
.stay-cell { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.cell-label { color: var(--m-muted); font-size: 11px; font-weight: 600; }
.cell-value { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.stay-link { margin-top: var(--m-space-2); color: var(--m-primary-dark); font-weight: 700; }

/* Glance */
.glance-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: var(--m-space-3); }
.glance-card {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: var(--m-space-4);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.glance-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.glance-label { color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Shortcuts */
.links-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: var(--m-space-3); }
.link-tile {
  display: flex;
  min-height: 56px;
  align-items: center;
  gap: var(--m-space-3);
  padding: var(--m-space-3);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease, background-color 0.12s ease;
}
.link-tile:active { transform: scale(0.97); }
.link-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.link-label { min-width: 0; }

@media (prefers-reduced-motion: reduce) {
  .link-tile { transition: none; }
}
</style>
