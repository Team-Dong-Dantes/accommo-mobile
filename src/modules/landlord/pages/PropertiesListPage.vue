<template>
  <q-page class="properties-list-page bg-grey-1">
    <div class="list-view">
      <!-- Header -->
      <div class="header-section q-pa-lg">
        <div class="row items-center justify-between q-gutter-md">
          <div class="col">
            <div class="page-title">Boarding Houses</div>
            <div class="page-subtitle">
              {{ totalProperties }} properties · {{ totalAvailableRooms }} rooms available
            </div>
          </div>
           <div class="col-auto row items-center q-gutter-sm">
             <q-btn
               unelevated
               rounded
               color="teal-8"
               text-color="white"
               label="Add"
               icon-right="add"
               @click="goToAddProperty"
               class="add-property-btn"
             />
           </div>
        </div>
      </div>

      <!-- Search Bar -->
      <div class="search-section q-px-lg q-pb-md">
        <q-input
          v-model="searchText"
          outlined
          dense
          bg-color="white"
          placeholder="Search properties..."
          class="search-input"
        >
          <template #prepend>
            <q-icon name="search" color="grey-7" />
          </template>
        </q-input>
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="text-center q-pa-lg">
        <q-spinner size="50px" color="teal-8" />
        <div class="text-grey-7 q-mt-md">Loading properties...</div>
      </div>

      <!-- Error State -->
      <div v-if="loadError" class="q-pa-lg">
        <q-banner class="bg-red-1 text-red-8 rounded-borders">
          <template #avatar>
            <q-icon name="error_outline" />
          </template>
          {{ loadError }}
        </q-banner>
      </div>

      <!-- Properties List -->
      <div v-if="!isLoading && !loadError && filteredProperties.length > 0" class="properties-grid q-pa-lg">
        <q-card
          v-for="property in filteredProperties"
          :key="property.id"
          flat
          bordered
          class="property-card cursor-pointer"
          @click="openProperty(property.id)"
        >
          <!-- Hero Section with Gradient -->
          <div class="property-hero" :style="getHeroStyle(property)">
            <div class="hero-overlay" />

            <div class="hero-badges">
              <q-badge
                :color="property.status === 'active' ? 'teal-8' : 'orange-6'"
                text-color="white"
                class="status-badge"
              >
                {{ property.status === 'active' ? 'Active' : 'Pending' }}
              </q-badge>
              <q-badge color="white" text-color="teal-8" class="osas-badge">
                <q-icon name="verified_user" size="14px" class="q-mr-xs" />
                OSAS
              </q-badge>
            </div>

            <div class="hero-content">
              <div class="property-name">{{ property.name }}</div>
              <div class="property-address">{{ property.address }}</div>
            </div>
          </div>

          <!-- Card Body -->
          <q-card-section class="card-body q-pa-md">
            <!-- Amenities Row -->
            <div class="amenities-row q-mb-md">
              <q-badge
                v-for="amenity in getAmenities(property)"
                :key="amenity.name"
                :color="amenity.color"
                text-color="black"
                class="amenity-chip"
              >
                {{ amenity.name }}
              </q-badge>
            </div>

            <!-- Occupancy Row -->
            <div class="occupancy-row q-mb-md row items-center justify-between">
              <div class="row items-center q-gutter-sm">
                <div class="dots-container">
                  <span
                    v-for="i in (property.total_rooms || 0)"
                    :key="i"
                    class="occupancy-dot"
                    :class="i <= (property.occupied_rooms || 0) ? 'filled' : 'empty'"
                  />
                </div>
                <div class="occupancy-text">
                  {{ property.occupied_rooms || 0 }}/{{ property.total_rooms || 0 }} full
                </div>
                <q-badge color="teal-1" text-color="teal-8" class="available-badge">
                  {{ (property.total_rooms || 0) - (property.occupied_rooms || 0) }} avail
                </q-badge>
              </div>

              <div class="tenant-avatars">
                <q-avatar
                  v-for="(tenant, idx) in getTenantAvatars(property)"
                  :key="tenant.id"
                  :color="tenant.color"
                  text-color="white"
                  size="28px"
                  class="tenant-avatar"
                  :style="{ marginLeft: idx > 0 ? '-8px' : '0' }"
                >
                  {{ tenant.initials }}
                </q-avatar>
              </div>
            </div>

            <!-- Rating Row -->
            <div class="rating-row row items-center q-gutter-xs">
              <q-icon name="star" color="amber-6" size="18px" />
              <span class="rating-value">{{ property.rating || 0 }}</span>
              <span class="review-count">({{ property.reviews || 0 }} reviews)</span>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Empty State -->
      <div v-if="!isLoading && !loadError && filteredProperties.length === 0" class="text-center q-pa-lg">
        <q-icon name="business" size="64px" color="grey-5" />
        <div class="text-h6 text-grey-7 q-mt-md">No properties found</div>
        <div class="text-body2 text-grey-6">Add your first property to get started</div>
      </div>
    </div>

  </q-page>

