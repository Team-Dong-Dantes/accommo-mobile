<template>
  <q-page class="property-detail-page">
    <div class="page-wrapper">
      <div class="detail-container">
        <!-- Header -->
        <div class="detail-header">
          <q-btn flat round dense icon="arrow_back" color="teal-8" @click="goBack" />
          <div class="header-text">
            <div class="detail-title">{{ property?.name || 'Property' }}</div>
            <div class="detail-subtitle">Property Details</div>
          </div>
          <q-badge
            v-if="property"
            :color="property.status === 'active' ? 'teal-8' : 'orange-6'"
            text-color="white"
            class="status-badge"
          >
            {{ property.status === 'active' ? 'Active' : 'Pending' }}
          </q-badge>
        </div>

        <div v-if="isLoading" class="text-center q-pa-lg">
          <q-spinner size="50px" color="teal-8" />
          <div class="text-grey-7 q-mt-md">Loading property…</div>
        </div>

        <div v-else-if="loadError" class="q-pa-lg">
          <q-banner class="bg-red-1 text-red-8 rounded-borders">
            <template #avatar>
              <q-icon name="error_outline" />
            </template>
            {{ loadError }}
          </q-banner>
        </div>

        <div v-else-if="property" class="detail-content">
          <!-- Photo Gallery -->
          <div v-if="images.length" class="gallery-section">
            <img :src="images[activeImageIndex]" class="gallery-main" alt="Property photo" />
            <div v-if="images.length > 1" class="gallery-thumbs">
              <img
                v-for="(src, i) in images"
                :key="i"
                :src="src"
                class="gallery-thumb"
                :class="{ active: i === activeImageIndex }"
                @click="activeImageIndex = i"
                alt="Property thumbnail"
              />
            </div>
          </div>

          <!-- Location Map -->
          <div
            v-if="mapAvailable"
            id="detail-map"
            ref="detailMapContainer"
            class="detail-map"
          />
          <q-banner v-else class="bg-grey-2 text-grey-8 rounded-borders">
            <template #avatar>
              <q-icon name="map" />
            </template>
            Map preview is not available on this deployment.
          </q-banner>

          <!-- Basic Info -->
          <div class="info-section">
            <div class="info-row">
              <span class="info-label">Type</span>
              <span class="info-value">{{ property.room_type || '—' }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Address</span>
              <span class="info-value">{{ property.address || '—' }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Contact No</span>
              <span class="info-value">{{ property.landlord_phone || '—' }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Email</span>
              <span class="info-value">{{ property.landlord_email || '—' }}</span>
            </div>
          </div>

          <!-- Description -->
          <div v-if="property.description" class="info-block">
            <div class="section-title">Description</div>
            <div class="description-text">{{ property.description }}</div>
          </div>

          <!-- Amenities -->
          <div class="info-block">
            <div class="section-title">Amenities</div>
            <div v-if="amenitiesList.length" class="chips-row">
              <q-badge
                v-for="a in amenitiesList"
                :key="a"
                color="teal-1"
                text-color="teal-8"
                class="info-chip"
              >
                {{ a }}
              </q-badge>
            </div>
            <div v-else class="muted-text">No amenities listed</div>
          </div>

          <!-- House Rules -->
          <div class="info-block">
            <div class="section-title">House Rules</div>
            <ul v-if="rulesList.length" class="rules-ul">
              <li v-for="(r, i) in rulesList" :key="i">{{ r }}</li>
            </ul>
            <div v-else class="muted-text">No house rules listed</div>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

interface PropertyDetail {
  id: string
  name: string
  property_type: string | null
  room_type: string | null
  address: string | null
  status: string
  description: string | null
  landlord_phone: string | null
  landlord_email: string | null
  amenities: string[]
  rules: string[]
  images: string[]
  lat: number | null
  lng: number | null
}

const route = useRoute()
const router = useRouter()

const property = ref<PropertyDetail | null>(null)
const isLoading = ref(false)
const loadError = ref<string | null>(null)
const detailMapContainer = ref<HTMLElement | null>(null)
let map: any = null
let marker: any = null
const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined
const mapAvailable = true

const amenitiesList = computed<string[]>(() => {
  const a = property.value?.amenities
  if (Array.isArray(a)) return a.map((x: any) => String(x))
  if (typeof a === 'string' && a) return [a]
  return []
})

const rulesList = computed<string[]>(() => {
  const r = property.value?.rules
  if (Array.isArray(r)) return r.map((x: any) => String(x))
  if (typeof r === 'string' && r) return [r]
  return []
})

const images = computed<string[]>(() => property.value?.images || [])
const activeImageIndex = ref(0)

async function fetchProperty() {
  isLoading.value = true
  loadError.value = null
  try {
    const id = route.params.id as string

    const { data: p, error } = await supabase
      .from('properties')
      .select('id, name, property_type, room_type, address, description, lat, lng, status, landlord_id')
      .eq('id', id)
      .single()
    if (error) throw error

    const [amenRes, polRes, usrRes, imgRes] = await Promise.all([
      supabase.from('property_amenities').select('amenity').eq('property_id', id),
      supabase.from('property_policies').select('house_rules_json').eq('property_id', id).maybeSingle(),
      supabase.from('users').select('phone, email').eq('id', p.landlord_id).maybeSingle(),
      supabase
        .from('property_images')
        .select('url, sort_order')
        .eq('property_id', id)
        .order('sort_order', { ascending: true }),
    ])

    const imageList = (imgRes.data || []).map((row: any) => row.url as string)
    activeImageIndex.value = 0

    property.value = {
      ...p,
      landlord_phone: usrRes.data?.phone ?? null,
      landlord_email: usrRes.data?.email ?? null,
      amenities: (amenRes.data || []).map((a: any) => a.amenity),
      rules: (polRes.data?.house_rules_json as string[]) || [],
      images: imageList,
    } as PropertyDetail
  } catch (e: any) {
    loadError.value = e?.message || 'Failed to load property'
  } finally {
    isLoading.value = false
  }
}

function initMap(tries = 0) {
  if (!mapAvailable) return
  const mapboxgl = (window as any).mapboxgl
  if (!mapboxgl) {
    if (tries < 20) setTimeout(() => initMap(tries + 1), 300)
    return
  }
  if (!detailMapContainer.value || !property.value) return
  if (!MAPBOX_TOKEN) return
  try {
    mapboxgl.accessToken = MAPBOX_TOKEN
    const hasCoords = !!property.value.lat && !!property.value.lng
    const center: [number, number] = hasCoords
      ? [property.value.lng as number, property.value.lat as number]
      : [123.8854, 10.3157]
    map = new mapboxgl.Map({
      container: detailMapContainer.value,
      style: 'mapbox://styles/mapbox/streets-v12',
      center,
      zoom: hasCoords ? 15 : 12,
    })
    if (hasCoords) {
      marker = new mapboxgl.Marker()
        .setLngLat([property.value.lng as number, property.value.lat as number])
        .addTo(map)
    }
    setTimeout(() => map && map.resize(), 200)
  } catch (e) {
    // Map is non-critical on the detail view; ignore init errors.
  }
}

function goBack() {
  void router.push('/landlord/properties')
}

onMounted(() => {
  void fetchProperty().then(() => initMap())
})
</script>

<style scoped>
.property-detail-page {
  background: #f4f5f7;
  min-height: 100vh;
  padding: 20px;
}

.page-wrapper {
  width: 100%;
  max-width: 600px;
  margin: 0 auto;
}

.detail-container {
  background: white;
  border-radius: 20px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.detail-header {
  background: white;
  padding: 20px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  display: flex;
  align-items: center;
  gap: 12px;
}

.header-text {
  flex: 1;
}

.detail-title {
  color: #111827;
  font-size: 18px;
  font-weight: 800;
  line-height: 1.2;
}

.detail-subtitle {
  color: #6b7280;
  font-size: 12px;
  font-weight: 600;
  margin-top: 2px;
}

.status-badge {
  border-radius: 20px;
  font-size: 10px;
  font-weight: 700;
  padding: 5px 10px;
}

.detail-map {
  width: 100%;
  height: 220px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  position: relative;
  z-index: 1;
}

.gallery-section {
  background: #000;
}

.gallery-main {
  width: 100%;
  height: 280px;
  object-fit: cover;
  display: block;
}

.gallery-thumbs {
  display: flex;
  gap: 8px;
  padding: 10px;
  overflow-x: auto;
  background: #f4f5f7;
}

.gallery-thumb {
  width: 64px;
  height: 64px;
  object-fit: cover;
  border-radius: 8px;
  cursor: pointer;
  border: 2px solid transparent;
  flex-shrink: 0;
}

.gallery-thumb.active {
  border-color: #00897b;
}

.detail-content {
  padding: 20px;
}

.info-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 20px;
}

.info-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  padding-bottom: 10px;
}

.info-label {
  color: #6b7280;
  font-size: 13px;
  font-weight: 700;
}

.info-value {
  color: #111827;
  font-size: 13px;
  font-weight: 600;
  text-align: right;
  word-break: break-word;
}

.info-block {
  margin-bottom: 20px;
}

.section-title {
  color: #111827;
  font-size: 14px;
  font-weight: 800;
  margin-bottom: 10px;
}

.description-text {
  color: #374151;
  font-size: 14px;
  line-height: 1.5;
}

.chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.info-chip {
  border-radius: 20px;
  font-size: 11px;
  font-weight: 700;
  padding: 5px 10px;
}

.rules-ul {
  margin: 0;
  padding-left: 18px;
  color: #374151;
  font-size: 14px;
  line-height: 1.6;
}

.muted-text {
  color: #9ca3af;
  font-size: 13px;
  font-style: italic;
}
</style>
