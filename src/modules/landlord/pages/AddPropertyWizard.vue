<template>
  <q-page class="add-property-page">
    <div class="page-wrapper">
      <div class="wizard-container">
    <!-- Header Section -->
    <div class="wizard-header">
      <div class="header-left">
        <div class="icon-circle">
          <q-icon name="apartment" size="28px" color="teal-8" />
        </div>
        <div class="header-text">
          <div class="wizard-title">Add New Property</div>
          <div class="wizard-subtitle">
            {{ currentStep === 1 ? 'Step 1 of 2 — Basic Info' : 'Step 2 of 2 — Amenities & Rules' }}
          </div>
        </div>
      </div>
      <q-btn flat round dense icon="close" color="grey-7" @click="handleClose" />
    </div>

    <!-- Step Indicator -->
    <div class="step-indicator">
      <div class="step-item" :class="{ active: currentStep >= 1, completed: currentStep > 1 }">
        <div class="step-circle">1</div>
      </div>
      <div class="step-line" :class="{ active: currentStep > 1 }" />
      <div class="step-item" :class="{ active: currentStep >= 2 }">
        <div class="step-circle">2</div>
      </div>
    </div>

    <!-- Content Section -->
    <div class="wizard-content">
      <!-- Step 1: Basic Info -->
      <div v-if="currentStep === 1" class="step-1-content">
        <!-- Property Name -->
        <div class="form-field">
          <label class="field-label">Property Name <span class="required">*</span></label>
          <q-input
            v-model="form.propertyName"
            outlined
            dense
            placeholder="e.g. Pinzon Student Hub"
            class="custom-input"
            :error="!!nameError"
            :error-message="nameError"
            @update:model-value="clearNameError"
          />
        </div>

        <!-- Property Type Toggle -->
        <div class="form-field">
          <label class="field-label">Room Type <span class="required">*</span></label>
          <div class="toggle-group">
            <button
              v-for="type in propertyTypes"
              :key="type"
              class="toggle-pill"
              :class="{ active: form.propertyType === type }"
              @click="form.propertyType = type"
            >
              {{ type }}
            </button>
          </div>
        </div>

        <!-- Full Address -->
        <div class="form-field">
          <label class="field-label">Full Address <span class="required">*</span></label>
          <q-input
            v-model="form.address"
            outlined
            dense
            placeholder="Blk, Purok, Brgy, Municipality, Province"
            class="custom-input"
            :error="!!addressError"
            :error-message="addressError"
            @update:model-value="clearAddressError"
          >
            <template #prepend>
              <q-icon name="location_on" color="grey-7" />
            </template>
          </q-input>
        </div>

          <!-- Property Location (Map) -->
          <div class="form-field">
            <label class="field-label">Property Location <span class="required">*</span></label>
            <div
              v-if="mapAvailable"
              id="property-map"
              ref="mapContainer"
              class="property-map"
            />
            <q-banner v-else class="bg-grey-2 text-grey-8 rounded-borders">
              <template #avatar>
                <q-icon name="map" />
              </template>
              Map preview is not available on this deployment. You can still set the location with "Use my location".
            </q-banner>
          <div class="map-actions q-mt-sm">
            <q-btn
              unelevated
              color="teal-8"
              text-color="white"
              icon="my_location"
              label="Use my location"
              size="sm"
              @click="useMyLocation"
            />
            <span v-if="form.latitude && form.longitude" class="coords-text">
              Lat: {{ form.latitude?.toFixed(5) }}, Lng: {{ form.longitude?.toFixed(5) }}
            </span>
            <span v-else class="coords-hint">Tap the map to drop a pin</span>
          </div>
          <q-banner v-if="locationError" class="bg-red-1 text-red-8 rounded-borders q-mt-sm">
            <template #avatar>
              <q-icon name="error_outline" />
            </template>
            {{ locationError }}
          </q-banner>
          <q-banner v-if="mapError" class="bg-red-1 text-red-8 rounded-borders q-mt-sm">
            <template #avatar>
              <q-icon name="error_outline" />
            </template>
            {{ mapError }}
          </q-banner>
        </div>



        <!-- Description -->
        <div class="form-field">
          <label class="field-label">Description <span class="required">*</span></label>
          <q-input
            v-model="form.description"
            outlined
            type="textarea"
            rows="4"
            placeholder="Tell us about your property..."
            class="custom-input"
            :error="!!descriptionError"
            :error-message="descriptionError"
            @update:model-value="clearDescriptionError"
          />
        </div>

        <!-- Pricing & Capacity -->
        <div class="form-field">
          <label class="field-label">Monthly Rent (₱) <span class="required">*</span></label>
          <q-input
            v-model="form.monthlyRent"
            outlined
            dense
            type="number"
            prefix="₱"
            placeholder="e.g. 3500"
            class="custom-input"
            :error="!!monthlyRentError"
            :error-message="monthlyRentError"
            @update:model-value="clearMonthlyRentError"
          />
        </div>

        <div class="two-column-row">
          <div class="form-field">
            <label class="field-label">Total Rooms <span class="required">*</span></label>
            <q-input
              v-model="form.totalRooms"
              outlined
              dense
              type="number"
              placeholder="e.g. 6"
              class="custom-input"
              :error="!!totalRoomsError"
              :error-message="totalRoomsError"
              @update:model-value="clearTotalRoomsError"
            />
          </div>
          <div class="form-field">
            <label class="field-label">Capacity <span class="required">*</span></label>
            <q-input
              v-model="form.capacity"
              outlined
              dense
              type="number"
              placeholder="e.g. 12"
              class="custom-input"
              :error="!!capacityError"
              :error-message="capacityError"
              @update:model-value="clearCapacityError"
            />
          </div>
        </div>


      </div>

        <!-- Step 2: Amenities & Rules -->
      <div v-if="currentStep === 2" class="step-2-content">
        <!-- Amenities Section -->
        <div class="form-section">
          <div class="section-title">Amenities Included</div>
          <div class="amenities-grid">
            <button
              v-for="amenity in amenitiesOptions"
              :key="amenity"
              class="amenity-button"
              :class="{ active: form.amenities.includes(amenity) }"
              @click="toggleAmenity(amenity)"
            >
              <q-icon :name="getAmenityIcon(amenity)" size="24px" />
              <div class="amenity-label">{{ amenity.charAt(0).toUpperCase() + amenity.slice(1) }}</div>
            </button>
          </div>
        </div>

        <!-- House Rules Section -->
        <div class="form-section q-mt-lg">
          <div class="section-title">House Rules</div>

          <!-- Rules List -->
          <div v-if="form.rules.length > 0" class="rules-list">
            <div v-for="(rule, index) in form.rules" :key="index" class="rule-item">
              <q-icon name="description" color="grey-6" size="18px" />
              <span class="rule-text">{{ rule }}</span>
              <q-btn
                flat
                round
                dense
                icon="delete_outline"
                size="sm"
                color="red-6"
                @click="deleteRule(index)"
              />
            </div>
          </div>

          <!-- Add Rule Input -->
          <div class="add-rule-row">
            <q-input
              v-model="newRule"
              outlined
              dense
              placeholder="Add a house rule..."
              class="custom-input rule-input"
              @keyup.enter="addRule"
            />
            <q-btn
              unelevated
              color="teal-8"
              text-color="white"
              label="Add"
              @click="addRule"
              class="add-rule-btn"
            />
          </div>
        </div>

        <!-- Photos Section -->
        <div class="form-section q-mt-lg">
          <div class="section-title">Photos <span class="required-hint">(optional but recommended)</span></div>

          <div class="photo-dropzone" :class="{ 'has-error': !!imageError }" @click="triggerPhotoInput">
            <q-icon name="cloud_upload" size="32px" color="teal-8" />
            <div class="photo-drop-text">Tap to add photos of your property</div>
            <div class="photo-drop-sub">JPG, PNG or WebP · up to 3MB each · max {{ maxPhotos }}</div>
          </div>
          <input
            ref="photoInput"
            type="file"
            accept="image/*"
            multiple
            hidden
            @change="onPhotosSelected"
          />

          <div v-if="imageError" class="photo-error">{{ imageError }}</div>

          <div v-if="form.images.length" class="photo-grid">
            <div v-for="(img, idx) in form.images" :key="idx" class="photo-thumb">
              <img :src="img.dataUrl" class="photo-img" alt="property photo" />
              <q-btn
                round
                dense
                flat
                icon="close"
                size="xs"
                color="white"
                class="photo-remove"
                @click.stop="removeImage(idx)"
              />
            </div>
          </div>
          <div v-else class="muted-text q-mt-sm">No photos added yet.</div>
        </div>
      </div>
    </div>

    <!-- Footer Section -->
    <div class="wizard-footer">
      <q-btn
        v-if="currentStep === 1"
        flat
        color="grey-8"
        label="Cancel"
        @click="handleClose"
        class="footer-btn"
      />
      <q-btn
        v-if="currentStep === 1"
        unelevated
        color="teal-8"
        text-color="white"
        label="Next"
        icon-right="arrow_forward"
        @click="goNext"
        class="footer-btn action-btn"
      />
      <q-btn
        v-if="currentStep === 2"
        flat
        color="grey-8"
        label="Back"
        icon="arrow_back"
        @click="currentStep = 1"
        class="footer-btn"
      />
      <q-btn
        v-if="currentStep === 2"
        unelevated
        color="teal-8"
        text-color="white"
        label="Save Property"
        icon="check_circle"
        @click="handleSave"
        class="footer-btn action-btn"
      />
    </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useLandlordStore } from '@/stores/landlord'
