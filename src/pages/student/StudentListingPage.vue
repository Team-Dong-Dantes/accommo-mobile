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
      <ErrorCard title="Couldn't load this listing" :detail="error" :retry="load" inset />
    </div>

    <div v-else class="page">
      <ListingHero :images="images" :alt="listing.name" />

      <div class="body">
        <h1 class="name">{{ listing.name }}</h1>
        <!-- campusDistanceLabel already ends in "from campus" -->
        <p class="where">{{ listing.address }}<template v-if="distance"> · {{ distance }}</template></p>
        <div class="badge-row">
          <span class="badge">
            <IconifyIcon icon="lucide:shield-check" width="11" />OSAS Accredited
          </span>
          <span v-if="buildingType" class="type-pill">{{ buildingType }}</span>
          <span v-if="genderPolicy" class="type-pill">{{ genderPolicy }}</span>
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
        <ListingBlock title="Rooms">
          <RoomRail v-if="availableRooms.length" :rooms="availableRooms" alt-from-type />
          <p v-else-if="rooms.length" class="none">All rooms are currently taken.</p>
          <p v-else class="none">This listing hasn't published any rooms yet.</p>
        </ListingBlock>

        <!-- Amenities -->
        <ListingBlock v-if="amenities.length" title="Amenities">
          <IconGrid :items="amenityItems(amenities)" />
        </ListingBlock>

        <!-- Facilities -->
        <ListingBlock v-if="sharedFacilities.length || privateFacilityNote" title="Facilities">
          <IconGrid v-if="sharedFacilities.length" :items="facilityItems(sharedFacilities)" />
          <p v-if="privateFacilityNote" class="private-note">
            <IconifyIcon icon="lucide:door-closed" width="13" />
            {{ privateFacilityNote }}
          </p>
        </ListingBlock>

        <!-- House rules -->
        <ListingBlock v-if="rules.length" title="House rules">
          <RuleList :rows="rules" />
        </ListingBlock>

        <!-- Location -->
        <ListingBlock v-if="mapUrl" title="Location">
          <div class="map">
            <img :src="mapUrl" :alt="`Map showing ${listing.name} and ${CAMPUS.label}`" loading="lazy" />
          </div>
          <p class="map-note">
            <IconifyIcon icon="lucide:school" width="12" />
            {{ distance || 'Distance unknown' }} from {{ CAMPUS.label }}
          </p>
        </ListingBlock>

        <!-- Manager -->
        <LandlordBlock v-if="manager.id" :manager="manager" />
      </div>
    </div>

    <!-- Enquiry hand-off: the conversation is where applying happens -->
    <MessageManagerCta v-if="!loading && !error && manager.id" :manager-id="manager.id" :title="manager.title" />
  </q-page>
</template>

<script setup lang="ts">
import ListingHero from '@/components/student/listing/ListingHero.vue'
import ListingBlock from '@/components/student/listing/ListingBlock.vue'
import IconGrid from '@/components/student/listing/IconGrid.vue'
import RuleList from '@/components/student/listing/RuleList.vue'
import RoomRail from '@/components/student/listing/RoomRail.vue'
import LandlordBlock from '@/components/student/listing/LandlordBlock.vue'
import { amenityItems, facilityItems } from '@/utils/listings'
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { initialsOf, landlordTitle } from '@/utils/format'
import { resolveAsset, AVATAR, CARD, COVER } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, staticMapUrl, CAMPUS } from '@/utils/geo'
import { AMENITY_META, FACILITY_META, utilitiesFromRow, utilitiesHint, type UtilityColumns, roomTypeLabel, buildingTypeLabel, genderPolicyLabel } from '@/utils/listings'
import MessageManagerCta from '@/components/student/MessageManagerCta.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { POLICY_FULL, ROOM_CARD } from '@/api/selects'

interface RoomRow {
  id: string
  label: string
  meta: string
  /** How this room's utilities are paid, in one line (rooms in a house can differ). */
  utilities: string
  capacity: number
  type: string
  rent: number
  rentBasis: 'room' | 'person'
  free: boolean
  image: string
}

const route = useRoute()

