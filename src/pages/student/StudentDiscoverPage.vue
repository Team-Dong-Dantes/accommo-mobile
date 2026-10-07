<template>
  <q-page class="disc">
    <!-- Desktop: search pinned at the top of the list half, not floating. -->
    <SearchDock
      v-if="isDesktop && !loading && !error"
      v-model="query"
      inline
      class="desk-search"
      :filter-count="activeFilterCount"
      placeholder="Search accommodations, rooms, landlords/landladies"
      search-label="Search accommodations, rooms, landlords/landladies"
      @open-filters="filtersOpen = true"
    />
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
      <ErrorCard title="Couldn't load listings" :detail="error" :retry="load" />
    </div>

    <template v-else>
      <!-- Desktop: the map is the card's right half (MainLayout's
           #desk-map-slot), beside the list rather than a strip above it. -->
      <Teleport v-if="!deskMap || active" to="#desk-map-slot" :disabled="!deskMap" defer>
      <div
        v-if="hasMapToken"
        class="map-region"
        :class="{ 'map-region--full': mapExpanded, 'map-region--desk': deskMap }"
        :style="mapRegionStyle"
      >
        <div ref="mapEl" class="map-el" aria-label="Map of accommodations" />
        <button v-if="!mapExpanded && !deskMap" type="button" class="map-expand-btn" @click="toggleMapExpanded(true)">
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

      <!-- Quick chips: the questions a student asks of a map, one tap each.
           They narrow the pins and cards only; the full filter sheet still
           drives the list. -->
      <div
        v-if="hasMapToken && (mapExpanded || deskMap)"
        class="map-chips"
        :class="{ 'map-chips--desk': deskMap }"
        :style="deskMap ? undefined : { top: (headerReservedPx + 60) + 'px' }"
      >
        <button
          v-for="chip in visibleChips"
          :key="chip.key"
          type="button"
          class="map-chip"
          :class="{ 'map-chip--on': mapChips[chip.key] }"
          :aria-pressed="mapChips[chip.key]"
          @click="mapChips[chip.key] = !mapChips[chip.key]"
        >
          <IconifyIcon :icon="chip.icon" width="13" />
          {{ chip.label }}
        </button>
      </div>

      <!-- One carousel, synced both ways with the pins: swiping a card flies
           the map to its pin, tapping a pin scrolls to its card. Desktop has
           the list beside it, so it shows only the picked place. -->
      <div
        v-if="hasMapToken && (mapExpanded || (deskMap && selected))"
        class="map-float"
        :class="{ 'map-float--desk': deskMap }"
      >
        <div ref="mapRailEl" class="map-rail" @scrollend="onRailSettled">
          <button
            v-for="item in railItems"
            :key="item.id"
            :data-id="item.id"
            type="button"
            class="map-card"
            :class="{ 'map-card--on': item.id === selectedId, 'map-card--dim': !fitsMe(item) }"
            @click="open(item.id)"
          >
            <span class="map-card-shot" :class="{ 'map-card-shot--empty': !item.image }">
              <img v-if="item.image" :src="item.image" :alt="item.name" loading="lazy" />
              <IconifyIcon v-else icon="lucide:image-off" width="20" />
            </span>
            <span class="map-card-body">
              <span class="map-card-name">{{ item.name }}</span>
              <span class="map-card-rent" :class="{ 'map-card-rent--full': !item.vacancies }">
                <template v-if="!item.vacancies">Full right now</template>
                <template v-else-if="item.minVacantRent">from {{ formatPeso(item.minVacantRent) }}<span class="map-card-per">/mo</span></template>
                <template v-else>Rent on request</template>
              </span>
              <span v-if="walkText(item)" class="map-card-line">
                <IconifyIcon icon="lucide:footprints" width="12" />
                {{ walkText(item) }}
              </span>
              <span class="map-card-tags">
                <span v-if="item.vacancies" class="map-card-tag map-card-tag--ok">{{ item.vacancies }} free</span>
                <span v-if="item.genderPolicy" class="map-card-tag">{{ item.genderPolicy }}</span>
                <span v-if="item.buildingType" class="map-card-tag">{{ item.buildingType }}</span>
              </span>
            </span>
          </button>
          <p v-if="!railItems.length" class="map-rail-none">No places match these chips.</p>
        </div>
      </div>
      </Teleport>

    <div class="stack" :class="{ 'stack--desk': isDesktop }">
      <section v-if="filteredProperties.length" class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Accommodations</h2>
          <div class="sec-actions">
            <!-- A mouse has no swipe, so desktop gets arrows for the rail. -->
            <template v-if="isDesktop">
              <button type="button" class="rail-arrow" aria-label="Previous accommodations" @click="slideRail(-1)">
                <IconifyIcon icon="lucide:chevron-left" width="16" />
              </button>
              <button type="button" class="rail-arrow" aria-label="Next accommodations" @click="slideRail(1)">
                <IconifyIcon icon="lucide:chevron-right" width="16" />
              </button>
            </template>
            <button type="button" class="sec-more" @click="router.push('/student/properties')">
              View all
            </button>
          </div>
        </div>
        <div ref="railEl" class="rail" :class="{ 'rail--desk': isDesktop }">
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
            :gender-policy="item.genderPolicy"
            @open="open"
          />
        </div>
      </section>

      <!-- Managers only surface once a search narrows to them -->
      <section v-if="query.trim() && filteredManagers.length" class="sec">
        <h2 class="sec-title">Landlords/Landladies</h2>
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
              <span class="tile-flag">{{ room.label }}</span>
            </span>
            <span class="tile-body">
              <span class="tile-name-row">
                <span class="tile-name">{{ room.typeLabel }}</span>
                <span v-if="room.meta" class="tile-name-meta">{{ room.meta }}</span>
              </span>
              <span class="tile-where">{{ room.propertyName }}</span>
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
    <SearchDock
      v-if="!loading && !error && !isDesktop"
      v-model="query"
      :filter-count="activeFilterCount"
      placeholder="Search accommodations, rooms, landlords/landladies"
      search-label="Search accommodations, rooms, landlords/landladies"
      above-nav
      @open-filters="filtersOpen = true"
    />

    <!-- Filters — apply to the room grid, the page's main content -->
    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      :done-label="`Show ${filteredRooms.length} ${filteredRooms.length === 1 ? 'room' : 'rooms'}`"
      @clear="resetFilters"
    >
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
        <div class="m-chips">
          <button
            v-for="type in roomTypeOptions"
            :key="type"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': filters.roomTypes.includes(type) }"
            @click="toggle(filters.roomTypes, type)"
          >
            {{ roomTypeLabel(type) }}
          </button>
        </div>
      </div>

      <div class="sheet-block">
        <span class="sheet-label">Must have</span>
        <div class="m-chips">
          <button
            v-for="f in SEARCH_FEATURES"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': filters.amenities.includes(f.key) }"
            @click="toggle(filters.amenities, f.key)"
          >
            <IconifyIcon :icon="f.icon" width="13" />
            {{ f.label }}
          </button>
        </div>
      </div>
    </BottomSheet>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted, onUnmounted, onActivated, onDeactivated } from 'vue'