import { isLocalDev } from '@/shared/utils/env'

interface PropertyFormData {
  propertyName: string
  propertyType: string
  address: string
  description: string
  monthlyRent: string
  totalRooms: string
  capacity: string
  amenities: string[]
  rules: string[]
  images: { file: File; dataUrl: string }[]
  latitude: number | null
  longitude: number | null
}

const router = useRouter()
const landlordStore = useLandlordStore()
const $q = useQuasar()

const currentStep = ref(1)

const form = ref<PropertyFormData>({
  propertyName: '',
  propertyType: 'solo',
  address: '',
  description: '',
  monthlyRent: '',
  totalRooms: '',
  capacity: '',
  amenities: [],
  rules: ['No overnight visitors', 'No smoking inside'],
  images: [],
  latitude: null,
  longitude: null,
})

const newRule = ref('')

// --- Validation for required fields ---
const nameError = ref('')
const addressError = ref('')
const locationError = ref('')
const descriptionError = ref('')

const monthlyRentError = ref('')
const totalRoomsError = ref('')
const capacityError = ref('')

function validateStep1(): boolean {
  const f = form.value
  nameError.value = f.propertyName.trim() ? '' : 'Property name is required'
  addressError.value = f.address.trim() ? '' : 'Full address is required'
  // Property location is optional — the map may be unavailable (e.g. Mapbox
  // token URL restriction), so never block the wizard on it.
  locationError.value = ''
  descriptionError.value = f.description.trim() ? '' : 'Description is required'
  monthlyRentError.value = f.monthlyRent.trim() ? '' : 'Monthly rent is required'
  totalRoomsError.value = f.totalRooms.trim() ? '' : 'Total rooms is required'
  capacityError.value = f.capacity.trim() ? '' : 'Capacity is required'
  return (
    !nameError.value &&
    !addressError.value &&
    !descriptionError.value &&
    !monthlyRentError.value &&
    !totalRoomsError.value &&
    !capacityError.value
  )
}

