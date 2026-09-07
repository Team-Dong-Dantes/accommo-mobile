<template>
  <q-page class="lp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="240px" square />
      <div class="sk-body">
        <q-skeleton type="text" width="65%" height="20px" />
        <q-skeleton type="text" width="45%" height="13px" />
        <q-skeleton type="text" width="80px" height="20px" class="sk-pill" />
        <div class="sk-rail">
          <div v-for="n in 2" :key="n" class="sk-room">
            <q-skeleton type="rect" class="sk-room-photo" />
            <q-skeleton type="text" width="70%" height="13px" />
          </div>
        </div>
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this listing</p>
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
      <!-- Edge-to-edge hero — one photo at a time, not a boxed thumbnail strip -->
      <div v-if="images.length" class="hero">
        <span class="hero-fallback"><IconifyIcon icon="lucide:image" width="24" /></span>
        <img v-for="(src, i) in images" :key="i" :src="src" :alt="listing.name" class="hero-img" />
        <span v-if="images.length > 1" class="hero-count">
          <IconifyIcon icon="lucide:image" width="11" />{{ images.length }}
        </span>
      </div>
      <div v-else class="hero hero--none">
        <IconifyIcon icon="lucide:image-off" width="26" />
        <span class="hero-none-label">No photos yet</span>
      </div>

      <div class="body">
        <h1 class="name">{{ listing.name }}</h1>
        <p class="where">{{ listing.address }}<template v-if="distance"> · {{ distance }} from campus</template></p>
        <div class="badge-row">
          <span class="badge">
            <IconifyIcon icon="lucide:shield-check" width="11" />OSAS Accredited
          </span>
          <span v-if="buildingType" class="type-pill">{{ buildingType }}</span>
          <span class="vacancy" :class="vacancies ? 'vacancy--ok' : 'vacancy--none'">
            {{ vacancies ? `${vacancies} room${vacancies === 1 ? '' : 's'} free` : 'Currently full' }}
          </span>
        </div>

        <div v-if="facts.length" class="stat-row">
          <span v-for="f in facts" :key="f.label" class="stat">
            <IconifyIcon :icon="f.icon" width="15" />
            <strong>{{ f.value }}</strong>
            <small>{{ f.label }}</small>
          </span>
        </div>

        <p v-if="listing.description" class="desc">{{ listing.description }}</p>

        <!-- Rooms: a rail to browse, not a settings-style list -->
        <section class="block">
          <h2 class="block-title">Rooms</h2>
          <div v-if="availableRooms.length" class="room-rail">
            <button
              v-for="room in availableRooms"
              :key="room.id"
              type="button"
              class="room-card"
              @click="router.push(`/student/room/${room.id}`)"
            >
              <span class="room-card-photo">
                <img v-if="room.image" :src="room.image" :alt="room.label" loading="lazy" />
                <span v-else class="room-card-mono">{{ monogram }}</span>
                <span v-if="room.type" class="room-card-type">{{ room.type }}</span>
              </span>
              <span class="room-card-name">{{ room.label }}</span>
              <span class="room-card-meta">{{ room.meta }}</span>
              <span v-if="room.rent" class="room-card-rent">
                {{ formatPeso(room.rent) }}<span class="room-card-per">/mo{{ room.rentBasis === 'person' ? '/person' : '' }}</span>
              </span>
              <span v-else class="room-card-rent room-card-rent--none">On request</span>
            </button>
          </div>
          <p v-else-if="rooms.length" class="none">All rooms are currently taken.</p>
          <p v-else class="none">This listing hasn't published any rooms yet.</p>
        </section>

        <!-- Amenities -->
        <section v-if="amenities.length" class="block">
          <h2 class="block-title">Amenities</h2>
          <div class="icon-grid">
            <span v-for="a in amenities" :key="a" class="icon-item">
              <span class="icon-circle"><IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="19" /></span>
              <small>{{ AMENITY_META[a]?.label || a }}</small>
            </span>
          </div>
        </section>

        <!-- Facilities -->
        <section v-if="sharedFacilities.length || privateFacilityNote" class="block">
          <h2 class="block-title">Facilities</h2>
          <div v-if="sharedFacilities.length" class="icon-grid">
            <span v-for="f in sharedFacilities" :key="f.type + f.label" class="icon-item">
              <span class="icon-circle"><IconifyIcon :icon="FACILITY_META[f.type]?.icon || 'lucide:dot'" width="19" /></span>
              <small>{{ f.label || FACILITY_META[f.type]?.label || f.type }}</small>
            </span>
          </div>
          <p v-if="privateFacilityNote" class="private-note">
            <IconifyIcon icon="lucide:door-closed" width="13" />
            {{ privateFacilityNote }}
          </p>
        </section>

        <!-- House rules -->
        <section v-if="rules.length" class="block">
          <h2 class="block-title">House rules</h2>
          <div class="rule-list">
            <div v-for="rule in rules" :key="rule.label" class="rule-row">
              <span class="rule-label">{{ rule.label }}</span>
              <span class="rule-value">{{ rule.value }}</span>
            </div>
          </div>
        </section>

        <!-- Location -->
        <section v-if="mapUrl" class="block">
          <h2 class="block-title">Location</h2>
          <div class="map">
            <img :src="mapUrl" :alt="`Map showing ${listing.name} and ${CAMPUS.label}`" loading="lazy" />
          </div>
          <p class="map-note">
            <IconifyIcon icon="lucide:school" width="12" />
            {{ distance || 'Distance unknown' }} from {{ CAMPUS.label }}
          </p>
        </section>

        <!-- Manager -->
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

    <!-- Enquiry hand-off: the conversation is where applying happens -->
    <MessageManagerCta v-if="!loading && !error && manager.id" :manager-id="manager.id" />
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, initialsOf } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, staticMapUrl, CAMPUS } from '@/utils/geo'
import { AMENITY_META, FACILITY_META, roomTypeLabel, buildingTypeLabel, listingMonogram } from '@/utils/listings'
import MessageManagerCta from '@/components/student/MessageManagerCta.vue'