import { useRouter } from 'vue-router'
import { Dark } from 'quasar'
import { Icon as IconifyIcon } from '@iconify/vue'
import mapboxgl from '@/utils/mapbox'
import { supabase } from '@/utils/supabase'
import { isDesktop } from '@/utils/useTabletMode'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { formatPeso, landlordTitle } from '@/utils/format'
import { resolveAsset, AVATAR, CARD } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, kmBetween, geolocationErrorMessage, CAMPUS } from '@/utils/geo'
import { SEARCH_FEATURES, isUtilityAvailable, roomTypeLabel, buildingTypeLabel, genderPolicyLabel, listingMonogram } from '@/utils/listings'
import { useNotify } from '@/utils/notify'
import { pinLabel, takesSex, passesChips, walkMinutesGuess, pricePinElement, campusBadgeElement, UNDER_RENT, type MapChips } from '@/utils/mapPins'
import PropertyCard from '@/components/student/PropertyCard.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'

interface Property {
  id: string
  name: string
  address: string
  image: string
  monogram: string
  distance: string
  vacancies: number
  minRent: number | null
  minVacantRent: number | null
  buildingType: string
  buildingKind: string | null
  genderPolicy: string
  genderKind: string | null
  lat: number | null
  lng: number | null
  haystack: string
}

