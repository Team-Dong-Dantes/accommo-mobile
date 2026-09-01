<template>
  <q-page class="properties-page">
    <main class="properties-shell">
      <header class="page-header">
        <h1 class="sr-only">Properties</h1>
        <p class="page-summary">{{ totalProperties }} {{ totalProperties === 1 ? 'accommodation' : 'accommodations' }} · {{ totalAvailableRooms }} available {{ totalAvailableRooms === 1 ? 'room' : 'rooms' }}</p>
        <q-btn no-caps unelevated class="add-button" to="/landlord/properties/new">
          <IconifyIcon icon="lucide:plus" aria-hidden="true" />
          Add accommodation
        </q-btn>
      </header>

      <section class="controls" aria-label="Find and filter properties">
        <label class="sr-only" for="property-search">Search accommodations</label>
        <div class="search-control">
          <IconifyIcon icon="lucide:search" width="19" aria-hidden="true" />
          <input id="property-search" v-model="searchText" type="search" placeholder="Search accommodations" autocomplete="off" />
          <button v-if="searchText" type="button" aria-label="Clear search" @click="searchText = ''">
            <IconifyIcon icon="lucide:x" width="18" aria-hidden="true" />
          </button>
        </div>
        <nav class="filter-bar" aria-label="Accommodation filters">
          <button v-for="filter in filters" :key="filter.value" type="button" :class="{ active: filterValue === filter.value }" :aria-pressed="filterValue === filter.value" @click="filterValue = filter.value">{{ filter.label }}</button>
        </nav>
        <div class="result-bar" aria-live="polite">
          <span>{{ filteredProperties.length }} {{ filteredProperties.length === 1 ? 'result' : 'results' }}</span>
          <button v-if="searchText || filterValue !== 'all'" type="button" @click="clearFilters">Clear filters</button>
        </div>
      </section>

      <section v-if="isLoading" class="property-list surface" aria-busy="true" aria-label="Loading accommodations">
        <div v-for="index in 4" :key="index" class="skeleton-row" aria-hidden="true"><span /><i /><i /><b /></div>
        <span class="sr-only">Loading properties</span>
      </section>

      <section v-else-if="loadError" class="state-panel surface" role="alert">
        <span class="state-icon state-icon--danger"><IconifyIcon icon="lucide:cloud-alert" width="24" aria-hidden="true" /></span>
        <h2>Unable to load accommodations</h2><p>{{ loadError }}</p>
        <button type="button" class="primary-action" @click="fetchProperties"><IconifyIcon icon="lucide:refresh-cw" width="17" aria-hidden="true" /> Retry</button>
      </section>

      <template v-else>
        <section v-if="filteredProperties.length" class="property-list surface" aria-label="Managed accommodations">
          <button v-for="property in filteredProperties" :key="property.id" type="button" class="property-row" @click="openProperty(property.id)">
            <span class="property-icon" aria-hidden="true"><IconifyIcon icon="lucide:building-2" width="21" /></span>
            <span class="property-copy">
              <strong :title="property.name">{{ property.name }}</strong>
              <span :title="property.address">{{ property.address || 'Address not set' }}</span>
              <span class="property-meta">{{ property.roomCount }} {{ property.roomCount === 1 ? 'room' : 'rooms' }} · {{ property.occupiedSpaces }} of {{ property.capacity }} spaces occupied</span>
            </span>
            <span class="property-side">
              <span class="status-badge" :class="`status-badge--${property.statusTone}`">{{ property.statusLabel }}</span>
              <span :class="{ attention: property.needsSetup }">{{ property.availableSpaces }} available</span>
            </span>
            <IconifyIcon class="chevron" icon="lucide:chevron-right" width="20" aria-hidden="true" />
          </button>
        </section>

        <section v-else-if="properties.length" class="state-panel surface">
          <span class="state-icon"><IconifyIcon icon="lucide:search-x" width="24" aria-hidden="true" /></span>
          <h2>No matching accommodations</h2><p>Try another search or clear the active filters.</p>
          <button type="button" class="secondary-action" @click="clearFilters">Clear filters</button>
        </section>

        <section v-else class="state-panel surface">
          <span class="state-icon"><IconifyIcon icon="lucide:building-2" width="24" aria-hidden="true" /></span>
          <h2>Add your first accommodation</h2><p>Create an accommodation, then add its rooms and setup details from its management page.</p>
          <q-btn no-caps unelevated class="primary-action" to="/landlord/properties/new"><IconifyIcon icon="lucide:plus" aria-hidden="true" /> Add accommodation</q-btn>
        </section>
      </template>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

type FilterValue = 'all' | 'needs-setup' | 'accreditation' | 'vacant'
type Tone = 'success' | 'warning' | 'danger' | 'neutral'
interface Property { id: string; name: string; address: string; roomCount: number; capacity: number; occupiedSpaces: number; availableSpaces: number; needsSetup: boolean; statusLabel: string; statusTone: Tone }

