<template>
  <q-page class="dash">
    <div v-if="loading" class="stack">
      <q-skeleton type="text" width="55%" height="26px" />
      <q-skeleton type="rect" height="150px" class="sk" />
      <q-skeleton type="rect" height="118px" class="sk" />
      <q-skeleton type="rect" height="150px" class="sk" />
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
      <div class="greet">
        <span class="greet-time">{{ greeting }},</span>
        <span class="greet-name">{{ firstName }}</span>
      </div>

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
              cx="60" cy="60" r="52" class="ring-fill"
              :stroke-dasharray="`${(occupancyRate / 100) * 326.7} 326.7`"
              transform="rotate(-90 60 60)"
            />
          </svg>
        </div>
      </q-card>

      <div class="strip">
        <div class="strip-cell">
          <span class="strip-value">{{ formatPeso(expectedMonthly) }}</span>
          <span class="strip-label">Expected / month</span>
        </div>
        <div class="strip-div" />
        <div class="strip-cell">
          <span class="strip-value">{{ vacantBeds }}</span>
          <span class="strip-label">{{ vacantBeds === 1 ? 'Bed free' : 'Beds free' }}</span>
        </div>
      </div>

      <!-- Needs attention: the actual items, not counts of them -->
      <q-card flat bordered class="card">
        <div class="card-head">
          <span class="card-title">Needs attention</span>
          <span v-if="attention.length" class="card-count">{{ attention.length }}</span>
        </div>

        <button
          v-for="item in visibleAttention"
          :key="item.id"
          type="button"
          class="row"
          @click="go(item.route)"
        >
          <span class="row-icon" :class="`row-icon--${item.tone}`">
            <IconifyIcon :icon="item.icon" width="14" />
          </span>
          <span class="row-body">
            <span class="row-label">{{ item.label }}</span>
            <span class="row-hint">{{ item.hint }}</span>
          </span>
          <span v-if="item.when" class="row-when">{{ item.when }}</span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chev" />
        </button>

        <button v-if="moreAttention > 0" type="button" class="row row--more" @click="go('/manager/osas-compliance')">
          <span class="row-label row-label--link">+ {{ moreAttention }} more</span>
        </button>

        <div v-if="!attention.length" class="row row--static">
          <span class="row-icon row-icon--ok"><IconifyIcon icon="lucide:check" width="14" /></span>
          <span class="row-body">
            <span class="row-label">All clear</span>
            <span class="row-hint">Concerns, applications and renewals land here</span>
          </span>
        </div>
      </q-card>

      <!-- Accommodations: ordered by what needs work, keyed on free beds -->
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
              <template v-if="a.expired">
                <span class="row-flag">{{ a.expired }} expired</span>
              </template>
            </span>
          </span>
          <span class="vac" :class="{ 'vac--full': a.beds > 0 && a.free === 0, 'vac--none': a.beds === 0 }">
            {{ a.beds === 0 ? 'No rooms' : a.free === 0 ? 'Full' : `${a.free} free` }}
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chev" />
        </button>

        <button v-if="moreAccommodations > 0" type="button" class="row row--more" @click="go('/manager/properties')">
          <span class="row-label row-label--link">+ {{ moreAccommodations }} more</span>
        </button>

        <button v-if="!hasAccommodations" type="button" class="row" @click="go('/manager/properties/new')">
          <span class="row-icon row-icon--add"><IconifyIcon icon="lucide:plus" width="13" /></span>
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
  free: number
  expired: number
}

interface AttentionItem {
  id: string
  icon: string
  label: string
  hint: string
  when: string
  route: string
  tone: 'danger' | 'warn'
  rank: number
}