interface RoomTile {
  id: string
  propertyId: string
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
const notify = useNotify()

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
const deskMap = computed(() => hasMapToken && isDesktop.value)
const MAP_PREVIEW_VH = 32
const mapEl = ref<HTMLElement | null>(null)
const mapExpanded = ref(false)

// The floating header reserves this much space via padding-top on
// .q-page-container rather than pushing it down in normal flow (it's
// `position: fixed`). Reused to pull the map's own top edge up by the same
// amount, so it runs behind the header instead of starting below it.
const headerReservedPx = ref(0)

function measureViewport() {
  const container = document.querySelector('.q-page-container') as HTMLElement | null
  if (!container) return
  headerReservedPx.value = parseFloat(getComputedStyle(container).paddingTop) || 0
}

/** The height applied to the map. The negative margin above puts the map's
 * top edge at the top of the window, so expanded is simply the window's own
 * height — `dvh` rather than `vh` so a mobile browser showing/hiding its URL
 * bar doesn't leave the map overhanging the screen. This used to be measured
 * off `.q-page-container`'s rendered box, but that box is as tall as the
 * page's whole content (map + every listing below it), so the expanded map
 * came out around twice the height of the screen: the map rendered for a
 * viewport far taller than the visible one, which is why it looked stretched
 * and why pins sat off-screen and slid around when zooming. */
const mapFillHeight = computed(() =>
  deskMap.value ? '100%' : mapExpanded.value ? '100dvh' : `${MAP_PREVIEW_VH}vh`,
)

// In preview it's a plain in-flow block that scrolls away with the rest of the
// page, pulled up by the header's reserved padding so it fills that space
// (running behind the floating header) instead of leaving a blank gap above
// it. Expanded, `.map-region--full` lifts it out of flow entirely — see there
// for why. The negative margin has to go with it, or the fixed box would sit
// that far above the viewport.
// On desktop the page is the list half of a card, below the header rather than
// behind it, so the map starts at the card's top edge like everything else.
const mapUnderHeaderPx = computed(() => (isDesktop.value ? 0 : headerReservedPx.value))

const mapRegionStyle = computed(() => ({
  height: mapFillHeight.value,
  marginTop: mapExpanded.value ? '0px' : `-${mapUnderHeaderPx.value}px`,
  // The map runs up behind the floating header, so mapbox's own controls
  // land underneath it and can't be tapped at all. Push them clear by the
  // same amount the header reserves.
  '--map-ctrl-top': `${mapUnderHeaderPx.value + 8}px`,
}))

// The place picked on the map, by pin or by swiping to its card.
const selectedId = ref<string | null>(null)
const selected = computed(() => properties.value.find((p) => p.id === selectedId.value) ?? null)
/** Real walking minutes from Directions, per place, once a route is fetched. */
const routeMinutes = reactive<Record<string, number>>({})

// users.sex (M | F | U) of the signed-in student, so places that don't take
// them fade on the map. Null signed-out, which fades nothing.
const mySex = ref<string | null>(null)
async function loadMySex() {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return
  const { data } = await supabase.from('users').select('sex').eq('id', session.user.id).maybeSingle()
  mySex.value = data?.sex ?? null
}
function fitsMe(p: Property) {
  return takesSex(p.genderKind, mySex.value)
}

const mapChips = reactive<MapChips>({ vacant: false, fitsMe: false, under3k: false, dorm: false, boarding: false })
const CHIPS: { key: keyof MapChips; label: string; icon: string }[] = [
  { key: 'vacant', label: 'Has vacancy', icon: 'lucide:door-open' },
  { key: 'fitsMe', label: 'Fits me', icon: 'lucide:user-check' },
  { key: 'under3k', label: `Under ${formatPeso(UNDER_RENT)}`, icon: 'lucide:wallet' },
  { key: 'dorm', label: 'Dorm', icon: 'lucide:school' },
  { key: 'boarding', label: 'Boarding house', icon: 'lucide:house' },
]
// "Fits me" means nothing without a known sex.
const visibleChips = computed(() => CHIPS.filter((c) => c.key !== 'fitsMe' || mySex.value === 'M' || mySex.value === 'F'))

function walkText(p: Property) {
  const min = routeMinutes[p.id] ?? walkMinutesGuess(p.lat, p.lng)
  return min === null ? '' : `${routeMinutes[p.id] ? '' : '~'}${min} min walk to campus`
}

let map: mapboxgl.Map | null = null
let markers: mapboxgl.Marker[] = []
const pinEls = new Map<string, HTMLElement>()
let mapResizeObserver: ResizeObserver | null = null
let campusLinkLabel: mapboxgl.Marker | null = null

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

/** What the map shows — the pins and the full-map rail both read this, so
 * searching and filtering reach the map, not just the list below it. A place
 * survives an active filter when it still has at least one room that passes,
 * reusing filteredRooms rather than restating the rules, so the map can't
 * drift away from the room grid. Filters only bite once one is actually
 * set (activeFilterCount treats the default "vacant only" as unset), which
 * keeps the untouched default view showing everything, full places included. */
const mapProperties = computed(() => {
  const matching = filterByHaystack(properties.value).filter((p) => passesChips(p, mapChips, mySex.value))
  if (activeFilterCount.value === 0) return matching
  const withMatchingRooms = new Set(filteredRooms.value.map((r) => r.propertyId))
  return matching.filter((p) => withMatchingRooms.has(p.id))
})

/** The map's cards: every place on the map, or on desktop (list beside it)
 * just the picked one. */
const railItems = computed(() => (deskMap.value ? (selected.value ? [selected.value] : []) : mapProperties.value))

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

const railEl = ref<HTMLElement | null>(null)
function slideRail(dir: 1 | -1) {
  railEl.value?.scrollBy({ left: dir * railEl.value.clientWidth * 0.9, behavior: 'smooth' })
}

function openRoom(id: string) {
  void router.push(`/student/room/${id}`)
}

function openManager(id: string) {
  void router.push(`/student/manager/${id}`)
}

function toggleMapExpanded(expanded: boolean) {
  // The expanded height fills the whole window on the assumption the map
  // sits at the very top of the scroll container. It's no longer sticky, so
  // if the page was scrolled down at all when "Map view" is tapped, that
  // assumption breaks and the tall box overshoots past the bottom of the
  // screen — snap back to the top first so it always holds.
  if (expanded) document.querySelector('.q-page-container')?.scrollTo({ top: 0 })
  mapExpanded.value = expanded
}

function initMap() {
  if (!mapEl.value || map || !hasMapToken) return
  mapboxgl.accessToken = MAPBOX_TOKEN!
  map = new mapboxgl.Map({
    container: mapEl.value,
    style: mapStyle(),
    center: [CAMPUS.lng, CAMPUS.lat],
    zoom: 13,
  })
  map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right')

  // "Where am I?" — Mapbox's own control, so the user dot, accuracy ring and
  // permission prompt come for free. One-shot rather than trackUserLocation,
  // which would keep re-centring on the student and fight the framing below.
  const locate = new mapboxgl.GeolocateControl({
    positionOptions: { enableHighAccuracy: true, timeout: 20000 },
    trackUserLocation: false,
    showUserLocation: true,
  })
  map.addControl(locate, 'top-right')
  // Centring on the student alone would push the listings off screen, and the
  // point is seeing yourself *and* the places at once.
  locate.on('geolocate', (position) => {
    const p = position as GeolocationPosition
    frameAround([p.coords.longitude, p.coords.latitude])
  })
  locate.on('error', (err) => {
    notify.error(geolocationErrorMessage(err as GeolocationPositionError))
  })

  // style.load, not load: a theme switch swaps the style, which drops the
  // route layer, and this puts it back (with the route, if one is showing).
  map.on('style.load', () => {
    addCampusLinkLayer()
    if (selected.value) void showCampusLink(selected.value)
  })
  map.on('load', () => syncMarkers(!mapExpanded.value))
  // Mapbox has no built-in tracking of its own container's size (only a
  // window-resize listener) — its canvas keeps whatever pixel size it was
  // last told, so if that ever drifts from the container's real rendered
  // size (a CSS transition settling a frame later than expected, a
  // heuristic timer firing early, ...) the map renders visibly stretched.
  // A ResizeObserver reports the container's actual settled size on every
  // change, so resizing from it can't go stale the way a one-shot guess can.
  mapResizeObserver = new ResizeObserver(() => map?.resize())
  mapResizeObserver.observe(mapEl.value)
  addCampusMarker()
}

/** A muted base map, so the price pins are what stands out; dark in dark mode. */
function mapStyle() {
  return Dark.isActive ? 'mapbox://styles/mapbox/dark-v11' : 'mapbox://styles/mapbox/light-v11'
}
watch(() => Dark.isActive, () => map?.setStyle(mapStyle()))

/** Every distance on this page reads "N m from campus", so the campus itself
 * has to be on the map for that to mean anything. A badge rather than a pin,
 * so it never reads as a listing. Added once (it never moves) and kept out of
 * `markers`, which syncMarkers() clears on every refresh. */
function addCampusMarker() {
  if (!map) return
  new mapboxgl.Marker({ element: campusBadgeElement(CAMPUS.label) }).setLngLat([CAMPUS.lng, CAMPUS.lat]).addTo(map)
}

const CAMPUS_LINK = 'campus-link'

/** Empty line source + layer, created once the style is ready; selecting a
 * place just swaps the source's data rather than adding/removing layers. */
function addCampusLinkLayer() {
  if (!map || map.getSource(CAMPUS_LINK)) return
  map.addSource(CAMPUS_LINK, {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  })
  map.addLayer({
    id: CAMPUS_LINK,
    type: 'line',
    source: CAMPUS_LINK,
    layout: { 'line-cap': 'round' },
    paint: {
      'line-color': getComputedStyle(document.documentElement).getPropertyValue('--m-primary-dark').trim() || '#0f766e',
      'line-width': 3,
      // Dashed, so it reads as "distance to campus" rather than as a road.
      'line-dasharray': [1.6, 1.4],
    },
  })
}

type Coord = [number, number]

/** Bumped on every selection so a slow response for a place you've already
 * navigated away from can't overwrite the current route. */
let campusLinkRequest = 0

/** The walking route along actual roads, from Mapbox Directions. */
async function fetchWalkingRoute(from: Coord, to: Coord) {
  const url =
    `https://api.mapbox.com/directions/v5/mapbox/walking/` +
    `${from[0]},${from[1]};${to[0]},${to[1]}` +
    `?geometries=geojson&overview=full&access_token=${MAPBOX_TOKEN}`
  try {
    const res = await fetch(url)
    if (!res.ok) return null
    const route = (await res.json())?.routes?.[0]
    const coordinates = route?.geometry?.coordinates
    if (!Array.isArray(coordinates) || coordinates.length < 2) return null
    return { coordinates: coordinates as Coord[], distance: Number(route.distance), duration: Number(route.duration) }
  } catch {
    return null
  }
}

/** The point half way *along* the route, so the label sits mid-walk. Using
 * the middle array index instead would drag it toward whichever end has the
 * most turns, since that's where the vertices bunch up. */
function midpointAlong(coords: Coord[]): Coord {
  const legs = coords.slice(1).map((c, i) => kmBetween(coords[i]![1], coords[i]![0], c[1], c[0]))
  const half = legs.reduce((a, b) => a + b, 0) / 2
  let walked = 0
  for (let i = 0; i < legs.length; i++) {
    walked += legs[i]!
    if (walked >= half) return coords[i + 1]!
  }
  return coords[coords.length - 1]!
}

function walkLabel(metres: number, seconds: number) {
  const dist = metres < 1000 ? `${Math.round(metres)} m` : `${(metres / 1000).toFixed(1)} km`
  return `${dist} · ${Math.max(1, Math.round(seconds / 60))} min walk`
}

function setCampusLink(coordinates: Coord[], labelAt: Coord, text: string) {
  const source = map?.getSource(CAMPUS_LINK) as mapboxgl.GeoJSONSource | undefined
  if (!map || !source) return
  source.setData({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates } })
  const el = document.createElement('div')
  el.className = 'campus-link-label'
  el.textContent = text
  campusLinkLabel?.remove()
  campusLinkLabel = new mapboxgl.Marker({ element: el }).setLngLat(labelAt).addTo(map)
}

