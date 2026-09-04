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
      <!-- Greeting -->
      <div class="greet">
        <span class="greet-time">{{ greeting }},</span>
        <span class="greet-name">{{ firstName }}</span>
      </div>

      <!-- Occupancy Card -->
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

      <!-- Stats strip -->
      <div class="strip">
        <button type="button" class="strip-cell strip-cell--link" @click="go('/manager/payments')">
          <span class="strip-value">{{ formatPeso(expectedMonthly) }}</span>
          <span class="strip-label">Expected / month · View payments</span>
        </button>
        <div class="strip-div" />
        <div class="strip-cell">
          <span class="strip-value">{{ vacantBeds }}</span>
          <span class="strip-label">{{ vacantBeds === 1 ? 'Bed free' : 'Beds free' }}</span>
        </div>
      </div>

      <!-- ===== TENANT PULSE (unchanged) ===== -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Tenant pulse</h2>
          <button
            v-if="recentFeedback.length"
            type="button"
            class="sec-link"
            @click="go('/manager/support')"
          >
            View all
          </button>
        </div>

        <div v-if="recentFeedback.length" class="pulse-list">
          <div
            v-for="item in recentFeedback"
            :key="item.id"
            class="pulse-item"
          >
            <div class="pulse-icon">
              <IconifyIcon icon="lucide:message-square" width="16" />
            </div>
            <div class="pulse-content">
              <span class="pulse-label">{{ item.label }}</span>
              <span class="pulse-meta">
                <span class="pulse-who">{{ item.kind }}</span>
                <span v-if="item.when" class="pulse-when">{{ item.when }}</span>
              </span>
            </div>
            <q-btn
              :label="item.action"
              flat
              dense
              no-caps
              size="sm"
              color="primary"
              class="pulse-action"
              @click="go(item.route)"
            />
          </div>
        </div>

        <div v-else class="empty-pulse">
          <IconifyIcon icon="lucide:smile" width="24" class="empty-pulse-icon" />
          <span class="empty-pulse-label">No recent feedback</span>
          <span class="empty-pulse-hint">Tenant concerns and reviews appear here</span>
        </div>
      </section>

      <!-- ===== PROPERTY HEALTH – permits & compliance only ===== -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Property health</h2>
          <button
            v-if="hasAccommodations"
            type="button"
            class="sec-link"
            @click="go('/manager/properties')"
          >
            Manage
          </button>
        </div>

        <div class="grid">
          <button
            v-for="a in accommodations"
            :key="a.id"
            type="button"
            class="tile"
            :class="`tile--health-${healthTone(a)}`"
            @click="go(`/manager/properties/${a.id}`)"
          >
            <span class="tile-top">
              <span class="tile-status" :class="`tile-status--${toneOf(a.status)}`">
                {{ statusLabel(a.status) }}
              </span>
              <!-- Health dot moved to top‑right -->
              <span class="tile-health-dot" :class="`tile-health-dot--${healthTone(a)}`" />
            </span>

            <span class="tile-name">{{ a.name }}</span>

            <!-- Document health summary -->
            <span class="tile-doc-summary">
              <span v-if="a.expired > 0" class="tile-doc-expired">
                <IconifyIcon icon="lucide:file-warning" width="14" />
                {{ a.expired }} expired {{ a.expired === 1 ? 'permit' : 'permits' }}
              </span>
              <span v-else-if="a.expiringSoon > 0" class="tile-doc-expiring">
                <IconifyIcon icon="lucide:clock" width="14" />
                {{ a.expiringSoon }} expiring soon
              </span>
              <span v-else class="tile-doc-ok">
                <IconifyIcon icon="lucide:check-circle" width="14" />
                All permits up to date
              </span>
            </span>
          </button>

          <!-- Add tile -->
          <button type="button" class="tile tile--add" @click="go('/manager/properties/new')">
            <span class="tile-add-icon"><IconifyIcon icon="lucide:plus" width="22" /></span>
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
import { ago } from '@/utils/profile'

interface AccommodationCard {
  id: string
  name: string
  status: string
  expired: number      // count of expired documents
  expiringSoon: number // count of documents expiring within 30 days
}

interface AttentionItem {
  id: string
  icon: string
  kind: string
  label: string
  hint: string
  when: string
  action: string
  route: string
  tone: 'danger' | 'warn'
  rank: number
}

const MAX_FEEDBACK = 3

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

// Tenant Pulse: filter concerns from attention list
const recentFeedback = computed(() =>
  attention.value
    .filter(item => item.kind === 'Student concern')
    .slice(0, MAX_FEEDBACK),
)

