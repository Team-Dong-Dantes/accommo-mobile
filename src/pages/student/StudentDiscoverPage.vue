<template>
  <q-page class="disc">
    <div v-if="loading" class="stack">
      <section class="sec">
        <q-skeleton type="text" width="90px" height="16px" />
        <div class="rail">
          <div v-for="n in 2" :key="n" class="sk-car rail-item">
            <q-skeleton type="rect" class="sk-car-shot" />
            <q-skeleton type="text" width="70%" height="14px" />
            <q-skeleton type="text" width="45%" height="11px" />
          </div>
        </div>
      </section>
      <section class="sec">
        <q-skeleton type="text" width="60px" height="16px" />
        <div class="grid">
          <div v-for="n in 4" :key="n" class="sk-tile">
            <q-skeleton type="rect" class="sk-tile-shot" />
            <q-skeleton type="text" width="70%" height="13px" />
            <q-skeleton type="text" width="45%" height="11px" />
          </div>
        </div>
      </section>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load listings</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn
          unelevated
          rounded
          no-caps
          dense
          color="primary"
          label="Try again"
          class="q-mt-sm q-px-md"
          @click="load()"
        />
      </q-card>
    </div>

    <template v-else>
      <div
        v-if="hasMapToken"
        class="map-region"
        :style="mapRegionStyle"
        @transitionend="onMapRegionTransitionEnd"
      >
        <div ref="mapEl" class="map-el" aria-label="Map of accommodations" />
        <button v-if="!mapExpanded" type="button" class="map-expand-btn" @click="toggleMapExpanded(true)">
          <IconifyIcon icon="lucide:maximize-2" width="15" />
          <span>Map view</span>
        </button>
      </div>

      <!-- Full map: the preview button above is now covered by the fixed
           full-screen map, so this is the way back — parked just under the
           header where the rail/info card below can never cover it. -->
      <button
        v-if="hasMapToken && mapExpanded"
        type="button"
        class="map-collapse-btn"
        :style="{ top: (headerReservedPx + 16) + 'px' }"
        @click="toggleMapExpanded(false)"
      >
        <IconifyIcon icon="lucide:x" width="16" />
        <span>List view</span>
      </button>

      <!-- Full-map mode: a floating recommendations rail above the search
           dock; picking one flies the map to it and swaps the rail for that
           item's info + a way straight into it. -->
      <div v-if="hasMapToken && mapExpanded" class="map-float">
        <div v-if="!selectedPin" class="map-float-rail">
          <PropertyCard
            v-for="item in properties.slice(0, 10)"
            :key="item.id"
            variant="carousel"
            class="map-float-card"
            :id="item.id"
            :name="item.name"
            :address="item.address"
            :image="item.image"
            :monogram="item.monogram"
            :distance="item.distance"
            :vacancies="item.vacancies"
            :building-type="item.buildingType"
            @open="selectPinById"
          />
          <button
            v-for="room in rooms.slice(0, 10)"
            :key="room.id"
            type="button"
            class="map-float-card map-float-room"
            @click="selectRoomById(room.id)"
          >
            <span class="map-float-room-shot" :class="{ 'map-float-room-shot--empty': !room.image }">
              <img v-if="room.image" :src="room.image" :alt="room.label" loading="lazy" />
              <IconifyIcon v-else icon="lucide:image-off" width="22" />
              <span v-if="room.typeLabel" class="map-float-room-type">{{ room.typeLabel }}</span>
            </span>
            <span class="map-float-room-body">
              <span class="map-float-room-name">{{ room.label }}</span>
              <span class="map-float-room-where">{{ room.propertyName }}</span>
              <span v-if="room.rent" class="map-float-room-rent">{{ formatPeso(room.rent) }}/mo</span>
            </span>
          </button>
        </div>
        <div v-else class="map-float-info">
          <span class="map-float-info-shot" :class="{ 'map-float-info-shot--empty': !selectedPin.image }">
            <img v-if="selectedPin.image" :src="selectedPin.image" :alt="selectedPin.name" loading="lazy" />
            <IconifyIcon v-else icon="lucide:image-off" width="22" />
            <button type="button" class="map-float-close" aria-label="Back to recommendations" @click="clearSelectedPin">
              <IconifyIcon icon="lucide:x" width="16" />
            </button>
          </span>
          <span class="map-float-info-body">
            <span class="map-float-info-text">
              <strong>{{ selectedPin.name }}</strong>
              <span v-if="selectedPin.subtitle">{{ selectedPin.subtitle }}</span>
            </span>
            <q-btn
              unelevated
              no-caps
              color="primary"
              class="map-float-cta"
              :label="selectedPin.kind === 'room' ? 'View room' : 'View accommodation'"
              @click="router.push(selectedPin.route)"
            />
          </span>
        </div>
      </div>

    <div class="stack">
      <section v-if="filteredProperties.length" class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Accommodations</h2>
          <button type="button" class="sec-more" @click="router.push('/student/properties')">
            View all
          </button>
        </div>
        <div class="rail">
          <PropertyCard
            v-for="item in filteredProperties.slice(0, 10)"
            :key="item.id"
            variant="carousel"
            class="rail-item"
            :id="item.id"
            :name="item.name"
            :address="item.address"
            :image="item.image"
            :monogram="item.monogram"
            :distance="item.distance"
            :vacancies="item.vacancies"
            :building-type="item.buildingType"
            @open="open"
          />
        </div>
      </section>

      <!-- Managers only surface once a search narrows to them -->
      <section v-if="query.trim() && filteredManagers.length" class="sec">
        <h2 class="sec-title">Managers</h2>
        <div class="mgrs">
          <button
            v-for="m in filteredManagers"
            :key="m.id"
            type="button"
            class="mgr-row"
            @click="openManager(m.id)"
          >
            <span class="mgr-avatar">
              <img v-if="m.avatarUrl" :src="m.avatarUrl" alt="" class="mgr-avatar-img" @error="m.avatarUrl = null" />
              <template v-else>{{ m.initials }}</template>
            </span>
            <span class="mgr-body">
              <span class="mgr-name">{{ m.name }}</span>
              <span class="mgr-sub">
                {{ m.propertyCount ? `${m.propertyCount} ${m.propertyCount === 1 ? 'accommodation' : 'accommodations'}` : 'New manager' }}
              </span>
            </span>
          </button>
        </div>
      </section>

      <section class="sec">
        <h2 class="sec-title">Rooms</h2>
        <div v-if="filteredRooms.length" class="grid">
          <button
            v-for="room in filteredRooms"
            :key="room.id"
            type="button"
            class="tile"
            @click="openRoom(room.id)"
          >
            <span class="tile-shot" :class="{ 'tile-shot--empty': !room.image }">
              <img v-if="room.image" :src="room.image" :alt="room.label" loading="lazy" />
              <span v-else class="shot-empty">
                <IconifyIcon icon="lucide:image-off" width="22" />
                <span class="shot-empty-label">No photo</span>
              </span>
              <span v-if="room.typeLabel" class="tile-flag">{{ room.typeLabel }}</span>
            </span>
            <span class="tile-body">
              <span class="tile-name">{{ room.label }}</span>
              <span class="tile-where">{{ room.propertyName }}</span>
              <span v-if="room.meta" class="tile-meta">{{ room.meta }}</span>
              <span v-if="room.rent" class="tile-rent">
                {{ formatPeso(room.rent) }}<span class="tile-per">/mo{{ room.rentBasis === 'person' ? ' per person' : '' }}</span>
              </span>
              <span v-else class="tile-rent tile-rent--none">Rent on request</span>
            </span>
          </button>
        </div>
        <p v-else class="none">
          {{ query.trim() ? 'No rooms match your search.' : 'No rooms published yet.' }}
        </p>
      </section>

      <p
        v-if="query.trim() && !filteredProperties.length && !filteredManagers.length && !filteredRooms.length"
        class="none"
      >
        Nothing matches "{{ query.trim() }}".
      </p>
    </div>
    </template>

    <!-- Search sits on the FAB's baseline so the two read as one control band -->
    <div v-if="!loading && !error" class="dock">
      <button
        type="button"
        class="dock-btn"
        :class="{ 'dock-btn--on': activeFilterCount > 0 }"
        aria-label="Filters"
        @click="filtersOpen = true"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
        <span v-if="activeFilterCount" class="dock-dot">{{ activeFilterCount }}</span>
      </button>
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input
          v-model="query"
          class="dock-input"
          type="search"
          placeholder="Search accommodations, rooms, managers"
          aria-label="Search accommodations, rooms, managers"
        />
      </div>
    </div>

    <!-- Filters — apply to the room grid, the page's main content -->
    <q-dialog v-model="filtersOpen" position="bottom">
      <div class="sheet">
        <div class="sheet-head">
          <h2 class="sheet-title">Filters</h2>
          <button type="button" class="sheet-clear" @click="resetFilters">Reset</button>
        </div>

        <label class="sheet-row">
          <span class="sheet-label">Only available rooms</span>
          <q-toggle v-model="filters.vacantOnly" color="primary" dense />
        </label>

        <div class="sheet-block">
          <span class="sheet-label">Monthly rent up to {{ formatPeso(filters.maxRent) }}</span>
          <q-slider
            v-model="filters.maxRent"
            :min="rentBounds.min"
            :max="rentBounds.max"
            :step="500"
            color="primary"
            class="q-px-sm"
          />
        </div>

        <div class="sheet-block">
          <span class="sheet-label">Room type</span>
          <div class="chips">
            <button
              v-for="type in roomTypeOptions"
              :key="type"
              type="button"
              class="chip"
              :class="{ 'chip--on': filters.roomTypes.includes(type) }"
              @click="toggle(filters.roomTypes, type)"
            >
              {{ roomTypeLabel(type) }}
            </button>
          </div>
        </div>

        <div class="sheet-block">
          <span class="sheet-label">Must have</span>
          <div class="chips">
            <button
              v-for="key in AMENITY_KEYS"
              :key="key"
              type="button"
              class="chip"
              :class="{ 'chip--on': filters.amenities.includes(key) }"
              @click="toggle(filters.amenities, key)"
            >
              <IconifyIcon :icon="AMENITY_META[key]?.icon || 'lucide:dot'" width="13" />
              {{ AMENITY_META[key]?.label }}
            </button>
          </div>
        </div>

        <button type="button" class="sheet-done" @click="filtersOpen = false">
          Show {{ filteredRooms.length }} {{ filteredRooms.length === 1 ? 'room' : 'rooms' }}
        </button>
      </div>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted, onUnmounted, onDeactivated, nextTick } from 'vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import mapboxgl from 'mapbox-gl'
