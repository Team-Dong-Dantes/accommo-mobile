<template>
  <q-page class="disc">
    <div class="search">
      <IconifyIcon icon="lucide:search" width="17" class="search-icon" />
      <input
        v-model="query"
        class="search-input"
        type="search"
        placeholder="Search by name or address"
        aria-label="Search accommodations"
      />
      <button
        type="button"
        class="search-filter"
        :class="{ 'search-filter--on': activeFilterCount > 0 }"
        aria-label="Filters"
        @click="filtersOpen = true"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
        <span v-if="activeFilterCount" class="search-filter-dot">{{ activeFilterCount }}</span>
      </button>
    </div>

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

    <div v-else-if="!results.length" class="empty">
      <span class="empty-icon"><IconifyIcon icon="lucide:search-x" width="26" /></span>
      <p class="empty-title">{{ listings.length ? 'Nothing matches' : 'No listings yet' }}</p>
      <p class="empty-text">
        {{
          listings.length
            ? 'Try a different search, or loosen your filters.'
            : 'Accredited accommodations will appear here once OSAS approves them.'
        }}
      </p>
      <button v-if="listings.length && activeFilterCount" type="button" class="empty-act" @click="resetFilters">
        Clear filters
      </button>
    </div>

    <div v-else class="stack">
      <p class="count">{{ results.length }} {{ results.length === 1 ? 'place' : 'places' }}</p>

      <button
        v-for="item in results"
        :key="item.id"
        type="button"
        class="lst"
        @click="open(item.id)"
      >
        <span class="lst-thumb">
          <img v-if="item.image" :src="item.image" :alt="item.name" loading="lazy" />
          <span v-else class="lst-mono">{{ item.monogram }}</span>
        </span>

        <span class="lst-body">
          <span class="lst-top">
            <span class="lst-name">{{ item.name }}</span>
            <span v-if="item.vacancies" class="lst-free">{{ item.vacancies }} free</span>
            <span v-else class="lst-full">Full</span>
          </span>

          <span class="lst-where">{{ item.address }}</span>
          <span v-if="item.distance" class="lst-dist">
            <IconifyIcon icon="lucide:map-pin" width="11" />{{ item.distance }}
          </span>

          <span class="lst-foot">
            <span v-if="item.minRent !== null" class="lst-rent">
              {{ formatPeso(item.minRent) }}<span class="lst-per">/mo</span>
            </span>
            <span v-else class="lst-rent lst-rent--none">Rent on request</span>

            <span v-if="item.amenities.length" class="lst-am">
              <IconifyIcon
                v-for="a in item.amenities.slice(0, 4)"
                :key="a"
                :icon="AMENITY_META[a]?.icon || 'lucide:dot'"
                width="13"
              />
            </span>
          </span>
        </span>
      </button>
    </div>

    <!-- Filters -->
    <q-dialog v-model="filtersOpen" position="bottom">
      <div class="sheet">
        <div class="sheet-head">
          <h2 class="sheet-title">Filters</h2>
          <button type="button" class="sheet-clear" @click="resetFilters">Reset</button>
        </div>

        <label class="sheet-row">
          <span class="sheet-label">Only places with a free room</span>
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
              v-for="type in roomTypes"
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
          Show {{ results.length }} {{ results.length === 1 ? 'place' : 'places' }}
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
import { formatPeso } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { AMENITY_META, AMENITY_KEYS, roomTypeLabel, listingMonogram } from '@/utils/listings'

interface Listing {
  id: string
  name: string
  address: string
  image: string
  monogram: string
  distance: string
  vacancies: number
  minRent: number | null
  amenities: string[]
  roomTypes: string[]
  haystack: string
}

const router = useRouter()

const loading = ref(true)
const error = ref('')
const query = ref('')
const filtersOpen = ref(false)
const listings = ref<Listing[]>([])

const DEFAULT_MAX = 10000
const rentBounds = reactive({ min: 0, max: DEFAULT_MAX })
const filters = reactive({
  vacantOnly: false,
  maxRent: DEFAULT_MAX,
  roomTypes: [] as string[],
  amenities: [] as string[],
})

const roomTypes = computed(() => {
  const seen = new Set<string>()
  for (const l of listings.value) for (const t of l.roomTypes) seen.add(t)
  return [...seen].sort()
})

const activeFilterCount = computed(
  () =>
    (filters.vacantOnly ? 1 : 0) +
    (filters.maxRent < rentBounds.max ? 1 : 0) +
    filters.roomTypes.length +
    filters.amenities.length,
)

const results = computed(() => {
  const needle = query.value.trim().toLowerCase()
  return listings.value.filter((l) => {
    if (needle && !l.haystack.includes(needle)) return false
    if (filters.vacantOnly && !l.vacancies) return false
    // A listing with no priced room cannot be excluded on price without
    // hiding it from every search, so it only drops out below the ceiling.
    if (filters.maxRent < rentBounds.max && l.minRent !== null && l.minRent > filters.maxRent) {
      return false
    }
    if (filters.roomTypes.length && !filters.roomTypes.some((t) => l.roomTypes.includes(t))) {
      return false
    }
    if (filters.amenities.length && !filters.amenities.every((a) => l.amenities.includes(a))) {
      return false
    }
    return true
  })
})

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