const loading = ref(true)
const error = ref('')
const listing = reactive({
  name: '',
  address: '',
  description: '',
  type: '' as string | null,
  genderPolicy: '' as string | null,
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
const manager = reactive({ id: '', name: '', title: landlordTitle(null), initials: '?', avatarUrl: null as string | null, replyMinutes: null as number | null })

const id = computed(() => String(route.params.id || ''))
const buildingType = computed(() => buildingTypeLabel(listing.type))
const genderPolicy = computed(() => genderPolicyLabel(listing.genderPolicy))
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
        `id,name,address,city,barangay,purok,description,accommodation_type,gender_policy,lat,lng,landlord_id,total_floors,total_rooms,capacity,rooms(${ROOM_CARD},room_images(url,sort_order)),accommodation_amenities(amenity),accommodation_images(url,sort_order),accommodation_facilities(facility_type,access_scope,label,room_id),accommodation_policies(${POLICY_FULL})`,
      )
      .eq('id', id.value)
      .eq('status', 'accredited').eq('hidden_from_listings', false)
      .maybeSingle()
    if (loadError) throw loadError
    if (!data) {
      error.value = 'This listing is no longer available.'
      return
    }

    listing.name = data.name?.trim() || 'Unnamed accommodation'
    listing.address =
      data.address || [data.purok, data.barangay, data.city].filter(Boolean).join(', ') || 'Address not given'
    listing.description = data.description || ''
    listing.type = data.accommodation_type
    listing.genderPolicy = data.gender_policy
    listing.lat = data.lat
    listing.lng = data.lng
    listing.totalFloors = data.total_floors
    listing.totalRooms = data.total_rooms
    listing.capacity = data.capacity

    images.value = [...((data.accommodation_images ?? []) as { url: string; sort_order: number | null }[])]
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      .map((i) => resolveAsset(i.url, COVER))
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

    rooms.value = ((data.rooms ?? []) as ({
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
    } & Partial<UtilityColumns>)[])
      .map((r) => {
        const roomImages = [...(r.room_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        const privateLabels = privateByRoom.get(r.id) ?? []
        return {
          id: r.id,
          label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
          // Capacity rides in its own capsule beside the title now, the way
          // the discover cards show it — so this is just the private bits.
          meta: privateLabels.length ? `private ${privateLabels.join(', ')}` : '',
          utilities: utilitiesHint(utilitiesFromRow(r)),
          capacity: Number(r.capacity ?? 0),
          type: roomTypeLabel(r.custom_room_type || r.room_type),
          rent: Number(r.monthly_rent ?? 0),
          rentBasis: (r.rent_basis === 'person' && (r.capacity ?? 0) > 1 ? 'person' : 'room') as 'room' | 'person',
          free: r.status === 'available',
          image: roomImages[0]?.url ? resolveAsset(roomImages[0].url, CARD) : '',
        }
      })
      .sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

    amenities.value = ((data.accommodation_amenities ?? []) as { amenity: string }[])
      .map((a) => a.amenity)
      .filter((a) => a in AMENITY_META)

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
        { label: 'Contract type', value: String(policy.contract_type ?? '') },
      ]
      rules.value = built.filter((r) => r.value)
    }

    if (data.landlord_id) {
      const [{ data: person }, { data: profile }] = await Promise.all([
        supabase
          .from('users')
          .select('full_name,initials,avatar_url,sex')
          .eq('id', data.landlord_id)
          .maybeSingle(),
        supabase
          .from('landlord_profiles')
          .select('avg_response_minutes')
          .eq('user_id', data.landlord_id)
          .maybeSingle(),
      ])
      manager.id = data.landlord_id
      manager.name = person?.full_name || landlordTitle(person?.sex)
      manager.title = landlordTitle(person?.sex)
      manager.initials = person?.initials || initialsOf(manager.name)
      manager.avatarUrl = person?.avatar_url ? resolveAsset(person.avatar_url, AVATAR) : null
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

<style scoped src="@/components/student/listing/detail.css"></style>

<style scoped>
.lp {
  background: var(--m-bg);
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
.where {
  margin: 5px 0 0;
  color: var(--m-muted);
  font-size: 13.5px;
}
.stat-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 18px;
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px solid var(--m-border);
}
.desc {
  margin: 14px 0 0;
  color: var(--m-text);
  font-size: 14px;
  line-height: 1.55;
  text-wrap: pretty;
}
.none {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
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
</style>