import 'mapbox-gl/dist/mapbox-gl.css'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, CAMPUS } from '@/utils/geo'
import { AMENITY_META, AMENITY_KEYS, roomTypeLabel, buildingTypeLabel, listingMonogram } from '@/utils/listings'
import PropertyCard from '@/components/student/PropertyCard.vue'

interface Property {
  id: string
  name: string
  address: string
  image: string
  monogram: string
  distance: string
  vacancies: number
  minRent: number | null
  buildingType: string
  lat: number | null
  lng: number | null
  haystack: string
}

interface RoomTile {
  id: string
  label: string
  image: string
  monogram: string
  propertyName: string
  meta: string
  typeLabel: string
  rent: number
  rentBasis: 'room' | 'person'
  free: boolean
  roomType: string
  amenities: string[]
  lat: number | null
  lng: number | null
  haystack: string
}

interface ManagerRow {
  id: string
  name: string
  initials: string
  avatarUrl: string | null
  propertyCount: number
  haystack: string
}

const router = useRouter()

const loading = ref(true)
const error = ref('')
const query = ref('')
const properties = ref<Property[]>([])
const rooms = ref<RoomTile[]>([])
const managers = ref<ManagerRow[]>([])

// Map preview + full-screen toggle — the map's height is a plain vh slice of
// the page, so it lives in normal document flow above the list and the
// existing page scroll (see MainLayout's .q-page-container) keeps working
// unchanged; no special fixed-height layout is needed for "expand it to fill
// the page". Two states, switched by pressing a button rather than dragging
// a handle — a plain height transition (CSS) between them.
const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined
const hasMapToken = Boolean(MAPBOX_TOKEN)
const MAP_PREVIEW_VH = 32
const mapEl = ref<HTMLElement | null>(null)
const mapExpanded = ref(false)