function clearNameError() {
  if (nameError.value) nameError.value = ''
}
function clearAddressError() {
  if (addressError.value) addressError.value = ''
}
function clearLocationError() {
  if (locationError.value) locationError.value = ''
}
function clearDescriptionError() {
  if (descriptionError.value) descriptionError.value = ''
}
function clearMonthlyRentError() {
  if (monthlyRentError.value) monthlyRentError.value = ''
}
function clearTotalRoomsError() {
  if (totalRoomsError.value) totalRoomsError.value = ''
}
function clearCapacityError() {
  if (capacityError.value) capacityError.value = ''
}

const propertyTypes = ['solo', 'duo', 'triple', 'bedspace', 'studio']

const amenitiesOptions = ['wifi', 'water', 'electric', 'aircon']

// --- Mapbox GL JS map picker ---
// Temporary: Mapbox is disabled outside localhost until the token's URL
// restriction is configured for the deployed domain. Remove this gate once the
// Mapbox token allows the live site URL.
const mapAvailable = isLocalDev()
const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined
const mapContainer = ref<HTMLElement | null>(null)
const mapError = ref<string | null>(null)
let map: any = null
let marker: any = null
let mapInitTries = 0
let mapErrorReported = false
const DEFAULT_CENTER: [number, number] = [123.8854, 10.3157] // [lng, lat] Cebu City

