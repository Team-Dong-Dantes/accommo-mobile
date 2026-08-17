<template>
  <q-page class="properties-page bg-grey-1">
    <div class="page-shell q-pb-xl">
      <div class="header-block q-px-md q-pt-lg q-pb-sm">
        <div class="row justify-between items-center">
          <div>
            <div class="page-title">Properties</div>
            <div class="page-subtitle">3 properties - 7 rooms available</div>
          </div>
          <q-btn unelevated rounded color="teal-8" text-color="white" label="Add" icon-right="add" @click="goToAddProperty" class="add-property-btn" />
        </div>
      </div>

      <div class="q-px-md q-mt-md">
        <q-input
          v-model="searchText"
          outlined
          dense
          bg-color="white"
          class="property-search"
          placeholder="Search properties..."
        >
          <template #prepend>
            <q-icon name="search" color="grey-7" />
          </template>
        </q-input>
      </div>

      <div class="q-px-md q-mt-md">
        <q-card
          v-for="property in filteredProperties"
          :key="property.id"
          flat
          bordered
          class="property-card"
        >
          <div class="property-hero" :style="property.heroStyle">
            <div class="hero-overlay" />

            <div class="hero-badges">
              <q-badge :color="property.statusColor" class="status-badge">
                {{ property.status }}
              </q-badge>
              <q-badge color="white" text-color="green-8" class="status-badge osas-badge">
                <q-icon name="verified" size="14px" class="q-mr-xs" />
                OSAS
              </q-badge>
            </div>

            <div class="hero-content">
              <div class="property-title">{{ property.name }}</div>
              <div class="property-address">{{ property.address }}</div>
            </div>
          </div>

          <q-card-section class="q-pt-md q-pb-sm">
            <div class="amenity-row">
              <q-badge
                v-for="amenity in property.amenities"
                :key="amenity.name"
                :color="amenity.color"
                text-color="black"
                class="amenity-badge"
              >
                {{ amenity.name }}
              </q-badge>
            </div>

            <div class="occupancy-row q-mt-md">
              <div class="dots-wrap">
                <span
                  v-for="dot in property.capacity.total"
                  :key="dot"
                  class="occupancy-dot"
                  :class="dot <= property.capacity.occupied ? 'filled' : 'empty'"
                />
              </div>

              <div class="occupancy-text">{{ property.capacity.occupied }}/{{ property.capacity.total }} full</div>

              <q-badge color="teal-1" text-color="teal-9" class="availability-badge">
                {{ property.available }} avail
              </q-badge>

              <div class="tenant-stack">
                <q-avatar
                  v-for="tenant in property.tenants"
                  :key="tenant.id"
                  size="28px"
                  class="tenant-avatar"
                  :style="tenant.style"
                >
                  {{ tenant.initials }}
                </q-avatar>
              </div>
            </div>

            <div class="rating-row q-mt-md">
              <q-icon name="star" color="amber-6" size="18px" />
              <span class="rating-value">{{ property.rating }}</span>
              <span class="review-text">({{ property.reviews }} reviews)</span>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

interface Amenity {
  name: string
  color: string
}

interface TenantAvatar {
  id: string
  initials: string
  style: Record<string, string>
}

interface PropertyItem {
  id: string
  name: string
  address: string
  status: string
  statusColor: string
  heroStyle: Record<string, string>
  amenities: Amenity[]
  capacity: {
    occupied: number
    total: number
  }
  available: number
  tenants: TenantAvatar[]
  rating: number
  reviews: number
}

const router = useRouter()
const searchText = ref('')

function goToAddProperty() {
  void router.push('/landlord/properties/new')
}