// 100vh overshoots: the header eats into the viewport before the scroll
// container (.q-page-container) even starts, so a literal 100vh map runs
// past the bottom of the screen. Measured from the container's own rendered
// box — the actual space available — rather than assumed from the header's
// nominal size, so it can't drift out of sync with it.
const headerOffsetPx = ref(0)
const pageViewportPx = ref(0)
// The floating header reserves this much space via padding-top on
// .q-page-container rather than pushing it down in normal flow (it's
// `position: fixed`). Reused to pull the map's own top edge up by the same
// amount, so it runs behind the header instead of starting below it.
const headerReservedPx = ref(0)

function measureViewport() {
  const container = document.querySelector('.q-page-container') as HTMLElement | null
  if (!container) return
  const rect = container.getBoundingClientRect()
  headerOffsetPx.value = rect.top
  pageViewportPx.value = rect.height
  headerReservedPx.value = parseFloat(getComputedStyle(container).paddingTop) || 0
}

/** The height applied to the map. Expanded uses the whole window (header
 * height + container height), not just the container's own visible slice,
 * so it fills the screen edge to edge. Both states stay `position: sticky`
 * (see mapRegionStyle below) rather than switching to `fixed` for expanded —
 * a CSS transition can animate a height change smoothly, but position type
 * itself can't be animated at all, so that switch made expanding look like
 * an instant jump cut instead of a resize. */
