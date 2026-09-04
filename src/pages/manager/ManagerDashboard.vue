<template>
  <q-page class="dash q-pb-xl">
    <header class="dash-head q-px-md q-pt-md">
      <p class="head-eyebrow">{{ greeting }}</p>
      <h1 class="head-name">{{ firstName }}</h1>
    </header>

    <div v-if="loading" class="q-px-md q-pt-md">
      <q-skeleton type="rect" height="132px" class="sk q-mb-md" />
      <q-skeleton type="rect" height="92px" class="sk q-mb-md" />
      <q-skeleton type="rect" height="160px" class="sk" />
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
      <!-- Occupancy: beds, not room.status (room.status is unreliable) -->
      <section class="q-px-md q-pt-md">
        <q-card flat class="occ-card" :class="{ 'occ-card--empty': !hasAccommodations }">
          <div class="occ-top">
            <span class="occ-caption">Occupancy</span>
            <span class="occ-rate">{{ hasAccommodations ? `${occupancyRate}%` : '—' }}</span>
          </div>
          <div class="occ-track">
            <div class="occ-fill" :style="{ width: `${occupancyRate}%` }" />
          </div>
          <div class="occ-foot">
            <span v-if="hasAccommodations">
              {{ filledBeds }} of {{ totalBeds }} beds · {{ accommodations.length }}
              {{ accommodations.length === 1 ? 'accommodation' : 'accommodations' }}
            </span>
            <span v-else>No accommodations yet — your occupancy shows here</span>
          </div>
        </q-card>
      </section>

      <!-- Compliance: the signal with real, urgent data -->
      <section class="q-px-md q-pt-md">
        <div class="row-head">
          <h2 class="sec-title">Compliance</h2>
          <q-btn
            flat dense no-caps class="sec-action" label="OSAS"
            @click="go('/manager/osas-compliance')"
          />
        </div>
        <div class="stat-row">
          <button
            type="button" class="stat" :class="{ 'stat--danger': expiredDocs > 0 }"
            @click="go('/manager/osas-compliance')"
          >
            <span class="stat-value">{{ expiredDocs }}</span>
            <span class="stat-label">Expired</span>
          </button>
          <button
            type="button" class="stat" :class="{ 'stat--warn': expiringDocs > 0 }"
            @click="go('/manager/osas-compliance')"
          >
            <span class="stat-value">{{ expiringDocs }}</span>
            <span class="stat-label">Expiring</span>
          </button>
          <button
            type="button" class="stat" :class="{ 'stat--warn': notAccredited > 0 }"
            @click="go('/manager/osas-compliance')"
          >
            <span class="stat-value">{{ notAccredited }}</span>
            <span class="stat-label">Unaccredited</span>
          </button>
        </div>
      </section>

      <!-- Tenancy -->
      <section class="q-px-md q-pt-md">
        <h2 class="sec-title">Tenancy</h2>
        <div class="stat-row">
          <button type="button" class="stat stat--wide" @click="go('/manager/tenants')">
            <span class="stat-value">{{ activeTenants }}</span>
            <span class="stat-label">Active tenants</span>
          </button>
          <button type="button" class="stat stat--wide" @click="go('/manager/tenants')">
            <span class="stat-value">{{ formatPeso(expectedMonthly) }}</span>
            <span class="stat-label">Expected rent / month</span>
          </button>
        </div>
      </section>

      <!-- Needs attention: always present, states its own emptiness -->
      <section class="q-px-md q-pt-md">
        <h2 class="sec-title">Needs attention</h2>
        <q-card flat bordered class="panel list-card">
          <template v-if="attention.length > 0">
            <button
              v-for="(item, i) in attention"
              :key="item.label"
              type="button"
              class="list-row"
              :class="{ 'list-row--divided': i > 0 }"
              @click="go(item.route)"
            >
              <span class="list-icon" :class="`list-icon--${item.tone}`">
                <IconifyIcon :icon="item.icon" width="16" />
              </span>
              <span class="list-text">
                <span class="list-label">{{ item.label }}</span>
                <span class="list-hint">{{ item.hint }}</span>
              </span>
              <IconifyIcon icon="lucide:chevron-right" width="16" class="text-grey-5" />
            </button>
          </template>
          <div v-else class="list-row list-row--quiet">
            <span class="list-icon list-icon--ok">
              <IconifyIcon icon="lucide:check" width="16" />
            </span>
            <span class="list-text">
              <span class="list-label">All clear</span>
              <span class="list-hint">Approvals, renewals and issues appear here</span>
            </span>
          </div>
        </q-card>
      </section>

      <!-- Accommodations: scales 1..9, and holds its shape at zero -->
      <section class="q-px-md q-pt-md">
        <div class="row-head">
          <h2 class="sec-title">Accommodations</h2>
          <q-btn
            v-if="hasAccommodations"
            flat dense no-caps class="sec-action" label="View all"
            @click="go('/manager/properties')"
          />
        </div>

        <q-card flat bordered class="panel list-card">
          <template v-if="hasAccommodations">
            <button
              v-for="(a, i) in accommodations"
              :key="a.id"
              type="button"
              class="list-row"
              :class="{ 'list-row--divided': i > 0 }"
              @click="go(`/manager/properties/${a.id}`)"
            >
              <span class="acc-text">
                <span class="list-label">{{ a.name }}</span>
                <span class="list-hint">
                  {{ a.filled }}/{{ a.beds }} beds · {{ statusLabel(a.status) }}
                </span>
              </span>
              <span class="acc-meter" aria-hidden="true">
                <span class="acc-meter-fill" :style="{ width: `${a.rate}%` }" />
              </span>
              <IconifyIcon icon="lucide:chevron-right" width="16" class="text-grey-5" />
            </button>
          </template>

          <!-- Zero state keeps the row shape rather than replacing the section -->
          <button v-else type="button" class="list-row list-row--add" @click="go('/manager/properties/new')">
            <span class="list-icon list-icon--add">
              <IconifyIcon icon="lucide:plus" width="16" />
            </span>
            <span class="list-text">
              <span class="list-label">Add your first accommodation</span>
              <span class="list-hint">Rooms, tenants and compliance follow from here</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="text-grey-5" />
          </button>
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
import { formatPeso } from '@/utils/format'

