<template>
  <q-page class="rp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="220px" square />
      <div class="sk-body">
        <q-skeleton type="text" width="55%" height="20px" />
        <q-skeleton type="text" width="40%" height="13px" />
        <q-skeleton type="text" width="90px" height="20px" class="sk-pill" />
        <div class="sk-stats">
          <q-skeleton type="text" width="60px" height="30px" />
          <q-skeleton type="text" width="60px" height="30px" />
          <q-skeleton type="text" width="60px" height="30px" />
        </div>
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this room</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn
          unelevated
          rounded
          no-caps
          dense
          color="primary"
          label="Try again"
          class="q-mt-sm q-px-md"
          @click="load"
        />
      </q-card>
    </div>

    <div v-else class="page">
      <div v-if="images.length" class="hero">
        <span class="hero-fallback"><span class="hero-mono">{{ monogram }}</span></span>
        <img v-for="(src, i) in images" :key="i" :src="src" :alt="room.label" class="hero-img" />
        <span v-if="images.length > 1" class="hero-count">
          <IconifyIcon icon="lucide:image" width="11" />{{ images.length }}
        </span>
      </div>
      <div v-else class="hero hero--none">
        <IconifyIcon icon="lucide:image-off" width="26" />
        <span class="hero-none-label">No photos yet</span>
      </div>

      <div class="body">
        <h1 class="name">{{ room.label }}</h1>
        <button type="button" class="where" @click="router.push(`/student/listing/${room.propertyId}`)">
          <IconifyIcon icon="lucide:building-2" width="12" />
          {{ room.propertyName }}
        </button>
        <div class="badge-row">
          <span class="badge">
            <IconifyIcon icon="lucide:shield-check" width="11" />OSAS Accredited
          </span>
          <span v-if="typeLabel" class="type-pill">{{ typeLabel }}</span>
        </div>

        <div class="price-row">
          <p v-if="room.rent" class="price">{{ formatPeso(room.rent) }}<span class="price-per">/mo{{ perPersonSuffix }}</span></p>
          <p v-else class="price price--none">Rent on request</p>
          <span class="vacancy" :class="room.free ? 'vacancy--ok' : 'vacancy--none'">
            {{ room.free ? 'Available' : 'Taken' }}
          </span>
        </div>

        <div class="stat-row">
          <span v-if="room.capacity" class="stat">
            <IconifyIcon icon="lucide:bed" width="15" />
            <strong>{{ room.capacity }} bed{{ room.capacity === 1 ? '' : 's' }}</strong>
          </span>
          <span v-if="room.floor" class="stat">
            <IconifyIcon icon="lucide:layers" width="15" />
            <strong>Floor {{ room.floor }}</strong>
          </span>
          <span v-if="distance" class="stat">
            <IconifyIcon icon="lucide:map-pin" width="15" />
            <!-- campusDistanceLabel already ends in "from campus" -->
            <small>{{ distance }}</small>
          </span>
        </div>

        <!-- What it costs to move in, and how long you're committing to -->
        <section v-if="moveIn || policy.minStay || policy.contractType" class="block">
          <h2 class="block-title">Move-in cost</h2>
          <div class="rule-list">
            <div v-if="moveIn?.advance" class="rule-row">
              <span class="rule-label">Advance ({{ moveIn.advanceMonths }} mo)</span>
              <span class="rule-value">{{ formatPeso(moveIn.advance) }}</span>
            </div>
            <div v-if="moveIn?.deposit" class="rule-row">
              <span class="rule-label">Deposit ({{ moveIn.depositMonths }} mo)</span>
              <span class="rule-value">{{ formatPeso(moveIn.deposit) }}</span>
            </div>
            <div v-if="policy.minStay" class="rule-row">
              <span class="rule-label">Minimum stay</span>
              <span class="rule-value">{{ policy.minStay }} month{{ policy.minStay === 1 ? '' : 's' }}</span>
            </div>
            <div v-if="policy.contractType" class="rule-row">
              <span class="rule-label">Contract type</span>
              <span class="rule-value">{{ policy.contractType }}</span>
            </div>
          </div>
          <div v-if="moveIn" class="total-strip">
            <span>Total due at signing</span>
            <strong>{{ formatPeso(moveIn.total) }}</strong>
          </div>
        </section>

        <!-- What's in this room specifically, if anything was published -->
        <section v-if="facilities.length" class="block">
          <h2 class="block-title">In this room</h2>
          <div class="icon-grid">
            <span v-for="f in facilities" :key="f.type + f.label" class="icon-item">
              <span class="icon-circle"><IconifyIcon :icon="FACILITY_META[f.type]?.icon || 'lucide:dot'" width="19" /></span>
              <small>{{ f.label || FACILITY_META[f.type]?.label || f.type }}</small>
            </span>
          </div>
        </section>

        <!-- Amenities are property-level; a room has no set of its own -->
        <section v-if="amenities.length" class="block">
          <h2 class="block-title">What's here</h2>
          <div class="icon-grid">
            <span v-for="a in amenities" :key="a" class="icon-item">
              <span class="icon-circle"><IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="19" /></span>
              <small>{{ AMENITY_META[a]?.label || a }}</small>
            </span>
          </div>
        </section>

        <!-- Property context for anyone who lands on a room without ever
             seeing the listing first (a search result, a shared link) -->
        <section v-if="listingDescription" class="block">
          <h2 class="block-title">About {{ room.propertyName }}</h2>
          <p class="desc">{{ listingDescription }}</p>
          <button type="button" class="see-listing" @click="router.push(`/student/listing/${room.propertyId}`)">
            See full listing
            <IconifyIcon icon="lucide:chevron-right" width="14" />
          </button>
        </section>

        <!-- Other rooms in the same property, without backing out to the listing -->
        <section v-if="visibleSiblingRooms.length" class="block">
          <h2 class="block-title">More rooms at {{ room.propertyName }}</h2>
          <div class="room-rail">
            <button
              v-for="r in visibleSiblingRooms"
              :key="r.id"
              type="button"
              class="room-card"
              @click="router.push(`/student/room/${r.id}`)"
            >
              <span class="room-card-photo">
                <img v-if="r.image" :src="r.image" :alt="r.label" loading="lazy" />
                <span v-else class="room-card-mono">{{ monogram }}</span>
                <span class="room-card-type">{{ r.label }}</span>
              </span>
              <span class="room-card-name-row">
                <span class="room-card-name">{{ r.type }}</span>
                <span v-if="r.capacity" class="room-card-cap">{{ r.capacity }} left</span>
              </span>
              <span v-if="r.rent" class="room-card-rent">
                {{ formatPeso(r.rent) }}<span class="room-card-per">/mo{{ r.rentBasis === 'person' ? '/person' : '' }}</span>
              </span>
              <span v-else class="room-card-rent room-card-rent--none">On request</span>
            </button>
          </div>
        </section>

        <!-- The person to ask -->
        <section v-if="manager.id" class="block">
          <h2 class="block-title">Managed by</h2>
          <button type="button" class="mgr" @click="router.push(`/student/manager/${manager.id}`)">
            <span class="mgr-avatar">
              <img v-if="manager.avatarUrl" :src="manager.avatarUrl" alt="" class="mgr-avatar-img" @error="manager.avatarUrl = null" />
              <template v-else>{{ manager.initials }}</template>
            </span>
            <span class="mgr-body">
              <span class="mgr-name">{{ manager.name }}</span>
              <span class="mgr-sub">
                {{ manager.replyMinutes ? `Replies in ~${manager.replyMinutes} min` : 'Accommodation manager' }}
              </span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="mgr-chevron" />
          </button>
        </section>
      </div>
    </div>

    <div v-if="!loading && !error && manager.id" class="cta">
      <button type="button" class="cta-btn cta-btn--ghost" @click="router.push(`/student/messages?to=${manager.id}`)">
        <IconifyIcon icon="lucide:message-circle" width="17" />
        Message
      </button>
      <button v-if="room.free && !myLease.hasAny" type="button" class="cta-btn" @click="goApply">
        <IconifyIcon icon="lucide:file-check-2" width="17" />
        Apply for this room
      </button>
      <span v-else-if="myLease.onThisRoom" class="cta-note">Applied — awaiting response</span>
      <span v-else-if="myLease.hasAny" class="cta-note">You already have a stay</span>
      <span v-else class="cta-note">This room is taken</span>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, initialsOf } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { AMENITY_META, FACILITY_META, roomTypeLabel, listingMonogram } from '@/utils/listings'