const mapFillHeight = computed(() =>
  mapExpanded.value && pageViewportPx.value > 0
    ? `${headerOffsetPx.value + pageViewportPx.value}px`
    : `${MAP_PREVIEW_VH}vh`,
)

// Sticky, in normal flow, in both states — so it starts below the header's
// reserved padding by default. Pulling only its static (pre-scroll)
// position up by that amount lets it run behind the floating header too;
// the sticky pin itself stays at the default `top: 0` from the CSS class,
// since that offset is resolved against the scrollport's padding edge and
// already nets out correctly once the negative margin is factored in —
// also offsetting `top` here would double-count it.
const mapRegionStyle = computed(() => ({
  height: mapFillHeight.value,
  marginTop: `-${headerReservedPx.value}px`,
}))

interface SelectedPin {
  kind: 'property' | 'room'
  name: string
  subtitle: string
  image: string
  route: string
}
const selectedPin = ref<SelectedPin | null>(null)

let map: mapboxgl.Map | null = null
let markers: mapboxgl.Marker[] = []

const filtersOpen = ref(false)
const DEFAULT_MAX = 10000
const rentBounds = reactive({ min: 0, max: DEFAULT_MAX })
const filters = reactive({
  vacantOnly: true,
  maxRent: DEFAULT_MAX,
  roomTypes: [] as string[],
  amenities: [] as string[],
})

const roomTypeOptions = computed(() => {
  const seen = new Set<string>()
  for (const r of rooms.value) if (r.roomType) seen.add(r.roomType)
  return [...seen].sort()
})

const activeFilterCount = computed(
  () =>
    (filters.vacantOnly ? 0 : 1) +
    (filters.maxRent < rentBounds.max ? 1 : 0) +
    filters.roomTypes.length +
    filters.amenities.length,
)

const filteredProperties = computed(() => filterByHaystack(properties.value))
const filteredManagers = computed(() => filterByHaystack(managers.value))
const filteredRooms = computed(() => {
  return filterByHaystack(rooms.value).filter((r) => {
    if (filters.vacantOnly && !r.free) return false
    // A room with no listed rent can't be excluded on price without hiding
    // it from every search, so it only drops out below the ceiling.
    if (filters.maxRent < rentBounds.max && r.rent > 0 && r.rent > filters.maxRent) return false
    if (filters.roomTypes.length && !filters.roomTypes.includes(r.roomType)) return false
    if (filters.amenities.length && !filters.amenities.every((a) => r.amenities.includes(a))) return false
    return true
  })
})

function filterByHaystack<T extends { haystack: string }>(list: T[]): T[] {
  const needle = query.value.trim().toLowerCase()
  return needle ? list.filter((item) => item.haystack.includes(needle)) : list
}

function toggle(list: string[], value: string) {
  const at = list.indexOf(value)
  if (at === -1) list.push(value)
  else list.splice(at, 1)
}

function resetFilters() {
  filters.vacantOnly = true
  filters.maxRent = rentBounds.max
  filters.roomTypes = []
  filters.amenities = []
}

function open(id: string) {
  void router.push(`/student/listing/${id}`)
}

function openRoom(id: string) {
  void router.push(`/student/room/${id}`)
}

function openManager(id: string) {
  void router.push(`/student/manager/${id}`)
}

function onMapRegionTransitionEnd() {
  map?.resize()
}