function setMarker(lng: number, lat: number) {
  form.value.longitude = lng
  form.value.latitude = lat
  clearLocationError()
  const mapboxgl = (window as any).mapboxgl
  if (!mapboxgl || !map) return
  if (marker) {
    marker.setLngLat([lng, lat])
  } else {
    marker = new mapboxgl.Marker().setLngLat([lng, lat]).addTo(map)
  }
}

function initMap() {
  if (!mapAvailable) return
  if (!mapContainer.value) return
  const mapboxgl = (window as any).mapboxgl
  if (!mapboxgl) {
    mapInitTries += 1
    if (mapInitTries > 20) {
      mapError.value = 'Map could not be loaded. Check your connection.'
      return
    }
    setTimeout(initMap, 300)
    return
  }
  if (!MAPBOX_TOKEN) {
    mapError.value = 'Mapbox token is not configured. Set VITE_MAPBOX_TOKEN in your .env.local.'
    return
  }
  mapError.value = null
  try {
    mapboxgl.accessToken = MAPBOX_TOKEN
    map = new mapboxgl.Map({
      container: mapContainer.value,
      style: 'mapbox://styles/mapbox/streets-v12',
      center: DEFAULT_CENTER,
      zoom: 13,
    })

    map.on('click', (e: any) => {
      setMarker(e.lngLat.lng, e.lngLat.lat)
    })

    map.on('load', () => {
      if (form.value.latitude && form.value.longitude) {
        map.setCenter([form.value.longitude, form.value.latitude])
        setMarker(form.value.longitude, form.value.latitude)
      }
    })

    // Surface real Mapbox errors (token/style/network) instead of a silent blank map.
    map.on('error', (e: any) => {
      if (!mapErrorReported) {
        mapErrorReported = true
        console.error('[Mapbox error event]', e)
      }
      const status = e?.error?.status
      let msg = e?.error?.message || e?.message || ''
      if (!msg) {
        msg = status === 401
          ? 'Mapbox token is not allowed on this website. Add your site URL in the Mapbox token URL restrictions.'
          : 'Unknown map error (see console for details)'
      }
      if (!mapError.value) mapError.value = 'Map error: ' + msg
    })

    setTimeout(() => map && map.resize(), 200)
  } catch (e: any) {
    mapError.value = 'Failed to initialize map: ' + (e?.message ?? e)
  }
}

function useMyLocation() {
  if (!navigator.geolocation) {
    mapError.value =
      'Geolocation is not supported on this device/browser. Tap the map to drop a pin instead.'
    return
  }
  mapError.value = null

  const onSuccess = (pos: any) => {
    const lng = pos.coords.longitude
    const lat = pos.coords.latitude
    if (map) map.flyTo({ center: [lng, lat], zoom: 16 })
    setMarker(lng, lat)
  }

  const onError = (err: any) => {
    let msg = 'Could not get your location. '
    if (err?.code === 1) {
      msg +=
        'Permission was denied. On iPhone, open Settings → Safari → Location and set this site to "Allow", then try again. ' +
        'You can also just tap the map to drop a pin.'
    } else if (err?.code === 2) {
      msg +=
        'Your location is currently unavailable. Make sure Location Services is on, or tap the map to drop a pin.'
    } else if (err?.code === 3) {
      msg += 'The request timed out. Try again, or tap the map to drop a pin manually.'
    } else {
      msg += err?.message || 'Unknown error.'
    }
    mapError.value = msg
  }

  // Try high-accuracy first; if it times out / is unavailable, retry with coarse accuracy.
  navigator.geolocation.getCurrentPosition(onSuccess, (err) => {
    if (err?.code === 3 || err?.code === 2) {
      navigator.geolocation.getCurrentPosition(onSuccess, onError, {
        enableHighAccuracy: false,
        timeout: 15000,
        maximumAge: 60000,
      })
    } else {
      onError(err)
    }
  }, { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 })
}

onMounted(() => {
  initMap()
})

// Re-bind the map when returning to Step 1. The map lives inside a v-if step,
// so leaving and re-entering Step 1 recreates the container <div>; the old
// `map` would still point at the detached node and render blank. Rebuild it.
watch(currentStep, (step) => {
  if (step === 1) {
    const detached =
      !map || !map.getContainer || !map.getContainer() || !map.getContainer().isConnected
    if (detached) {
      marker = null
      mapInitTries = 0
      map = null
      nextTick(() => initMap())
    } else {
      setTimeout(() => map && map.resize(), 200)
    }
  }
})