interface AccommodationCard {
  id: string
  name: string
  status: string
  beds: number
  filled: number
  rate: number
}

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const accommodations = ref<AccommodationCard[]>([])
const totalBeds = ref(0)
const filledBeds = ref(0)
const activeTenants = ref(0)
const pendingLeases = ref(0)
const leaveRequests = ref(0)
const expectedMonthly = ref(0)
const expiredDocs = ref(0)
const expiringDocs = ref(0)
const openTickets = ref(0)

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const hasAccommodations = computed(() => accommodations.value.length > 0)
const occupancyRate = computed(() =>
  totalBeds.value === 0 ? 0 : Math.min(100, Math.round((filledBeds.value / totalBeds.value) * 100)),
)
const notAccredited = computed(
  () => accommodations.value.filter((a) => a.status !== 'accredited').length,
)

function statusLabel(status: string) {
  const map: Record<string, string> = {
    accredited: 'Accredited',
    pending: 'Pending',
    reviewing: 'Reviewing',
    rejected: 'Rejected',
    delisted: 'Delisted',
  }
  return map[status] ?? status
}

const attention = computed(() => {
  const items: { icon: string; label: string; hint: string; route: string; tone: string }[] = []
  if (pendingLeases.value > 0)
    items.push({
      icon: 'lucide:user-plus',
      label: `${pendingLeases.value} pending ${pendingLeases.value === 1 ? 'application' : 'applications'}`,
      hint: 'Waiting on your decision',
      route: '/manager/tenants',
      tone: 'warn',
    })
  if (leaveRequests.value > 0)
    items.push({
      icon: 'lucide:door-open',
      label: `${leaveRequests.value} leave ${leaveRequests.value === 1 ? 'request' : 'requests'}`,
      hint: 'Tenant wants to move out',
      route: '/manager/tenants',
      tone: 'warn',
    })
  if (expiredDocs.value > 0)
    items.push({
      icon: 'lucide:file-warning',
      label: `${expiredDocs.value} expired ${expiredDocs.value === 1 ? 'document' : 'documents'}`,
      hint: 'Re-upload to stay accredited',
      route: '/manager/osas-compliance',
      tone: 'danger',
    })
  if (openTickets.value > 0)
    items.push({
      icon: 'lucide:life-buoy',
      label: `${openTickets.value} open ${openTickets.value === 1 ? 'ticket' : 'tickets'}`,
      hint: 'Reported by tenants or OSAS',
      route: '/manager/support',
      tone: 'warn',
    })
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

    const { data: accRows, error: accError } = await supabase
      .from('accommodations')
      .select('id, name, status')
      .eq('accommodation_manager_id', user.id)
    if (accError) throw accError

    const accs = accRows || []
    const accIds = accs.map((a) => a.id)

    // Capacity comes from rooms, but occupancy is counted from active leases.
    // room.status and rooms.current_pax both disagree with the lease data
    // (current_pax sits at 0 even for accommodations with active tenants),
    // so leases are the only trustworthy source of who is actually housed.
    let roomRows: { id: string; accommodation_id: string; capacity: number | null }[] = []
    if (accIds.length > 0) {
      const { data, error: roomError } = await supabase
        .from('rooms')
        .select('id, accommodation_id, capacity')
        .in('accommodation_id', accIds)
      if (roomError) throw roomError
      roomRows = data || []
    }

    const { data: leaseRows, error: leaseError } = await supabase
      .from('leases')
      .select('id, status, monthly_rent, room_id')
      .eq('accommodation_manager_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
    if (leaseError) throw leaseError

    const leases = leaseRows || []

    const roomToAcc = new Map(roomRows.map((r) => [r.id, r.accommodation_id]))
    const filledByAcc = new Map<string, number>()
    for (const l of leases) {
      if (l.status !== 'active') continue
      const accId = roomToAcc.get(l.room_id)
      if (accId) filledByAcc.set(accId, (filledByAcc.get(accId) || 0) + 1)
    }

    totalBeds.value = roomRows.reduce((n, r) => n + Number(r.capacity || 0), 0)
    filledBeds.value = [...filledByAcc.values()].reduce((n, v) => n + v, 0)

    accommodations.value = accs.map((a) => {
      const beds = roomRows
        .filter((r) => r.accommodation_id === a.id)
        .reduce((n, r) => n + Number(r.capacity || 0), 0)
      const filled = filledByAcc.get(a.id) || 0
      return {
        id: a.id,
        name: a.name,
        status: a.status,
        beds,
        filled,
        rate: beds === 0 ? 0 : Math.min(100, Math.round((filled / beds) * 100)),
      }
    })
    activeTenants.value = leases.filter((l) => l.status === 'active').length
    pendingLeases.value = leases.filter((l) => l.status === 'pending').length
    leaveRequests.value = leases.filter((l) => l.status === 'leave_requested').length
    expectedMonthly.value = leases
      .filter((l) => l.status === 'active')
      .reduce((n, l) => n + Number(l.monthly_rent || 0), 0)

    if (accIds.length > 0) {
      const { data: docRows } = await supabase
        .from('accommodation_documents')
        .select('expires_at')
        .in('accommodation_id', accIds)
      const now = Date.now()
      const soon = now + 30 * 24 * 60 * 60 * 1000
      const docs = (docRows || []).filter((d) => d.expires_at)
      expiredDocs.value = docs.filter((d) => new Date(d.expires_at as string).getTime() < now).length
      expiringDocs.value = docs.filter((d) => {
        const t = new Date(d.expires_at as string).getTime()
        return t >= now && t < soon
      }).length
    }

    const { count } = await supabase
      .from('tickets')
      .select('*', { count: 'exact', head: true })
      .eq('accommodation_manager_id', user.id)
      .neq('status', 'resolved')
    openTickets.value = count || 0
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
.row-head .sec-title { margin-bottom: var(--m-space-2); }
.sec-action { color: var(--m-primary-dark); font-weight: 700; }

.sk, .panel { border-radius: var(--m-radius); }
.panel { background: var(--m-surface); }
.panel-title { margin: var(--m-space-2) 0 0; color: var(--m-ink); font-weight: 700; }
.panel-sub { margin: 4px 0 0; color: var(--m-muted); font-size: 13px; }

/* Occupancy */
.occ-card { padding: var(--m-space-4); border-radius: var(--m-radius); background: var(--m-primary); color: #fff; }
.occ-card--empty { background: var(--m-surface); border: 1px dashed var(--m-border); color: var(--m-ink); }
.occ-top { display: flex; align-items: baseline; justify-content: space-between; }
.occ-caption { font-size: 12px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; opacity: 0.9; }
.occ-rate { font-family: var(--m-font-display); font-size: 30px; font-weight: 700; letter-spacing: -0.02em; }
.occ-track { margin-top: var(--m-space-3); height: 8px; border-radius: 999px; background: rgba(255, 255, 255, 0.32); overflow: hidden; }
.occ-card--empty .occ-track { background: var(--m-bg); }
.occ-fill { display: block; height: 100%; border-radius: 999px; background: #fff; transition: width 0.4s ease; }
.occ-card--empty .occ-fill { background: var(--m-border); }
.occ-foot { margin-top: var(--m-space-2); font-size: 13px; opacity: 0.92; }
.occ-card--empty .occ-foot { color: var(--m-muted); opacity: 1; }

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
.stat--warn { border-color: color-mix(in srgb, var(--m-warning) 45%, var(--m-border)); background: var(--m-warning-soft); }
.stat--danger { border-color: color-mix(in srgb, var(--m-danger) 40%, var(--m-border)); background: var(--m-danger-soft); }
.stat-value { color: var(--m-ink); font-family: var(--m-font-display); font-size: 20px; font-weight: 700; letter-spacing: -0.02em; }
.stat--wide .stat-value { font-size: 18px; }
.stat-label { color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Lists */
.list-card { overflow: hidden; }
.list-row {
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
.list-row--divided { border-top: 1px solid var(--m-border); }
.list-row--quiet { cursor: default; }
.list-row--add { cursor: pointer; }
.list-icon { display: grid; width: 32px; height: 32px; flex: 0 0 32px; place-items: center; border-radius: var(--m-radius-sm); }
.list-icon--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.list-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.list-icon--ok { background: var(--m-success-soft); color: var(--m-success); }
.list-icon--add { border: 1px dashed var(--m-border); background: var(--m-bg); color: var(--m-primary-dark); }
.list-text, .acc-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.list-label { color: var(--m-ink); font-size: 14px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.list-hint { color: var(--m-muted); font-size: 12px; }
.acc-meter { display: block; width: 44px; height: 6px; flex: 0 0 44px; border-radius: 999px; background: var(--m-bg); overflow: hidden; }
.acc-meter-fill { display: block; height: 100%; border-radius: 999px; background: var(--m-primary); }

@media (prefers-reduced-motion: reduce) {
  .stat, .occ-fill { transition: none; }
}
</style>