// Mapbox renders to a canvas sized once, not something that keeps pace with
// a CSS transition on its own — without this, the height animates smoothly
// but the map's own content stays a static, wrong-sized image for the whole
// 260ms and only snaps to fill the box at transitionend, which reads as
// janky rather than smooth. Driving resize() every frame for the duration
// of the transition keeps the map itself resizing in step with the box.
const MAP_TRANSITION_MS = 260
function toggleMapExpanded(expanded: boolean) {
  mapExpanded.value = expanded
  const start = performance.now()
  const step = (now: number) => {
    map?.resize()
    if (now - start < MAP_TRANSITION_MS) requestAnimationFrame(step)
  }
  requestAnimationFrame(step)
}

function initMap() {
  if (!mapEl.value || map || !hasMapToken) return
  mapboxgl.accessToken = MAPBOX_TOKEN!
  map = new mapboxgl.Map({
    container: mapEl.value,
    style: 'mapbox://styles/mapbox/streets-v12',
    center: [CAMPUS.lng, CAMPUS.lat],
    zoom: 13,
  })
  map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right')
  map.on('load', syncMarkers)
}

/** Re-places one pin per accommodation that has coordinates; called after
 * every load (including silent realtime refreshes) once the map exists. */
function syncMarkers() {
  if (!map) return
  for (const marker of markers) marker.remove()
  markers = []

  const located = properties.value.filter(
    (p): p is Property & { lat: number; lng: number } => p.lat !== null && p.lng !== null,
  )
  for (const property of located) {
    const el = document.createElement('button')
    el.type = 'button'
    el.className = 'map-pin'
    el.setAttribute('aria-label', property.name)
    // Full map: tapping a pin selects it in the floating rail instead of
    // leaving the map. Smaller/default sizes still jump straight to it.
    el.addEventListener('click', () => (mapExpanded.value ? selectPin(property) : open(property.id)))
    markers.push(new mapboxgl.Marker({ element: el }).setLngLat([property.lng, property.lat]).addTo(map))
  }

  if (located.length) {
    const bounds = new mapboxgl.LngLatBounds()
    for (const p of located) bounds.extend([p.lng, p.lat])
    map.fitBounds(bounds, { padding: 60, maxZoom: 15, duration: 0 })
  }
}

function selectPin(property: Property & { lat: number; lng: number }) {
  selectedPin.value = {
    kind: 'property',
    name: property.name,
    subtitle: property.buildingType || property.address,
    image: property.image,
    route: `/student/listing/${property.id}`,
  }
  map?.flyTo({ center: [property.lng, property.lat], zoom: 16, essential: true })
}

function selectPinById(id: string) {
  const property = properties.value.find((p) => p.id === id)
  if (property && property.lat !== null && property.lng !== null) {
    selectPin(property as Property & { lat: number; lng: number })
  }
}

function selectRoom(room: RoomTile & { lat: number; lng: number }) {
  selectedPin.value = {
    kind: 'room',
    name: room.label,
    subtitle: [room.propertyName, room.rent ? `${formatPeso(room.rent)}/mo` : ''].filter(Boolean).join(' · '),
    image: room.image,
    route: `/student/room/${room.id}`,
  }
  map?.flyTo({ center: [room.lng, room.lat], zoom: 16, essential: true })
}

function selectRoomById(id: string) {
  const room = rooms.value.find((r) => r.id === id)
  if (room && room.lat !== null && room.lng !== null) {
    selectRoom(room as RoomTile & { lat: number; lng: number })
  }
}

function clearSelectedPin() {
  selectedPin.value = null
}

// Leaving the expanded map shouldn't leave a stale selection waiting behind
// the rail next time it's re-opened.
// Both map states are `position: sticky` now (see mapRegionStyle), so
// expanded is just a much taller in-flow box, not a true overlay — without
// this, scrolling past it would reveal the room list underneath instead of
// staying an isolated full-screen map until "List view" is pressed.
watch(mapExpanded, (expanded) => {
  if (!expanded) selectedPin.value = null
  document.documentElement.style.overflow = expanded ? 'hidden' : ''
})