/** Traces the walk from the selected place to campus along the roads, with
 * the walking distance and time at the halfway point. Falls back to a plain
 * straight line (and the page's usual as-the-crow-flies distance) if
 * Directions can't be reached, so the link never just silently vanishes. */
async function showCampusLink(pin: Property) {
  if (!map || pin.lat === null || pin.lng === null) return clearCampusLink()
  const from: Coord = [pin.lng, pin.lat]
  const to: Coord = [CAMPUS.lng, CAMPUS.lat]

  const token = ++campusLinkRequest
  const route = await fetchWalkingRoute(from, to)
  if (route) routeMinutes[pin.id] = Math.max(1, Math.round(route.duration / 60))
  if (token !== campusLinkRequest || !selectedId.value) return

  if (route) {
    setCampusLink(route.coordinates, midpointAlong(route.coordinates), walkLabel(route.distance, route.duration))
  } else {
    const straight: Coord[] = [from, to]
    setCampusLink(straight, [(from[0] + to[0]) / 2, (from[1] + to[1]) / 2], pin.distance || campusDistanceLabel(pin.lat, pin.lng))
  }
}

function clearCampusLink() {
  // Invalidates any in-flight route so a late response can't draw itself
  // back on after the card has been closed.
  campusLinkRequest++
  const source = map?.getSource(CAMPUS_LINK) as mapboxgl.GeoJSONSource | undefined
  source?.setData({ type: 'FeatureCollection', features: [] })
  campusLinkLabel?.remove()
  campusLinkLabel = null
}

