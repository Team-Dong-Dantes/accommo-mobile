<template>
  <q-page class="dash">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="128px" class="sk" />
      <q-skeleton type="rect" height="112px" class="sk" />
      <q-skeleton type="rect" height="132px" class="sk" />
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
      <!-- 1 · Portfolio. Every headline figure lives here and nowhere else. -->
      <q-card flat class="hero" :class="{ 'hero--empty': !hasAccommodations }">
        <div class="hero-top">
          <span class="hero-cap">Occupancy</span>
          <span class="hero-rate">{{ hasAccommodations ? `${occupancyRate}%` : '—' }}</span>
        </div>
        <div class="hero-track">
          <div class="hero-fill" :style="{ width: `${occupancyRate}%` }" />
        </div>
        <div class="hero-facts">
          <span>
            <b>{{ tenants }}</b>/{{ totalBeds }} beds
          </span>
          <span class="hero-dot">·</span>
          <span>
            <b>{{ accommodations.length }}</b>
            {{ accommodations.length === 1 ? 'accommodation' : 'accommodations' }}
          </span>
          <span class="hero-dot">·</span>
          <span><b>{{ formatPeso(expectedMonthly) }}</b> expected</span>
        </div>
      </q-card>

      <!-- 2 · One action queue. Compliance, approvals and tickets rank together
           here rather than each getting its own duplicate counter row. -->
      <q-card flat bordered class="card">
        <div class="card-head">
          <span class="card-title">Needs attention</span>
          <span v-if="attention.length" class="card-count">{{ attention.length }}</span>
        </div>
        <button
          v-for="item in attention"
          :key="item.label"
          type="button"
          class="row"
          @click="go(item.route)"
        >
          <span class="row-dot" :class="`row-dot--${item.tone}`" />
          <span class="row-body">
            <span class="row-label">{{ item.label }}</span>
            <span class="row-hint">{{ item.hint }}</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chev" />
        </button>
        <div v-if="!attention.length" class="row row--static">
          <span class="row-dot row-dot--ok" />
          <span class="row-body">
            <span class="row-label">All clear</span>
            <span class="row-hint">Renewals, applications and tickets land here</span>
          </span>
        </div>
      </q-card>

      <!-- 3 · The portfolio itself. Status appears once, per accommodation. -->
      <q-card flat bordered class="card">
        <div class="card-head">
          <span class="card-title">Accommodations</span>
          <button v-if="hasAccommodations" type="button" class="card-link" @click="go('/manager/properties')">
            Manage
          </button>
        </div>

        <button
          v-for="a in accommodations"
          :key="a.id"
          type="button"
          class="row"
          @click="go(`/manager/properties/${a.id}`)"
        >
          <span class="row-body">
            <span class="row-label">{{ a.name }}</span>
            <span class="row-hint">
              <i class="pip" :class="`pip--${toneOf(a.status)}`" />{{ statusLabel(a.status) }}
              · {{ a.filled }}/{{ a.beds }}
            </span>
          </span>
          <span class="meter" aria-hidden="true">
            <span class="meter-fill" :style="{ width: `${a.rate}%` }" />
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chev" />
        </button>

        <button v-if="!hasAccommodations" type="button" class="row" @click="go('/manager/properties/new')">
          <span class="row-dot row-dot--add"><IconifyIcon icon="lucide:plus" width="12" /></span>
          <span class="row-body">
            <span class="row-label">Add your first accommodation</span>
            <span class="row-hint">Rooms, tenants and compliance follow from here</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chev" />
        </button>
      </q-card>
    </div>
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
const accommodations = ref<AccommodationCard[]>([])
const totalBeds = ref(0)
// Tenants and filled beds are the same measure (both counted from active
// leases), so it is stored and shown once.
const tenants = ref(0)
const pendingLeases = ref(0)
const leaveRequests = ref(0)
const expectedMonthly = ref(0)
const expiredDocs = ref(0)
const expiringDocs = ref(0)
const openTickets = ref(0)

const hasAccommodations = computed(() => accommodations.value.length > 0)
const occupancyRate = computed(() =>
  totalBeds.value === 0 ? 0 : Math.min(100, Math.round((tenants.value / totalBeds.value) * 100)),
)
const notAccredited = computed(
  () => accommodations.value.filter((a) => a.status !== 'accredited').length,
)

const STATUS_LABEL: Record<string, string> = {
  accredited: 'Accredited',
  pending: 'Pending',
  reviewing: 'Reviewing',
  rejected: 'Rejected',
  delisted: 'Delisted',
}
function statusLabel(s: string) {
  return STATUS_LABEL[s] ?? s
}
function toneOf(s: string) {
  if (s === 'accredited') return 'ok'
  if (s === 'rejected' || s === 'delisted') return 'danger'
  return 'warn'
}

