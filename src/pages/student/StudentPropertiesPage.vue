<template>
  <q-page class="disc">
    <SearchDock
      v-if="!loading && !error"
      v-model="query"
      :filter-count="activeFilterCount"
      placeholder="Search places"
      search-label="Search accommodations"
      @open-filters="filtersOpen = true"
    />

    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="96px" class="sk" />
      <q-skeleton type="rect" height="96px" class="sk" />
      <q-skeleton type="rect" height="96px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load listings" :detail="error" :retry="load" />
    </div>

    <EmptyState
      v-else-if="!results.length"
      :icon="listings.length ? 'lucide:search-x' : 'lucide:building-2'"
      :title="listings.length ? 'Nothing matches' : 'No listings yet'"
      :message="
        listings.length
          ? 'Try a different search, or loosen your filters.'
          : 'Accredited accommodations will appear here once OSAS approves them.'
      "
    >
      <template v-if="listings.length && activeFilterCount" #actions>
        <button type="button" class="empty-act" @click="resetFilters">
          Clear filters
        </button>
      </template>
    </EmptyState>

    <div v-else class="stack">
      <div class="count">
        <span>{{ results.length }} {{ results.length === 1 ? 'place' : 'places' }}</span>
      </div>

      <div class="grid">
        <PropertyCard
          v-for="item in results"
          :key="item.id"
          variant="grid"
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
    </div>

    <!-- Filters -->
    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      :done-label="`Show ${results.length} ${results.length === 1 ? 'place' : 'places'}`"
      @clear="resetFilters"
    >
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
        <div class="m-chips">
          <button
            v-for="type in roomTypes"
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
            v-for="key in AMENITY_KEYS"
            :key="key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': filters.amenities.includes(key) }"
            @click="toggle(filters.amenities, key)"
          >
            <IconifyIcon :icon="AMENITY_META[key]?.icon || 'lucide:dot'" width="13" />
            {{ AMENITY_META[key]?.label }}
          </button>
        </div>
      </div>
    </BottomSheet>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { formatPeso } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { AMENITY_META, AMENITY_KEYS, roomTypeLabel, listingMonogram } from '@/utils/listings'
import PropertyCard from '@/components/student/PropertyCard.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'

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

async function load(silent = false) {
  if (!silent) loading.value = true
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
    // A silent (realtime-triggered) refresh must not reset a filter the
    // student has actively narrowed — only the real first load defaults it.
    if (!silent) filters.maxRent = rentBounds.max
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

// Kept alive across navigation (see MainLayout's KEEP_ALIVE_PAGES), so new and
// updated listings push here instead of the page re-asking on every return.
// utils/useLiveData.ts owns the whole policy — first load, the subscription's
// lifetime, and how stale the data may be on return. Public data (accredited
// listings), so no per-user filter is needed.
useLiveData({
  key: 'student-properties',
  load,
  watch: () => [{ table: 'accommodations' }],
  cache: { get: () => listings.value, set: (d) => { listings.value = d as Listing[]; loading.value = false } },
})
</script>

<style scoped>
.disc {
  background: var(--m-bg);
}

.stack {
  display: flex;
  flex-direction: column;
  gap: 4px;
  /* Bottom clears the now-floating dock, same as the sibling sub-pages. */
  padding: 10px var(--m-page-gutter) 74px;
}
.sk {
  border-radius: var(--m-radius);
}
.count {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin: 0 0 1px 2px;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

/* Search + filter, sitting in normal flow just below the header */
/* Floats over the list like every other search dock. This is a sub-page —
   back-arrow header, no bottom nav — so it sits on the safe-area inset
   rather than the 68px the tabbed pages use to clear the nav. */

.card {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}

/* Empty */
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
.m-chip {
  min-height: 36px;
  padding: 0 13px;
}
</style>
