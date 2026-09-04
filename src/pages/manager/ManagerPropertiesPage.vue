<template>
  <q-page class="properties-page">
    <main class="properties-shell">
      <section v-if="!isLoading && !loadError && properties.length" class="portfolio-summary" aria-label="Accommodation portfolio summary">
        <div class="portfolio-summary__primary">
          <span>Portfolio occupancy</span>
          <strong>{{ totalOccupiedSpaces }}<small>/{{ totalCapacity }} residents</small></strong>
          <div class="portfolio-summary__meter" aria-hidden="true"><i :style="{ width: `${portfolioOccupancy}%` }" /></div>
          <p>{{ portfolioOccupancy }}% occupied across your listings</p>
        </div>
        <div class="portfolio-summary__stats">
          <div>
            <span>Open spaces</span>
            <strong>{{ totalAvailableSpaces }}</strong>
          </div>
          <div>
            <span>Active listings</span>
            <strong>{{ activeProperties }}<small>/{{ properties.length }}</small></strong>
          </div>
        </div>
      </section>

      <div class="list-heading" aria-live="polite">
        <div>
          <h2>Your listings</h2>
          <p>{{ properties.length }} {{ properties.length === 1 ? 'accommodation' : 'accommodations' }}</p>
        </div>
        <div class="list-heading__actions">
          <q-btn no-caps unelevated class="add-button" to="/manager/properties/new">
            <IconifyIcon icon="lucide:plus" width="18" aria-hidden="true" />
            <span>Add</span>
          </q-btn>
        </div>
      </div>

      <section v-if="isLoading" class="property-grid" aria-busy="true" aria-label="Loading accommodations">
        <article v-for="index in 3" :key="index" class="property-card property-card--loading" aria-hidden="true">
          <span class="skeleton skeleton--photo" />
          <span class="skeleton skeleton--title" />
          <span class="skeleton skeleton--line" />
          <span class="skeleton skeleton--line skeleton--short" />
        </article>
        <span class="sr-only">Loading accommodations</span>
      </section>

      <section v-else-if="loadError" class="state-panel" role="alert">
        <span class="state-icon state-icon--danger"><IconifyIcon icon="lucide:cloud-alert" width="24" aria-hidden="true" /></span>
        <h2>Unable to load accommodations</h2>
        <p>{{ loadError }}</p>
        <button type="button" class="primary-action" @click="fetchProperties"><IconifyIcon icon="lucide:refresh-cw" width="17" aria-hidden="true" /> Retry</button>
      </section>

      <section v-else-if="properties.length" class="property-grid" aria-label="Managed accommodations">
        <button v-for="property in properties" :key="property.id" type="button" class="property-card" @click="openProperty(property.id)">
          <div class="property-photo">
            <img v-if="property.imageUrl" :src="property.imageUrl" :alt="`${property.name} exterior`" />
            <span v-else class="property-photo__empty"><IconifyIcon icon="lucide:building-2" width="28" aria-hidden="true" /></span>
            <span class="status-badge" :class="`status-badge--${property.statusTone}`">{{ property.statusLabel }}</span>
          </div>
          <span class="property-card__content">
            <span class="property-card__title-row">
              <strong :title="property.name">{{ property.name }}</strong>
              <IconifyIcon icon="lucide:arrow-up-right" width="18" aria-hidden="true" />
            </span>
            <span class="property-address" :title="property.address">
              <IconifyIcon icon="lucide:map-pin" width="14" aria-hidden="true" />
              {{ property.address || 'Address not set' }}
            </span>
            <span class="property-card__metrics">
              <span><b>{{ property.roomCount }}</b> {{ property.roomCount === 1 ? 'room' : 'rooms' }}</span>
              <span><b>{{ property.occupiedSpaces }}</b> residents</span>
            </span>
            <span class="capacity-row">
              <span class="capacity-track" aria-hidden="true"><i :style="{ width: `${property.occupancyPercent}%` }" /></span>
              <span :class="{ attention: property.needsSetup }">{{ property.capacity ? `${property.availableSpaces} open` : 'Set up rooms' }}</span>
            </span>
          </span>
        </button>
      </section>

      <EmptyState v-else icon="lucide:building-2" title="Add your first accommodation" message="Submit the listing and required permits to OSAS. Room setup opens after approval.">
        <q-btn no-caps unelevated class="primary-action" to="/manager/properties/new"><IconifyIcon icon="lucide:plus" width="17" aria-hidden="true" /> Add accommodation</q-btn>
      </EmptyState>
    </main>

  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'
