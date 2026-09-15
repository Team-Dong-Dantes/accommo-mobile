<template>
  <q-page class="dash">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <div class="greet">
          <q-skeleton type="text" width="60px" height="17px" />
          <q-skeleton type="text" width="100px" height="20px" />
        </div>
        <q-skeleton type="rect" height="96px" class="sk" />
        <q-skeleton type="rect" height="46px" class="sk" />
        <q-skeleton type="rect" height="150px" class="sk" />
        <section class="sec">
          <q-skeleton type="text" width="120px" height="16px" />
          <q-skeleton type="rect" height="42px" class="sk-sm" />
          <q-skeleton type="rect" height="42px" class="sk-sm" />
        </section>
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your dashboard" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <!-- Greeting -->
        <div class="greet">
          <span class="greet-time">{{ greeting }},</span>
          <span class="greet-name">{{ firstName }}</span>
        </div>

        <!-- Occupancy -->
        <q-card flat class="occ" :class="{ 'occ--empty': !hasProperties }">
          <div class="occ-left">
            <span class="occ-cap">Occupancy</span>
            <span class="occ-pct">
              {{ hasProperties ? occupancyRate : 0 }}<span class="occ-sign">%</span>
            </span>
            <span class="occ-sub">
              {{ hasProperties ? `${tenants} of ${totalBeds} beds filled` : 'No beds listed yet' }}
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

        <!-- The rest of the numbers, rating included -->
        <div class="chips">
          <div class="chip">
            <span class="chip-value">{{ formatPeso(expectedMonthly) }}</span>
            <span class="chip-label">Expected/mo</span>
          </div>
          <div class="chip-div" />
          <div class="chip">
            <span class="chip-value">{{ vacantBeds }}</span>
            <span class="chip-label">{{ vacantBeds === 1 ? 'Bed free' : 'Beds free' }}</span>
          </div>
          <template v-if="reviewCount > 0">
            <div class="chip-div" />
            <div class="chip">
              <span class="chip-value chip-value--rating">
                <IconifyIcon icon="lucide:star" width="14" />
                {{ ratingAvg?.toFixed(1) }}
              </span>
              <span class="chip-label">
                {{ reviewCount }} {{ reviewCount === 1 ? 'review' : 'reviews' }}
              </span>
            </div>
          </template>
        </div>

        <!-- Needs attention: the most urgent item stays put, the rest list below it -->
        <DashPriority
          :task="priority"
          empty-label="Nothing needs you"
          empty-hint="Concerns, applications and accreditation land here"
          @go="go"
        />
        <DashTodoList title="Needs attention" :tasks="todo" :done-count="0" @go="go" />

        <!-- Properties -->
        <section class="sec">
          <div class="sec-head">
            <h2 class="sec-title">Your properties</h2>
            <button v-if="hasProperties" type="button" class="sec-link" @click="go('/manager/properties')">
              Manage
            </button>
          </div>

          <div class="plist">
            <PropertyCard v-for="p in topProperties" :key="p.id" :property="p" @open="openProperty" />

            <button
              v-if="properties.length > topProperties.length"
              type="button"
              class="more"
              @click="go('/manager/properties')"
            >
              View all ({{ properties.length }})
              <IconifyIcon icon="lucide:arrow-right" width="15" />
            </button>

            <PropertyCard
              v-if="!hasProperties"
              add-label="Add your first accommodation"
              @add="go('/manager/properties/new')"
            />
          </div>
        </section>
      </div>
    </q-pull-to-refresh>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { formatPeso } from '@/utils/format'
import { ago } from '@/utils/profile'
import { resolveAsset, CARD } from '@/utils/cloudinaryUrl'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import DashPriority from '@/components/shared/DashPriority.vue'
import DashTodoList from '@/components/shared/DashTodoList.vue'
import PropertyCard from '@/components/manager/PropertyCard.vue'
import { healthTone, type Property } from '@/components/manager/property'
import type { Task } from '@/components/shared/dashboard'

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const properties = ref<Property[]>([])
const attention = ref<Task[]>([])
const totalBeds = ref(0)
const tenants = ref(0)
const expectedMonthly = ref(0)
const ratingAvg = ref<number | null>(null)
const reviewCount = ref(0)

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const hasProperties = computed(() => properties.value.length > 0)
const occupancyRate = computed(() =>
  totalBeds.value === 0 ? 0 : Math.min(100, Math.round((tenants.value / totalBeds.value) * 100)),
)
const vacantBeds = computed(() => Math.max(0, totalBeds.value - tenants.value))