async function loadProperties(silent = false) {
  // Only accredited listings are readable, and the policy grants the public
  // role, so this works signed-out too — keep this select clear of the
  // `users` table, which anon cannot read at all.
  const { data, error: loadError } = await supabase
    .from('accommodations')
    .select(
      'id,name,address,city,barangay,lat,lng,accommodation_type,rooms(id,label,room_number,room_type,custom_room_type,capacity,monthly_rent,rent_basis,status,room_images(url,sort_order)),accommodation_amenities(amenity),accommodation_images(url,sort_order)',
    )
    .eq('status', 'accredited')
  if (loadError) throw loadError

  const propertyList: Property[] = []
  const roomList: RoomTile[] = []
  let rentCeiling = 0

  for (const row of data ?? []) {
    const rows = (row.rooms ?? []) as {
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
    }[]
    const priced = rows.map((r) => Number(r.monthly_rent)).filter((n) => n > 0)
    const minRent = priced.length ? Math.min(...priced) : null

    const images = [...((row.accommodation_images ?? []) as { url: string; sort_order: number | null }[])]
      .sort((x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0))
    const amenities = ((row.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity)
    const address = row.address || [row.barangay, row.city].filter(Boolean).join(', ') || 'Address not given'
    const name = row.name?.trim() || 'Unnamed accommodation'
    const monogram = listingMonogram(name)

    propertyList.push({
      id: row.id,
      name,
      address,
      image: images[0]?.url ? resolveAsset(images[0].url) : '',
      monogram,
      distance: campusDistanceLabel(row.lat, row.lng),
      vacancies: rows.filter((r) => r.status === 'available').length,
      minRent,
      buildingType: buildingTypeLabel(row.accommodation_type),
      lat: typeof row.lat === 'number' ? row.lat : null,
      lng: typeof row.lng === 'number' ? row.lng : null,
      haystack: `${name} ${address}`.toLowerCase(),
    })

    for (const r of rows) {
      const roomImages = [...(r.room_images ?? [])].sort((x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0))
      const label = r.label || (r.room_number ? `Room ${r.room_number}` : 'Room')
      const roomType = r.custom_room_type || r.room_type || ''
      const typeLabel = roomTypeLabel(roomType)
      const rent = Number(r.monthly_rent ?? 0)
      if (rent > 0) rentCeiling = Math.max(rentCeiling, rent)
      roomList.push({
        id: r.id,
        label,
        image: roomImages[0]?.url ? resolveAsset(roomImages[0].url) : '',
        monogram,
        propertyName: name,
        meta: r.capacity ? `sleeps ${r.capacity}` : '',
        typeLabel,
        rent,
        rentBasis: r.rent_basis === 'person' && (r.capacity ?? 0) > 1 ? 'person' : 'room',
        free: r.status === 'available',
        roomType,
        amenities,
        // A room has no coordinates of its own — it's wherever its building is.
        lat: typeof row.lat === 'number' ? row.lat : null,
        lng: typeof row.lng === 'number' ? row.lng : null,
        haystack: `${name} ${address} ${label} ${typeLabel}`.toLowerCase(),
      })
    }
  }

  // Somewhere to move beats somewhere full, then cheapest first.
  propertyList.sort((a, b) => {
    if ((b.vacancies > 0 ? 1 : 0) !== (a.vacancies > 0 ? 1 : 0)) {
      return (b.vacancies > 0 ? 1 : 0) - (a.vacancies > 0 ? 1 : 0)
    }
    return (a.minRent ?? Number.MAX_SAFE_INTEGER) - (b.minRent ?? Number.MAX_SAFE_INTEGER)
  })
  roomList.sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

  properties.value = propertyList
  rooms.value = roomList
  rentBounds.max = Math.max(DEFAULT_MAX, Math.ceil(rentCeiling / 500) * 500)
  // A silent (realtime-triggered) refresh must not reset a filter the
  // student has actively narrowed — only the real first load defaults it.
  if (!silent) filters.maxRent = rentBounds.max
}

async function loadManagers() {
  // Anon (fully signed-out) sessions have no grant on `users` at all, so this
  // is expected to come back empty rather than throw for a signed-out demo
  // session — a real authenticated student can read it. Kept separate from
  // loadProperties() so that failure never blocks the rest of the page.
  try {
    const { data, error: loadError } = await supabase
      .from('users')
      .select('id,full_name,avatar_url,accommodations(id,name,status)')
      .eq('role', 'accommodation_manager')
    if (loadError) throw loadError

    managers.value = (data ?? [])
      .map((row) => {
        const accredited = ((row.accommodations ?? []) as { id: string; name: string; status: string }[]).filter(
          (a) => a.status === 'accredited',
        )
        const name = row.full_name?.trim() || 'Accommodation manager'
        return {
          id: row.id,
          name,
          initials: name
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map((w) => w[0]?.toUpperCase())
            .join(''),
          avatarUrl: row.avatar_url ? resolveAsset(row.avatar_url) : null,
          propertyCount: accredited.length,
          haystack: `${name} ${accredited.map((a) => a.name).join(' ')}`.toLowerCase(),
        }
      })
      // Managers actively hosting listings surface first.
      .sort((a, b) => b.propertyCount - a.propertyCount || a.name.localeCompare(b.name))
  } catch {
    managers.value = []
  }
}

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    await Promise.all([loadProperties(silent), loadManagers()])
    syncMarkers()
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

// Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so this
// only really runs once per session rather than on every visit. New/updated
// listings push here instead of the page re-asking on every return — same
// channel shape as stores/notifications.ts, just refetching instead of
// merging since this page has no per-row incremental-update need. Public
// data (accredited listings), so no per-user filter is needed.
let listingsChannel: RealtimeChannel | null = null

onMounted(async () => {
  await load()
  await nextTick()
  initMap()
  measureViewport()
  window.addEventListener('resize', measureViewport)
  if (typeof supabase.channel !== 'function') return
  listingsChannel = supabase
    .channel('discover-listings')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'accommodations' }, () => void load(true))
    .subscribe()
})