async function load() {
  loading.value = true
  error.value = ''
  try {
    // Only accredited listings are readable, and the policy grants the public
    // role, so this works signed-out too.
    const { data, error: loadError } = await supabase
      .from('accommodations')
      .select(
        'id,name,address,city,barangay,lat,lng,accommodation_type,rooms(status,monthly_rent,room_type),accommodation_amenities(amenity),accommodation_images(url,sort_order)',
      )
      .eq('status', 'accredited')
    if (loadError) throw loadError

    let ceiling = 0
    listings.value = (data ?? [])
      .map((row) => {
        const rooms = (row.rooms ?? []) as { status: string; monthly_rent: number | null; room_type: string | null }[]
        const priced = rooms.map((r) => Number(r.monthly_rent)).filter((n) => n > 0)
        const minRent = priced.length ? Math.min(...priced) : null
        if (minRent !== null) ceiling = Math.max(ceiling, minRent)

        const images = [...((row.accommodation_images ?? []) as { url: string; sort_order: number | null }[])]
          .sort((x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0))
        const amenities = ((row.accommodation_amenities ?? []) as { amenity: string }[]).map(
          (a) => a.amenity,
        )
        const address = row.address || [row.barangay, row.city].filter(Boolean).join(', ') || 'Address not given'
        const name = row.name?.trim() || 'Unnamed accommodation'

        return {
          id: row.id,
          name,
          address,
          image: images[0]?.url ? resolveAsset(images[0].url) : '',
          monogram: listingMonogram(name),
          distance: campusDistanceLabel(row.lat, row.lng),
          vacancies: rooms.filter((r) => r.status === 'available').length,
          minRent,
          amenities,
          roomTypes: [...new Set(rooms.map((r) => r.room_type).filter(Boolean) as string[])],
          haystack: `${name} ${address}`.toLowerCase(),
        }
      })
      // Somewhere to move beats somewhere full, then cheapest first.
      .sort((a, b) => {
        if ((b.vacancies > 0 ? 1 : 0) !== (a.vacancies > 0 ? 1 : 0)) {
          return (b.vacancies > 0 ? 1 : 0) - (a.vacancies > 0 ? 1 : 0)
        }
        return (a.minRent ?? Number.MAX_SAFE_INTEGER) - (b.minRent ?? Number.MAX_SAFE_INTEGER)
      })

    rentBounds.max = Math.max(DEFAULT_MAX, Math.ceil(ceiling / 500) * 500)
    filters.maxRent = rentBounds.max
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.disc {
  background: var(--m-bg);
}

.search {
  position: sticky;
  top: 0;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px var(--m-page-gutter);
  border-bottom: 1px solid var(--m-border);
  background: var(--m-bg);
}
.search-icon {
  position: absolute;
  left: calc(var(--m-page-gutter) + 12px);
  color: var(--m-muted);
  pointer-events: none;
}
.search-input {
  flex: 1 1 auto;
  min-height: 44px;
  padding: 0 12px 0 36px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.search-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.search-filter {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.search-filter--on {
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.search-filter-dot {
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

.stack {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 8px var(--m-page-gutter) 20px;
}
.sk {
  border-radius: var(--m-radius);
}
.count {
  margin: 0 0 1px 2px;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
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

/* Listing card — text first, because only a few listings have a photo */
.lst {
  display: flex;
  width: 100%;
  align-items: stretch;
  gap: 11px;
  padding: 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.lst-thumb {
  display: grid;
  width: 66px;
  height: 66px;
  flex: 0 0 66px;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
}
.lst-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.lst-mono {
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 800;
}
.lst-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 1px;
}
.lst-top {
  display: flex;
  align-items: baseline;
  gap: 8px;
}
.lst-name {
  min-width: 0;
  flex: 1 1 auto;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.lst-free {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 10.5px;
  font-weight: 700;
}
.lst-full {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 700;
}
.lst-where {
  color: var(--m-muted);
  font-size: 12px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.lst-dist {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  color: var(--m-primary-dark);
  font-size: 11.5px;
  font-weight: 600;
}
.lst-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-top: 3px;
}
.lst-rent {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.lst-rent--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 12px;
  font-weight: 600;
}
.lst-per {
  font-size: 11px;
  font-weight: 600;
  opacity: 0.7;
}
.lst-am {
  display: flex;
  flex: 0 0 auto;
  gap: 6px;
  color: var(--m-muted);
}

/* Empty */
.empty {
  display: flex;
  min-height: 55vh;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 24px var(--m-page-gutter);
  text-align: center;
}
.empty-icon {
  display: grid;
  width: 54px;
  height: 54px;
  place-items: center;
  margin-bottom: 6px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary);
}
.empty-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
.empty-text {
  margin: 0;
  max-width: 280px;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}
.empty-act {
  min-height: 40px;
  margin-top: 10px;
  padding: 0 18px;
  border: 1px solid var(--m-primary);
  border-radius: 999px;
  background: transparent;
  color: var(--m-primary);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
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
</style>