const properties = ref<PropertyItem[]>([
  {
    id: 'green-hills',
    name: 'Green Hills Residences',
    address: '118 Avenue, Quezon City',
    status: 'Active',
    statusColor: 'green-6',
    heroStyle: {
      background: 'linear-gradient(135deg, rgba(20, 84, 82, 0.8), rgba(13, 148, 136, 0.35)), linear-gradient(135deg, #0f766e, #2dd4bf)',
    },
    amenities: [
      { name: 'Wifi', color: 'teal-1' },
      { name: 'Water', color: 'blue-1' },
      { name: 'Electric', color: 'amber-1' },
      { name: 'Aircon', color: 'purple-1' },
    ],
    capacity: {
      occupied: 3,
      total: 6,
    },
    available: 3,
    tenants: [
      { id: 't1', initials: 'MR', style: { background: '#dbeafe', color: '#1d4ed8', marginLeft: '0px' } },
      { id: 't2', initials: 'LM', style: { background: '#dcfce7', color: '#166534', marginLeft: '-8px' } },
      { id: 't3', initials: 'AJ', style: { background: '#f3e8ff', color: '#6b21a8', marginLeft: '-8px' } },
    ],
    rating: 4.8,
    reviews: 13,
  },
  {
    id: 'sunset-terrace',
    name: 'Sunset Terrace',
    address: '66 Ipil Street, Makati',
    status: 'Pending',
    statusColor: 'orange-5',
    heroStyle: {
      background: 'linear-gradient(135deg, rgba(94, 52, 18, 0.72), rgba(245, 158, 11, 0.32)), linear-gradient(135deg, #ca8a04, #fbbf24)',
    },
    amenities: [
      { name: 'Wifi', color: 'teal-1' },
      { name: 'Water', color: 'blue-1' },
      { name: 'Electric', color: 'amber-1' },
      { name: 'Aircon', color: 'purple-1' },
    ],
    capacity: {
      occupied: 2,
      total: 5,
    },
    available: 3,
    tenants: [
      { id: 't4', initials: 'EA', style: { background: '#fef3c7', color: '#92400e', marginLeft: '0px' } },
      { id: 't5', initials: 'RT', style: { background: '#e0e7ff', color: '#3730a3', marginLeft: '-8px' } },
    ],
    rating: 4.7,
    reviews: 7,
  },
  {
    id: 'maple-haven',
    name: 'Maple Haven',
    address: '24 M. Paterno Street, Cebu',
    status: 'Active',
    statusColor: 'green-6',
    heroStyle: {
      background: 'linear-gradient(135deg, rgba(38, 60, 92, 0.75), rgba(59, 130, 246, 0.35)), linear-gradient(135deg, #1d4ed8, #60a5fa)',
    },
    amenities: [
      { name: 'Wifi', color: 'teal-1' },
      { name: 'Water', color: 'blue-1' },
      { name: 'Electric', color: 'amber-1' },
      { name: 'Aircon', color: 'purple-1' },
    ],
    capacity: {
      occupied: 4,
      total: 6,
    },
    available: 2,
    tenants: [
      { id: 't6', initials: 'KD', style: { background: '#fbcfe8', color: '#9d174d', marginLeft: '0px' } },
      { id: 't7', initials: 'TN', style: { background: '#e0f2fe', color: '#075985', marginLeft: '-8px' } },
      { id: 't8', initials: 'LP', style: { background: '#fef9c3', color: '#854d0e', marginLeft: '-8px' } },
    ],
    rating: 4.9,
    reviews: 18,
  },
])

const filteredProperties = computed(() => {
  if (!searchText.value.trim()) return properties.value

  const term = searchText.value.trim().toLowerCase()

  return properties.value.filter((property) =>
    property.name.toLowerCase().includes(term) ||
    property.address.toLowerCase().includes(term),
  )
})
</script>

<style scoped>
.properties-page {
  background: #f4f5f7;
}

.page-shell {
  padding-bottom: 110px;
}

.header-block {
  background: #f4f5f7;
}

.page-title {
  color: #111827;
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.05em;
}

.page-subtitle {
  margin-top: 4px;
  color: #6b7280;
  font-size: 13px;
  font-weight: 600;
}

.property-search :deep(.q-field__control) {
  height: 48px;
  border-radius: 14px;
}

.property-card {
  margin-bottom: 18px;
  border-radius: 22px;
  overflow: hidden;
  background: white;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.property-hero {
  position: relative;
  min-height: 180px;
  padding: 14px 14px 16px;
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
  align-items: center;
  justify-content: space-between;
}

.status-badge {
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  padding: 4px 10px;
}

.osas-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.hero-content {
  margin-top: auto;
}

.property-title {
  color: white;
  font-size: 20px;
  font-weight: 800;
  letter-spacing: -0.04em;
}

.property-address {
  margin-top: 6px;
  color: rgba(255, 255, 255, 0.86);
  font-size: 12px;
  font-weight: 600;
}

.amenity-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.amenity-badge {
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  padding: 6px 10px;
}

.occupancy-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.dots-wrap {
  display: flex;
  align-items: center;
  gap: 5px;
}

.occupancy-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
}

.occupancy-dot.filled {
  background: #0f766e;
}

.occupancy-dot.empty {
  background: #d1d5db;
}

.occupancy-text {
  color: #374151;
  font-size: 12px;
  font-weight: 700;
}

.availability-badge {
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  padding: 6px 10px;
}

.tenant-stack {
  margin-left: auto;
  display: flex;
  align-items: center;
}

.tenant-avatar {
  border: 2px solid white;
  font-size: 10px;
  font-weight: 700;
}

.rating-row {
  display: flex;
  align-items: center;
  gap: 6px;
}

.rating-value {
  color: #111827;
  font-size: 14px;
  font-weight: 800;
}

.review-text {
  color: #6b7280;
  font-size: 12px;
}

.add-property-btn {
  border-radius: 12px;
  font-weight: 600;
  padding: 8px 16px;
}
</style>