function getAmenityIcon(amenity: string): string {
const icons: Record<string, string> = {
  wifi: 'wifi',
  water: 'water_drop',
  electric: 'electric_bolt',
  aircon: 'ac_unit',
}
  return icons[amenity] || 'help'
}

function toggleAmenity(amenity: string) {
  const index = form.value.amenities.indexOf(amenity)
  if (index > -1) {
    form.value.amenities.splice(index, 1)
  } else {
    form.value.amenities.push(amenity)
  }
}

function addRule() {
  if (newRule.value.trim()) {
    form.value.rules.push(newRule.value.trim())
    newRule.value = ''
  }
}

function deleteRule(index: number) {
  form.value.rules.splice(index, 1)
}

// --- Photo upload (stored as data URLs; no storage bucket change) ---
const maxPhotos = 6
const imageError = ref('')
const photoInput = ref<HTMLInputElement | null>(null)

function triggerPhotoInput() {
  photoInput.value?.click()
}

function validatePhotoFile(file: File): string | null {
  const allowed = ['image/jpeg', 'image/png', 'image/webp']
  if (!allowed.includes(file.type)) return 'Only JPG, PNG or WebP images are allowed.'
  if (file.size > 3 * 1024 * 1024) return 'Each photo must be under 3MB.'
  return null
}

function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })
}

async function onPhotosSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files || [])
  imageError.value = ''
  for (const file of files) {
    if (form.value.images.length >= maxPhotos) {
      imageError.value = `You can upload up to ${maxPhotos} photos.`
      break
    }
    const err = validatePhotoFile(file)
    if (err) {
      imageError.value = err
      continue
    }
    try {
      const dataUrl = await fileToDataUrl(file)
      form.value.images.push({ file, dataUrl })
    } catch {
      imageError.value = 'Failed to read one of the images.'
    }
  }
  input.value = ''
}

function removeImage(idx: number) {
  form.value.images.splice(idx, 1)
  imageError.value = ''
}

function handleClose() {
  void router.push('/landlord/properties')
}

function goNext() {
  if (validateStep1()) {
    currentStep.value = 2
  }
}

async function handleSave() {
  mapError.value = null
  if (!validateStep1()) {
    currentStep.value = 1
    return
  }
  try {
    const ok = await landlordStore.addProperty({
      name: form.value.propertyName,
      roomType: form.value.propertyType,
      propertyType: form.value.propertyType,
        address: form.value.address,
        description: form.value.description,
        monthlyRent: form.value.monthlyRent,
        totalRooms: form.value.totalRooms,
        capacity: form.value.capacity,
        amenities: form.value.amenities,
      rules: form.value.rules,
      images: form.value.images,
      latitude: form.value.latitude,
      longitude: form.value.longitude,
    })
    if (ok) {
      $q.notify({
        type: 'positive',
        message: 'Property added successfully',
        icon: 'check_circle',
        timeout: 2500,
      })
      void router.push('/landlord/properties')
    } else {
      const msg = 'Failed to save property. Please sign in and try again.'
      mapError.value = msg
      $q.notify({ type: 'negative', message: msg, icon: 'error' })
    }
  } catch (e: any) {
    const msg = e?.message ?? 'Failed to save property'
    mapError.value = msg
    $q.notify({ type: 'negative', message: msg, icon: 'error' })
  }
}
</script>