const attention = computed(() => {
  const items: { label: string; hint: string; route: string; tone: string }[] = []
  if (expiredDocs.value)
    items.push({
      label: `${expiredDocs.value} expired ${expiredDocs.value === 1 ? 'document' : 'documents'}`,
      hint: 'Re-upload to keep accreditation',
      route: '/manager/osas-compliance',
      tone: 'danger',
    })
  if (pendingLeases.value)
    items.push({
      label: `${pendingLeases.value} pending ${pendingLeases.value === 1 ? 'application' : 'applications'}`,
      hint: 'Waiting on your decision',
      route: '/manager/tenants',
      tone: 'warn',
    })
  if (leaveRequests.value)
    items.push({
      label: `${leaveRequests.value} leave ${leaveRequests.value === 1 ? 'request' : 'requests'}`,
      hint: 'Tenant wants to move out',
      route: '/manager/tenants',
      tone: 'warn',
    })
  if (openTickets.value)
    items.push({
      label: `${openTickets.value} open ${openTickets.value === 1 ? 'ticket' : 'tickets'}`,
      hint: 'Reported by tenants or OSAS',
      route: '/manager/support',
      tone: 'warn',
    })
  if (expiringDocs.value)
    items.push({
      label: `${expiringDocs.value} ${expiringDocs.value === 1 ? 'document expires' : 'documents expire'} soon`,
      hint: 'Within 30 days',
      route: '/manager/osas-compliance',
      tone: 'warn',
    })
  if (notAccredited.value)
    items.push({
      label: `${notAccredited.value} awaiting accreditation`,
      hint: 'Not yet approved by OSAS',
      route: '/manager/osas-compliance',
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

    const { data: accRows, error: accError } = await supabase
      .from('accommodations')
      .select('id, name, status')
      .eq('accommodation_manager_id', user.id)
    if (accError) throw accError

    const accs = accRows || []
    const accIds = accs.map((a) => a.id)

    // Capacity comes from rooms; occupancy is counted from active leases.
    // rooms.current_pax sits at 0 even where tenants exist, and rooms.status
    // disagrees with the lease data, so leases are the only reliable source.
    let roomRows: { id: string; accommodation_id: string; capacity: number | null }[] = []
    if (accIds.length) {
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
    tenants.value = leases.filter((l) => l.status === 'active').length
    pendingLeases.value = leases.filter((l) => l.status === 'pending').length
    leaveRequests.value = leases.filter((l) => l.status === 'leave_requested').length
    expectedMonthly.value = leases
      .filter((l) => l.status === 'active')
      .reduce((n, l) => n + Number(l.monthly_rent || 0), 0)

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

    if (accIds.length) {
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
.hero-top { display: flex; align-items: baseline; justify-content: space-between; }
.hero-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; opacity: 0.9; }
.hero-rate { font-family: var(--m-font-display); font-size: 28px; font-weight: 700; letter-spacing: -0.02em; line-height: 1; }
.hero-track { margin-top: 10px; height: 6px; border-radius: 999px; background: rgba(255, 255, 255, 0.3); overflow: hidden; }
.hero--empty .hero-track { background: var(--m-bg); }
.hero-fill { display: block; height: 100%; border-radius: 999px; background: #fff; transition: width 0.4s ease; }
.hero--empty .hero-fill { background: var(--m-border); }
.hero-facts {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 5px;
  margin-top: 8px;
  font-size: 12px;
  opacity: 0.94;
}
.hero-facts b { font-weight: 700; }
.hero--empty .hero-facts { color: var(--m-muted); opacity: 1; }
.hero-dot { opacity: 0.5; }

/* Card head */
.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 11px 14px 7px;
}
.card-title { color: var(--m-ink); font-size: 13px; font-weight: 700; letter-spacing: -0.01em; }
.card-count {
  min-width: 18px;
  padding: 1px 6px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  text-align: center;
}
.card-link { border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 12px; font-weight: 700; padding: 0; }

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
.row--static { cursor: default; }
.row-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.row-label { color: var(--m-ink); font-size: 13.5px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.row-hint { display: flex; align-items: center; gap: 5px; color: var(--m-muted); font-size: 11.5px; }
.row-chev { color: #c7ccd3; flex: 0 0 auto; }

.row-dot { display: grid; width: 22px; height: 22px; flex: 0 0 22px; place-items: center; border-radius: 999px; }
.row-dot--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.row-dot--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.row-dot--ok { background: var(--m-success-soft); color: var(--m-success); }
.row-dot--add { border: 1px dashed var(--m-border); background: var(--m-bg); color: var(--m-primary-dark); }
.row-dot--danger::before, .row-dot--warn::before, .row-dot--ok::before {
  content: '';
  width: 7px;
  height: 7px;
  border-radius: 999px;
  background: currentColor;
}

.pip { display: inline-block; width: 6px; height: 6px; border-radius: 999px; }
.pip--ok { background: var(--m-success); }
.pip--warn { background: var(--m-warning); }
.pip--danger { background: var(--m-danger); }

.meter { display: block; width: 38px; height: 5px; flex: 0 0 38px; border-radius: 999px; background: var(--m-bg); overflow: hidden; }
.meter-fill { display: block; height: 100%; border-radius: 999px; background: var(--m-primary); }

@media (prefers-reduced-motion: reduce) {
  .hero-fill { transition: none; }
}
</style>
