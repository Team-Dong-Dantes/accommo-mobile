<template>
  <q-page class="dash">
    <div v-if="loading" class="stack">
      <q-skeleton type="text" width="55%" height="26px" />
      <q-skeleton type="rect" height="150px" class="sk" />
      <q-skeleton type="rect" height="118px" class="sk" />
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
      <!-- Greeting -->
      <div class="greet">
        <span class="greet-time">{{ greeting }},</span>
        <span class="greet-name">{{ firstName }}</span>
      </div>

      <!-- Occupancy card -->
      <q-card flat class="occ" :class="{ 'occ--empty': !hasAccommodations }">
        <div class="occ-left">
          <span class="occ-cap">Occupancy</span>
          <span class="occ-pct">
            {{ hasAccommodations ? occupancyRate : 0 }}<span class="occ-sign">%</span>
          </span>
          <span class="occ-sub">
            {{ hasAccommodations ? `${tenants} of ${totalBeds} beds filled` : 'No beds listed yet' }}
          </span>
        </div>

        <div class="occ-right" aria-hidden="true">
          <svg viewBox="0 0 120 120" class="ring">
            <circle cx="60" cy="60" r="52" class="ring-track" />
            <circle
              cx="60"
              cy="60"
              r="52"
              class="ring-fill"
              :stroke-dasharray="`${(occupancyRate / 100) * 326.7} 326.7`"
              transform="rotate(-90 60 60)"
            />
          </svg>
        </div>
      </q-card>

      <!-- Money + scale, as a quiet strip under the headline number -->
      <div class="strip">
        <div class="strip-cell">
          <span class="strip-value">{{ formatPeso(expectedMonthly) }}</span>
          <span class="strip-label">Expected / month</span>
        </div>
        <div class="strip-div" />
        <div class="strip-cell">
          <span class="strip-value">{{ accommodations.length }}</span>
          <span class="strip-label">
            {{ accommodations.length === 1 ? 'Accommodation' : 'Accommodations' }}
          </span>
        </div>
      </div>

      <!-- Action queue -->
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
            <span class="row-hint">Concerns, applications and renewals land here</span>
          </span>
        </div>
      </q-card>

      <!-- Register -->
      <q-card flat bordered class="card">
        <div class="card-head">
          <span class="card-title">Accommodations</span>
          <button v-if="hasAccommodations" type="button" class="card-link" @click="go('/manager/properties')">
            Manage
          </button>
        </div>

        <button
          v-for="a in visibleAccommodations"
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

        <button v-if="hiddenCount > 0" type="button" class="row row--more" @click="go('/manager/properties')">
          <span class="row-label row-label--link">+ {{ hiddenCount }} more</span>
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

const MAX_VISIBLE = 4

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const accommodations = ref<AccommodationCard[]>([])
const totalBeds = ref(0)
// Tenants and filled beds are one measure (both counted from active leases).
const tenants = ref(0)
const pendingLeases = ref(0)
const leaveRequests = ref(0)
const expectedMonthly = ref(0)
const expiredDocs = ref(0)
const expiringDocs = ref(0)
const openConcerns = ref(0)

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const hasAccommodations = computed(() => accommodations.value.length > 0)
const occupancyRate = computed(() =>
  totalBeds.value === 0 ? 0 : Math.min(100, Math.round((tenants.value / totalBeds.value) * 100)),
)
const visibleAccommodations = computed(() => accommodations.value.slice(0, MAX_VISIBLE))
const hiddenCount = computed(() => Math.max(0, accommodations.value.length - MAX_VISIBLE))
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
  if (openConcerns.value)
    items.push({
      label: `${openConcerns.value} student ${openConcerns.value === 1 ? 'concern' : 'concerns'}`,
      hint: 'Raised about your accommodation',
      route: '/manager/support',
      tone: 'danger',
    })
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

    // Concerns are filed by students against a lease, so they reach the manager
    // through it. Anything not yet resolved still needs a reply.
    const { count: concernCount } = await supabase
      .from('concerns')
      .select('id, leases!inner(accommodation_manager_id)', { count: 'exact', head: true })
      .eq('leases.accommodation_manager_id', user.id)
      .neq('status', 'resolved')
    openConcerns.value = concernCount || 0
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
  padding: 8px var(--m-page-gutter) 24px;
}
.sk { border-radius: var(--m-radius); }

.card { border-radius: var(--m-radius); background: var(--m-surface); overflow: hidden; }
.card--pad { padding: 18px 14px; }
.err-title { margin: 8px 0 0; color: var(--m-ink); font-size: 14px; font-weight: 700; }
.err-sub { margin: 2px 0 0; color: var(--m-muted); font-size: 12px; }

/* Greeting */
.greet { display: flex; align-items: baseline; gap: 5px; padding: 2px 2px 0; flex-wrap: wrap; }
.greet-time { color: var(--m-muted); font-size: 15px; font-weight: 500; }
.greet-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

/* Occupancy card */
.occ {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 16px;
  border-radius: var(--m-radius);
  background: var(--m-primary);
  color: #fff;
}
.occ--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.occ-left { display: flex; min-width: 0; flex-direction: column; gap: 3px; }
.occ-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; opacity: 0.9; }
.occ-pct {
  font-family: var(--m-font-display);
  font-size: 40px;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
}
.occ-sign { font-size: 20px; font-weight: 600; opacity: 0.8; }
.occ-sub { font-size: 12.5px; opacity: 0.9; }
.occ--empty .occ-sub, .occ--empty .occ-cap { color: var(--m-muted); opacity: 1; }
.occ-right { flex: 0 0 76px; }
.ring { display: block; width: 76px; height: 76px; }
.ring-track { fill: none; stroke: rgba(255, 255, 255, 0.28); stroke-width: 11; }
.occ--empty .ring-track { stroke: var(--m-bg); }
.ring-fill {
  fill: none;
  stroke: #fff;
  stroke-width: 11;
  stroke-linecap: round;
  transition: stroke-dasharray 0.5s ease;
}
.occ--empty .ring-fill { stroke: var(--m-border); }

/* Strip */
.strip {
  display: flex;
  align-items: stretch;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.strip-cell { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; gap: 2px; padding: 11px 14px; }
.strip-div { width: 1px; background: var(--m-border); }
.strip-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.strip-label { color: var(--m-muted); font-size: 11.5px; font-weight: 600; }

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
.row--more { min-height: 42px; }
.row-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.row-label { color: var(--m-ink); font-size: 13.5px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.row-label--link { color: var(--m-primary-dark); font-size: 12.5px; }
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
  .ring-fill { transition: none; }
}
</style>