</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useLandlordStore } from '@/stores/landlord'
import { supabase } from '@/shared/utils/supabase'

interface Property {
  id: string
  name: string
  address: string
  status: 'active' | 'pending'
  room_type: string
  total_rooms: number
  occupied_rooms: number
  rating: number
  reviews: number
  amenities: string[]
  coverImage?: string
  latitude?: number
  longitude?: number
}

interface Tenant {
  id: string
  initials: string
  color: string
}

const router = useRouter()
const landlordStore = useLandlordStore()

const searchText = ref('')
const isLoading = ref(false)
const loadError = ref<string | null>(null)
const properties = ref<Property[]>([])

const filteredProperties = computed(() => {
  if (!searchText.value.trim()) return properties.value

  const term = searchText.value.trim().toLowerCase()
  return properties.value.filter(
    (p) =>
      p.name.toLowerCase().includes(term) ||
      p.address.toLowerCase().includes(term) ||
      p.room_type.toLowerCase().includes(term),
  )
})

const totalProperties = computed(() => properties.value.length)

const totalAvailableRooms = computed(() => {
  return properties.value.reduce((sum, p) => sum + ((p.total_rooms || 0) - (p.occupied_rooms || 0)), 0)
})

function getHeroStyle(property: Property) {
  if (property.coverImage) {
    return {
      backgroundImage: `linear-gradient(180deg, rgba(17, 24, 39, 0.15), rgba(17, 24, 39, 0.5)), url("${property.coverImage}")`,
      backgroundSize: 'cover',
      backgroundPosition: 'center',
    }
  }
  if (property.status === 'active') {
    return {
      background:
        'linear-gradient(135deg, rgba(13, 148, 136, 0.8), rgba(0, 137, 123, 0.5)), linear-gradient(135deg, #0f766e, #2dd4bf)',
    }
  } else {
    return {
      background:
        'linear-gradient(135deg, rgba(180, 83, 9, 0.8), rgba(245, 158, 11, 0.4)), linear-gradient(135deg, #ca8a04, #fbbf24)',
    }
  }
}

function getAmenities(property: Property) {
  const amenityMap: Record<string, { name: string; color: string }> = {
    wifi: { name: 'Wifi', color: 'teal-1' },
    water: { name: 'Water', color: 'blue-1' },
    electric: { name: 'Electric', color: 'amber-1' },
    aircon: { name: 'Aircon', color: 'purple-1' },
  }

  return (property.amenities || []).map((a) => amenityMap[a.toLowerCase()] || { name: a, color: 'grey-2' })
}

function getTenantAvatars(_property: Property): Tenant[] {
  // Tenant names are not readable by a landlord under RLS, so we don't render
  // fabricated avatars. Occupancy is shown via the dots above.
  return []
}

async function fetchProperties() {
  isLoading.value = true
  loadError.value = null

  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
      loadError.value = 'Please sign in to view properties'
      void router.push('/login')
      return
    }

    const { data, error } = await supabase
      .from('properties')
      .select('*, property_amenities(amenity), property_images(url, sort_order)')
      .eq('landlord_id', user.id)
      .order('id', { ascending: false })

    if (error) throw error

    // Occupancy is derived from active leases — the properties table has no
    // occupied_rooms column. Group active leases by their property.
    const { data: leases } = await supabase
      .from('leases')
      .select('room:rooms!room_id(property:properties(id))')
      .eq('landlord_id', user.id)
      .eq('status', 'active')

    const occupiedByProperty = new Map<string, number>()
    ;(leases || []).forEach((l: any) => {
      const propertyId = l.room?.property?.id
      if (propertyId) {
        occupiedByProperty.set(propertyId, (occupiedByProperty.get(propertyId) || 0) + 1)
      }
    })

    properties.value = (data || []).map((p: any) => {
      const imgs = (p.property_images || [])
        .slice()
        .sort((a: any, b: any) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      return {
        id: p.id,
        name: p.name || '',
        address: p.address || '',
        status: p.status === 'pending' ? 'pending' : 'active',
        room_type: p.room_type || 'solo',
        total_rooms: p.total_rooms || 0,
        occupied_rooms: occupiedByProperty.get(p.id) || 0,
        rating: p.rating_avg || 0,
        reviews: p.reviews_count || 0,
        amenities: (p.property_amenities || []).map((a: any) => a.amenity),
        coverImage: imgs[0]?.url || undefined,
        latitude: p.latitude,
        longitude: p.longitude,
      }
    })
  } catch (err) {
    loadError.value = err instanceof Error ? err.message : 'Failed to load properties'
    console.error('Fetch error:', err)
  } finally {
    isLoading.value = false
  }
}