/** Frames the student's own position together with the listings and campus,
 * so "where am I" and "where are the places" are answered in one view. */
function frameAround(me: [number, number]) {
  if (!map) return
  const bounds = new mapboxgl.LngLatBounds().extend(me).extend([CAMPUS.lng, CAMPUS.lat])
  for (const p of mapProperties.value) {
    if (p.lat !== null && p.lng !== null) bounds.extend([p.lng, p.lat])
  }
  map.fitBounds(bounds, {
    padding: { top: 110, right: 80, bottom: mapExpanded.value ? 300 : 60, left: 80 },
    maxZoom: 16,
  })
}

/** Re-places one pin per accommodation that has coordinates; called after
 * every load (including silent realtime refreshes) once the map exists.
 * `reframe` defaults to off in full-map mode so a background refresh can't
 * yank the camera out from under someone browsing — but a search or filter
 * change passes it explicitly, since that's the user asking to be shown
 * something and leaving the matches off-screen just looks broken. */
function syncMarkers(reframe = !mapExpanded.value && !deskMap.value) {
  if (!map) return
  for (const marker of markers) marker.remove()
  markers = []
  pinEls.clear()

  const located = mapProperties.value.filter(
    (p): p is Property & { lat: number; lng: number } => p.lat !== null && p.lng !== null,
  )
  for (const property of located) {
    const { anchor, pin: el } = pricePinElement(property.name, pinLabel(property), { full: !property.vacancies, dim: !fitsMe(property) })
    if (property.id === selectedId.value) el.classList.add('price-pin--on')
    // Full map: tapping a pin selects it and scrolls its card into view
    // instead of leaving the map. The preview strip still jumps straight to it.
    el.addEventListener('click', (e) => {
      e.stopPropagation()
      if (mapExpanded.value || deskMap.value) selectPin(property, true)
      else open(property.id)
    })
    markers.push(new mapboxgl.Marker({ element: anchor, anchor: 'bottom', offset: [0, -5] }).setLngLat([property.lng, property.lat]).addTo(map))
    pinEls.set(property.id, el)
  }

  // The default view keeps campus dead centre — it's the reference point
  // every distance on this page is measured from. Mirroring each listing
  // across campus makes the bounding box symmetric about it, so fitting that
  // box centres campus and still frames every pin.
  if (located.length && reframe) {
    const bounds = new mapboxgl.LngLatBounds()
    for (const p of located) {
      bounds.extend([p.lng, p.lat])
      bounds.extend([2 * CAMPUS.lng - p.lng, 2 * CAMPUS.lat - p.lat])
    }
    map.fitBounds(bounds, { padding: 60, maxZoom: 15, duration: 0 })
  }
}

/** Picks a place: highlights its pin, draws its walk to campus and frames
 * both. `scrollCard` brings its card into view — wanted when the pin was
 * tapped, not when the card was swiped to (it's already there). */
function selectPin(property: Property, scrollCard = false) {
  pinEls.get(selectedId.value ?? '')?.classList.remove('price-pin--on')
  selectedId.value = property.id
  pinEls.get(property.id)?.classList.add('price-pin--on')
  if (scrollCard) {
    mapRailEl.value
      ?.querySelector<HTMLElement>(`[data-id="${property.id}"]`)
      ?.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' })
  }
  // Not every accommodation has a pinned location — the card still works
  // without one, it just can't draw a line or move the camera.
  if (map && property.lat !== null && property.lng !== null) {
    void showCampusLink(property)
    // Frame both ends rather than zooming into the place alone — the whole
    // point of the line is seeing how far it sits from campus, which you
    // can't judge with campus off-screen.
    const bounds = new mapboxgl.LngLatBounds()
      .extend([property.lng, property.lat])
      .extend([CAMPUS.lng, CAMPUS.lat])
    // Generous side padding: the campus pill is ~110px wide and centred on
    // its coordinate, so a tighter inset leaves it hugging the screen edge.
    map.fitBounds(bounds, { padding: { top: 120, right: 90, bottom: 300, left: 90 }, maxZoom: 16 })
  } else {
    clearCampusLink()
  }
}

