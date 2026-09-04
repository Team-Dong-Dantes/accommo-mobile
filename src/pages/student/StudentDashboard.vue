<template>
  <q-page class="dash q-pb-xl">
    <header class="dash-head q-px-md q-pt-md">
      <p class="head-eyebrow">{{ greeting }}</p>
      <h1 class="head-name">{{ firstName }}</h1>
    </header>

    <div v-if="loading" class="q-px-md q-pt-md">
      <q-skeleton type="rect" height="150px" class="sk q-mb-md" />
      <q-skeleton type="rect" height="82px" class="sk q-mb-md" />
      <q-skeleton type="rect" height="120px" class="sk" />
    </div>

    <div v-else-if="error" class="q-px-md q-pt-md">
      <q-card flat bordered class="panel text-center q-pa-lg">
        <IconifyIcon icon="lucide:cloud-off" width="26" class="text-grey-6" />
        <p class="panel-title q-mt-sm">Couldn't load your dashboard</p>
        <p class="panel-sub">{{ error }}</p>
        <q-btn unelevated rounded color="primary" label="Try again" class="q-mt-sm" @click="load" />
      </q-card>
    </div>

    <template v-else>
      <!-- Your stay: same card shape whether or not a lease exists -->
      <section class="q-px-md q-pt-md">
        <q-card v-if="stay" flat class="stay-card">
          <div class="stay-top">
            <span class="stay-caption">Your stay</span>
            <q-badge class="stay-badge">{{ statusLabel(stay.status) }}</q-badge>
          </div>
          <div class="stay-name">{{ stay.accommodationName }}</div>
          <div class="stay-room">{{ roomLabel }}</div>
          <div class="stay-grid">
            <div class="stay-cell">
              <span class="cell-label">Monthly rent</span>
              <span class="cell-value">{{ formatPeso(stay.monthlyRent) }}</span>
            </div>
            <div class="stay-cell">
              <span class="cell-label">Since</span>
              <span class="cell-value">{{ formatDate(stay.startDate) }}</span>
            </div>
            <div class="stay-cell">
              <span class="cell-label">Until</span>
              <span class="cell-value">{{ formatDate(stay.endDate) }}</span>
            </div>
          </div>
        </q-card>

        <q-card v-else flat class="stay-card stay-card--empty">
          <div class="stay-top">
            <span class="stay-caption">Your stay</span>
          </div>
          <div class="stay-name">No accommodation yet</div>
          <div class="stay-room">Your room, rent and dates appear here once a manager accepts you</div>
          <div class="stay-grid">
            <div v-for="label in ['Monthly rent', 'Since', 'Until']" :key="label" class="stay-cell">
              <span class="cell-label">{{ label }}</span>
              <span class="cell-value cell-value--muted">—</span>
            </div>
          </div>
          <q-btn
            unelevated rounded no-caps color="primary" label="Find a room"
            class="q-mt-md" @click="go('/student/discover')"
          />
        </q-card>
      </section>

      <!-- Standing -->
      <section class="q-px-md q-pt-md">
        <h2 class="sec-title">Standing</h2>
        <div class="stat-row">
          <div class="stat" :class="verificationTone">
            <span class="stat-value">{{ verificationLabel }}</span>
            <span class="stat-label">OSAS status</span>
          </div>
          <button type="button" class="stat" @click="go('/student/messages')">
            <span class="stat-value">{{ unreadMessages }}</span>
            <span class="stat-label">
              {{ unreadMessages === 1 ? 'Unread message' : 'Unread messages' }}
            </span>
          </button>
        </div>
      </section>

      <!-- Rent: payments are not yet recorded, so this is stated as expected -->
      <section class="q-px-md q-pt-md">
        <div class="row-head">
          <h2 class="sec-title">Rent</h2>
          <q-btn
            flat dense no-caps class="sec-action" label="Payments"
            @click="go('/student/payments')"
          />
        </div>
        <q-card flat bordered class="panel rent-card">
          <div class="rent-main">
            <span class="rent-label">{{ stay ? 'Due each month' : 'Nothing due' }}</span>
            <span class="rent-amount" :class="{ 'rent-amount--muted': !stay }">
              {{ stay ? formatPeso(stay.monthlyRent) : '—' }}
            </span>
          </div>
          <p class="rent-note">
            {{
              stay
                ? 'Payment records show up here once your manager logs them.'
                : 'Rent appears here when your stay begins.'
            }}
          </p>
        </q-card>
      </section>

      <!-- Shortcuts: always available, so the page never bottoms out -->
      <section class="q-px-md q-pt-md">
        <h2 class="sec-title">Shortcuts</h2>
        <div class="tile-grid">
          <button
            v-for="link in shortcuts"
            :key="link.route"
            type="button"
            class="tile"
            @click="go(link.route)"
          >
            <span class="tile-icon"><IconifyIcon :icon="link.icon" width="18" /></span>
            <span class="tile-label">{{ link.label }}</span>
          </button>
        </div>
      </section>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { formatPeso, formatDate } from '@/utils/format'