const router = useRouter()
const searchText = ref('')
const filterValue = ref<FilterValue>('all')
const isLoading = ref(true)
const loadError = ref<string | null>(null)
const properties = ref<Property[]>([])
const filters: { label: string; value: FilterValue }[] = [{ label: 'All', value: 'all' }, { label: 'Needs setup', value: 'needs-setup' }, { label: 'Accreditation', value: 'accreditation' }, { label: 'Vacant rooms', value: 'vacant' }]

const totalProperties = computed(() => properties.value.length)
const totalAvailableRooms = computed(() => properties.value.reduce((total, property) => total + property.availableSpaces, 0))
const filteredProperties = computed(() => {
  const term = searchText.value.trim().toLowerCase()
  return properties.value.filter((property) => {
    const matchesSearch = !term || [property.name, property.address].some((value) => value.toLowerCase().includes(term))
    const matchesFilter = filterValue.value === 'all' || (filterValue.value === 'needs-setup' && property.needsSetup) || (filterValue.value === 'accreditation' && property.statusTone !== 'success') || (filterValue.value === 'vacant' && property.availableSpaces > 0)
    return matchesSearch && matchesFilter
  })
})

function statusPresentation(status: string | null, accreditationStatus: string | null): { label: string; tone: Tone } {
  const accreditation = (accreditationStatus || '').toLowerCase()
  if (['rejected', 'delisted', 'expired'].includes(accreditation)) return { label: accreditation === 'delisted' ? 'Delisted' : accreditation[0]!.toUpperCase() + accreditation.slice(1), tone: 'danger' }
  if (['pending', 'reviewing', 'submitted'].includes(accreditation) || status === 'pending') return { label: accreditation === 'reviewing' ? 'In review' : 'Pending', tone: 'warning' }
  if (['accredited', 'approved', 'active'].includes(accreditation) || status === 'active') return { label: 'Active', tone: 'success' }
  return { label: 'Not set', tone: 'neutral' }
}

async function fetchProperties() {
  isLoading.value = true; loadError.value = null
  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError) throw userError
    if (!user) { void router.push('/login'); return }
    const { data: accommodationRows, error: accommodationError } = await (supabase as any).from('accommodations').select('id, name, business_name, address, status, accreditation_status, capacity').eq('accommodation_manager_id', user.id).order('name')
    if (accommodationError) throw accommodationError
    const accommodations = accommodationRows ?? []
    const ids = accommodations.map((item: any) => item.id)
    const { data: roomRows, error: roomError } = ids.length ? await (supabase as any).from('rooms').select('id, accommodation_id, capacity, current_pax').in('accommodation_id', ids) : { data: [], error: null }
    if (roomError) throw roomError
    const roomsByProperty = new Map<string, any[]>()
    ;(roomRows ?? []).forEach((room: any) => roomsByProperty.set(room.accommodation_id, [...(roomsByProperty.get(room.accommodation_id) ?? []), room]))
    properties.value = accommodations.map((property: any) => {
      const rooms = roomsByProperty.get(property.id) ?? []
      const capacity = rooms.reduce((total: number, room: any) => total + Math.max(Number(room.capacity) || 0, 0), 0) || Math.max(Number(property.capacity) || 0, 0)
      const occupiedSpaces = rooms.reduce((total: number, room: any) => total + Math.max(Number(room.current_pax) || 0, 0), 0)
      const status = statusPresentation(property.status, property.accreditation_status)
      return { id: property.id, name: property.business_name || property.name || 'Unnamed property', address: property.address || '', roomCount: rooms.length, capacity, occupiedSpaces, availableSpaces: Math.max(capacity - occupiedSpaces, 0), needsSetup: rooms.length === 0, statusLabel: status.label, statusTone: status.tone }
    })
  } catch (error) { loadError.value = error instanceof Error ? error.message : 'We could not retrieve your properties.' } finally { isLoading.value = false }
}
function clearFilters() { searchText.value = ''; filterValue.value = 'all' }
function openProperty(id: string) { void router.push(`/landlord/properties/${id}`) }
onMounted(() => { void fetchProperties() })
</script>