import EmptyState from '@/components/shared/EmptyState.vue'

type Tone = 'success' | 'warning' | 'danger' | 'neutral'
interface Property { id: string; name: string; address: string; imageUrl: string; roomCount: number; capacity: number; occupiedSpaces: number; availableSpaces: number; occupancyPercent: number; needsSetup: boolean; statusLabel: string; statusTone: Tone }

const router = useRouter()
const isLoading = ref(true)
const loadError = ref<string | null>(null)
const properties = ref<Property[]>([])
const activeProperties = computed(() => properties.value.filter((property) => property.statusTone === 'success').length)
const totalAvailableSpaces = computed(() => properties.value.reduce((total, property) => total + property.availableSpaces, 0))
const totalCapacity = computed(() => properties.value.reduce((total, property) => total + property.capacity, 0))
const totalOccupiedSpaces = computed(() => properties.value.reduce((total, property) => total + property.occupiedSpaces, 0))
const portfolioOccupancy = computed(() => totalCapacity.value ? Math.round((totalOccupiedSpaces.value / totalCapacity.value) * 100) : 0)

function statusPresentation(status: string | null, accreditationStatus: string | null): { label: string; tone: Tone } {
  const accreditation = (accreditationStatus || '').toLowerCase()
  if (['rejected', 'delisted', 'expired'].includes(accreditation) || ['rejected', 'delisted'].includes(status || '')) return { label: accreditation === 'delisted' || status === 'delisted' ? 'Delisted' : 'Rejected', tone: 'danger' }
  if (['pending', 'reviewing', 'submitted'].includes(accreditation) || ['pending', 'reviewing'].includes(status || '')) return { label: accreditation === 'reviewing' || status === 'reviewing' ? 'In review' : 'Pending', tone: 'warning' }
  if (['accredited', 'approved', 'active'].includes(accreditation) || ['active', 'accredited'].includes(status || '')) return { label: 'Active', tone: 'success' }
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
    const [roomResult, imageResult] = await Promise.all([
      ids.length ? (supabase as any).from('rooms').select('id, accommodation_id, capacity, current_pax').in('accommodation_id', ids) : Promise.resolve({ data: [], error: null }),
      ids.length ? (supabase as any).from('accommodation_images').select('accommodation_id, url, sort_order').in('accommodation_id', ids).order('sort_order') : Promise.resolve({ data: [], error: null }),
    ])
    if (roomResult.error) throw roomResult.error
    if (imageResult.error) throw imageResult.error
    const roomsByProperty = new Map<string, any[]>()
    ;(roomResult.data ?? []).forEach((room: any) => roomsByProperty.set(room.accommodation_id, [...(roomsByProperty.get(room.accommodation_id) ?? []), room]))
    const imageByProperty = new Map<string, string>()
    ;(imageResult.data ?? []).forEach((image: any) => { if (!imageByProperty.has(image.accommodation_id)) imageByProperty.set(image.accommodation_id, image.url) })
    properties.value = accommodations.map((property: any) => {
      const rooms = roomsByProperty.get(property.id) ?? []
      const capacity = rooms.reduce((total: number, room: any) => total + Math.max(Number(room.capacity) || 0, 0), 0) || Math.max(Number(property.capacity) || 0, 0)
      const occupiedSpaces = rooms.reduce((total: number, room: any) => total + Math.max(Number(room.current_pax) || 0, 0), 0)
      const status = statusPresentation(property.status, property.accreditation_status)
      return { id: property.id, name: property.business_name || property.name || 'Unnamed property', address: property.address || '', imageUrl: imageByProperty.get(property.id) || '', roomCount: rooms.length, capacity, occupiedSpaces, availableSpaces: Math.max(capacity - occupiedSpaces, 0), occupancyPercent: capacity ? Math.min(Math.round((occupiedSpaces / capacity) * 100), 100) : 0, needsSetup: rooms.length === 0, statusLabel: status.label, statusTone: status.tone }
    })
  } catch (error) { loadError.value = error instanceof Error ? error.message : 'We could not retrieve your accommodations.' } finally { isLoading.value = false }
}
function openProperty(id: string) { void router.push(`/manager/properties/${id}`) }
onMounted(() => { void fetchProperties() })
</script>