const route = useRoute()
const router = useRouter()

const loading = ref(true)
const error = ref('')
const room = reactive({
  label: '',
  propertyId: '',
  propertyName: '',
  type: null as string | null,
  capacity: null as number | null,
  floor: null as number | null,
  rent: 0,
  rentBasis: 'room' as 'room' | 'person',
  free: false,
  lat: null as number | null,
  lng: null as number | null,
})
const images = ref<string[]>([])
const amenities = ref<string[]>([])
const facilities = ref<{ type: string; label: string | null }[]>([])
const policy = reactive({ advanceMonths: 0, depositMonths: 0, minStay: 0, contractType: '' })
const manager = reactive({ id: '', name: '', initials: '?', avatarUrl: null as string | null, replyMinutes: null as number | null })
const myLease = reactive({ hasAny: false, onThisRoom: false })
const listingDescription = ref('')
interface SiblingRoom {
  id: string
  label: string
  capacity: number
  type: string
  rent: number
  rentBasis: 'room' | 'person'
  free: boolean
  image: string
}
const siblingRooms = ref<SiblingRoom[]>([])
const visibleSiblingRooms = computed(() => siblingRooms.value.filter((r) => r.free))

const id = computed(() => String(route.params.id || ''))
const monogram = computed(() => listingMonogram(room.propertyName))
const typeLabel = computed(() => (room.type ? roomTypeLabel(room.type) : ''))
const distance = computed(() => campusDistanceLabel(room.lat, room.lng))
const perPersonSuffix = computed(() => (room.rentBasis === 'person' && (room.capacity ?? 0) > 1 ? ' per person' : ''))
const moveIn = computed(() => {
  if (!room.rent || (!policy.advanceMonths && !policy.depositMonths)) return null
  const advance = policy.advanceMonths * room.rent
  const deposit = policy.depositMonths * room.rent
  return {
    advanceMonths: policy.advanceMonths,
    depositMonths: policy.depositMonths,
    advance,
    deposit,
    total: advance + deposit,
  }
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('rooms')
      .select(
        'id,label,room_number,room_type,custom_room_type,capacity,floor,monthly_rent,advance_months,deposit_months,rent_basis,status,room_images(url,sort_order),accommodation_facilities(facility_type,label),accommodations(id,name,address,city,barangay,lat,lng,accommodation_manager_id,status,description,accommodation_amenities(amenity),accommodation_images(url,sort_order),accommodation_policies(advance_months,deposit_months,min_stay,contract_type))',
      )
      .eq('id', id.value)
      .maybeSingle()
    if (loadError) throw loadError

    const property = data?.accommodations as
      | {
          id: string
          name: string | null
          accommodation_manager_id: string | null
          status: string
          lat: number | null
          lng: number | null
          description: string | null
          accommodation_amenities: { amenity: string }[] | null
          accommodation_images: { url: string; sort_order: number | null }[] | null
          accommodation_policies: {
            advance_months: number | null
            deposit_months: number | null
            min_stay: number | null
            contract_type: string | null
          } | null
        }
      | null
    if (!data || !property || property.status !== 'accredited') {
      error.value = 'This room is no longer available.'
      return
    }

    room.label = data.label || (data.room_number ? `Room ${data.room_number}` : 'Room')
    room.propertyId = property.id
    room.propertyName = property.name?.trim() || 'Unnamed accommodation'
    room.type = data.custom_room_type || data.room_type
    room.capacity = data.capacity
    room.floor = data.floor
    room.rent = Number(data.monthly_rent ?? 0)
    room.rentBasis = data.rent_basis === 'person' ? 'person' : 'room'
    room.free = data.status === 'available'
    room.lat = property.lat
    room.lng = property.lng

    amenities.value = (property.accommodation_amenities ?? []).map((a) => a.amenity)
    listingDescription.value = property.description || ''

    facilities.value = ((data.accommodation_facilities ?? []) as { facility_type: string; label: string | null }[])
      .map((f) => ({ type: f.facility_type, label: f.label }))

    // So a student can browse other rooms in the same property without
    // backing out to the listing and finding the Rooms section again.
    const { data: siblingRows, error: siblingError } = await supabase
      .from('rooms')
      .select('id,label,room_number,room_type,custom_room_type,capacity,monthly_rent,rent_basis,status,room_images(url,sort_order)')
      .eq('accommodation_id', property.id)
      .neq('id', id.value)
    if (siblingError) throw siblingError
    siblingRooms.value = ((siblingRows ?? []) as {
      id: string
      label: string | null
      room_number: string | null
      room_type: string | null
      custom_room_type: string | null
      capacity: number | null
      monthly_rent: number | null
      rent_basis: string | null
      status: string
      room_images: { url: string; sort_order: number | null }[] | null
    }[])
      .map((r) => {
        const roomImgs = [...(r.room_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        return {
          id: r.id,
          label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
          capacity: Number(r.capacity ?? 0),
          type: roomTypeLabel(r.custom_room_type || r.room_type),
          rent: Number(r.monthly_rent ?? 0),
          rentBasis: (r.rent_basis === 'person' && (r.capacity ?? 0) > 1 ? 'person' : 'room') as 'room' | 'person',
          free: r.status === 'available',
          image: roomImgs[0]?.url ? resolveAsset(roomImgs[0].url) : '',
        }
      })
      .sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

    // A room's own advance/deposit terms override the property's default —
    // fall back to the accommodation-level policy only when this room hasn't
    // set its own (most rooms don't; without this fallback the whole
    // "Move-in cost" section silently disappeared for them).
    const accPolicy = property.accommodation_policies
    policy.advanceMonths = data.advance_months ?? accPolicy?.advance_months ?? 0
    policy.depositMonths = data.deposit_months ?? accPolicy?.deposit_months ?? 0
    // Lease length/contract terms are set at the property level only (no
    // per-room override exists in the schema), so no fallback chain needed.
    policy.minStay = accPolicy?.min_stay ?? 0
    policy.contractType = accPolicy?.contract_type ?? ''

    // Most rooms have no photos of their own yet — fall back to the
    // property's photos rather than showing a bare monogram.
    const roomImages = [...((data.room_images ?? []) as { url: string; sort_order: number | null }[])].sort(
      (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
    )
    const sourceImages = roomImages.length
      ? roomImages
      : [...(property.accommodation_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
    images.value = sourceImages.map((i) => resolveAsset(i.url)).filter(Boolean)

    if (property.accommodation_manager_id) {
      const [{ data: person }, { data: profile }] = await Promise.all([
        supabase
          .from('users')
          .select('full_name,initials,avatar_url')
          .eq('id', property.accommodation_manager_id)
          .maybeSingle(),
        supabase
          .from('accommodation_manager_profiles')
          .select('avg_response_minutes')
          .eq('user_id', property.accommodation_manager_id)
          .maybeSingle(),
      ])
      manager.id = property.accommodation_manager_id
      manager.name = person?.full_name || 'Accommodation manager'
      manager.initials = person?.initials || initialsOf(manager.name)
      manager.avatarUrl = person?.avatar_url ? resolveAsset(person.avatar_url) : null
      manager.replyMinutes = profile?.avg_response_minutes ?? null
    }

    const { data: authData } = await supabase.auth.getUser()
    const uid = authData?.user?.id
    if (uid) {
      const { data: mine } = await supabase
        .from('leases')
        .select('room_id,status')
        .eq('student_id', uid)
        .in('status', ['pending', 'active', 'leave_requested'])
      const list = mine ?? []
      myLease.hasAny = list.length > 0
      myLease.onThisRoom = list.some((l) => l.room_id === id.value)
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

function goApply() {
  void router.push(`/student/messages?to=${manager.id}&room=${id.value}`)
}

onMounted(load)
// Vue Router reuses this component when navigating from one room straight to
// another (same route, different :id — e.g. the "More rooms" rail below),
// so onMounted alone would leave the page showing the previous room.
watch(id, load)
</script>

<style scoped>
.rp {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
.sk-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.sk-pill {
  border-radius: 999px;
}
.sk-stats {
  display: flex;
  gap: 18px;
  margin-top: 6px;
}

.card {
  padding: 18px 14px;
  margin: 8px var(--m-page-gutter) 0;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
}

.page {
  display: flex;
  flex-direction: column;
}

/* Hero — one photo filling the width at a time, no card frame around it */
.hero {
  position: relative;
  display: flex;
  height: 240px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  background: var(--m-primary-soft);
}
.hero-fallback {
  position: absolute;
  inset: 0;
  z-index: 0;
  display: grid;
  place-items: center;
}
.hero-img {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  flex: 0 0 100%;
  object-fit: cover;
  scroll-snap-align: start;
}
.hero--none {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  background: linear-gradient(160deg, var(--m-border), var(--m-bg) 85%);
  color: var(--m-muted);
}
.hero-none-label {
  font-size: 13px;
  font-weight: 700;
}
.hero-mono {
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 42px;
  font-weight: 800;
}
.hero-count {
  position: absolute;
  right: 12px;
  bottom: 12px;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.55);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
}

.body {
  display: flex;
  flex-direction: column;
  padding: 18px var(--m-page-gutter) 100px;
}

.name {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 26px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
}
.where {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 4px;
  margin: 5px 0 0;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.badge-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
  margin-top: 9px;
}
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 11px;
  font-weight: 700;
}
.type-pill {
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 11px;
  font-weight: 700;
}

.price-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid var(--m-border);
}
.price {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 27px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.price--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 14px;
  font-weight: 600;
}
.price-per {
  font-size: 13px;
  font-weight: 600;
  opacity: 0.7;
}
.vacancy {
  flex: 0 0 auto;
  padding: 4px 11px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 700;
}
.vacancy--ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.vacancy--none {
  background: var(--m-bg);
  color: var(--m-muted);
}

.stat-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 18px;
  margin-top: 12px;
}
.stat {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--m-muted);
}
.stat svg {
  flex: 0 0 auto;
  color: var(--m-primary-dark);
}
.stat strong {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.stat small {
  font-size: 11.5px;
}

/* Each block carries its own leading divider — so an empty, un-rendered
   section never leaves a doubled gap the way a fixed divider between every
   pair of sections would. */
.block {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 22px;
  padding-top: 22px;
  border-top: 1px solid var(--m-border);
}
.block:first-of-type {
  border-top: 0;
  padding-top: 0;
}
.block-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}

/* Move-in cost */
.rule-list {
  display: flex;
  flex-direction: column;
}
.rule-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 0;
  border-top: 1px solid var(--m-border);
}
.rule-list > .rule-row:first-child {
  border-top: 0;
  padding-top: 0;
}
.rule-label {
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 600;
}
.rule-value {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
}
.total-strip {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-top: 4px;
  padding: 12px 14px;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13.5px;
  font-weight: 700;
}
.total-strip strong {
  font-family: var(--m-font-display);
  font-size: 16px;
}

/* Icon grid — amenities / in-room facilities */
.icon-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(68px, 1fr));
  gap: 16px 6px;
}
.icon-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  text-align: center;
}
.icon-circle {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 50%;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.icon-item small {
  color: var(--m-text);
  font-size: 11px;
  font-weight: 600;
  line-height: 1.2;
}

/* About the property */
.desc {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.55;
  text-wrap: pretty;
}
.see-listing {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 2px;
  margin-top: 2px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

/* More rooms at this property — same rail card as the Listing page */
.room-rail {
  display: flex;
  gap: 12px;
  margin: 0 calc(var(--m-page-gutter) * -1);
  padding: 0 var(--m-page-gutter);
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
}
.room-card {
  display: flex;
  width: 148px;
  flex: 0 0 148px;
  flex-direction: column;
  border: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  scroll-snap-align: start;
  -webkit-tap-highlight-color: transparent;
}
.room-card-photo {
  position: relative;
  display: grid;
  height: 120px;
  place-items: center;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
}
.room-card-photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.room-card-mono {
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 800;
}
.room-card-type {
  position: absolute;
  left: 6px;
  top: 6px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  background: rgba(15, 23, 42, 0.55);
  color: #fff;
}
.room-card-name-row {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
}
.room-card-name {
  min-width: 0;
  flex: 1 1 auto;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.room-card-cap {
  flex: 0 0 auto;
  margin-left: auto;
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 10px;
  font-weight: 700;
  white-space: nowrap;
}
.room-card-rent {
  margin-top: 4px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 13.5px;
  font-weight: 700;
}
.room-card-rent--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 11.5px;
  font-weight: 600;
}
.room-card-per {
  font-size: 10px;
  font-weight: 600;
  opacity: 0.7;
}

/* Manager */
.mgr {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 11px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.mgr-avatar {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.mgr-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.mgr-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.mgr-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.mgr-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.mgr-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}

.cta {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.cta-btn {
  display: inline-flex;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 46px;
  padding: 0 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.cta-btn--ghost {
  flex: 0 0 auto;
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.cta-note {
  flex: 1;
  padding: 0 8px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
  text-align: center;
}
</style>
