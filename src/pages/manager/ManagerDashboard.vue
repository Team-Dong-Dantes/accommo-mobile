<template>
  <q-page class="dash">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <div class="greet">
          <q-skeleton type="text" width="160px" height="24px" />
        </div>
        <q-skeleton type="rect" height="150px" class="sk" />
        <q-skeleton type="rect" height="190px" class="sk" />
        <q-skeleton type="rect" height="150px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your dashboard" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <div class="greet">
          <span class="greet-line">
            <span class="greet-time">{{ greeting }},</span>
            <span class="greet-name">{{ firstName }}</span>
          </span>
          <span class="greet-date">{{ today }}</span>
        </div>

        <!-- Only while OSAS has not verified the account yet. -->
        <VerificationBanner />

        <!-- Occupancy, rent and rating in one card. Beds are said once, in the bar's caption. -->
        <div class="occ" :class="{ 'occ--empty': !hasProperties }">
          <div class="occ-head">
            <span class="occ-cap">Occupancy</span>
            <span class="occ-beds">
              {{ hasProperties ? `${tenants} filled · ${vacantBeds} free` : 'No beds listed yet' }}
            </span>
          </div>
          <span class="occ-pct">{{ occupancyRate }}<span class="occ-sign">%</span></span>
          <span
            class="occ-bar"
            role="progressbar"
            :aria-valuenow="occupancyRate"
            aria-valuemin="0"
            aria-valuemax="100"
            aria-label="Beds filled"
          >
            <span class="occ-fill" :style="{ width: `${occupancyRate}%` }" />
          </span>

          <div v-if="hasProperties" class="occ-stats">
            <span class="occ-stat">
              <span class="occ-stat-value">{{ formatPeso(expectedMonthly) }}</span>
              <span class="occ-stat-label">Expected / month</span>
            </span>
            <span class="occ-stat">
              <span class="occ-stat-value">
                <IconifyIcon icon="lucide:star" width="15" />
                {{ reviewCount > 0 ? ratingAvg?.toFixed(1) : '—' }}
              </span>
              <span class="occ-stat-label">
                {{ reviewCount > 0 ? `${reviewCount} ${reviewCount === 1 ? 'rating' : 'ratings'}` : 'No ratings yet' }}
              </span>
            </span>
          </div>
        </div>

        <DashTasks
          :tasks="upNext"
          :total="attention.length"
          empty-label="Nothing needs you"
          empty-hint="Concerns, applications and accreditation land here"
          @go="go"
        />

        <!-- Properties -->
        <section class="sec">
          <div class="sec-head">
            <h2 class="sec-title">Your properties</h2>
            <button v-if="hasProperties" type="button" class="sec-link" @click="go('/manager/properties')">
              Manage
            </button>
          </div>

          <div v-if="hasProperties" class="plist">
            <PropertyRow v-for="p in topProperties" :key="p.id" :property="p" @open="openProperty" />
            <button
              v-if="properties.length > topProperties.length"
              type="button"
              class="more"
              @click="go('/manager/properties')"
            >
              View all ({{ properties.length }})
              <IconifyIcon icon="lucide:arrow-right" width="16" />
            </button>
          </div>

          <PropertyCard
            v-else-if="auth.isVerifiedLandlord"
            add-label="Add your first accommodation"
            @add="go('/manager/properties/new')"
          />
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
import DashTasks from '@/components/shared/DashTasks.vue'
import VerificationBanner from '@/components/manager/VerificationBanner.vue'
import { useAuthStore } from '@/stores/auth'
import PropertyCard from '@/components/manager/PropertyCard.vue'
import PropertyRow from '@/components/manager/PropertyRow.vue'
import { healthTone, type Property } from '@/components/manager/property'
import type { Task } from '@/components/shared/dashboard'

const router = useRouter()
const auth = useAuthStore()

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

const today = new Date().toLocaleDateString('en-PH', { weekday: 'short', month: 'short', day: 'numeric' })

// The top item leads; the next five list beneath it. Beyond that the
// dashboard stops being a summary — one expired permit per property adds up
// fast, and every one of those rows routes to /manager/osas anyway.
const upNext = computed(() => attention.value.slice(0, 6))

