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

      <!-- Needs attention: one actionable lead, the rest kept quiet -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Needs attention</h2>
          <button
            v-if="moreAttention > 0"
            type="button"
            class="sec-link"
            @click="go('/manager/osas-compliance')"
          >
            +{{ moreAttention }} more
          </button>
        </div>

        <!-- Lead item: the one thing to deal with first, with its action -->
        <div v-if="lead" class="lead" :class="`lead--${lead.tone}`">
          <div class="lead-top">
            <span class="lead-icon"><IconifyIcon :icon="lead.icon" width="18" /></span>
            <span class="lead-kind">{{ lead.kind }}</span>
            <span v-if="lead.when" class="lead-when">{{ lead.when }}</span>
          </div>
          <p class="lead-label">{{ lead.label }}</p>
          <p class="lead-hint">{{ lead.hint }}</p>
          <button type="button" class="lead-action" @click="go(lead.route)">
            {{ lead.action }}
            <IconifyIcon icon="lucide:arrow-right" width="15" />
          </button>
        </div>

        <!-- Everything else stays quiet until it is the lead -->
        <div v-if="rest.length" class="minors">
          <button
            v-for="item in rest"
            :key="item.id"
            type="button"
            class="minor"
            @click="go(item.route)"
          >
            <span class="minor-dot" :class="`minor-dot--${item.tone}`" />
            <span class="minor-text">
              <span class="minor-label">{{ item.label }}</span>
              <span class="minor-hint">{{ item.hint }}</span>
            </span>
            <span v-if="item.when" class="minor-when">{{ item.when }}</span>
          </button>
        </div>

        <div v-if="!attention.length" class="clear">
          <span class="clear-icon"><IconifyIcon icon="lucide:check" width="17" /></span>
          <span class="clear-text">
            <span class="clear-label">Nothing needs you</span>
            <span class="clear-hint">Concerns, applications and renewals land here</span>
          </span>
        </div>
      </section>

      <!-- Accommodations: a card rail, ordered by what needs work -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Accommodations</h2>
          <button
            v-if="hasAccommodations"
            type="button"
            class="sec-link"
            @click="go('/manager/properties')"
          >
            Manage
          </button>
        </div>

        <div class="rail">
          <button
            v-for="a in accommodations"
            :key="a.id"
            type="button"
            class="tile"
            @click="go(`/manager/properties/${a.id}`)"
          >
            <span class="tile-top">
              <span class="tile-status" :class="`tile-status--${toneOf(a.status)}`">
                {{ statusLabel(a.status) }}
              </span>
              <span v-if="a.expired" class="tile-alert">
                <IconifyIcon icon="lucide:file-warning" width="13" />{{ a.expired }}
              </span>
            </span>

            <span class="tile-name">{{ a.name }}</span>

            <span class="tile-foot">
              <span class="tile-free" :class="{ 'tile-free--muted': a.beds === 0 || a.free === 0 }">
                {{ a.beds === 0 ? 'No rooms yet' : a.free === 0 ? 'Full' : `${a.free} free` }}
              </span>
              <span class="tile-bar" aria-hidden="true">
                <span
                  class="tile-bar-fill"
                  :style="{ width: `${a.beds === 0 ? 0 : Math.round((a.filled / a.beds) * 100)}%` }"
                />
              </span>
            </span>
          </button>

          <button type="button" class="tile tile--add" @click="go('/manager/properties/new')">
            <span class="tile-add-icon"><IconifyIcon icon="lucide:plus" width="18" /></span>
            <span class="tile-add-label">
              {{ hasAccommodations ? 'Add another' : 'Add your first accommodation' }}
            </span>
          </button>
        </div>
      </section>
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
  /** Short category shown above the lead item. */
  kind: string
  label: string
  hint: string
  when: string
  /** What the button offers to do about it. */
  action: string
  route: string
  tone: 'danger' | 'warn'
  rank: number
}