interface RoomRow {
  id: string
  label: string
  meta: string
  type: string
  rent: number
  rentBasis: 'room' | 'person'
  free: boolean
  image: string
}

const route = useRoute()
const router = useRouter()

const loading = ref(true)
const error = ref('')
const listing = reactive({
  name: '',
  address: '',
  description: '',
  type: '' as string | null,
  lat: null as number | null,
  lng: null as number | null,
  totalFloors: null as number | null,
  totalRooms: null as number | null,
  capacity: null as number | null,
})
const images = ref<string[]>([])
const rooms = ref<RoomRow[]>([])
const amenities = ref<string[]>([])
const sharedFacilities = ref<{ type: string; label: string | null }[]>([])
const privateFacilityTypes = ref<string[]>([])
const rules = ref<{ label: string; value: string }[]>([])
const manager = reactive({ id: '', name: '', initials: '?', avatarUrl: null as string | null, replyMinutes: null as number | null })

const id = computed(() => String(route.params.id || ''))
const monogram = computed(() => listingMonogram(listing.name))
const buildingType = computed(() => buildingTypeLabel(listing.type))
const distance = computed(() => campusDistanceLabel(listing.lat, listing.lng))
const mapUrl = computed(() => staticMapUrl(listing.lat, listing.lng))
const vacancies = computed(() => rooms.value.filter((r) => r.free).length)
const availableRooms = computed(() => rooms.value.filter((r) => r.free))
const facts = computed(() =>
  [
    listing.totalFloors ? { icon: 'lucide:layers', label: `floor${listing.totalFloors === 1 ? '' : 's'}`, value: listing.totalFloors } : null,
    listing.totalRooms ? { icon: 'lucide:door-open', label: `room${listing.totalRooms === 1 ? '' : 's'}`, value: listing.totalRooms } : null,
    listing.capacity ? { icon: 'lucide:bed', label: 'beds total', value: listing.capacity } : null,
  ].filter((f): f is { icon: string; label: string; value: number } => f !== null),
)

