<template>
  <q-dialog :model-value="modelValue" position="bottom" @update:model-value="(v) => emit('update:modelValue', v)">
    <q-card class="room-sheet room-sheet--paged room-sheet--wizard">
      <span class="sheet-grip" aria-hidden="true" />
      <div class="sheet-header">
        <span class="sheet-header-icon"><IconifyIcon icon="lucide:map-pin" width="18" /></span>
        <h3 class="room-sheet-title">Set location</h3>
      </div>

      <div class="room-sheet-scroll">
        <template v-if="!hasToken">
          <p class="none">Map unavailable — VITE_MAPBOX_TOKEN isn't configured.</p>
        </template>
        <template v-else>
          <label class="field">
            <span class="field-label">Search</span>
            <input v-model="query" type="text" class="field-input" placeholder="Search an address or landmark" @input="onQueryInput" />
          </label>

          <div v-if="searching" class="sec-hint">Searching…</div>
          <div v-else-if="results.length" class="group">
            <button v-for="r in results" :key="r.id" type="button" class="facility-row" @click="pickResult(r)">
              <span class="facility-icon"><IconifyIcon icon="lucide:map-pin" width="16" /></span>
              <span class="facility-body">
                <span class="facility-name">{{ r.name }}</span>
                <span v-if="r.addressGuess" class="facility-sub">{{ r.addressGuess }}</span>
              </span>
            </button>
          </div>

          <div class="location-map-wrap">
            <div ref="mapEl" class="location-map" aria-label="Map used to set the accommodation location" />
          </div>
          <p class="sec-hint">Tap the map to drop a pin, or use search / your current location above.</p>
        </template>
      </div>

      <div v-if="hasToken" class="photo-actions photo-actions--pinned">
        <button type="button" class="photo-action-btn" :disabled="locating" @click="useCurrentLocation">
          <IconifyIcon icon="lucide:locate-fixed" width="15" />
          {{ locating ? 'Locating…' : 'Use my current location' }}
        </button>
      </div>

      <div class="wizard-nav">
        <button type="button" class="ghost-btn" @click="emit('update:modelValue', false)">Cancel</button>
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="save-btn"
          label="Use this location"
          :disable="lat === null || lng === null"
          :loading="confirming"
          @click="confirmLocation"
        />
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch, nextTick, onBeforeUnmount } from 'vue'
import mapboxgl from 'mapbox-gl'
import 'mapbox-gl/dist/mapbox-gl.css'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useNotify } from '@/utils/notify'
import { CAMPUS } from '@/utils/geo'

const props = defineProps<{
  modelValue: boolean
  initialLat?: number | null
  initialLng?: number | null
}>()

const emit = defineEmits<{
  'update:modelValue': [boolean]
  confirm: [{ lat: number; lng: number; address: string; barangay: string; city: string }]
}>()

const notify = useNotify()
const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined
const hasToken = Boolean(MAPBOX_TOKEN)

interface SearchResult {
  id: string
  name: string
  addressGuess: string
  barangayGuess: string
  cityGuess: string
  lat: number
  lng: number
}

const mapEl = ref<HTMLElement | null>(null)
const query = ref('')
const results = ref<SearchResult[]>([])
const searching = ref(false)
const locating = ref(false)
const confirming = ref(false)
const lat = ref<number | null>(null)
const lng = ref<number | null>(null)
const addressGuess = ref('')
const barangayGuess = ref('')
const cityGuess = ref('')

let map: mapboxgl.Map | null = null
let marker: mapboxgl.Marker | null = null
let searchTimer: ReturnType<typeof setTimeout> | undefined

function setPin(pinLng: number, pinLat: number, zoom = 16) {
  lat.value = pinLat
  lng.value = pinLng
  if (!map) return
  if (!marker) marker = new mapboxgl.Marker({ color: '#00897b' })
  marker.setLngLat([pinLng, pinLat]).addTo(map)
  map.flyTo({ center: [pinLng, pinLat], zoom, essential: true })
}

function initMap() {
  if (!mapEl.value || map || !hasToken) return
  mapboxgl.accessToken = MAPBOX_TOKEN!
  const startLng = props.initialLng ?? CAMPUS.lng
  const startLat = props.initialLat ?? CAMPUS.lat
  map = new mapboxgl.Map({
    container: mapEl.value,
    style: 'mapbox://styles/mapbox/streets-v12',
    center: [startLng, startLat],
    zoom: props.initialLng != null ? 16 : 13,
  })
  map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right')
  map.on('load', () => {
    if (props.initialLat != null && props.initialLng != null) setPin(props.initialLng, props.initialLat)
  })
  map.on('click', (event) => setPin(event.lngLat.lng, event.lngLat.lat))
}

function destroyMap() {
  marker = null
  map?.remove()
  map = null
}

// A dialog's content isn't in the DOM with real dimensions until it opens —
// mapbox-gl needs a visible, sized container to render into, so wait for
// that instead of initializing on component mount.
watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      query.value = ''
      results.value = []
      lat.value = props.initialLat ?? null
      lng.value = props.initialLng ?? null
      addressGuess.value = ''
      barangayGuess.value = ''
      cityGuess.value = ''
      void nextTick(() => {
        setTimeout(() => {
          initMap()
          map?.resize()
        }, 50)
      })
    } else {
      destroyMap()
    }
  },
)

onBeforeUnmount(destroyMap)

function contextName(context: Record<string, { name?: string }> | undefined, key: string): string {
  return context?.[key]?.name ?? ''
}