<style scoped>
.properties-page { min-height: 100%; background: var(--m-bg); color: var(--m-text); }
.properties-shell { width: 100%; max-width: 760px; margin: 0 auto; padding: var(--m-space-3) var(--m-page-gutter) calc(168px + env(safe-area-inset-bottom)); }
.eyebrow { display: block; margin-bottom: 5px; color: var(--m-primary-dark); font-size: 10px; font-weight: 850; letter-spacing: .1em; text-transform: uppercase; }.add-button,.primary-action { min-height: 44px; border-radius: 11px; background: var(--m-primary-dark); color: #fff; font-size: 12px; font-weight: 800; }.add-button { flex: 0 0 auto; padding: 0 13px; }.add-button svg,.primary-action svg { margin-right: 5px; vertical-align: -3px; }
.portfolio-summary { display: grid; grid-template-columns: minmax(0, 1.35fr) minmax(0, 1fr); margin-bottom: var(--m-space-3); overflow: hidden; border-radius: var(--m-radius); background: var(--m-primary-dark); color: #fff; }.portfolio-summary__primary { min-width: 0; padding: 14px; }.portfolio-summary__primary > span,.portfolio-summary__stats span { display: block; color: rgba(255,255,255,.7); font-size: 10px; font-weight: 700; }.portfolio-summary__primary > strong { display: block; margin-top: 4px; font-size: 25px; font-weight: 850; letter-spacing: -.04em; line-height: 1; }.portfolio-summary__primary > strong small,.portfolio-summary__stats strong small { margin-left: 2px; color: rgba(255,255,255,.68); font-size: 11px; font-weight: 700; letter-spacing: 0; }.portfolio-summary__meter { height: 5px; margin: 12px 0 6px; overflow: hidden; border-radius: 999px; background: rgba(255,255,255,.2); }.portfolio-summary__meter i { display: block; height: 100%; border-radius: inherit; background: #91e7dc; }.portfolio-summary__primary p { margin: 0; color: rgba(255,255,255,.72); font-size: 10px; }.portfolio-summary__stats { display: grid; align-content: center; gap: 12px; padding: 14px; border-left: 1px solid rgba(255,255,255,.2); background: rgba(0,0,0,.07); }.portfolio-summary__stats div { min-width: 0; }.portfolio-summary__stats strong { display: block; margin-top: 2px; font-size: 18px; font-weight: 850; line-height: 1.1; }
.list-heading { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); margin-bottom: 8px; }.list-heading h2 { margin: 0; color: var(--m-ink); font-size: 15px; font-weight: 850; }.list-heading p { margin: 1px 0 0; color: var(--m-muted); font-size: 11px; }.list-heading__actions { display: flex; flex: 0 0 auto; align-items: center; gap: 4px; }
.property-grid { display: grid; gap: var(--m-space-2); }.property-card { display: grid; width: 100%; overflow: hidden; padding: 0; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); color: inherit; text-align: left; cursor: pointer; transition: border-color .15s ease, transform .15s ease; }.property-card:active { transform: scale(.99); border-color: var(--m-primary); }.property-photo { position: relative; height: 118px; overflow: hidden; background: var(--m-surface-2, #eef1f3); }.property-photo img { display: block; width: 100%; height: 100%; object-fit: cover; }.property-photo__empty { display: grid; width: 100%; height: 100%; place-items: center; color: var(--m-muted); }.status-badge { position: absolute; top: 8px; right: 8px; min-height: 22px; padding: 3px 7px; border-radius: 999px; box-shadow: 0 2px 8px rgba(15,23,42,.12); font-size: 10px; font-weight: 850; }.status-badge--success { background: var(--m-success-soft); color: var(--m-success); }.status-badge--warning { background: var(--m-warning-soft); color: var(--m-warning); }.status-badge--danger { background: var(--m-danger-soft); color: var(--m-danger); }.status-badge--neutral { background: var(--m-bg); color: var(--m-text); }.property-card__content { display: grid; gap: 5px; padding: 11px 12px; }.property-card__title-row { display: flex; align-items: center; justify-content: space-between; gap: 10px; }.property-card__title-row strong { min-width: 0; overflow: hidden; color: var(--m-ink); font-size: 15px; font-weight: 850; text-overflow: ellipsis; white-space: nowrap; }.property-card__title-row svg { flex: 0 0 auto; color: var(--m-primary-dark); }.property-address { display: flex; min-width: 0; align-items: center; gap: 4px; overflow: hidden; color: var(--m-muted); font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }.property-address svg { flex: 0 0 auto; }.property-card__metrics { display: flex; gap: 12px; color: var(--m-text); font-size: 11px; }.property-card__metrics b { color: var(--m-ink); font-weight: 850; }.capacity-row { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: center; gap: 8px; margin-top: 1px; color: var(--m-muted); font-size: 10px; font-weight: 750; }.capacity-row .attention { color: var(--m-warning); }.capacity-track { height: 4px; overflow: hidden; border-radius: 999px; background: var(--m-border); }.capacity-track i { display: block; height: 100%; border-radius: inherit; background: var(--m-primary); }
.state-panel { display: flex; min-height: 280px; flex-direction: column; align-items: flex-start; justify-content: center; padding: 24px; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }.state-panel--first { background: linear-gradient(145deg, var(--m-surface) 0%, var(--m-primary-soft) 100%); }.state-icon { display: grid; width: 44px; height: 44px; place-items: center; margin-bottom: 16px; border-radius: 13px; background: var(--m-primary-soft); color: var(--m-primary-dark); }.state-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }.state-panel h2 { margin: 0; color: var(--m-ink); font-size: 20px; font-weight: 850; }.state-panel p { max-width: 310px; margin: 8px 0 20px; color: var(--m-muted); font-size: 13px; line-height: 1.5; }.secondary-action { min-height: 44px; padding: 0 16px; border: 1px solid var(--m-border); border-radius: 10px; background: var(--m-surface); color: var(--m-primary-dark); font-size: 13px; font-weight: 800; }
.property-card--loading { pointer-events: none; }.skeleton { display: block; border-radius: 7px; background: #e7eaed; animation: pulse 1.4s ease infinite; }.skeleton--photo { width: 100%; height: 138px; border-radius: 0; }.skeleton--title { width: 58%; height: 15px; margin: 13px 13px 0; }.skeleton--line { width: 82%; height: 10px; margin: 0 13px; }.skeleton--short { width: 42%; margin-bottom: 13px; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap; border: 0; } @keyframes pulse { 50% { opacity: .5; } } @media (min-width: 600px) { .property-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } .properties-shell { padding-right: var(--m-space-5); padding-left: var(--m-space-5); } } @media (prefers-reduced-motion: reduce) { .property-card { transition: none; } .skeleton { animation: none; } }
</style>