interface Stay {
  id: string
  status: string
  startDate: string
  endDate: string
  monthlyRent: number
  accommodationName: string
  roomNumber: string | null
  roomLabel: string | null
}

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const stay = ref<Stay | null>(null)
const verification = ref('unverified')
const unreadMessages = ref(0)

const shortcuts = [
  { icon: 'lucide:search', label: 'Discover', route: '/student/discover' },
  { icon: 'lucide:bed-double', label: 'My stay', route: '/student/stay' },
  { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/student/concerns' },
  { icon: 'lucide:shield-check', label: 'OSAS', route: '/student/support' },
] as const

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const roomLabel = computed(() => {
  if (!stay.value) return ''
  const { roomNumber, roomLabel: label } = stay.value
  if (roomNumber && label) return `Room ${roomNumber} · ${label}`
  if (roomNumber) return `Room ${roomNumber}`
  return label || 'Room'
})

function statusLabel(status: string) {
  const map: Record<string, string> = {
    active: 'Active',
    pending: 'Pending',
    leave_requested: 'Leaving',
    ended: 'Ended',
    terminated: 'Ended',
  }
  return map[status] ?? status
}

const verificationLabel = computed(() => {
  const map: Record<string, string> = {
    verified: 'Verified',
    pending: 'Pending',
    reviewing: 'In review',
    unverified: 'Unverified',
    rejected: 'Rejected',
    suspended: 'Suspended',
  }
  return map[verification.value] ?? verification.value
})

const verificationTone = computed(() => {
  if (verification.value === 'verified') return 'stat--ok'
  if (verification.value === 'rejected' || verification.value === 'suspended') return 'stat--danger'
  return 'stat--warn'
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
      .select('full_name, status')
      .eq('id', user.id)
      .maybeSingle()
    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'
    verification.value = profile?.status || 'unverified'

    // Students hold at most one live lease, so a single row is enough.
    const { data: leaseRow, error: leaseError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, rooms(room_number, label, monthly_rent, accommodations(name))',
      )
      .eq('student_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (leaseError) throw leaseError

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as
        | {
            room_number: string | null
            label: string | null
            monthly_rent: number | null
            accommodations: { name: string } | null
          }
        | null
      stay.value = {
        id: leaseRow.id,
        status: leaseRow.status,
        startDate: leaseRow.start_date,
        endDate: leaseRow.end_date,
        monthlyRent: Number(leaseRow.monthly_rent ?? room?.monthly_rent ?? 0),
        accommodationName: room?.accommodations?.name || 'Your accommodation',
        roomNumber: room?.room_number ?? null,
        roomLabel: room?.label ?? null,
      }
    } else {
      stay.value = null
    }

    // conversations carries denormalised unread counters per side.
    const { data: convos } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
    unreadMessages.value = (convos || []).reduce((n, c) => {
      const mine = c.user_a_id === user.id ? c.unread_a : c.unread_b
      return n + Number(mine || 0)
    }, 0)
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

.dash-head { padding-bottom: 2px; }
.head-eyebrow { margin: 0; color: var(--m-muted); font-size: 13px; font-weight: 600; }
.head-name {
  margin: 2px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.sec-title { margin: 0 0 var(--m-space-2); color: var(--m-ink); font-size: 15px; font-weight: 700; letter-spacing: -0.01em; }
.row-head { display: flex; align-items: center; justify-content: space-between; }
.sec-action { color: var(--m-primary-dark); font-weight: 700; }

.sk, .panel { border-radius: var(--m-radius); }
.panel { background: var(--m-surface); }
.panel-title { margin: var(--m-space-2) 0 0; color: var(--m-ink); font-weight: 700; }
.panel-sub { margin: 4px 0 0; color: var(--m-muted); font-size: 13px; }

/* Stay */
.stay-card { padding: var(--m-space-4); border-radius: var(--m-radius); background: var(--m-primary); color: #fff; }
.stay-card--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.stay-top { display: flex; align-items: center; justify-content: space-between; }
.stay-caption { font-size: 12px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; opacity: 0.9; }
.stay-badge { border-radius: 999px; padding: 3px 10px; background: rgba(255, 255, 255, 0.22); color: #fff; font-size: 11px; font-weight: 700; }
.stay-name { margin-top: var(--m-space-2); font-family: var(--m-font-display); font-size: 20px; font-weight: 700; letter-spacing: -0.02em; }
.stay-room { margin-top: 2px; font-size: 13px; opacity: 0.9; }
.stay-card--empty .stay-room { color: var(--m-muted); opacity: 1; }
.stay-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--m-space-2); margin-top: var(--m-space-4); }
.stay-cell { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.cell-label { font-size: 11px; font-weight: 600; opacity: 0.85; }
.stay-card--empty .cell-label { color: var(--m-muted); opacity: 1; }
.cell-value { font-size: 14px; font-weight: 700; }
.cell-value--muted { color: var(--m-border); }

/* Stats */
.stat-row { display: flex; gap: var(--m-space-3); }
.stat {
  display: flex;
  min-height: 74px;
  flex: 1 1 0;
  min-width: 0;
  flex-direction: column;
  justify-content: center;
  gap: 2px;
  padding: var(--m-space-3);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.stat:active { transform: scale(0.97); }
.stat--ok { border-color: color-mix(in srgb, var(--m-success) 40%, var(--m-border)); background: var(--m-success-soft); }
.stat--warn { border-color: color-mix(in srgb, var(--m-warning) 45%, var(--m-border)); background: var(--m-warning-soft); }
.stat--danger { border-color: color-mix(in srgb, var(--m-danger) 40%, var(--m-border)); background: var(--m-danger-soft); }
.stat-value { color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 700; letter-spacing: -0.02em; }
.stat-label { color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Rent */
.rent-card { padding: var(--m-space-4); }
.rent-main { display: flex; align-items: baseline; justify-content: space-between; gap: var(--m-space-2); }
.rent-label { color: var(--m-muted); font-size: 13px; font-weight: 600; }
.rent-amount { color: var(--m-ink); font-family: var(--m-font-display); font-size: 22px; font-weight: 700; letter-spacing: -0.02em; }
.rent-amount--muted { color: var(--m-border); }
.rent-note { margin: var(--m-space-2) 0 0; color: var(--m-muted); font-size: 12px; }

/* Shortcuts */
.tile-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: var(--m-space-3); }
.tile {
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
  transition: transform 0.12s ease;
}
.tile:active { transform: scale(0.97); }
.tile-icon { display: grid; width: 34px; height: 34px; flex: 0 0 34px; place-items: center; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); color: var(--m-primary-dark); }
.tile-label { min-width: 0; }

@media (prefers-reduced-motion: reduce) {
  .stat, .tile { transition: none; }
}
</style>
