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
      <span v-if="reviewCount > 0" class="rating-badge">
        <IconifyIcon icon="lucide:star" width="12" />
        {{ ratingAvg?.toFixed(1) }} · {{ reviewCount }} {{ reviewCount === 1 ? 'review' : 'reviews' }}
      </span>

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

      <!-- Stat chips -->
      <div class="chips">
        <button type="button" class="chip chip--link" @click="go('/manager/payments')">
          <span class="chip-value">{{ formatPeso(expectedMonthly) }}</span>
          <span class="chip-label">Expected/mo</span>
        </button>
        <div class="chip-div" />
        <div class="chip">
          <span class="chip-value">{{ vacantBeds }}</span>
          <span class="chip-label">{{ vacantBeds === 1 ? 'Bed free' : 'Beds free' }}</span>
        </div>
      </div>

      <!-- Needs attention -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Needs attention</h2>
        </div>

        <template v-if="attention.length">
          <q-carousel
            v-model="carouselSlide"
            class="lead-carousel"
            animated
            transition-prev="slide-right"
            transition-next="slide-left"
            autoplay
            :interval="3000"
            infinite
            swipeable
          >
            <q-carousel-slide
              v-for="item in attention"
              :key="item.id"
              :name="item.id"
              class="lead-slide"
            >
              <div class="lead" :class="`lead--${item.tone}`">
                <div class="lead-top">
                  <span class="lead-icon"><IconifyIcon :icon="item.icon" width="18" /></span>
                  <span class="lead-kind">{{ item.kind }}</span>
                  <span v-if="item.when" class="lead-when">{{ item.when }}</span>
                </div>
                <div class="lead-row">
                  <div class="lead-body">
                    <p class="lead-label">{{ item.label }}</p>
                    <p class="lead-hint">{{ item.hint }}</p>
                  </div>
                  <button type="button" class="lead-action" @click="go(item.route)">
                    {{ item.action }}
                    <IconifyIcon icon="lucide:arrow-right" width="15" />
                  </button>
                </div>
              </div>
            </q-carousel-slide>
          </q-carousel>

          <div v-if="attention.length > 1" class="dots">
            <button
              v-for="item in attention"
              :key="item.id"
              type="button"
              class="dot"
              :class="{ 'dot--active': item.id === carouselSlide }"
              :aria-label="`Show ${item.kind}`"
              @click="carouselSlide = item.id"
            />
          </div>
        </template>

        <div v-if="!attention.length" class="clear">
          <IconifyIcon icon="lucide:smile" width="24" class="clear-icon" />
          <span class="clear-text">
            <span class="clear-label">Nothing needs you</span>
            <span class="clear-hint">Concerns, applications and compliance land here</span>
          </span>
        </div>
      </section>

      <!-- Property health -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Your properties</h2>
          <button
            v-if="hasAccommodations"
            type="button"
            class="sec-link"
            @click="go('/manager/properties')"
          >
            Manage
          </button>
        </div>

        <div class="plist">
          <button
            v-for="a in accommodations"
            :key="a.id"
            type="button"
            class="pcard"
            @click="go(`/manager/properties/${a.id}`)"
          >
            <span class="pcard-photo" :class="{ 'pcard-photo--empty': !a.photoUrl }">
              <img v-if="a.photoUrl" :src="a.photoUrl" alt="" />
              <span v-else class="pcard-photo-empty">
                <IconifyIcon icon="lucide:image-off" width="24" />
                <span class="pcard-photo-empty-label">No photo</span>
              </span>
              <span class="pcard-status" :class="`pcard-status--${toneOf(a.status)}`">
                <IconifyIcon :icon="statusIcon(a.status)" width="10" />
                {{ statusLabel(a.status) }}
              </span>
              <span class="pcard-health-dot" :class="`pcard-health-dot--${healthTone(a)}`" />
            </span>

            <span class="pcard-body">
              <span class="pcard-head">
                <span class="pcard-name">{{ a.name }}</span>
                <span v-if="a.type" class="pcard-type">{{ a.type }}</span>
              </span>
              <span v-if="a.address" class="pcard-address">
                <IconifyIcon icon="lucide:map-pin" width="12" />
                {{ a.address }}
              </span>

              <span class="facts">
                <span class="fact">
                  <span class="fact-value">{{ a.roomCount ?? '—' }}</span>
                  <span class="fact-label">{{ a.roomCount === 1 ? 'Room' : 'Rooms' }}</span>
                </span>
                <span class="fact-div" />
                <span class="fact">
                  <span class="fact-value">{{ a.filled }}/{{ a.capacity }}</span>
                  <span class="fact-label">Beds filled</span>
                </span>
              </span>

              <span class="pcard-doc-summary">
                <span v-if="a.expired > 0" class="doc-expired">
                  <IconifyIcon icon="lucide:file-warning" width="14" />
                  {{ a.expired }} expired {{ a.expired === 1 ? 'permit' : 'permits' }}
                </span>
                <span v-else-if="a.expiringSoon > 0" class="doc-expiring">
                  <IconifyIcon icon="lucide:clock" width="14" />
                  {{ a.expiringSoon }} expiring soon
                </span>
                <span v-else class="doc-ok">
                  <IconifyIcon icon="lucide:check-circle" width="14" />
                  All permits up to date
                </span>
              </span>
            </span>
          </button>

          <!-- Add card -->
          <button type="button" class="pcard pcard--add" @click="go('/manager/properties/new')">
            <span class="pcard-add-icon"><IconifyIcon icon="lucide:plus" width="22" /></span>
            <span class="pcard-add-label">
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
import { resolveAsset } from '@/utils/cloudinaryUrl'

