<template>
  <div class="group">
    <div class="quick-stats">
      <div class="stat-block">
        <span class="stat-badge"><IconifyIcon icon="lucide:door-open" width="16" /></span>
        <div>
          <span class="stat-number">{{ rooms.length }}</span>
          <span class="stat-label">Rooms</span>
        </div>
      </div>
      <div class="stat-divider" />
      <div class="stat-block">
        <span class="stat-badge"><IconifyIcon icon="lucide:user-check" width="16" /></span>
        <div>
          <span class="stat-number">{{ occupiedRoomCount }}</span>
          <span class="stat-label">Occupied</span>
        </div>
      </div>
      <div class="stat-divider" />
      <div class="stat-block">
        <span class="stat-badge"><IconifyIcon icon="lucide:door-closed" width="16" /></span>
        <div>
          <span class="stat-number">{{ vacantRoomCount }}</span>
          <span class="stat-label">Vacant</span>
        </div>
      </div>
    </div>
  </div>

  <div class="sec-head">
    <h2 class="sec-title">Details</h2>
  </div>
  <div class="view-group">
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('name')">
      <span class="view-label">Name</span>
      <span class="view-value">{{ acc.name || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('accommodationType')">
      <span class="view-label">Type</span>
      <span class="view-value">{{ BUILDING_TYPE_LABEL[acc.accommodationType] || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('genderPolicy')">
      <span class="view-label">Accepts</span>
      <span class="view-value">{{ GENDER_POLICY_LABEL[acc.genderPolicy] || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('purok')">
      <span class="view-label">Purok</span>
      <span class="view-value">{{ acc.purok || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('barangay')">
      <span class="view-label">Barangay</span>
      <span class="view-value">{{ acc.barangay || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('city')">
      <span class="view-label">City</span>
      <span class="view-value">{{ acc.city || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <!-- Counted from the floors on the Rooms tab (the database keeps
         total_floors in step), so it can't disagree with them. -->
    <div class="view-row">
      <span class="view-label">Floors</span>
      <span class="view-value">{{ floorCount || '—' }}</span>
    </div>
    <button type="button" class="view-row view-row--tap view-row--block" @click="openFieldDialog('description')">
      <span class="view-row-head">
        <span class="view-label">Description</span>
        <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
      </span>
      <p class="view-text">{{ acc.description || 'No description yet.' }}</p>
    </button>
  </div>

  <div class="sec-head">
    <h2 class="sec-title">Location</h2>
    <button type="button" class="sec-link" @click="locationPickerOpen = true">
      {{ mapUrl ? 'Change location' : 'Set location' }}
    </button>
  </div>
  <div v-if="mapUrl" class="map">
    <img :src="mapUrl" :alt="`Map showing ${acc.name || 'this accommodation'} and ${CAMPUS.label}`" loading="lazy" />
    <p class="map-note">
      <IconifyIcon icon="lucide:school" width="12" />
      {{ distance || 'Distance unknown' }} · {{ CAMPUS.label }}
    </p>
  </div>
  <p v-else class="none">Location not set yet.</p>
</template>

<script setup lang="ts">
// The Overview tab: room counts, the listing's details (each row opens
// the one-field editor) and its map.
import { Icon as IconifyIcon } from '@iconify/vue'
import { CAMPUS } from '@/utils/geo'
import { BUILDING_TYPE_LABEL, GENDER_POLICY_LABEL } from '@/utils/listings'
import { useAccommodationDetail } from './detail'

const {
  acc,
  distance,
  floorCount,
  locationPickerOpen,
  mapUrl,
  occupiedRoomCount,
  openFieldDialog,
  rooms,
  vacantRoomCount,
} = useAccommodationDetail()
</script>

<style scoped src="./rows.css"></style>

<style scoped>
.view-row--block { flex-direction: column; align-items: stretch; gap: 4px; }
.view-row-head { display: flex; width: 100%; align-items: center; justify-content: space-between; }
.view-text {
  margin: 0;
  color: var(--m-ink);
  font-size: 13.5px;
  line-height: 1.4;
  text-wrap: pretty;
}
.map-note {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 0;
  padding: 8px 12px;
  border-top: 1px solid var(--m-border);
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.quick-stats {
  display: flex;
  align-items: center;
  justify-content: space-around;
  padding: 14px 12px;
}
.stat-block {
  display: flex;
  align-items: center;
  gap: 8px;
}
.stat-badge {
  display: flex;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.stat-number {
  display: block;
  color: var(--m-ink);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.2;
}
.stat-label {
  display: block;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}
.stat-divider {
  width: 1px;
  height: 30px;
  background: var(--m-border);
}
</style>