const MAX_MINOR = 3

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
const lead = computed<AttentionItem | null>(() => attention.value[0] ?? null)
const rest = computed(() => attention.value.slice(1, 1 + MAX_MINOR))
const moreAttention = computed(() => Math.max(0, attention.value.length - 1 - MAX_MINOR))

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
            kind: 'Compliance',
            label: `${titleCase(d.doc_type)} expired`,
            hint: `${where} — accreditation is at risk until this is renewed`,
            when: ago(d.expires_at),
            action: 'Upload renewal',
            route: '/manager/osas-compliance',
            tone: 'danger',
            rank: 1,
          })
        } else if (t < soon) {
          items.push({
            id: `doc-soon-${d.id}`,
            icon: 'lucide:calendar-clock',
            kind: 'Compliance',
            label: `${titleCase(d.doc_type)} expires soon`,
            hint: `${where} — renew it before it lapses`,
            when: '',
            action: 'Renew now',
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
        icon: 'lucide:message-square-warning',
        kind: 'Student concern',
        label: `${titleCase(c.category) || 'Concern'} reported by ${who}`,
        hint: where ? `At ${where} — awaiting your reply` : 'Awaiting your reply',
        when: ago(c.reported_at),
        action: 'Reply',
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
          kind: 'Application',
          label: `${who} wants to move in`,
          hint: where || 'Waiting on your decision',
          when: ago(l.start_date),
          action: 'Review application',
          route: '/manager/tenants',
          tone: 'warn',
          rank: 2,
        })
      } else {
        items.push({
          id: `leave-${l.id}`,
          icon: 'lucide:door-open',
          kind: 'Leave request',
          label: `${who} wants to move out`,
          hint: where || 'Waiting on your decision',
          when: ago(l.leave_requested_at),
          action: 'Review request',
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
  gap: 8px;
  padding: 6px var(--m-page-gutter) 20px;
}
.sk { border-radius: var(--m-radius); }

.card { border-radius: var(--m-radius); background: var(--m-surface); overflow: hidden; }
.card--pad { padding: 18px 14px; }
.err-title { margin: 8px 0 0; color: var(--m-ink); font-size: 14px; font-weight: 700; }
.err-sub { margin: 2px 0 0; color: var(--m-muted); font-size: 12px; }

.greet { display: flex; align-items: baseline; gap: 5px; padding: 0 2px; flex-wrap: wrap; }
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
  padding: 13px 14px;
  border-radius: var(--m-radius);
  background: var(--m-primary);
  color: #fff;
}
.occ--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.occ-left { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.occ-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; opacity: 0.9; }
.occ-pct { font-family: var(--m-font-display); font-size: 36px; font-weight: 700; letter-spacing: -0.03em; line-height: 1; }
.occ-sign { font-size: 20px; font-weight: 600; opacity: 0.8; }
.occ-sub { font-size: 12.5px; opacity: 0.9; }
.occ--empty .occ-sub, .occ--empty .occ-cap { color: var(--m-muted); opacity: 1; }
.occ-right { flex: 0 0 68px; }
.ring { display: block; width: 68px; height: 68px; }
.ring-track { fill: none; stroke: rgba(255, 255, 255, 0.28); stroke-width: 11; }
.occ--empty .ring-track { stroke: var(--m-bg); }
.ring-fill { fill: none; stroke: #fff; stroke-width: 11; stroke-linecap: round; transition: stroke-dasharray 0.5s ease; }
.occ--empty .ring-fill { stroke: var(--m-border); }

.strip { display: flex; align-items: stretch; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.strip-cell { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; gap: 1px; padding: 9px 12px; }
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

/* Sections */
.sec { display: flex; flex-direction: column; gap: 6px; }
.sec-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; padding: 0 2px; }
.sec-title { margin: 0; color: var(--m-ink); font-size: 14px; font-weight: 700; letter-spacing: -0.01em; }
.sec-link { border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 12.5px; font-weight: 700; padding: 0; }

/* Lead: the single thing to deal with first */
.lead {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 12px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.lead--danger { border-color: color-mix(in srgb, var(--m-danger) 22%, var(--m-border)); }
.lead--warn { border-color: color-mix(in srgb, var(--m-warning) 26%, var(--m-border)); }
.lead-top { display: flex; align-items: center; gap: 7px; }
.lead-icon { display: grid; width: 27px; height: 27px; flex: 0 0 27px; place-items: center; border-radius: 999px; }
.lead--danger .lead-icon { background: var(--m-danger-soft); color: var(--m-danger); }
.lead--warn .lead-icon { background: var(--m-warning-soft); color: var(--m-warning); }
.lead-kind {
  flex: 1 1 auto;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.lead--danger .lead-kind { color: var(--m-danger); }
.lead--warn .lead-kind { color: var(--m-warning); }
.lead-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.lead-label {
  margin: 4px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  text-wrap: pretty;
}
.lead-hint { margin: 1px 0 0; color: var(--m-muted); font-size: 12px; line-height: 1.35; text-wrap: pretty; }
.lead-action {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  min-height: 40px;
  margin-top: 9px;
  padding: 0 15px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.lead-action:active { transform: scale(0.97); }

/* Minors: everything still waiting, kept quiet */
.minors { display: flex; flex-direction: column; gap: 4px; }
.minor {
  display: flex;
  width: 100%;
  min-height: 44px;
  align-items: center;
  gap: 10px;
  padding: 6px 12px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.minor-dot { width: 7px; height: 7px; flex: 0 0 7px; border-radius: 999px; }
.minor-dot--danger { background: var(--m-danger); }
.minor-dot--warn { background: var(--m-warning); }
.minor-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.minor-label { color: var(--m-ink); font-size: 13px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.minor-hint { color: var(--m-muted); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.minor-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 600; }

/* Clear state keeps the block's footprint */
.clear {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.clear-icon { display: grid; width: 30px; height: 30px; flex: 0 0 30px; place-items: center; border-radius: 999px; background: var(--m-success-soft); color: var(--m-success); }
.clear-text { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.clear-label { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.clear-hint { color: var(--m-muted); font-size: 12px; }

/* Accommodation rail */
.rail {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 1px calc(var(--m-page-gutter)) 3px;
  margin: 0 calc(-1 * var(--m-page-gutter));
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.rail::-webkit-scrollbar { display: none; }
.tile {
  display: flex;
  flex: 0 0 162px;
  min-height: 118px;
  flex-direction: column;
  gap: 6px;
  padding: 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  scroll-snap-align: start;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.tile:active { transform: scale(0.97); }
.tile-top { display: flex; align-items: center; justify-content: space-between; gap: 6px; }
.tile-status { padding: 3px 8px; border-radius: 999px; font-size: 10.5px; font-weight: 700; }
.tile-status--ok { background: var(--m-success-soft); color: var(--m-success); }
.tile-status--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.tile-status--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.tile-alert { display: inline-flex; align-items: center; gap: 3px; color: var(--m-danger); font-size: 11px; font-weight: 700; }
.tile-name {
  flex: 1 1 auto;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
  line-height: 1.25;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.tile-foot { display: flex; flex-direction: column; gap: 5px; }
.tile-free { color: var(--m-primary-dark); font-size: 12.5px; font-weight: 700; }
.tile-free--muted { color: var(--m-muted); }
.tile-bar { display: block; height: 4px; border-radius: 999px; background: var(--m-bg); overflow: hidden; }
.tile-bar-fill { display: block; height: 100%; border-radius: 999px; background: var(--m-primary); }

.tile--add {
  align-items: center;
  justify-content: center;
  gap: 9px;
  border-style: dashed;
  background: transparent;
  text-align: center;
}
.tile-add-icon { display: grid; width: 34px; height: 34px; place-items: center; border-radius: 999px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.tile-add-label { color: var(--m-muted); font-size: 12.5px; font-weight: 700; line-height: 1.3; }

@media (prefers-reduced-motion: reduce) {
  .ring-fill, .lead-action, .tile { transition: none; }
}

@media (prefers-reduced-motion: reduce) {
  .ring-fill { transition: none; }
}
</style>