// A one-line summary rather than listing every private (room-scoped)
// facility here — that level of detail belongs on each room's own page, and
// duplicating it per-room at the listing level would just repeat itself.
const privateFacilityNote = computed(() => {
  if (!privateFacilityTypes.value.length) return ''
  const labels = privateFacilityTypes.value.map((t) => (FACILITY_META[t]?.label || t).toLowerCase())
  return `Some rooms also have their own ${labels.join(', ')} — see individual rooms for details.`
})

function yesNo(value: boolean | null | undefined): string {
  if (value === null || value === undefined) return ''
  return value ? 'Allowed' : 'Not allowed'
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('accommodations')
      .select(
        'id,name,address,city,barangay,description,accommodation_type,lat,lng,accommodation_manager_id,total_floors,total_rooms,capacity,rooms(id,room_number,label,room_type,custom_room_type,capacity,monthly_rent,rent_basis,status,room_images(url,sort_order)),accommodation_amenities(amenity),accommodation_images(url,sort_order),accommodation_facilities(facility_type,access_scope,label,room_id),accommodation_policies(curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets,smoking,min_stay,contract_type)',
      )
      .eq('id', id.value)
      .eq('status', 'accredited')
      .maybeSingle()
    if (loadError) throw loadError
    if (!data) {
      error.value = 'This listing is no longer available.'
      return
    }

    listing.name = data.name?.trim() || 'Unnamed accommodation'
    listing.address =
      data.address || [data.barangay, data.city].filter(Boolean).join(', ') || 'Address not given'
    listing.description = data.description || ''
    listing.type = data.accommodation_type
    listing.lat = data.lat
    listing.lng = data.lng
    listing.totalFloors = data.total_floors
    listing.totalRooms = data.total_rooms
    listing.capacity = data.capacity

    images.value = [...((data.accommodation_images ?? []) as { url: string; sort_order: number | null }[])]
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      .map((i) => resolveAsset(i.url))
      .filter(Boolean)

    const allFacilities = (data.accommodation_facilities ?? []) as {
      facility_type: string
      access_scope: string
      label: string | null
      room_id: string | null
    }[]
    sharedFacilities.value = allFacilities
      .filter((f) => !f.room_id)
      .map((f) => ({ type: f.facility_type, label: f.label }))
    privateFacilityTypes.value = [...new Set(allFacilities.filter((f) => f.room_id).map((f) => f.facility_type))]

    // So each room card can show what's private to it (e.g. "private bath")
    // without a student having to open every room to find out.
    const privateByRoom = new Map<string, string[]>()
    for (const f of allFacilities) {
      if (!f.room_id) continue
      const list = privateByRoom.get(f.room_id) ?? []
      list.push((FACILITY_META[f.facility_type]?.label || f.facility_type).toLowerCase())
      privateByRoom.set(f.room_id, list)
    }

    rooms.value = ((data.rooms ?? []) as {
      id: string
      room_number: string | null
      label: string | null
      room_type: string | null
      custom_room_type: string | null
      capacity: number | null
      monthly_rent: number | null
      rent_basis: string | null
      status: string
      room_images: { url: string; sort_order: number | null }[] | null
    }[])
      .map((r) => {
        const roomImages = [...(r.room_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        const privateLabels = privateByRoom.get(r.id) ?? []
        return {
          id: r.id,
          label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
          meta: [
            r.capacity ? `sleeps ${r.capacity}` : '',
            privateLabels.length ? `private ${privateLabels.join(', ')}` : '',
          ]
            .filter(Boolean)
            .join(' · '),
          type: roomTypeLabel(r.custom_room_type || r.room_type),
          rent: Number(r.monthly_rent ?? 0),
          rentBasis: (r.rent_basis === 'person' && (r.capacity ?? 0) > 1 ? 'person' : 'room') as 'room' | 'person',
          free: r.status === 'available',
          image: roomImages[0]?.url ? resolveAsset(roomImages[0].url) : '',
        }
      })
      .sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

    amenities.value = ((data.accommodation_amenities ?? []) as { amenity: string }[]).map(
      (a) => a.amenity,
    )

    // accommodation_policies is one row per accommodation, but the embed
    // returns it as an array when the relationship is not marked one-to-one.
    const policyRows = data.accommodation_policies as unknown
    const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as
      | Record<string, unknown>
      | null
    if (policy) {
      const built: { label: string; value: string }[] = [
        { label: 'Curfew', value: String(policy.curfew_time ?? '') },
        { label: 'Quiet hours', value: String(policy.quiet_hours ?? '') },
        { label: 'Visitors', value: String(policy.visitor_policy ?? '') },
        { label: 'Cooking', value: yesNo(policy.cooking as boolean | null) },
        { label: 'Laundry', value: yesNo(policy.laundry as boolean | null) },
        { label: 'Pets', value: yesNo(policy.pets as boolean | null) },
        { label: 'Smoking', value: yesNo(policy.smoking as boolean | null) },
        { label: 'Minimum stay', value: policy.min_stay ? `${policy.min_stay} month(s)` : '' },
        { label: 'Contract type', value: String(policy.contract_type ?? '') },
      ]
      rules.value = built.filter((r) => r.value)
    }

    if (data.accommodation_manager_id) {
      const [{ data: person }, { data: profile }] = await Promise.all([
        supabase
          .from('users')
          .select('full_name,initials,avatar_url')
          .eq('id', data.accommodation_manager_id)
          .maybeSingle(),
        supabase
          .from('accommodation_manager_profiles')
          .select('avg_response_minutes')
          .eq('user_id', data.accommodation_manager_id)
          .maybeSingle(),
      ])
      manager.id = data.accommodation_manager_id
      manager.name = person?.full_name || 'Accommodation manager'
      manager.initials = person?.initials || initialsOf(manager.name)
      manager.avatarUrl = person?.avatar_url ? resolveAsset(person.avatar_url) : null
      manager.replyMinutes = profile?.avg_response_minutes ?? null
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.lp {
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
.sk-rail {
  display: flex;
  gap: 12px;
  margin-top: 6px;
  overflow-x: hidden;
}
.sk-room {
  display: flex;
  width: 148px;
  flex: 0 0 148px;
  flex-direction: column;
  gap: 5px;
}
.sk-room-photo {
  height: 120px;
  border-radius: var(--m-radius-sm);
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
  color: var(--m-primary-dark);
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
  margin: 5px 0 0;
  color: var(--m-muted);
  font-size: 13.5px;
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
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px solid var(--m-border);
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

.desc {
  margin: 14px 0 0;
  color: var(--m-text);
  font-size: 14px;
  line-height: 1.55;
  text-wrap: pretty;
}

/* Each block carries its own leading divider — so an empty, un-rendered
   section (e.g. no amenities) never leaves a doubled gap the way a fixed
   divider between every pair of sections would. */
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
.none {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
}

/* Rooms rail */
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
.room-card-name {
  margin-top: 8px;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.room-card-meta {
  margin-top: 1px;
  color: var(--m-muted);
  font-size: 11px;
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

/* Amenities / facilities — an icon grid, not pill soup */
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
.private-note {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.4;
}

/* House rules — plain divided rows, not a bordered box */
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

/* Map */
.map {
  overflow: hidden;
  border-radius: var(--m-radius);
}
.map img {
  display: block;
  width: 100%;
  height: 150px;
  object-fit: cover;
}
.map-note {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 8px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}

/* Manager — the one other tappable, contact-card-like row besides Rooms */
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
</style>