function onQueryInput() {
  if (searchTimer) clearTimeout(searchTimer)
  const q = query.value.trim()
  results.value = []
  if (q.length < 3 || !hasToken) return
  searchTimer = setTimeout(() => void runSearch(q), 350)
}

async function runSearch(q: string) {
  searching.value = true
  try {
    const url =
      `https://api.mapbox.com/search/geocode/v6/forward?q=${encodeURIComponent(q)}` +
      `&proximity=${CAMPUS.lng},${CAMPUS.lat}&limit=5&access_token=${MAPBOX_TOKEN}`
    const response = await fetch(url)
    if (!response.ok) throw new Error('Search failed.')
    const payload = await response.json()
    results.value = ((payload.features ?? []) as unknown[]).flatMap((feature) => {
      const f = feature as {
        id: string
        geometry?: { coordinates?: number[] }
        properties?: { name?: string; place_formatted?: string; full_address?: string; context?: Record<string, { name?: string }> }
      }
      const [lngVal, latVal] = f.geometry?.coordinates ?? []
      if (typeof lngVal !== 'number' || typeof latVal !== 'number') return []
      return [{
        id: f.id,
        name: f.properties?.name || f.properties?.place_formatted || 'Selected location',
        addressGuess: f.properties?.place_formatted || f.properties?.full_address || '',
        barangayGuess: contextName(f.properties?.context, 'locality') || contextName(f.properties?.context, 'neighborhood'),
        cityGuess: contextName(f.properties?.context, 'place'),
        lng: lngVal,
        lat: latVal,
      }]
    })
  } catch (e) {
    results.value = []
    notify.error('Could not search for that location.')
  } finally {
    searching.value = false
  }
}

function pickResult(r: SearchResult) {
  addressGuess.value = r.addressGuess
  barangayGuess.value = r.barangayGuess
  cityGuess.value = r.cityGuess
  results.value = []
  query.value = r.name
  setPin(r.lng, r.lat)
}

function useCurrentLocation() {
  if (!navigator.geolocation) {
    notify.error('Your device does not support location services.')
    return
  }
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    (position) => {
      locating.value = false
      setPin(position.coords.longitude, position.coords.latitude)
      void reverseGeocode(position.coords.longitude, position.coords.latitude)
    },
    () => {
      locating.value = false
      notify.error('Could not get your current location.')
    },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

async function reverseGeocode(pinLng: number, pinLat: number) {
  if (!hasToken) return
  try {
    const url =
      `https://api.mapbox.com/search/geocode/v6/reverse?longitude=${pinLng}&latitude=${pinLat}` +
      `&access_token=${MAPBOX_TOKEN}`
    const response = await fetch(url)
    if (!response.ok) return
    const payload = await response.json()
    const feature = (payload.features ?? [])[0] as {
      properties?: { place_formatted?: string; full_address?: string; context?: Record<string, { name?: string }> }
    } | undefined
    if (!feature) return
    addressGuess.value ||= feature.properties?.place_formatted || feature.properties?.full_address || ''
    barangayGuess.value ||=
      contextName(feature.properties?.context, 'locality') || contextName(feature.properties?.context, 'neighborhood')
    cityGuess.value ||= contextName(feature.properties?.context, 'place')
  } catch {
    // Best-effort only — a failed reverse-geocode still leaves lat/lng set.
  }
}

async function confirmLocation() {
  if (lat.value === null || lng.value === null || confirming.value) return
  confirming.value = true
  try {
    if (!addressGuess.value && !barangayGuess.value && !cityGuess.value) {
      await reverseGeocode(lng.value, lat.value)
    }
    emit('confirm', {
      lat: lat.value,
      lng: lng.value,
      address: addressGuess.value,
      barangay: barangayGuess.value,
      city: cityGuess.value,
    })
    emit('update:modelValue', false)
  } finally {
    confirming.value = false
  }
}
</script>

<style scoped>
.room-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  max-height: 85vh;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
  background: var(--m-surface);
  overflow-y: auto;
}
.room-sheet--wizard {
  height: min(660px, 85vh);
}
.room-sheet--paged {
  overflow: hidden;
}
.room-sheet-scroll {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 12px;
  overflow-y: auto;
}
.sheet-grip {
  display: block;
  width: 40px;
  height: 4px;
  margin: 0 auto;
  border-radius: 999px;
  background: var(--m-border);
}
.sheet-header {
  display: flex;
  align-items: center;
  gap: 10px;
}
.sheet-header-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.room-sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.field {
  display: flex;
  flex: 1 1 130px;
  min-width: 130px;
  flex-direction: column;
  gap: 4px;
}
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.field-input {
  box-sizing: border-box;
  width: 100%;
  min-width: 0;
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.sec-hint {
  color: var(--m-muted);
  font-size: 12px;
}
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.facility-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .facility-row:first-child {
  border-top: 0;
}
.facility-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.facility-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.facility-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.facility-sub {
  color: var(--m-muted);
  font-size: 11.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.location-map-wrap {
  flex: 1;
  min-height: 220px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  overflow: hidden;
}
.location-map {
  width: 100%;
  height: 100%;
  min-height: 220px;
}
.photo-actions--pinned {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  flex: 0 0 auto;
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}
.photo-action-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.photo-action-btn:disabled {
  opacity: 0.6;
}
.wizard-nav {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  flex: 0 0 auto;
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}
.ghost-btn {
  flex: 0 0 auto;
  min-height: 46px;
  padding: 0 20px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.save-btn {
  min-height: 46px;
  font-weight: 700;
}
</style>