// This page is kept alive (see MainLayout's KEEP_ALIVE_PAGES) — switching
// tabs away from it doesn't unmount it, so the scroll lock from an expanded
// map has to be released here too, or it'd leak onto every other page.
onDeactivated(() => {
  document.documentElement.style.overflow = ''
})

onUnmounted(() => {
  document.documentElement.style.overflow = ''
  if (listingsChannel) void supabase.removeChannel(listingsChannel)
  window.removeEventListener('resize', measureViewport)
  for (const marker of markers) marker.remove()
  map?.remove()
  map = null
})
</script>

<style scoped>
.disc {
  background: var(--m-bg);
}

/* Map + expand button — sticky to the top of the page's scroll container
   (see MainLayout's .q-page-container), so the map stays put as the list
   scrolls under it instead of scrolling away itself. */
.map-region {
  position: sticky;
  top: 0;
  z-index: 5;
  min-height: 0;
  overflow: hidden;
  transition: height 260ms cubic-bezier(0.22, 0.61, 0.36, 1);
}
.map-el {
  width: 100%;
  height: 100%;
}
.map-expand-btn {
  position: absolute;
  right: 12px;
  bottom: 12px;
  z-index: 6;
  display: flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 14px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  white-space: nowrap;
  box-shadow: var(--m-shadow);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
:deep(.map-pin) {
  width: 30px;
  height: 30px;
  padding: 0;
  border: 2px solid #fff;
  border-radius: 50% 50% 50% 0;
  transform: rotate(-45deg);
  background: var(--m-primary-dark);
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.35);
}

/* Floating "list view" button — the expanded map covers everything below
   the header, so this is the way back: parked just under it, always in
   reach regardless of scroll position. */
.map-collapse-btn {
  position: fixed;
  left: 50%;
  z-index: 65;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px 8px 12px;
  transform: translateX(-50%);
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  white-space: nowrap;
  box-shadow: 0 3px 12px rgba(15, 23, 42, 0.35);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

/* Floating recommendations rail — full-map mode only, sitting just above
   the docked search/filter band. No card behind it: it's a bare positioning
   slot, and each item (property or room) carries its own card look, so nothing
   doubles up once an item is selected and swapped for the single info card. */
.map-float {
  position: fixed;
  right: 0;
  bottom: 122px;
  left: 0;
  z-index: 60;
}
.map-float-rail {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
}
.map-float-card {
  flex: 0 0 230px;
  scroll-snap-align: start;
  border-radius: var(--m-radius-lg, var(--m-radius));
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.18);
}
/* Higher specificity than PropertyCard's own scoped `.car` background rule
   (same class+attribute weight there), so this reliably wins regardless of
   which component's stylesheet the bundler happens to emit first. */
