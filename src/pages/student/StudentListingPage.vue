<template>
  <q-page class="lp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="180px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
      <q-skeleton type="rect" height="140px" class="sk" />
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

    <div v-else class="stack">
      <!-- Photos, or a monogram band when there are none -->
      <div v-if="images.length" class="gal">
        <img v-for="(src, i) in images" :key="i" :src="src" :alt="listing.name" class="gal-img" />
        <span v-if="images.length > 1" class="gal-count">
          <IconifyIcon icon="lucide:image" width="11" />{{ images.length }}
        </span>
      </div>
      <div v-else class="gal-none">
        <span class="gal-mono">{{ monogram }}</span>
      </div>

      <div class="head">
        <h1 class="head-name">{{ listing.name }}</h1>
        <p class="head-where">{{ listing.address }}</p>
        <span class="badge">
          <IconifyIcon icon="lucide:shield-check" width="11" />OSAS Accredited
        </span>
        <div class="head-tags">
          <span v-if="buildingType" class="tag">{{ buildingType }}</span>
          <span v-if="distance" class="tag tag--soft">
            <IconifyIcon icon="lucide:map-pin" width="11" />{{ distance }}
          </span>
          <span class="tag" :class="vacancies ? 'tag--ok' : 'tag--none'">
            {{ vacancies ? `${vacancies} room${vacancies === 1 ? '' : 's'} free` : 'Currently full' }}
          </span>
        </div>
        <div v-if="facts.length" class="facts">
          <span v-for="f in facts" :key="f.label" class="fact">
            <strong>{{ f.value }}</strong>{{ f.label }}
          </span>
        </div>
      </div>

      <p v-if="listing.description" class="desc">{{ listing.description }}</p>

      <!-- Rooms -->
      <section class="sec">
        <h2 class="sec-title">Rooms</h2>
        <div class="group">
          <button
            v-for="room in rooms"
            :key="room.id"
            type="button"
            class="room"
            :class="{ 'room--taken': !room.free }"
            @click="router.push(`/student/room/${room.id}`)"
          >
            <span class="room-thumb">
              <img v-if="room.image" :src="room.image" :alt="room.label" loading="lazy" />
              <span v-else class="room-thumb-mono">{{ monogram }}</span>
            </span>
            <span class="room-body">
              <span class="room-name">{{ room.label }}</span>
              <span class="room-meta">{{ room.meta }}</span>
            </span>
            <span class="room-side">
              <span v-if="room.rent" class="room-rent">{{ formatPeso(room.rent) }}<span class="room-per">/mo</span></span>
              <span v-else class="room-rent room-rent--none">On request</span>
              <span class="room-tag" :class="room.free ? 'room-tag--ok' : 'room-tag--none'">
                {{ room.free ? 'Available' : 'Taken' }}
              </span>
            </span>
          </button>
          <p v-if="!rooms.length" class="none">This listing hasn't published any rooms yet</p>
        </div>
      </section>

      <!-- Amenities -->
      <section v-if="amenities.length" class="sec">
        <h2 class="sec-title">What's here</h2>
        <div class="ams">
          <span v-for="a in amenities" :key="a" class="am">
            <IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="14" />
            {{ AMENITY_META[a]?.label || a }}
          </span>
        </div>
      </section>

      <!-- Shared facilities -->
      <section v-if="sharedFacilities.length" class="sec">
        <h2 class="sec-title">Shared facilities</h2>
        <div class="ams">
          <span v-for="f in sharedFacilities" :key="f.type + f.label" class="am">
            <IconifyIcon :icon="FACILITY_META[f.type]?.icon || 'lucide:dot'" width="14" />
            {{ f.label || FACILITY_META[f.type]?.label || f.type }}
          </span>
        </div>
      </section>

      <!-- House rules -->
      <section v-if="rules.length" class="sec">
        <h2 class="sec-title">House rules</h2>
        <div class="group">
          <div v-for="rule in rules" :key="rule.label" class="rule">
            <span class="rule-label">{{ rule.label }}</span>
            <span class="rule-value">{{ rule.value }}</span>
          </div>
        </div>
      </section>

      <!-- Where it is, relative to school -->
      <section v-if="mapUrl" class="sec">
        <h2 class="sec-title">Where it is</h2>
        <div class="map">
          <img :src="mapUrl" :alt="`Map showing ${listing.name} and ${CAMPUS.label}`" loading="lazy" />
          <p class="map-note">
            <IconifyIcon icon="lucide:school" width="12" />
            {{ distance || 'Distance unknown' }} · {{ CAMPUS.label }}
          </p>
        </div>
      </section>

      <!-- The person to ask -->
      <section v-if="manager.id" class="sec">
        <h2 class="sec-title">Managed by</h2>
        <button type="button" class="mgr" @click="router.push(`/student/manager/${manager.id}`)">
          <span class="mgr-avatar">{{ manager.initials }}</span>
          <span class="mgr-body">
            <span class="mgr-name">{{ manager.name }}</span>
            <span class="mgr-sub">
              {{ manager.replyMinutes ? `Replies in ~${manager.replyMinutes} min` : 'Accommodation manager' }}
            </span>
          </span>
        </button>
      </section>

      <div class="tail" />
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
  rent: number
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
const rules = ref<{ label: string; value: string }[]>([])
const manager = reactive({ id: '', name: '', initials: '?', replyMinutes: null as number | null })