const mapRailEl = ref<HTMLElement | null>(null)

/** A swipe came to rest: the card nearest the rail's centre is the pick. A
 * pin tap's own smooth scroll lands here too, on the card already picked,
 * so that one is skipped rather than re-framed. */
function onRailSettled() {
  const rail = mapRailEl.value
  if (!rail || deskMap.value) return
  const mid = rail.getBoundingClientRect().left + rail.clientWidth / 2
  let best: HTMLElement | null = null
  let bestGap = Infinity
  for (const card of rail.querySelectorAll<HTMLElement>('[data-id]')) {
    const r = card.getBoundingClientRect()
    const gap = Math.abs(r.left + r.width / 2 - mid)
    if (gap < bestGap) [best, bestGap] = [card, gap]
  }
  const id = best?.dataset.id
  if (!id || id === selectedId.value) return
  const property = properties.value.find((p) => p.id === id)
  if (property) selectPin(property)
}

function clearSelectedPin() {
  pinEls.get(selectedId.value ?? '')?.classList.remove('price-pin--on')
  selectedId.value = null
  clearCampusLink()
}

// Leaving the expanded map shouldn't leave a stale selection waiting behind
// the rail next time it's re-opened.
watch(mapExpanded, (expanded) => {
  if (!expanded) clearSelectedPin()
})

// A chip or search that hides the picked place drops the pick with it.
watch(mapProperties, (list) => {
  if (selectedId.value && !list.some((p) => p.id === selectedId.value)) clearSelectedPin()
})

// The map used to read the raw property list, so searching and filtering only
// ever changed the list below it. Re-pinning on every change to the matched
// set is what actually makes them work in map mode.
watch(mapProperties, () => syncMarkers(true))
// Knowing the student's sex (it loads after the pins) changes which pins fade.
watch(mySex, () => syncMarkers(false))

