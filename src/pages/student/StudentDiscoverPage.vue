<template>
  <q-page class="disc">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="96px" class="sk" />
      <q-skeleton type="rect" height="96px" class="sk" />
      <q-skeleton type="rect" height="96px" class="sk" />
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
          @click="load"
        />
      </q-card>
    </div>

    <div v-else class="stack">
      <section v-if="filteredProperties.length" class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Properties</h2>
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
            <span class="mgr-avatar">{{ m.initials }}</span>
            <span class="mgr-body">
              <span class="mgr-name">{{ m.name }}</span>
              <span class="mgr-sub">
                {{ m.propertyCount ? `${m.propertyCount} ${m.propertyCount === 1 ? 'property' : 'properties'}` : 'New manager' }}
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
              <span class="tile-flag" :class="room.free ? 'tile-flag--ok' : 'tile-flag--none'">
                {{ room.free ? 'Available' : 'Taken' }}
              </span>
            </span>
            <span class="tile-body">
              <span class="tile-name">{{ room.label }}</span>
              <span class="tile-where">{{ room.propertyName }}</span>
              <span v-if="room.rent" class="tile-rent">
                {{ formatPeso(room.rent) }}<span class="tile-per">/mo</span>
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
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { AMENITY_META, AMENITY_KEYS, roomTypeLabel, listingMonogram } from '@/utils/listings'
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
  haystack: string
}

interface RoomTile {
  id: string
  label: string
  image: string
  monogram: string
  propertyName: string
  rent: number
  free: boolean
  roomType: string
  amenities: string[]
  haystack: string
}

interface ManagerRow {
  id: string
  name: string
  initials: string
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

const filtersOpen = ref(false)
const DEFAULT_MAX = 10000
const rentBounds = reactive({ min: 0, max: DEFAULT_MAX })
const filters = reactive({
  vacantOnly: false,
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
    (filters.vacantOnly ? 1 : 0) +
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
  filters.vacantOnly = false
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

async function loadProperties() {
  // Only accredited listings are readable, and the policy grants the public
  // role, so this works signed-out too — keep this select clear of the
  // `users` table, which anon cannot read at all.
  const { data, error: loadError } = await supabase
    .from('accommodations')
    .select(
      'id,name,address,city,barangay,lat,lng,rooms(id,label,room_number,room_type,custom_room_type,capacity,monthly_rent,status,room_images(url,sort_order)),accommodation_amenities(amenity),accommodation_images(url,sort_order)',
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
      monthly_rent: number | null
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
        rent,
        free: r.status === 'available',
        roomType,
        amenities,
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
  filters.maxRent = rentBounds.max
}

async function loadManagers() {
  // Anon (fully signed-out) sessions have no grant on `users` at all, so this
  // is expected to come back empty rather than throw for a signed-out demo
  // session — a real authenticated student can read it. Kept separate from
  // loadProperties() so that failure never blocks the rest of the page.
  try {
    const { data, error: loadError } = await supabase
      .from('users')
      .select('id,full_name,accommodations(id,name,status)')
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

async function load() {
  loading.value = true
  error.value = ''
  try {
    await Promise.all([loadProperties(), loadManagers()])
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>

<style scoped>
.disc {
  background: var(--m-bg);
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
  /* 16px FAB inset + 44px FAB + 8px gap */
  right: 68px;
  z-index: 60;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dock-field {
  position: relative;
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
}
.dock-icon {
  position: absolute;
  left: 13px;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  height: 44px;
  padding: 0 14px 0 35px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.dock-btn {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 50%;
  background: var(--m-surface);
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
}
.tile-flag--ok {
  background: var(--m-success);
  color: #fff;
}
.tile-flag--none {
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
