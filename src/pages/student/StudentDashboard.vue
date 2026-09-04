<template>
  <q-page class="dash">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="146px" class="sk" />
      <q-skeleton type="rect" height="96px" class="sk" />
      <q-skeleton type="rect" height="112px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your dashboard</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <!-- 1 · The stay. Rent, room and dates live here only. -->
      <q-card flat class="hero" :class="{ 'hero--empty': !stay }">
        <div class="hero-top">
          <span class="hero-cap">Your stay</span>
          <span v-if="stay" class="hero-tag">{{ statusLabel(stay.status) }}</span>
        </div>

        <template v-if="stay">
          <div class="hero-name">{{ stay.accommodationName }}</div>
          <div class="hero-sub">{{ roomLabel }}</div>
          <div class="hero-rent">
            {{ formatPeso(stay.monthlyRent) }}<span class="hero-per">/mo</span>
          </div>
          <div class="hero-facts">
            <span>{{ formatDate(stay.startDate) }}</span>
            <span class="hero-dash">—</span>
            <span>{{ formatDate(stay.endDate) }}</span>
          </div>
        </template>

        <template v-else>
          <div class="hero-name">No accommodation yet</div>
          <div class="hero-sub">Your room, rent and dates appear here once a manager accepts you</div>
          <div class="hero-rent hero-rent--muted">—<span class="hero-per">/mo</span></div>
          <q-btn
            unelevated rounded no-caps dense color="primary" label="Find a room"
            class="hero-cta q-px-md" @click="go('/student/discover')"
          />
        </template>
      </q-card>

      <!-- 2 · Standing: only things needing a look, as one compact list. -->
      <q-card flat bordered class="card">
        <button type="button" class="row row--first" @click="go('/student/support')">
          <span class="row-dot" :class="`row-dot--${verificationTone}`" />
          <span class="row-body">
            <span class="row-label">OSAS {{ verificationLabel.toLowerCase() }}</span>
            <span class="row-hint">{{ verificationHint }}</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chev" />
        </button>
        <button type="button" class="row" @click="go('/student/messages')">
          <span class="row-dot" :class="unreadMessages ? 'row-dot--warn' : 'row-dot--ok'" />
          <span class="row-body">
            <span class="row-label">
              {{ unreadMessages ? `${unreadMessages} unread` : 'No unread messages' }}
            </span>
            <span class="row-hint">Conversations with your manager</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chev" />
        </button>
      </q-card>

      <!-- 3 · Destinations not already represented above. -->
      <div class="tiles">
        <button v-for="t in shortcuts" :key="t.route" type="button" class="tile" @click="go(t.route)">
          <IconifyIcon :icon="t.icon" width="17" class="tile-icon" />
          <span>{{ t.label }}</span>
        </button>
      </div>
    </div>
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
const stay = ref<Stay | null>(null)
const verification = ref('unverified')
const unreadMessages = ref(0)

// Discover and Payments are not reachable from anything above; Stay and OSAS
// already have their own rows, so they are deliberately not repeated here.
const shortcuts = [
  { icon: 'lucide:search', label: 'Discover', route: '/student/discover' },
  { icon: 'lucide:wallet-cards', label: 'Payments', route: '/student/payments' },
  { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/student/concerns' },
] as const

const roomLabel = computed(() => {
  if (!stay.value) return ''
  const { roomNumber, roomLabel: label } = stay.value
  if (roomNumber && label) return `Room ${roomNumber} · ${label}`
  if (roomNumber) return `Room ${roomNumber}`
  return label || 'Room'
})

const STATUS_LABEL: Record<string, string> = {
  active: 'Active',
  pending: 'Pending',
  leave_requested: 'Leaving',
  ended: 'Ended',
  terminated: 'Ended',
}
function statusLabel(s: string) {
  return STATUS_LABEL[s] ?? s
}

const VERIFY_LABEL: Record<string, string> = {
  verified: 'Verified',
  pending: 'Pending',
  reviewing: 'In review',
  unverified: 'Unverified',
  rejected: 'Rejected',
  suspended: 'Suspended',
}
const verificationLabel = computed(() => VERIFY_LABEL[verification.value] ?? verification.value)

const verificationHint = computed(() => {
  switch (verification.value) {
    case 'verified':
      return 'Your documents are approved'
    case 'reviewing':
      return 'OSAS is checking your documents'
    case 'rejected':
      return 'Re-upload your documents'
    case 'suspended':
      return 'Contact OSAS to resolve this'
    default:
      return 'Upload your documents to get verified'
  }
})

const verificationTone = computed(() => {
  if (verification.value === 'verified') return 'ok'
  if (verification.value === 'rejected' || verification.value === 'suspended') return 'danger'
  return 'warn'
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
      .select('status')
      .eq('id', user.id)
      .maybeSingle()
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
.stack {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 10px var(--m-page-gutter) 24px;
}
.sk { border-radius: var(--m-radius); }

.card { border-radius: var(--m-radius); background: var(--m-surface); overflow: hidden; }
.card--pad { padding: 18px 14px; }
.err-title { margin: 8px 0 0; color: var(--m-ink); font-size: 14px; font-weight: 700; }
.err-sub { margin: 2px 0 0; color: var(--m-muted); font-size: 12px; }

/* Hero */
.hero { padding: 14px; border-radius: var(--m-radius); background: var(--m-primary); color: #fff; }
.hero--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.hero-top { display: flex; align-items: center; justify-content: space-between; }
.hero-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; opacity: 0.9; }
.hero-tag { padding: 2px 9px; border-radius: 999px; background: rgba(255, 255, 255, 0.22); font-size: 10.5px; font-weight: 700; }
.hero-name { margin-top: 7px; font-family: var(--m-font-display); font-size: 19px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }
.hero-sub { margin-top: 2px; font-size: 12px; opacity: 0.9; }
.hero--empty .hero-sub { color: var(--m-muted); opacity: 1; }
.hero-rent { margin-top: 10px; font-family: var(--m-font-display); font-size: 26px; font-weight: 700; letter-spacing: -0.02em; line-height: 1; }
.hero-rent--muted { color: var(--m-border); }
.hero-per { font-size: 13px; font-weight: 600; opacity: 0.75; }
.hero-facts { margin-top: 4px; display: flex; gap: 6px; font-size: 12px; opacity: 0.9; }
.hero-dash { opacity: 0.6; }
.hero-cta { margin-top: 12px; }

/* Rows */
.row {
  display: flex;
  width: 100%;
  min-height: 48px;
  align-items: center;
  gap: 10px;
  padding: 8px 14px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.row--first { border-top: 0; }
.row-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.row-label { color: var(--m-ink); font-size: 13.5px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.row-hint { color: var(--m-muted); font-size: 11.5px; }
.row-chev { color: #c7ccd3; flex: 0 0 auto; }
.row-dot { display: grid; width: 22px; height: 22px; flex: 0 0 22px; place-items: center; border-radius: 999px; }
.row-dot--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.row-dot--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.row-dot--ok { background: var(--m-success-soft); color: var(--m-success); }
.row-dot::before { content: ''; width: 7px; height: 7px; border-radius: 999px; background: currentColor; }

/* Tiles */
.tiles { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.tile {
  display: flex;
  min-height: 62px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 5px;
  padding: 8px 4px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 11.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.tile:active { transform: scale(0.96); }
.tile-icon { color: var(--m-primary-dark); }

@media (prefers-reduced-motion: reduce) {
  .tile { transition: none; }
}
</style>