function goToAddProperty() {
  void router.push('/landlord/properties/new')
}

function openProperty(id: string) {
  void router.push('/landlord/properties/' + id)
}

onMounted(() => {
  fetchProperties()
})

watch(() => landlordStore.properties, () => {
  fetchProperties()
})
</script>

<style scoped>
.properties-list-page {
  background: #f4f5f7;
  min-height: 100vh;
}

/* List View */
.list-view {
  padding-bottom: 100px;
}

/* Header */
.header-section {
  background: #f4f5f7;
}

.page-title {
  color: #111827;
  font-size: 32px;
  font-weight: 800;
  letter-spacing: -0.05em;
}

.page-subtitle {
  color: #6b7280;
  font-size: 14px;
  font-weight: 600;
  margin-top: 4px;
}

.view-toggle-btn,
.add-property-btn {
  border-radius: 12px;
  font-weight: 600;
  padding: 8px 16px;
}

.add-property-btn {
  min-width: 110px;
}

/* Search Section */
.search-section {
  background: #f4f5f7;
}

.search-input {
  border-radius: 14px;
}

.search-input :deep(.q-field__control) {
  height: 48px;
  padding: 0 12px;
  font-size: 14px;
}

/* Properties Grid */
.properties-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 16px;
}

.property-card {
  border-radius: 20px;
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.06);
  transition: all 0.3s ease;
}

.property-card:hover {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
  transform: translateY(-2px);
}

/* Hero Section */
.property-hero {
  position: relative;
  min-height: 180px;
  padding: 14px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.hero-overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, rgba(17, 24, 39, 0.12), rgba(17, 24, 39, 0.5));
}

.hero-badges,
.hero-content {
  position: relative;
  z-index: 1;
}

.hero-badges {
  display: flex;
  justify-content: space-between;
  gap: 8px;
}

.status-badge {
  border-radius: 20px;
  font-size: 10px;
  font-weight: 700;
  padding: 5px 10px;
}

.osas-badge {
  border-radius: 20px;
  font-size: 10px;
  font-weight: 700;
  padding: 5px 10px;
  display: flex;
  align-items: center;
  gap: 4px;
}

.hero-content {
  margin-top: auto;
}

.property-name {
  color: white;
  font-size: 18px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.property-address {
  color: rgba(255, 255, 255, 0.85);
  font-size: 12px;
  font-weight: 600;
  margin-top: 6px;
}

/* Card Body */
.card-body {
  background: white;
  padding: 16px;
}

.amenities-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.amenity-chip {
  border-radius: 20px;
  font-size: 11px;
  font-weight: 700;
  padding: 5px 10px;
}

/* Occupancy Row */
.occupancy-row {
  gap: 12px;
}

.dots-container {
  display: flex;
  gap: 5px;
}

.occupancy-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
  transition: all 0.2s ease;
}

.occupancy-dot.filled {
  background: #00897b;
}

.occupancy-dot.empty {
  background: #d1d5db;
}

.occupancy-text {
  color: #374151;
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
}

.available-badge {
  border-radius: 20px;
  font-size: 10px;
  font-weight: 800;
  padding: 5px 10px;
  white-space: nowrap;
}

.tenant-avatars {
  display: flex;
  align-items: center;
}

.tenant-avatar {
  border: 2px solid white;
  font-size: 10px;
  font-weight: 700;
}

/* Rating Row */
.rating-row {
  margin-top: 12px;
}

.rating-value {
  color: #111827;
  font-size: 14px;
  font-weight: 800;
}

.review-count {
  color: #6b7280;
  font-size: 12px;
}

/* Loading and Error States */
.q-spinner {
  display: block;
  margin: 0 auto;
}

.q-banner {
  border-radius: 12px;
}
</style>
