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
          <label class="field-label">Property Name</label>
          <q-input
            v-model="form.propertyName"
            outlined
            dense
            placeholder="e.g. Pinzon Student Hub"
            class="custom-input"
          />
        </div>

        <!-- Property Type Toggle -->
        <div class="form-field">
          <label class="field-label">Room Type</label>
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
          <label class="field-label">Full Address</label>
          <q-input
            v-model="form.address"
            outlined
            dense
            placeholder="Blk, Purok, Brgy, Municipality, Province"
            class="custom-input"
          >
            <template #prepend>
              <q-icon name="location_on" color="grey-7" />
            </template>
          </q-input>
        </div>

        <!-- Property Location (Map) -->
        <div class="form-field">
          <label class="field-label">Property Location</label>
          <div
            id="property-map"
            ref="mapContainer"
            class="property-map"
          />
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
          <q-banner v-if="mapError" class="bg-red-1 text-red-8 rounded-borders q-mt-sm">
            <template #avatar>
              <q-icon name="error_outline" />
            </template>
            {{ mapError }}
          </q-banner>
        </div>

        <!-- Contact No and Email Row -->
        <div class="two-column-row">
          <div class="form-field">
            <label class="field-label">Contact No</label>
            <q-input
              v-model="form.contactNo"
              outlined
              dense
              placeholder="+63 9XX XXX XXXX"
              class="custom-input"
              :error="!!contactError"
              :error-message="contactError"
              @update:model-value="clearContactError"
            >
              <template #prepend>
                <q-icon name="phone" color="grey-7" />
              </template>
            </q-input>
          </div>
          <div class="form-field">
            <label class="field-label">Email</label>
            <q-input
              v-model="form.email"
              outlined
              dense
              placeholder="your@email.com"
              class="custom-input"
              :error="!!emailError"
              :error-message="emailError"
              @update:model-value="clearEmailError"
            >
              <template #prepend>
                <q-icon name="mail" color="grey-7" />
              </template>
            </q-input>
          </div>
        </div>

        <!-- Description -->
        <div class="form-field">
          <label class="field-label">Description</label>
          <q-input
            v-model="form.description"
            outlined
            type="textarea"
            rows="4"
            placeholder="Tell us about your property..."
            class="custom-input"
          />
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
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useLandlordStore } from '@/stores/landlord'

interface PropertyFormData {
  propertyName: string
  propertyType: string
  address: string
  contactNo: string
  email: string
  description: string
  amenities: string[]
  rules: string[]
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
  contactNo: '',
  email: '',
  description: '',
  amenities: [],
  rules: ['No overnight visitors', 'No smoking inside'],
  latitude: null,
  longitude: null,
})

const newRule = ref('')

// --- Validation for contact number and email ---
const contactError = ref('')
const emailError = ref('')

function validateContactNo(value: string): boolean {
  const digits = value.replace(/\D/g, '')
  if (digits.startsWith('63')) return digits.length === 12 && digits[2] === '9'
  if (digits.startsWith('0')) return digits.length === 11 && digits[1] === '9'
  return false
}

function validateEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())
}

function validateStep1(): boolean {
  contactError.value = form.value.contactNo.trim()
    ? validateContactNo(form.value.contactNo)
      ? ''
      : 'Enter a valid PH number, e.g. +63 9XX XXX XXXX or 09XX XXX XXXX'
    : 'Contact number is required'
  emailError.value = form.value.email.trim()
    ? validateEmail(form.value.email)
      ? ''
      : 'Enter a valid email address'
    : 'Email is required'
  return !contactError.value && !emailError.value
}

function clearContactError() {
  if (contactError.value) contactError.value = ''
}

function clearEmailError() {
  if (emailError.value) emailError.value = ''
}

const propertyTypes = ['solo', 'duo', 'triple', 'bedspace', 'studio']

const amenitiesOptions = ['wifi', 'water', 'electric', 'aircon']

// --- Mapbox GL JS map picker ---
const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined
const mapContainer = ref<HTMLElement | null>(null)
const mapError = ref<string | null>(null)
let map: any = null
let marker: any = null
let mapInitTries = 0
const DEFAULT_CENTER: [number, number] = [123.8854, 10.3157] // [lng, lat] Cebu City

function setMarker(lng: number, lat: number) {
  form.value.longitude = lng
  form.value.latitude = lat
  const mapboxgl = (window as any).mapboxgl
  if (!mapboxgl || !map) return
  if (marker) {
    marker.setLngLat([lng, lat])
  } else {
    marker = new mapboxgl.Marker().setLngLat([lng, lat]).addTo(map)
  }
}

function initMap() {
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

    setTimeout(() => map && map.resize(), 200)
  } catch (e: any) {
    mapError.value = 'Failed to initialize map: ' + (e?.message ?? e)
  }
}

function useMyLocation() {
  if (!navigator.geolocation) {
    mapError.value = 'Geolocation is not supported on this device'
    return
  }
  mapError.value = null
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      const lng = pos.coords.longitude
      const lat = pos.coords.latitude
      if (map) map.flyTo({ center: [lng, lat], zoom: 16 })
      setMarker(lng, lat)
    },
    (err) => {
      mapError.value = 'Could not get your location: ' + err.message
    },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

onMounted(() => {
  initMap()
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
      contactNo: form.value.contactNo,
      email: form.value.email,
      amenities: form.value.amenities,
      rules: form.value.rules,
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