interface AccommodationCard {
  id: string
  name: string
  status: string
  type: string
  address: string
  roomCount: number | null
  capacity: number
  filled: number
  photoUrl: string
  expired: number // count of expired documents
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

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const accommodations = ref<AccommodationCard[]>([])
const attention = ref<AttentionItem[]>([])
const carouselSlide = ref('')
const totalBeds = ref(0)
const tenants = ref(0)
const expectedMonthly = ref(0)
const ratingAvg = ref<number | null>(null)
const reviewCount = ref(0)

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const hasAccommodations = computed(() => accommodations.value.length > 0)
const occupancyRate = computed(() =>
  totalBeds.value === 0 ? 0 : Math.min(100, Math.round((tenants.value / totalBeds.value) * 100)),
)
const vacantBeds = computed(() => Math.max(0, totalBeds.value - tenants.value))

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
const STATUS_ICON: Record<string, string> = {
  accredited: 'lucide:badge-check',
  pending: 'lucide:hourglass',
  reviewing: 'lucide:search',
  rejected: 'lucide:x-circle',
  delisted: 'lucide:archive',
}
function statusIcon(s: string) {
  return STATUS_ICON[s] ?? 'lucide:circle'
}
function toneOf(s: string) {
  if (s === 'accredited') return 'ok'
  if (s === 'rejected') return 'danger'
  if (s === 'delisted') return 'grey'
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
      .select('id, name, status, address, barangay, city, accommodation_type, total_rooms')
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
    if (accIds.length) {
      const { data: imageRows } = await supabase
        .from('accommodation_images')
        .select('accommodation_id, url, sort_order')
        .in('accommodation_id', accIds)
        .order('sort_order', { ascending: true })
      for (const img of imageRows || []) {
        if (!photoByAcc.has(img.accommodation_id)) {
          photoByAcc.set(img.accommodation_id, resolveAsset(img.url))
        }
      }
    }

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

    // Build accommodation cards
    accommodations.value = accs.map((a) => ({
      id: a.id,
      name: a.name,
      status: a.status,
      type: titleCase(a.accommodation_type),
      address: a.address || [a.barangay, a.city].filter(Boolean).join(', '),
      roomCount: a.total_rooms ?? roomCountByAcc.get(a.id) ?? null,
      capacity: capacityByAcc.get(a.id) || 0,
      filled: filledByAcc.get(a.id) || 0,
      photoUrl: photoByAcc.get(a.id) || '',
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
    carouselSlide.value = attention.value[0]?.id ?? ''

    // Self rating — hidden until at least one review exists.
    const { data: reviewRows } = await supabase
      .from('accommodation_manager_reviews')
      .select('rating')
      .eq('accommodation_manager_id', user.id)
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

onMounted(load)
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
.rating-badge {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 4px;
  margin: 2px 2px 0;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 11.5px;
  font-weight: 700;
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

/* Stat chips */
.chips { display: flex; align-items: stretch; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.chip { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; gap: 1px; padding: 8px 11px; }
.chip-div { width: 1px; background: var(--m-border); }
.chip--link { border: 0; background: transparent; cursor: pointer; font: inherit; text-align: left; -webkit-tap-highlight-color: transparent; }
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
.chip-label { color: var(--m-muted); font-size: 11.5px; font-weight: 600; }

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

/* ===== NEEDS ATTENTION ===== */
.sec { display: flex; flex-direction: column; gap: 5px; }
.lead {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 11px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.lead--danger { border-color: color-mix(in srgb, var(--m-danger) 22%, var(--m-border)); }
.lead--warn { border-color: color-mix(in srgb, var(--m-warning) 26%, var(--m-border)); }
.lead-top { display: flex; align-items: center; gap: 7px; }
.lead-icon { display: grid; width: 25px; height: 25px; flex: 0 0 25px; place-items: center; border-radius: 999px; }
.lead--danger .lead-icon { background: var(--m-danger-soft); color: var(--m-danger); }
.lead--warn .lead-icon { background: var(--m-warning-soft); color: var(--m-warning); }
.lead-kind { flex: 1 1 auto; font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; }
.lead--danger .lead-kind { color: var(--m-danger); }
.lead--warn .lead-kind { color: var(--m-warning); }
.lead-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.lead-label {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15.5px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  text-wrap: pretty;
}
.lead-row { display: flex; align-items: center; gap: 10px; margin-top: 6px; }
.lead-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.lead-hint { margin: 0; color: var(--m-muted); font-size: 11.5px; line-height: 1.3; text-wrap: pretty; }
.lead-action {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.lead-action:active { transform: scale(0.97); }

.lead-carousel {
  height: 128px;
  background: transparent;
}
.lead-carousel :deep(.q-carousel__slide) {
  padding: 0;
}
.lead-slide {
  display: flex;
  align-items: stretch;
  height: 100%;
  padding: 0;
}
.lead-slide .lead { width: 100%; }

.dots { display: flex; align-items: center; justify-content: center; gap: 5px; margin-top: 8px; }
.dot {
  width: 5px;
  height: 5px;
  padding: 0;
  border: 0;
  border-radius: 999px;
  background: var(--m-border);
  cursor: pointer;
  transition: width 0.15s ease, background 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.dot--active { width: 14px; background: var(--m-primary); }

.clear {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.clear-icon { color: var(--m-muted); opacity: 0.6; }
.clear-text { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.clear-label { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.clear-hint { color: var(--m-muted); font-size: 12px; }

/* ===== PROPERTY CARDS ===== */
.plist {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.pcard {
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 0 0 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  overflow: hidden;
  transition: transform 0.12s ease, box-shadow 0.15s, border-color 0.15s;
  box-shadow: 0 1px 3px rgba(0,0,0,0.02);
  position: relative;
}
.pcard:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.06);
}
.pcard:active {
  transform: scale(0.985);
}

.pcard-photo {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 16 / 9;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pcard-photo img { width: 100%; height: 100%; object-fit: cover; }
.pcard-photo--empty { background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%); }
.pcard-photo-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
}
.pcard-photo-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }
.pcard-status {
  position: absolute;
  top: 8px;
  left: 8px;
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 3px 9px 3px 7px;
  border-radius: 999px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.01em;
}
.pcard-status--ok {
  background: var(--m-success);
  color: #fff;
}
.pcard-status--warn {
  background: var(--m-warning);
  color: #fff;
}
.pcard-status--danger {
  background: var(--m-danger);
  color: #fff;
}
.pcard-status--grey {
  background: rgba(23, 32, 42, 0.78);
  color: #fff;
}
.pcard-health-dot {
  position: absolute;
  top: 10px;
  right: 10px;
  width: 10px;
  height: 10px;
  border-radius: 999px;
  border: 2px solid rgba(255, 255, 255, 0.9);
  box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.15);
}
.pcard-health-dot--good {
  background: var(--m-success);
}
.pcard-health-dot--warn {
  background: var(--m-warning);
}
.pcard-health-dot--danger {
  background: var(--m-danger);
}

.pcard-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 4px;
  padding: 10px 12px 0;
}
.pcard-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; }
.pcard-name {
  min-width: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.01em;
  line-height: 1.25;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pcard-type {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10px;
  font-weight: 700;
}
.pcard-address {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 12px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.facts {
  display: flex;
  align-items: stretch;
  margin-top: 4px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.fact { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; align-items: center; gap: 0; padding: 6px 4px; text-align: center; }
.fact-div { width: 1px; background: var(--m-border); }
.fact-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 13px;
  font-weight: 700;
  letter-spacing: -0.01em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}
.fact-label { color: var(--m-muted); font-size: 10px; font-weight: 600; }

/* Document summary */
.pcard-doc-summary {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 6px;
  font-size: 12px;
  font-weight: 600;
}
.doc-expired {
  color: var(--m-danger);
}
.doc-expiring {
  color: var(--m-warning);
}
.doc-ok {
  color: var(--m-success);
}

.pcard--add {
  align-items: center;
  justify-content: center;
  gap: 10px;
  flex-direction: row;
  padding: 20px 12px;
  border-style: dashed;
  background: transparent;
  box-shadow: none;
}
.pcard--add:hover {
  background: var(--m-surface);
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}
.pcard-add-icon {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pcard-add-label {
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.3;
}

@media (prefers-reduced-motion: reduce) {
  .ring-fill, .pcard, .lead-action {
    transition: none !important;
  }
}
</style>