const MAX_ACCOMMODATIONS = 4
const MAX_ATTENTION = 4

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const accommodations = ref<AccommodationCard[]>([])
const attention = ref<AttentionItem[]>([])
const totalBeds = ref(0)
const tenants = ref(0)
const expectedMonthly = ref(0)

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const hasAccommodations = computed(() => accommodations.value.length > 0)
const occupancyRate = computed(() =>
  totalBeds.value === 0 ? 0 : Math.min(100, Math.round((tenants.value / totalBeds.value) * 100)),
)
const vacantBeds = computed(() => Math.max(0, totalBeds.value - tenants.value))
const visibleAccommodations = computed(() => accommodations.value.slice(0, MAX_ACCOMMODATIONS))
const moreAccommodations = computed(() =>
  Math.max(0, accommodations.value.length - MAX_ACCOMMODATIONS),
)
const visibleAttention = computed(() => attention.value.slice(0, MAX_ATTENTION))
const moreAttention = computed(() => Math.max(0, attention.value.length - MAX_ATTENTION))

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

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function ago(iso: string | null | undefined) {
  if (!iso) return ''
  const then = new Date(iso).getTime()
  if (Number.isNaN(then)) return ''
  const days = Math.floor((Date.now() - then) / 86400000)
  if (days <= 0) return 'today'
  if (days === 1) return '1d'
  if (days < 30) return `${days}d`
  const months = Math.floor(days / 30)
  return months === 1 ? '1mo' : `${months}mo`
}

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
    const accName = new Map(accs.map((a) => [a.id, a.name]))

    // Capacity comes from rooms; occupancy is counted from active leases.
    // rooms.current_pax sits at 0 even where tenants exist, so it is not used.
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
    expectedMonthly.value = leases
      .filter((l) => l.status === 'active')
      .reduce((n, l) => n + Number(l.monthly_rent || 0), 0)

    // --- documents: both the per-accommodation flag and the queue items ---
    const expiredByAcc = new Map<string, number>()
    const items: AttentionItem[] = []

    if (accIds.length) {
      const { data: docRows } = await supabase
        .from('accommodation_documents')
        .select('id, doc_type, expires_at, accommodation_id')
        .in('accommodation_id', accIds)
      const now = Date.now()
      const soon = now + 30 * 24 * 60 * 60 * 1000

      for (const d of docRows || []) {
        if (!d.expires_at) continue
        const t = new Date(d.expires_at).getTime()
        const where = accName.get(d.accommodation_id) || 'Accommodation'
        if (t < now) {
          expiredByAcc.set(d.accommodation_id, (expiredByAcc.get(d.accommodation_id) || 0) + 1)
          items.push({
            id: `doc-${d.id}`,
            icon: 'lucide:file-warning',
            label: `${titleCase(d.doc_type)} expired`,
            hint: where,
            when: ago(d.expires_at),
            route: '/manager/osas-compliance',
            tone: 'danger',
            rank: 1,
          })
        } else if (t < soon) {
          items.push({
            id: `doc-soon-${d.id}`,
            icon: 'lucide:calendar-clock',
            label: `${titleCase(d.doc_type)} expires soon`,
            hint: where,
            when: '',
            route: '/manager/osas-compliance',
            tone: 'warn',
            rank: 3,
          })
        }
      }
    }

    accommodations.value = accs
      .map((a) => {
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
          free: Math.max(0, beds - filled),
          expired: expiredByAcc.get(a.id) || 0,
        }
      })
      // Surface what needs work: expired paperwork, then unaccredited, then
      // the ones with beds going unfilled.
      .sort(
        (x, y) =>
          y.expired - x.expired ||
          Number(x.status === 'accredited') - Number(y.status === 'accredited') ||
          y.free - x.free,
      )

    // --- student concerns: filed against a lease, so joined through it ---
    const { data: concernRows } = await supabase
      .from('concerns')
      .select(
        'id, category, reported_at, leases!inner(accommodation_manager_id, users!leases_student_id_fkey(full_name), rooms(accommodations(name)))',
      )
      .eq('leases.accommodation_manager_id', user.id)
      .neq('status', 'resolved')
      .order('reported_at', { ascending: false })
      .limit(6)

    for (const c of concernRows || []) {
      const lease = c.leases as unknown as {
        users: { full_name: string } | null
        rooms: { accommodations: { name: string } | null } | null
      } | null
      const who = lease?.users?.full_name || 'A tenant'
      const where = lease?.rooms?.accommodations?.name
      items.push({
        id: `concern-${c.id}`,
        icon: 'lucide:triangle-alert',
        label: `${titleCase(c.category) || 'Concern'} · ${who}`,
        hint: where ? `Reported at ${where}` : 'Reported by a tenant',
        when: ago(c.reported_at),
        route: '/manager/support',
        tone: 'danger',
        rank: 0,
      })
    }

    // --- applications and leave requests, named ---
    const { data: peopleRows } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, leave_requested_at, users!leases_student_id_fkey(full_name), rooms(room_number, accommodations(name))',
      )
      .eq('accommodation_manager_id', user.id)
      .in('status', ['pending', 'leave_requested'])
      .limit(6)

    for (const l of peopleRows || []) {
      const who =
        (l.users as unknown as { full_name: string } | null)?.full_name || 'A student'
      const room = l.rooms as unknown as {
        room_number: string | null
        accommodations: { name: string } | null
      } | null
      const where = [room?.room_number ? `Room ${room.room_number}` : '', room?.accommodations?.name]
        .filter(Boolean)
        .join(' · ')
      if (l.status === 'pending') {
        items.push({
          id: `app-${l.id}`,
          icon: 'lucide:user-plus',
          label: who,
          hint: where || 'Wants to move in',
          when: ago(l.start_date),
          route: '/manager/tenants',
          tone: 'warn',
          rank: 2,
        })
      } else {
        items.push({
          id: `leave-${l.id}`,
          icon: 'lucide:door-open',
          label: `${who} wants to leave`,
          hint: where || 'Awaiting your decision',
          when: ago(l.leave_requested_at),
          route: '/manager/tenants',
          tone: 'warn',
          rank: 2,
        })
      }
    }

    attention.value = items.sort((a, b) => a.rank - b.rank)
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