// Four rows at most, worst health first, since the full set lives on
// /manager/properties.
const HEALTH_RANK = { danger: 0, warn: 1, good: 2 } as const
const topProperties = computed(() =>
  [...properties.value]
    .sort((a, b) => HEALTH_RANK[healthTone(a)] - HEALTH_RANK[healthTone(b)])
    .slice(0, 4),
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

    // Everything keyed only off the landlord/landlady's own id goes out at once. These
    // ran as nine round trips in series, which was comfortably the slowest
    // thing about the first screen a landlord/landlady sees.
    const [
      { data: profile },
      { data: accRows, error: accError },
      { data: leaseRows, error: leaseError },
      { data: concernRows },
      { data: peopleRows },
      { data: reviewRows },
      { count: paymentsToVerify },
    ] = await Promise.all([
      supabase.from('users').select('full_name').eq('id', user.id).maybeSingle(),
      supabase
        .from('accommodations')
        .select('id, name, status, address, barangay, purok, city, accommodation_type, total_rooms')
        .eq('landlord_id', user.id),
      supabase
        .from('leases')
        .select('id, status, monthly_rent, room_id')
        .eq('landlord_id', user.id)
        .in('status', ['active', 'pending', 'leave_requested']),
      supabase
        .from('concerns')
        .select(
          'id, category, reported_at, leases!inner(landlord_id, users!leases_student_id_fkey(full_name), rooms(accommodations(name)))',
        )
        .eq('leases.landlord_id', user.id)
        .neq('status', 'resolved')
        .order('reported_at', { ascending: false })
        .limit(6),
      supabase
        .from('leases')
        .select(
          'id, status, start_date, leave_requested_at, users!leases_student_id_fkey(full_name), rooms(room_number, accommodations(name))',
        )
        .eq('landlord_id', user.id)
        .in('status', ['pending', 'leave_requested'])
        .limit(6),
      // Own rating, via the anonymous inbox view — the base table is no longer
      // readable, and the reviewer's identity is not this screen's business.
      supabase.from('review_inbox').select('rating').eq('kind', 'manager'),
      // Only the number: the list itself lives on Tenants → Payments.
      supabase
        .from('payments')
        .select('id, leases!inner(landlord_id)', { count: 'exact', head: true })
        .eq('leases.landlord_id', user.id)
        .eq('status', 'pending_verification'),
    ])
    if (accError) throw accError
    if (leaseError) throw leaseError

    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'

    const accs = accRows || []
    const accIds = accs.map((a) => a.id)
    const accName = new Map(accs.map((a) => [a.id, a.name]))

    // Second wave: rooms, photos and permits all key off the accommodation ids
    // above, so they couldn't join the first — but they can go out together.
    // Skipped entirely for a landlord/landlady with no accommodations, which is half of
    // them (see the data notes in CLAUDE.md).
    let roomRows: {
      id: string
      accommodation_id: string
      capacity: number | null
      water_billing: string | null
      electric_billing: string | null
      wifi_billing: string | null
    }[] = []
    let imageRows: { accommodation_id: string; url: string; sort_order: number | null }[] = []
    let docRows: {
      id: string
      doc_type: string
      expires_at: string | null
      accommodation_id: string
    }[] = []
    if (accIds.length) {
      const [rooms, images, docs] = await Promise.all([
        supabase
          .from('rooms')
          .select('id, accommodation_id, capacity, water_billing, electric_billing, wifi_billing')
          .in('accommodation_id', accIds),
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

    // Rooms that don't yet say how utilities are paid — every room from before
    // utilities were per room. Students see nothing for them, and a draft
    // can't be submitted until they're set, so it's a task, not a footnote.
    const unsetByAcc = new Map<string, number>()
    for (const r of roomRows) {
      if (r.water_billing && r.electric_billing && r.wifi_billing) continue
      unsetByAcc.set(r.accommodation_id, (unsetByAcc.get(r.accommodation_id) || 0) + 1)
    }
    for (const [accId, count] of unsetByAcc) {
      items.push({
        id: `utilities-${accId}`,
        icon: 'lucide:plug-zap',
        kind: 'Utilities',
        label: `Set utilities on ${count} room${count === 1 ? '' : 's'}`,
        hint: `${accName.get(accId) || 'Accommodation'} — students can't see how water, power and Wi-Fi are paid`,
        when: '',
        action: 'Set utilities',
        route: `/manager/properties/${accId}`,
        tone: 'warn',
        rank: 3,
      })
    }

    properties.value = accs.map((a) => ({
      id: a.id,
      name: a.name,
      status: a.status,
      type: titleCase(a.accommodation_type),
      address: a.address || [a.purok, a.barangay, a.city].filter(Boolean).join(', '),
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
      const who = lease?.users?.full_name || 'A boarder'
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

    // One grouped row, like "Set utilities": a busy month would otherwise bury
    // concerns and applications under a row per payment.
    if (paymentsToVerify) {
      items.push({
        id: 'payments-to-verify',
        icon: 'lucide:receipt',
        kind: 'Payments',
        label: `Verify ${paymentsToVerify} payment${paymentsToVerify === 1 ? '' : 's'}`,
        hint: 'Students are waiting for these to be marked paid',
        when: '',
        action: 'Verify',
        route: '/manager/tenants?tab=payments',
        tone: 'warn',
        rank: 2,
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

    // OSAS has hidden their listings (account_standing, written only by OSAS):
    // the first thing they should read, with the reason OSAS gave.
    const { data: standing } = await supabase
      .from('account_standing')
      .select('reason, restrictions')
      .eq('user_id', user.id)
      .maybeSingle()
    if (standing?.restrictions?.includes('listings')) {
      items.push({
        id: 'osas-listings',
        icon: 'lucide:eye-off',
        kind: 'OSAS',
        label: 'OSAS has hidden your listings',
        hint: standing.reason || 'Students cannot see your accommodations for now',
        when: '',
        action: 'Contact OSAS',
        route: '/manager/support',
        tone: 'danger',
        rank: 0,
      })
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
type DashboardCache = {
  firstName: string
  properties: Property[]
  attention: Task[]
  totalBeds: number
  tenants: number
  expectedMonthly: number
  ratingAvg: number | null
  reviewCount: number
}

const { refresh } = useLiveData({
  key: 'manager-dashboard',
  load,
  // leases/payments are not in the realtime publication; every payment and
  // lease event notifies this user, so their notifications are the signal.
  watch: (uid) => [
    { table: 'leases', filter: `landlord_id=eq.${uid}` },
    { table: 'notifications', filter: `user_id=eq.${uid}` },
  ],
  cache: {
    get: (): DashboardCache => ({
      firstName: firstName.value,
      properties: properties.value,
      attention: attention.value,
      totalBeds: totalBeds.value,
      tenants: tenants.value,
      expectedMonthly: expectedMonthly.value,
      ratingAvg: ratingAvg.value,
      reviewCount: reviewCount.value,
    }),
    set: (d) => {
      const c = d as DashboardCache
      firstName.value = c.firstName
      properties.value = c.properties
      attention.value = c.attention
      totalBeds.value = c.totalBeds
      tenants.value = c.tenants
      expectedMonthly.value = c.expectedMonthly
      ratingAvg.value = c.ratingAvg
      reviewCount.value = c.reviewCount
      loading.value = false
    },
  },
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}
</script>

<style scoped>
/* One type scale: 11 / 12 / 13 / 15 / 17 / 20 / 40. */
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 8px var(--m-page-gutter) 20px;
}
.sk { border-radius: var(--m-radius); }

.greet { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; padding: 4px 2px 0; }
.greet-line { display: flex; min-width: 0; flex-wrap: wrap; align-items: baseline; gap: 6px; }
.greet-time { color: var(--m-muted); font-size: 15px; font-weight: 500; }
.greet-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.greet-date { flex: 0 0 auto; color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Occupancy: figure, bar, then the money and rating under a hairline */
.occ {
  display: flex;
  flex-direction: column;
  padding: 14px 14px 0;
  border-radius: var(--m-radius);
  background: var(--m-primary);
  color: #fff;
}
.occ--empty { padding-bottom: 14px; border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.occ-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; }
.occ-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; opacity: 0.85; }
.occ-beds { font-size: 13px; font-weight: 600; opacity: 0.9; }
.occ--empty .occ-cap, .occ--empty .occ-beds { color: var(--m-muted); opacity: 1; }
.occ-pct {
  margin-top: 4px;
  font-family: var(--m-font-display);
  font-size: 40px;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
}
.occ-sign { font-size: 20px; font-weight: 600; opacity: 0.8; }
.occ-bar { display: block; height: 8px; margin-top: 12px; overflow: hidden; border-radius: 999px; background: rgba(255, 255, 255, 0.25); }
.occ--empty .occ-bar { background: var(--m-bg); }
.occ-fill { display: block; height: 100%; border-radius: inherit; background: #fff; transition: width 0.5s ease; }

.occ-stats { display: flex; margin-top: 14px; border-top: 1px solid rgba(255, 255, 255, 0.22); }
.occ-stat { display: flex; min-width: 0; flex: 1 1 0; flex-direction: column; gap: 2px; padding: 12px 0; }
.occ-stat + .occ-stat { padding-left: 14px; border-left: 1px solid rgba(255, 255, 255, 0.22); }
.occ-stat-value {
  display: flex;
  align-items: center;
  gap: 4px;
  overflow: hidden;
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.occ-stat-label { font-size: 12px; font-weight: 600; opacity: 0.85; }

.sec { display: flex; flex-direction: column; gap: 6px; }
.sec-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 0 2px; }
.sec-title {
  margin: 0;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.03em;
  line-height: 1.4;
  text-transform: uppercase;
}
.sec-link {
  min-height: 32px;
  padding: 0 8px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  transition: background 0.15s;
}
.sec-link:hover { background: var(--m-primary-soft); }

.plist { overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.more {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 48px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

@media (prefers-reduced-motion: reduce) {
  .occ-fill, .sec-link { transition: none !important; }
}
</style>