// The top item is pinned; the next five list beneath it. Beyond that the
// dashboard stops being a summary — one expired permit per property adds up
// fast, and every one of those rows routes to /manager/osas anyway.
const priority = computed(() => attention.value[0] ?? null)
const todo = computed(() => attention.value.slice(1, 6))

// Two cards only, worst health first, since the full set lives on
// /manager/properties.
const HEALTH_RANK = { danger: 0, warn: 1, good: 2 } as const
const topProperties = computed(() =>
  [...properties.value]
    .sort((a, b) => HEALTH_RANK[healthTone(a)] - HEALTH_RANK[healthTone(b)])
    .slice(0, 2),
)

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function go(path: string) {
  void router.push(path)
}

function openProperty(id: string) {
  go(`/manager/properties/${id}`)
}

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: auth } = await authUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    // Everything keyed only off the manager's own id goes out at once. These
    // ran as nine round trips in series, which was comfortably the slowest
    // thing about the first screen a manager sees.
    const [
      { data: profile },
      { data: accRows, error: accError },
      { data: leaseRows, error: leaseError },
      { data: concernRows },
      { data: peopleRows },
      { data: reviewRows },
    ] = await Promise.all([
      supabase.from('users').select('full_name').eq('id', user.id).maybeSingle(),
      supabase
        .from('accommodations')
        .select('id, name, status, address, barangay, city, accommodation_type, total_rooms')
        .eq('accommodation_manager_id', user.id),
      supabase
        .from('leases')
        .select('id, status, monthly_rent, room_id')
        .eq('accommodation_manager_id', user.id)
        .in('status', ['active', 'pending', 'leave_requested']),
      supabase
        .from('concerns')
        .select(
          'id, category, reported_at, leases!inner(accommodation_manager_id, users!leases_student_id_fkey(full_name), rooms(accommodations(name)))',
        )
        .eq('leases.accommodation_manager_id', user.id)
        .neq('status', 'resolved')
        .order('reported_at', { ascending: false })
        .limit(6),
      supabase
        .from('leases')
        .select(
          'id, status, start_date, leave_requested_at, users!leases_student_id_fkey(full_name), rooms(room_number, accommodations(name))',
        )
        .eq('accommodation_manager_id', user.id)
        .in('status', ['pending', 'leave_requested'])
        .limit(6),
      // Own rating, via the anonymous inbox view — the base table is no longer
      // readable, and the reviewer's identity is not this screen's business.
      supabase.from('review_inbox').select('rating').eq('kind', 'manager'),
    ])
    if (accError) throw accError
    if (leaseError) throw leaseError

    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'

    const accs = accRows || []
    const accIds = accs.map((a) => a.id)
    const accName = new Map(accs.map((a) => [a.id, a.name]))

    // Second wave: rooms, photos and permits all key off the accommodation ids
    // above, so they couldn't join the first — but they can go out together.
    // Skipped entirely for a manager with no accommodations, which is half of
    // them (see the data notes in CLAUDE.md).
    let roomRows: { id: string; accommodation_id: string; capacity: number | null }[] = []
    let imageRows: { accommodation_id: string; url: string; sort_order: number | null }[] = []
    let docRows: {
      id: string
      doc_type: string
      expires_at: string | null
      accommodation_id: string
    }[] = []
    if (accIds.length) {
      const [rooms, images, docs] = await Promise.all([
        supabase.from('rooms').select('id, accommodation_id, capacity').in('accommodation_id', accIds),
        supabase
          .from('accommodation_images')
          .select('accommodation_id, url, sort_order')
          .in('accommodation_id', accIds)
          .order('sort_order', { ascending: true }),
        supabase
          .from('accommodation_documents')
          .select('id, doc_type, expires_at, accommodation_id')
          .in('accommodation_id', accIds),
      ])
      if (rooms.error) throw rooms.error
      roomRows = rooms.data || []
      imageRows = images.data || []
      docRows = docs.data || []
    }

    const leases = leaseRows || []
    const roomToAcc = new Map(roomRows.map((r) => [r.id, r.accommodation_id]))
    const filledByAcc = new Map<string, number>()
    for (const l of leases) {
      if (l.status !== 'active') continue
      const accId = roomToAcc.get(l.room_id)
      if (accId) filledByAcc.set(accId, (filledByAcc.get(accId) || 0) + 1)
    }

    const capacityByAcc = new Map<string, number>()
    const roomCountByAcc = new Map<string, number>()
    for (const r of roomRows) {
      capacityByAcc.set(r.accommodation_id, (capacityByAcc.get(r.accommodation_id) || 0) + Number(r.capacity || 0))
      roomCountByAcc.set(r.accommodation_id, (roomCountByAcc.get(r.accommodation_id) || 0) + 1)
    }

    totalBeds.value = roomRows.reduce((n, r) => n + Number(r.capacity || 0), 0)
    tenants.value = leases.filter((l) => l.status === 'active').length
    expectedMonthly.value = leases
      .filter((l) => l.status === 'active')
      .reduce((n, l) => n + Number(l.monthly_rent || 0), 0)

    // A photo per accommodation, fetched once for the whole portfolio.
    const photoByAcc = new Map<string, string>()
    for (const img of imageRows) {
      if (!photoByAcc.has(img.accommodation_id)) {
        photoByAcc.set(img.accommodation_id, resolveAsset(img.url, CARD))
      }
    }

    // Document tracking
    const expiredByAcc = new Map<string, number>()
    const expiringSoonByAcc = new Map<string, number>()
    const items: Task[] = []

    {
      const now = Date.now()
      const soon = now + 30 * 24 * 60 * 60 * 1000

      for (const d of docRows) {
        if (!d.expires_at) continue
        const t = new Date(d.expires_at).getTime()
        const where = accName.get(d.accommodation_id) || 'Accommodation'
        if (t < now) {
          expiredByAcc.set(d.accommodation_id, (expiredByAcc.get(d.accommodation_id) || 0) + 1)
          items.push({
            id: `doc-${d.id}`,
            icon: 'lucide:file-warning',
            kind: 'OSAS',
            label: `${titleCase(d.doc_type)} expired`,
            hint: `${where} — accreditation is at risk until this is renewed`,
            when: ago(d.expires_at),
            action: 'Upload renewal',
            route: '/manager/osas',
            tone: 'danger',
            rank: 1,
          })
        } else if (t < soon) {
          expiringSoonByAcc.set(d.accommodation_id, (expiringSoonByAcc.get(d.accommodation_id) || 0) + 1)
          items.push({
            id: `doc-soon-${d.id}`,
            icon: 'lucide:calendar-clock',
            kind: 'OSAS',
            label: `${titleCase(d.doc_type)} expires soon`,
            hint: `${where} — renew it before it lapses`,
            when: '',
            action: 'Renew now',
            route: '/manager/osas',
            tone: 'warn',
            rank: 3,
          })
        }
      }
    }

    properties.value = accs.map((a) => ({
      id: a.id,
      name: a.name,
      status: a.status,
      type: titleCase(a.accommodation_type),
      address: a.address || [a.barangay, a.city].filter(Boolean).join(', '),
      roomCount: a.total_rooms ?? roomCountByAcc.get(a.id) ?? null,
      capacity: capacityByAcc.get(a.id) || 0,
      filled: filledByAcc.get(a.id) || 0,
      image: photoByAcc.get(a.id) || '',
      expired: expiredByAcc.get(a.id) || 0,
      expiringSoon: expiringSoonByAcc.get(a.id) || 0,
    }))

    // Rest of attention items (concerns, applications, leave requests). Both
    // sets were fetched in the first wave; the ordering here still decides
    // where they land among the equal-rank items, since the sort below is
    // stable.
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

    // Self rating — hidden until at least one review exists.
    const reviews = reviewRows || []
    reviewCount.value = reviews.length
    ratingAvg.value =
      reviews.length > 0 ? reviews.reduce((sum, r) => sum + Number(r.rating || 0), 0) / reviews.length : null
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

// Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so the
// database pushes lease changes here instead of the page re-asking on every
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return.
const { refresh } = useLiveData({
  key: 'manager-dashboard',
  load,
  watch: (uid) => [{ table: 'leases', filter: `accommodation_manager_id=eq.${uid}` }],
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}
</script>

<style scoped>
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding: 5px var(--m-page-gutter) 16px;
}
.sk { border-radius: var(--m-radius); }
.sk-sm { border-radius: var(--m-radius-sm); }

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

.chips { display: flex; align-items: stretch; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.chip { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; gap: 1px; padding: 8px 11px; }
.chip-div { width: 1px; background: var(--m-border); }
.chip-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.chip-value--rating { display: flex; align-items: center; gap: 4px; color: var(--m-warning); }
.chip-label { color: var(--m-muted); font-size: 11.5px; font-weight: 600; }

.sec { display: flex; flex-direction: column; gap: 5px; }
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 0 2px 4px;
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
  padding: 4px 8px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  transition: background 0.15s;
}
.sec-link:hover { background: var(--m-primary-soft); }

.plist { display: flex; flex-direction: column; gap: 10px; }
.more {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 44px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

@media (prefers-reduced-motion: reduce) {
  .ring-fill, .sec-link { transition: none !important; }
}
</style>