.greet { display: flex; align-items: baseline; gap: 5px; padding: 2px 2px 0; flex-wrap: wrap; }
.greet-time { color: var(--m-muted); font-size: 15px; font-weight: 500; }
.greet-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

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
.occ-pct { font-family: var(--m-font-display); font-size: 40px; font-weight: 700; letter-spacing: -0.03em; line-height: 1; }
.occ-sign { font-size: 20px; font-weight: 600; opacity: 0.8; }
.occ-sub { font-size: 12.5px; opacity: 0.9; }
.occ--empty .occ-sub, .occ--empty .occ-cap { color: var(--m-muted); opacity: 1; }
.occ-right { flex: 0 0 76px; }
.ring { display: block; width: 76px; height: 76px; }
.ring-track { fill: none; stroke: rgba(255, 255, 255, 0.28); stroke-width: 11; }
.occ--empty .ring-track { stroke: var(--m-bg); }
.ring-fill { fill: none; stroke: #fff; stroke-width: 11; stroke-linecap: round; transition: stroke-dasharray 0.5s ease; }
.occ--empty .ring-fill { stroke: var(--m-border); }

.strip { display: flex; align-items: stretch; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
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

.card-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 11px 14px 7px; }
.card-title { color: var(--m-ink); font-size: 13px; font-weight: 700; letter-spacing: -0.01em; }
.card-count { min-width: 18px; padding: 1px 6px; border-radius: 999px; background: var(--m-bg); color: var(--m-muted); font-size: 11px; font-weight: 700; text-align: center; }
.card-link { border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 12px; font-weight: 700; padding: 0; }

.row {
  display: flex;
  width: 100%;
  min-height: 50px;
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
.row-hint { display: flex; align-items: center; gap: 5px; color: var(--m-muted); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.row-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 600; }
.row-chev { color: #c7ccd3; flex: 0 0 auto; }

.row-icon { display: grid; width: 26px; height: 26px; flex: 0 0 26px; place-items: center; border-radius: 8px; }
.row-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.row-icon--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.row-icon--ok { background: var(--m-success-soft); color: var(--m-success); }
.row-icon--add { border: 1px dashed var(--m-border); background: var(--m-bg); color: var(--m-primary-dark); }

.row-flag { color: var(--m-danger); font-weight: 700; }
.pip { display: inline-block; width: 6px; height: 6px; flex: 0 0 6px; border-radius: 999px; }
.pip--ok { background: var(--m-success); }
.pip--warn { background: var(--m-warning); }
.pip--danger { background: var(--m-danger); }

.vac {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11.5px;
  font-weight: 700;
}
.vac--full { background: var(--m-bg); color: var(--m-muted); }
.vac--none { background: var(--m-bg); color: var(--m-muted); }

@media (prefers-reduced-motion: reduce) {
  .ring-fill { transition: none; }
}
</style>