async function loadProperties(silent = false) {
  // Only accredited listings are readable, and the policy grants the public
  // role, so this works signed-out too — keep this select clear of the
  // `users` table, which anon cannot read at all.
  const { data, error: loadError } = await supabase
    .from('accommodations')
    .select(
      'id,name,address,city,barangay,purok,lat,lng,accommodation_type,gender_policy,rooms(id,label,room_number,room_type,custom_room_type,capacity,monthly_rent,rent_basis,status,wifi_billing,room_images(url,sort_order)),accommodation_amenities(amenity),accommodation_facilities(facility_type),accommodation_images(url,sort_order)',
    )
    .eq('status', 'accredited').eq('hidden_from_listings', false)
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
      wifi_billing: string | null
      room_images: { url: string; sort_order: number | null }[] | null
    }[]
    const priced = rows.map((r) => Number(r.monthly_rent)).filter((n) => n > 0)
    const minRent = priced.length ? Math.min(...priced) : null
    const vacantPriced = rows.filter((r) => r.status === 'available').map((r) => Number(r.monthly_rent)).filter((n) => n > 0)
    const minVacantRent = vacantPriced.length ? Math.min(...vacantPriced) : null

    const images = [...((row.accommodation_images ?? []) as { url: string; sort_order: number | null }[])]
      .sort((x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0))
    // Amenities plus facility types, so one filter covers both (see SEARCH_FEATURES).
    const amenities = [
      ...((row.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity),
      ...((row.accommodation_facilities ?? []) as { facility_type: string }[]).map((f) => f.facility_type),
      // Wi-Fi is per room; the listing offers it when any room has it.
      ...(rows.some((r) => isUtilityAvailable({ billing: r.wifi_billing, flatFee: null })) ? ['wifi'] : []),
    ]
    const address = row.address || [row.purok, row.barangay, row.city].filter(Boolean).join(', ') || 'Address not given'
    const name = row.name?.trim() || 'Unnamed accommodation'
    const monogram = listingMonogram(name)

    propertyList.push({
      id: row.id,
      name,
      address,
      image: images[0]?.url ? resolveAsset(images[0].url, CARD) : '',
      monogram,
      distance: campusDistanceLabel(row.lat, row.lng),
      vacancies: rows.filter((r) => r.status === 'available').length,
      minRent,
      minVacantRent,
      buildingType: buildingTypeLabel(row.accommodation_type),
      buildingKind: row.accommodation_type ?? null,
      genderPolicy: genderPolicyLabel(row.gender_policy),
      genderKind: row.gender_policy ?? null,
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
        propertyId: row.id,
        label,
        image: roomImages[0]?.url ? resolveAsset(roomImages[0].url, CARD) : '',
        monogram,
        propertyName: name,
        meta: r.capacity ? `${r.capacity} left` : '',
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
      // The FK must be named: `accommodations` points at `users` twice (the
      // landlord/landlady who owns it, and the admin reviewing it), and PostgREST refuses
      // an ambiguous embed outright — so this query threw on every load and the
      // Landlords/Landladies tab was permanently empty.
      .select(
        'id,full_name,avatar_url,sex,accommodations!accommodations_landlord_id_fkey(id,name,status)',
      )
      .eq('role', 'landlord')
    if (loadError) throw loadError

    managers.value = (data ?? [])
      .map((row) => {
        const accredited = ((row.accommodations ?? []) as { id: string; name: string; status: string }[]).filter(
          (a) => a.status === 'accredited',
        )
        const name = row.full_name?.trim() || landlordTitle(row.sex)
        return {
          id: row.id,
          name,
          initials: name
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map((w) => w[0]?.toUpperCase())
            .join(''),
          avatarUrl: row.avatar_url ? resolveAsset(row.avatar_url, AVATAR) : null,
          propertyCount: accredited.length,
          haystack: `${name} ${accredited.map((a) => a.name).join(' ')}`.toLowerCase(),
        }
      })
      // Landlords and landladies actively hosting listings surface first.
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

// Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so new
// and updated listings push here instead of the page re-asking on every
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return. Public
// data (accredited listings), so no per-user filter is needed.
type DiscoverCache = { properties: Property[]; rooms: RoomTile[]; managers: ManagerRow[] }

useLiveData({
  key: 'student-discover',
  load,
  watch: () => [{ table: 'accommodations' }],
  cache: {
    get: (): DiscoverCache => ({ properties: properties.value, rooms: rooms.value, managers: managers.value }),
    set: (d) => {
      const c = d as DiscoverCache
      properties.value = c.properties
      rooms.value = c.rooms
      managers.value = c.managers
      loading.value = false
    },
  },
})

// The map container sits in the `v-else` branch, so it does not exist in the
// DOM until the first load clears `loading` — mounting is too early to reach
// it, and initMap() bails on a null ref without ever retrying. Waiting on the
// template ref itself instead runs it the moment the element is really there,
// whichever order the load and the render happen to finish in.
watch(mapEl, (el) => {
  if (el) initMap()
}, { flush: 'post' })

onMounted(() => {
  void loadMySex()
  measureViewport()
  window.addEventListener('resize', measureViewport)
})

// Desktop keeps this page alive in the shell's list pane, and KeepAlive
// restores a live Teleport into the page instead of its target (Vue 3.5
// moveTeleport). So while inactive the map is dropped, and rebuilt in the
// fresh #desk-map-slot on the way back.
const active = ref(true)
onActivated(() => (active.value = true))
onDeactivated(() => {
  if (!deskMap.value) return
  active.value = false
  destroyMap()
})

onUnmounted(() => {
  window.removeEventListener('resize', measureViewport)
  destroyMap()
})

function destroyMap() {
  mapResizeObserver?.disconnect()
  mapResizeObserver = null
  campusLinkLabel?.remove()
  campusLinkLabel = null
  for (const marker of markers) marker.remove()
  markers = []
  map?.remove()
  map = null
  pinEls.clear()
  selectedId.value = null
}
</script>

<style scoped>
.disc {
  background: var(--m-bg);
}

/* Map + expand button — plain in-flow block, part of the page's normal
   scroll like any other section. */
.map-region {
  position: relative;
  z-index: 5;
  min-height: 0;
  overflow: hidden;
  transition: height 260ms cubic-bezier(0.22, 0.61, 0.36, 1);
}
/* Expanded, the map is a real overlay rather than a very tall in-flow box.
   As an in-flow box the page simply carried on scrolling underneath it and
   you reached the listings while the map was meant to be full-screen; locking
   `documentElement`'s overflow was an attempt to hold that back and did not
   survive contact with a touch screen. Out of flow there is nothing left to
   scroll: the box covers the viewport and mapbox owns every gesture on it.
   Sits under the bottom nav (z-index 50 in MainLayout) and under the collapse
   button, floating rail and search dock, which are already fixed above it. */
.map-region--full {
  position: fixed;
  top: 0;
  right: 0;
  left: 0;
  z-index: 40;
}
/* Desktop: fills the right half it is teleported into. */
.map-region--desk {
  height: 100%;
}
.map-el {
  width: 100%;
  height: 100%;
}
/* Zoom + locate buttons, cleared of the floating header that was covering
   them (they were unreachable before). */
:deep(.mapboxgl-ctrl-top-right) {
  top: var(--map-ctrl-top, 0);
}

/* Accommodation pins: a price pill with a tail. Grey "Full" and faded
   (doesn't take you) pins stay tappable but sink below the rest; the picked
   one fills with the brand colour and rises above everything. */
:deep(.price-pin) {
  position: relative;
  padding: 4px 9px;
  border: 1.5px solid var(--m-surface);
  border-radius: 999px;
  background: var(--m-primary-dark);
  color: #fff;
  font: inherit;
  font-size: 11.5px;
  font-weight: 800;
  line-height: 1.2;
  white-space: nowrap;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.3);
  cursor: pointer;
  transition: transform 0.15s ease, background-color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
:deep(.price-pin)::after {
  position: absolute;
  bottom: -5px;
  left: 50%;
  width: 8px;
  height: 8px;
  border-right: 1.5px solid var(--m-surface);
  border-bottom: 1.5px solid var(--m-surface);
  background: inherit;
  content: '';
  transform: translateX(-50%) rotate(45deg);
}
:deep(.price-pin--full) {
  background: var(--m-muted);
}
:deep(.price-pin--dim) {
  opacity: 0.45;
}
/* Mapbox stacks markers in DOM order; lift the picked one, sink full and
   faded ones. On the marker wrapper, which Mapbox gives no z-index of its own. */
:deep(.mapboxgl-marker:has(.price-pin)) {
  z-index: 1;
}
:deep(.mapboxgl-marker:has(.price-pin--full)),
:deep(.mapboxgl-marker:has(.price-pin--dim)) {
  z-index: 0;
}
:deep(.mapboxgl-marker:has(.price-pin--on)) {
  z-index: 2;
}
:deep(.price-pin--on) {
  background: var(--m-primary);
  opacity: 1;
  transform: scale(1.18);
  transform-origin: bottom center;
}

/* Campus landmark — a badge, not a control: never swallow a tap meant for
   the map or a nearby pin. */
:deep(.campus-badge) {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 3px 9px 3px 3px;
  border: 1.5px solid var(--m-primary-dark);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 800;
  white-space: nowrap;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.25);
  pointer-events: none;
}
:deep(.campus-badge-icon) {
  display: grid;
  width: 20px;
  height: 20px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-dark);
  color: #fff;
}
/* Distance parked at the middle of the campus link line. */
:deep(.campus-link-label) {
  padding: 3px 9px;
  border: 1px solid color-mix(in srgb, var(--m-border) 60%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 92%, transparent);
  -webkit-backdrop-filter: blur(10px) saturate(160%);
  backdrop-filter: blur(10px) saturate(160%);
  color: var(--m-primary-dark);
  font-size: 10.5px;
  font-weight: 800;
  white-space: nowrap;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.22);
  pointer-events: none;
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
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
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
  bottom: 136px;
  left: 0;
  z-index: 60;
  padding: 0 var(--m-page-gutter);
}
/* Desktop: the picked pin's card sits inside the map half, not the window. */
.map-float--desk {
  position: absolute;
  right: 14px;
  bottom: 14px;
  left: 14px;
  z-index: 6;
  padding: 0;
}
/* Quick chips — glass, like the rest of the map chrome. */
.map-chips {
  position: fixed;
  right: 0;
  left: 0;
  z-index: 60;
  display: flex;
  gap: 6px;
  padding: 0 var(--m-page-gutter);
  overflow-x: auto;
  scrollbar-width: none;
}
.map-chips::-webkit-scrollbar {
  display: none;
}
.map-chips--desk {
  position: absolute;
  top: 14px;
  padding: 0 14px;
  z-index: 6;
}
.map-chip {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 5px;
  height: 32px;
  padding: 0 12px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 78%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.15);
  -webkit-tap-highlight-color: transparent;
}
.map-chip--on {
  border-color: var(--m-primary-dark);
  background: var(--m-primary-dark);
  color: #fff;
}