// Health tone based on document status and accreditation
function healthTone(a: AccommodationCard): 'good' | 'warn' | 'danger' {
  if (a.expired > 0) return 'danger'
  if (a.expiringSoon > 0) return 'warn'
  if (a.status !== 'accredited') return 'warn'
  return 'good'
}

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

    // Document tracking
    const expiredByAcc = new Map<string, number>()
    const expiringSoonByAcc = new Map<string, number>()
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
          expiringSoonByAcc.set(d.accommodation_id, (expiringSoonByAcc.get(d.accommodation_id) || 0) + 1)
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

    // Build accommodation cards – now with only document data, no room metrics
    accommodations.value = accs.map((a) => ({
      id: a.id,
      name: a.name,
      status: a.status,
      expired: expiredByAcc.get(a.id) || 0,
      expiringSoon: expiringSoonByAcc.get(a.id) || 0,
    }))

    // Rest of attention items (concerns, applications, leave requests)
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
          route: `/manager/tenant/${l.id}`,
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
          route: `/manager/tenant/${l.id}`,
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
/* (All existing styles remain unchanged) */
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding: 5px var(--m-page-gutter) 16px;
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
  padding: 12px 13px;
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
.strip-cell { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; gap: 1px; padding: 8px 11px; }
.strip-cell--link { border: 0; background: transparent; text-align: left; font: inherit; cursor: pointer; -webkit-tap-highlight-color: transparent; }
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

/* ===== SECTION HEADERS ===== */
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 0 2px;

  padding-bottom: 4px;
}
.sec-title {
  margin: 0;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}
.sec-link {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  padding: 4px 8px;
  border-radius: 999px;
  transition: background 0.15s;
}
.sec-link:hover {
  background: var(--m-primary-soft);
}

/* ===== TENANT PULSE ===== */
.pulse-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.pulse-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;

  transition: background 0.15s;
}
.pulse-item:last-child {
  border-bottom: none;
}
.pulse-item:hover {
  background: var(--m-bg);
}
.pulse-icon {
  flex: 0 0 28px;
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pulse-content {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.pulse-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--m-ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.pulse-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  color: var(--m-muted);
}
.pulse-who {
  font-weight: 600;
}
.pulse-when {
  opacity: 0.8;
}
.pulse-action {
  flex: 0 0 auto;
  padding: 0 10px;
  min-height: 28px;
  font-weight: 700;
  color: var(--m-primary);
  border-radius: 4px;
}
.pulse-action:hover {
  background: var(--m-primary-soft);
}

.empty-pulse {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 20px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.empty-pulse-icon {
  color: var(--m-muted);
  opacity: 0.5;
}
.empty-pulse-label {
  font-size: 14px;
  font-weight: 700;
  color: var(--m-ink);
}
.empty-pulse-hint {
  font-size: 12px;
  color: var(--m-muted);
}

/* ===== PROPERTY HEALTH CARDS – permits only ===== */
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 10px;
}
.tile {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  transition: transform 0.12s ease, box-shadow 0.15s, border-color 0.15s;
  box-shadow: 0 1px 3px rgba(0,0,0,0.02);
  position: relative;
}
.tile:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.06);
}
.tile:active {
  transform: scale(0.97);
}

.tile-health-dot {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 10px;
  height: 10px;
  border-radius: 999px;
  border: 2px solid var(--m-surface);
  box-shadow: 0 0 0 1px var(--m-border);
}
.tile-health-dot--good {
  background: var(--m-success);
}
.tile-health-dot--warn {
  background: var(--m-warning);
}
.tile-health-dot--danger {
  background: var(--m-danger);
}

.tile-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
}
.tile-status {
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.tile-status--ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.tile-status--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.tile-status--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

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

/* Document summary */
.tile-doc-summary {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  font-weight: 600;
  margin-top: 2px;
}
.tile-doc-expired {
  color: var(--m-danger);
}
.tile-doc-expiring {
  color: var(--m-warning);
}
.tile-doc-ok {
  color: var(--m-success);
}

.tile--add {
  align-items: center;
  justify-content: center;
  gap: 10px;
  border-style: dashed;
  background: transparent;
  box-shadow: none;
}
.tile--add:hover {
  background: var(--m-surface);
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}
.tile-add-icon {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.tile-add-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 700;
  line-height: 1.3;
}

@media (prefers-reduced-motion: reduce) {
  .ring-fill, .tile, .tile-bar-fill {
    transition: none !important;
  }
}
</style>