const id = computed(() => String(route.params.id || ''))
const monogram = computed(() => listingMonogram(listing.name))
const buildingType = computed(() => buildingTypeLabel(listing.type))
const distance = computed(() => campusDistanceLabel(listing.lat, listing.lng))
const mapUrl = computed(() => staticMapUrl(listing.lat, listing.lng))
const vacancies = computed(() => rooms.value.filter((r) => r.free).length)
const facts = computed(() =>
  [
    listing.totalFloors ? { label: ` floor${listing.totalFloors === 1 ? '' : 's'}`, value: listing.totalFloors } : null,
    listing.totalRooms ? { label: ` room${listing.totalRooms === 1 ? '' : 's'}`, value: listing.totalRooms } : null,
    listing.capacity ? { label: ' beds total', value: listing.capacity } : null,
  ].filter((f): f is { label: string; value: number } => f !== null),
)

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
        'id,name,address,city,barangay,description,accommodation_type,lat,lng,accommodation_manager_id,total_floors,total_rooms,capacity,rooms(id,room_number,label,room_type,custom_room_type,capacity,monthly_rent,status,room_images(url,sort_order)),accommodation_amenities(amenity),accommodation_images(url,sort_order),accommodation_facilities(facility_type,access_scope,label,room_id),accommodation_policies(curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets,smoking,deposit_months,advance_months,min_stay,contract_type)',
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

    rooms.value = ((data.rooms ?? []) as {
      id: string
      room_number: string | null
      label: string | null
      room_type: string | null
      custom_room_type: string | null
      capacity: number | null
      monthly_rent: number | null
      status: string
      room_images: { url: string; sort_order: number | null }[] | null
    }[])
      .map((r) => {
        const roomImages = [...(r.room_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        return {
          id: r.id,
          label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
          meta: [
            roomTypeLabel(r.custom_room_type || r.room_type),
            r.capacity ? `sleeps ${r.capacity}` : '',
          ]
            .filter(Boolean)
            .join(' · '),
          rent: Number(r.monthly_rent ?? 0),
          free: r.status === 'available',
          image: roomImages[0]?.url ? resolveAsset(roomImages[0].url) : '',
        }
      })
      .sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

    amenities.value = ((data.accommodation_amenities ?? []) as { amenity: string }[]).map(
      (a) => a.amenity,
    )

    sharedFacilities.value = (
      (data.accommodation_facilities ?? []) as {
        facility_type: string
        access_scope: string
        label: string | null
        room_id: string | null
      }[]
    )
      .filter((f) => !f.room_id)
      .map((f) => ({ type: f.facility_type, label: f.label }))

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
        {
          label: 'Deposit',
          value: policy.deposit_months ? `${policy.deposit_months} month(s)` : '',
        },
        {
          label: 'Advance',
          value: policy.advance_months ? `${policy.advance_months} month(s)` : '',
        },
        { label: 'Minimum stay', value: policy.min_stay ? `${policy.min_stay} month(s)` : '' },
      ]
      rules.value = built.filter((r) => r.value)
    }

    if (data.accommodation_manager_id) {
      const [{ data: person }, { data: profile }] = await Promise.all([
        supabase
          .from('users')
          .select('full_name,initials')
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
.tail {
  height: 78px;
}

.card {
  padding: 18px 14px;
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

/* Gallery */
.gal {
  position: relative;
  display: flex;
  gap: 6px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
}
.gal-img {
  width: 88%;
  height: 190px;
  flex: 0 0 auto;
  border-radius: var(--m-radius);
  object-fit: cover;
  scroll-snap-align: start;
}
.gal-count {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 8px;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
}
.gal-none {
  display: grid;
  height: 120px;
  place-items: center;
  border-radius: var(--m-radius);
  background: var(--m-primary-soft);
}
.gal-mono {
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 34px;
  font-weight: 800;
}

.head-name {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 21px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
}
.head-where {
  margin: 3px 0 0;
  color: var(--m-muted);
  font-size: 13px;
}
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: 5px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 11px;
  font-weight: 700;
}
.head-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
}
.facts {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 14px;
  margin-top: 8px;
  color: var(--m-muted);
  font-size: 12px;
}
.facts strong {
  color: var(--m-ink);
  font-weight: 700;
}
.tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 11.5px;
  font-weight: 700;
}
.tag--soft {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.tag--ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.tag--none {
  background: var(--m-bg);
  color: var(--m-muted);
}

.desc {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
  text-wrap: pretty;
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-title {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}

/* Rooms */
.room {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .room:first-child {
  border-top: 0;
}
.room--taken {
  opacity: 0.6;
}
.room-thumb {
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
}
.room-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.room-thumb-mono {
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 13px;
  font-weight: 800;
}
.room-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.room-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.room-meta {
  color: var(--m-muted);
  font-size: 11.5px;
}
.room-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.room-rent {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14.5px;
  font-weight: 700;
}
.room-rent--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 12px;
}
.room-per {
  font-size: 10.5px;
  font-weight: 600;
  opacity: 0.7;
}
.room-tag {
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.room-tag--ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.room-tag--none {
  background: var(--m-bg);
  color: var(--m-muted);
}

/* Amenities */
.ams {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.am {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  font-size: 12.5px;
  font-weight: 600;
}

/* Rules */
.rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .rule:first-child {
  border-top: 0;
}
.rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}

/* Map */
.map {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.map img {
  display: block;
  width: 100%;
  height: 160px;
  object-fit: cover;
}
.map-note {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 0;
  padding: 8px 12px;
  border-top: 1px solid var(--m-border);
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}

/* Manager */
.mgr {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 11px;
  padding: 10px 12px;
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
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.mgr-body {
  display: flex;
  min-width: 0;
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

</style>