<style scoped>
.add-property-page {
  background: linear-gradient(135deg, #f0f9f8 0%, #f3f4f6 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 20px;
}

.page-wrapper {
  width: 100%;
  max-width: 600px;
}

.wizard-container {
  background: white;
  border-radius: 20px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
}

/* Header */
.wizard-header {
  background: white;
  padding: 20px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.header-left {
  display: flex;
  gap: 12px;
  flex: 1;
}

.icon-circle {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: rgba(0, 137, 123, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.header-text {
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.wizard-title {
  color: #111827;
  font-size: 18px;
  font-weight: 800;
  line-height: 1.2;
}

.wizard-subtitle {
  color: #6b7280;
  font-size: 12px;
  font-weight: 600;
  margin-top: 2px;
}

/* Step Indicator */
.step-indicator {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 20px;
}

.step-item {
  display: flex;
  align-items: center;
  justify-content: center;
}

.step-circle {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: 2px solid #d1d5db;
  background: white;
  color: #6b7280;
  font-size: 14px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
}

.step-item.active .step-circle {
  border-color: #00897b;
  background: #00897b;
  color: white;
}

.step-item.completed .step-circle {
  border-color: #00897b;
  background: #00897b;
  color: white;
}

.step-line {
  width: 60px;
  height: 2px;
  background: #d1d5db;
  transition: all 0.3s ease;
}

.step-line.active {
  background: #00897b;
}

/* Content Section */
.wizard-content {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
}

.step-1-content,
.step-2-content {
  animation: fadeIn 0.3s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.form-field {
  margin-bottom: 16px;
}

.field-label {
  display: block;
  color: #111827;
  font-size: 13px;
  font-weight: 700;
  margin-bottom: 6px;
}

.required {
  color: #e53935;
}

.custom-input {
  border-radius: 10px;
}

.custom-input :deep(.q-field__control) {
  padding: 10px 12px;
  font-size: 14px;
}

.custom-input :deep(.q-field__native) {
  padding: 8px 0;
}

/* Toggle Group */
.toggle-group {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.toggle-pill {
  padding: 8px 14px;
  border: 1.5px solid #d1d5db;
  background: white;
  color: #374151;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.toggle-pill:hover {
  border-color: #9ca3af;
}

.toggle-pill.active {
  border-color: #00897b;
  color: #00897b;
  background: rgba(0, 137, 123, 0.05);
}

/* Two Column Row */
.two-column-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

/* Map Picker */
.property-map {
  width: 100%;
  height: 280px;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  overflow: hidden;
  position: relative;
  z-index: 1;
}

.map-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.coords-text {
  color: #00897b;
  font-size: 12px;
  font-weight: 700;
}

.coords-hint {
  color: #6b7280;
  font-size: 12px;
  font-weight: 500;
}

/* Form Section */
.form-section {
  margin-bottom: 20px;
}

.section-title {
  color: #111827;
  font-size: 14px;
  font-weight: 800;
  margin-bottom: 12px;
}

/* Amenities Grid */
.amenities-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.amenity-button {
  padding: 16px 12px;
  border: 1.5px solid #d1d5db;
  background: white;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  color: #374151;
}

.amenity-button:hover {
  border-color: #9ca3af;
}

.amenity-button.active {
  border-color: #00897b;
  background: rgba(0, 137, 123, 0.08);
  color: #00897b;
}

.amenity-label {
  font-size: 12px;
  font-weight: 600;
}

/* Rules List */
.rules-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 16px;
}

.rule-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px;
  background: #f3f4f6;
  border-radius: 10px;
}

.rule-text {
  flex: 1;
  color: #374151;
  font-size: 13px;
  font-weight: 500;
}

/* Add Rule Row */
.add-rule-row {
  display: flex;
  gap: 8px;
}

.rule-input {
  flex: 1;
}

.add-rule-btn {
  border-radius: 10px;
  padding: 0 16px;
  font-weight: 600;
}

.required-hint {
  color: #6b7280;
  font-size: 11px;
  font-weight: 600;
}

.muted-text {
  color: #9ca3af;
  font-size: 13px;
  font-style: italic;
}

/* Photo upload */
.photo-dropzone {
  border: 2px dashed #d1d5db;
  border-radius: 14px;
  padding: 24px;
  text-align: center;
  cursor: pointer;
  background: #f9fafb;
  transition: all 0.2s ease;
}

.photo-dropzone:hover {
  border-color: #00897b;
  background: rgba(0, 137, 123, 0.04);
}

.photo-dropzone.has-error {
  border-color: #e53935;
}

.photo-drop-text {
  color: #111827;
  font-size: 14px;
  font-weight: 700;
  margin-top: 8px;
}

.photo-drop-sub {
  color: #6b7280;
  font-size: 12px;
  margin-top: 2px;
}

.photo-error {
  color: #e53935;
  font-size: 12px;
  font-weight: 600;
  margin-top: 8px;
}

.photo-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-top: 12px;
}

.photo-thumb {
  position: relative;
  aspect-ratio: 1 / 1;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.1);
}

.photo-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.photo-remove {
  position: absolute;
  top: 4px;
  right: 4px;
  background: rgba(0, 0, 0, 0.55);
}

/* Footer */
.wizard-footer {
  padding: 16px 20px;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
  display: flex;
  gap: 10px;
  justify-content: flex-end;
  background: white;
}

.footer-btn {
  border-radius: 10px;
  font-weight: 600;
  padding: 8px 16px;
  min-width: 100px;
}

.action-btn {
  min-width: 140px;
}
</style>