/* The synced carousel: one card centred at a time, its neighbours peeking. */
.map-rail {
  display: flex;
  gap: 10px;
  padding: 4px calc(50% - 150px);
  margin: 0 calc(var(--m-page-gutter) * -1);
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
  -webkit-overflow-scrolling: touch;
}
.map-rail::-webkit-scrollbar {
  display: none;
}
.map-float--desk .map-rail {
  padding: 0;
  margin: 0;
}
.map-card {
  display: flex;
  flex: 0 0 300px;
  gap: 10px;
  padding: 8px;
  scroll-snap-align: center;
  border: 1.5px solid color-mix(in srgb, var(--m-border) 45%, transparent);
  border-radius: var(--m-radius-lg, var(--m-radius));
  background: color-mix(in srgb, var(--m-surface) 88%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.18);
  cursor: pointer;
  font: inherit;
  text-align: left;
  transition: border-color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.map-float--desk .map-card {
  flex: 1 1 auto;
}
.map-card--on {
  border-color: var(--m-primary);
}
.map-card--dim {
  opacity: 0.6;
}
.map-card-shot {
  display: grid;
  width: 92px;
  height: 92px;
  flex: 0 0 auto;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm, 10px);
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
  color: var(--m-muted);
}
.map-card-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.map-card-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 3px;
}
.map-card-name {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.map-card-rent {
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.map-card-rent--full {
  color: var(--m-muted);
}
.map-card-per {
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
}
.map-card-line {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.map-card-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: auto;
}
.map-card-tag {
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 700;
}
.map-card-tag--ok {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.map-rail-none {
  margin: 0 auto;
  padding: 10px 14px;
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 88%, transparent);
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}

.stack {
  display: flex;
  flex-direction: column;
 
  /* Clears the docked search, which sits on the FAB's baseline. */
  padding: 8px var(--m-page-gutter) 126px;
}
/* Desktop: no docked search or FAB below the list to clear. */
.stack--desk {
  padding-bottom: 18px;
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

/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */

/* Filter sheet */

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
.rail--desk {
  scrollbar-width: none;
}
.rail--desk::-webkit-scrollbar {
  display: none;
}
.rail--desk .rail-item {
  flex-basis: calc((100% - 8px) / 2);
}
.sec-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
.rail-arrow {
  display: grid;
  width: 28px;
  height: 28px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
}
.rail-arrow:hover {
  background: var(--m-bg);
}

/* Landlords and landladies */
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
.tile-name-row {
  display: flex;
  align-items: center;
  gap: 6px;
}
.tile-name {
  min-width: 0;
  flex: 1 1 auto;
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
.tile-name-meta {
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
.m-chip {
  min-height: 36px;
  padding: 0 13px;
}
</style>