<style scoped>
.properties-page { min-height: 100%; background: var(--m-bg); color: var(--m-text); }
.properties-shell { width: 100%; max-width: 760px; margin: 0 auto; padding: max(var(--m-space-3), env(safe-area-inset-top)) var(--m-page-gutter) max(112px, calc(var(--m-space-8) + env(safe-area-inset-bottom))); }
.page-header { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 16px; }.page-summary { margin: 0; color: var(--m-muted); font-size: 13px; font-weight: 700; }.add-button,.primary-action { min-height: 44px; border-radius: 8px; background: var(--m-primary-dark); color: #fff; font-size: 13px; font-weight: 800; }.add-button svg,.primary-action svg { margin-right: 7px; font-size: 17px; }
.controls { display: grid; gap: 10px; margin-bottom: 16px; }.search-control { display: flex; min-height: 46px; align-items: center; gap: 10px; padding: 0 12px; border: 1px solid var(--m-border); border-radius: 8px; background: var(--m-surface); color: var(--m-muted); }.search-control input { width: 100%; min-width: 0; border: 0; outline: 0; background: transparent; color: var(--m-ink); font: inherit; }.search-control button,.result-bar button { display: grid; min-width: 32px; min-height: 32px; place-items: center; border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; }.filter-bar { display: flex; gap: 8px; overflow-x: auto; scrollbar-width: none; }.filter-bar button { min-height: 36px; flex: 0 0 auto; padding: 0 12px; border: 1px solid var(--m-border); border-radius: 999px; background: var(--m-surface); color: var(--m-text); font-size: 12px; font-weight: 750; cursor: pointer; }.filter-bar button.active { border-color: var(--m-primary); background: var(--m-primary-soft); color: var(--m-primary-dark); }.result-bar { display: flex; justify-content: space-between; align-items: center; min-height: 24px; color: var(--m-muted); font-size: 12px; font-weight: 700; }.result-bar button { width: auto; padding: 0; min-height: 28px; font: inherit; }
.surface { overflow: hidden; border: 1px solid var(--m-border); border-radius: 12px; background: var(--m-surface); }.property-row { display: grid; width: 100%; min-height: 92px; grid-template-columns: 40px minmax(0, 1fr) auto 20px; align-items: center; gap: 10px; padding: 12px; border: 0; border-bottom: 1px solid var(--m-border); background: transparent; color: inherit; text-align: left; cursor: pointer; }.property-row:last-child { border-bottom: 0; }.property-row:hover { background: var(--m-bg); }.property-icon,.state-icon { display: grid; place-items: center; width: 40px; height: 40px; border-radius: 10px; background: var(--m-primary-soft); color: var(--m-primary-dark); }.property-copy { display: grid; min-width: 0; gap: 2px; }.property-copy strong { overflow: hidden; color: var(--m-ink); font-size: 14px; font-weight: 800; line-height: 1.35; text-overflow: ellipsis; white-space: nowrap; }.property-copy > span { overflow: hidden; color: var(--m-muted); font-size: 11px; line-height: 1.35; text-overflow: ellipsis; white-space: nowrap; }.property-copy .property-meta { margin-top: 3px; color: var(--m-text); font-weight: 650; }.property-side { display: grid; justify-items: end; gap: 7px; color: var(--m-muted); font-size: 10px; font-weight: 750; white-space: nowrap; }.property-side .attention { color: var(--m-warning); }.status-badge { min-height: 23px; padding: 4px 7px; border-radius: 999px; font-size: 10px; font-weight: 800; }.status-badge--success { background: var(--m-success-soft); color: var(--m-success); }.status-badge--warning { background: var(--m-warning-soft); color: var(--m-warning); }.status-badge--danger { background: var(--m-danger-soft); color: var(--m-danger); }.status-badge--neutral { background: var(--m-bg); color: var(--m-text); }.chevron { color: var(--m-muted); }
.state-panel { display: flex; min-height: 280px; flex-direction: column; align-items: flex-start; justify-content: center; padding: 24px; }.state-icon { margin-bottom: 16px; }.state-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }.state-panel h2 { margin: 0; color: var(--m-ink); font-size: 20px; font-weight: 800; }.state-panel p { margin: 8px 0 20px; color: var(--m-muted); font-size: 13px; line-height: 1.5; }.secondary-action { min-height: 44px; padding: 0 16px; border: 1px solid var(--m-border); border-radius: 8px; background: var(--m-surface); color: var(--m-primary-dark); font-size: 13px; font-weight: 800; }.skeleton-row { display: grid; min-height: 92px; grid-template-columns: 40px 1fr 72px; align-items: center; gap: 12px; padding: 12px; border-bottom: 1px solid var(--m-border); }.skeleton-row > * { display: block; border-radius: 6px; background: #edf0f2; animation: pulse 1.4s ease infinite; }.skeleton-row span { width: 40px; height: 40px; }.skeleton-row i { height: 12px; }.skeleton-row i:nth-of-type(2) { width: 65%; margin-top: -24px; }.skeleton-row b { width: 72px; height: 22px; } .sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap; } @keyframes pulse { 50% { opacity: .48; } } @media (max-width: 390px) { .property-row { grid-template-columns: 40px minmax(0,1fr) 20px; }.property-side { display: none; } }
</style>