.map-float-rail .map-float-card {
  border-color: color-mix(in srgb, var(--m-border) 45%, transparent);
  background: color-mix(in srgb, var(--m-surface) 55%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
}
/* Room card mirrors PropertyCard's own carousel layout (image on top,
   name/where below) so it reads as the same family of card, not a smaller
   list row — and lands at the same height as the accommodation cards next
   to it in the rail. */
.map-float-room {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  cursor: pointer;
  font: inherit;
  padding: 0;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.map-float-room-shot {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 16 / 10;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.map-float-room-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.map-float-room-shot--empty {
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
  color: var(--m-muted);
}
.map-float-room-type {
  position: absolute;
  top: 8px;
  left: 8px;
  max-width: calc(100% - 16px);
  padding: 2px 9px;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
  font-size: 10.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.map-float-room-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 9px 11px 11px;
}
.map-float-room-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  line-height: 1.25;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.map-float-room-where {
  color: var(--m-muted);
  font-size: 11.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.map-float-room-rent {
  margin-top: 1px;
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 700;
}

/* Selected-item detail card — same image-on-top shape as the rail cards
   (so swapping the rail for this doesn't jump wildly in height), with the
   close button riding on the image itself instead of a separate header row. */
.map-float-info {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid color-mix(in srgb, var(--m-border) 45%, transparent);
  border-radius: var(--m-radius-lg, var(--m-radius));
  background: color-mix(in srgb, var(--m-surface) 55%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.18);
}
.map-float-info-shot {
  position: relative;
  display: grid;
  width: 100%;
  height: 144px;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.map-float-info-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.map-float-info-shot--empty {
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
  color: var(--m-muted);
}
.map-float-info-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 10px 12px 12px;
}
.map-float-info-text {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.map-float-info-text strong {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.map-float-info-text span {
  color: var(--m-muted);
  font-size: 11.5px;
}
.map-float-close {
  position: absolute;
  top: 8px;
  right: 8px;
  display: grid;
  width: 30px;
  height: 30px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.map-float-cta {
  width: 100%;
  min-height: 44px;
  font-weight: 700;
}

.stack {
  display: flex;
  flex-direction: column;
 
  /* Clears the docked search, which sits on the FAB's baseline. */
  padding: 8px var(--m-page-gutter) 126px;
}
.sk {
  border-radius: var(--m-radius);
}
.sk-car,
.sk-tile {
  display: flex;
  flex-direction: column;
  gap: 5px;
}
.sk-car-shot,
.sk-tile-shot {
  width: 100%;
  aspect-ratio: 16 / 10;
  border-radius: var(--m-radius-sm);
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

/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */
.dock {
  position: fixed;
  bottom: 68px;
  left: var(--m-page-gutter);
  right: var(--m-page-gutter);
  z-index: 60;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dock-field {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 8px;
  height: 44px;
  padding: 0 14px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
}
.dock-field:focus-within {
  border-color: var(--m-primary);
}
.dock-icon {
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input:focus {
  outline: none;
}
.dock-input::placeholder {
  color: var(--m-muted);
  opacity: 0.85;
}
.dock-btn {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 50%;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.dock-btn--on {
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.dock-dot {
  position: absolute;
  top: -2px;
  right: -2px;
  display: grid;
  min-width: 17px;
  height: 17px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}

/* Filter sheet */
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 14px;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.sheet-clear {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.sheet-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.sheet-block {
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.sheet-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  min-height: 36px;
  padding: 0 13px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.sheet-done {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}

/* Sections */
.sec {
  display: flex;
  flex-direction: column;

}
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
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
.sec-more {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
}

/* Property carousel */
.rail {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 2px;
}
.rail-item {
  flex: 0 0 62%;
  scroll-snap-align: start;
}

/* Managers */
.mgrs {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.mgr-row {
  display: flex;
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

/* Room grid — two per row */
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.tile {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  padding: 0;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.tile-shot {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 1 / 1;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.tile-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.tile-shot--empty {
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.shot-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
}
.shot-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }
.tile-flag {
  position: absolute;
  top: 7px;
  left: 7px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
}
.tile-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 8px 9px 10px;
}
.tile-name {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.25;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.tile-where {
  color: var(--m-muted);
  font-size: 11px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tile-meta {
  margin-top: 1px;
  color: var(--m-muted);
  font-size: 10.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tile-rent {
  margin-top: 2px;
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.tile-rent--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 11.5px;
  font-weight: 600;
}
.tile-per {
  font-size: 10.5px;
  font-weight: 600;
  opacity: 0.7;
}

.none {
  margin: 0;
  padding: 14px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
</style>
