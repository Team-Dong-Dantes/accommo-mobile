<template>
  <BottomSheet
    v-model="filtersOpen"
    title="Filters"
    @clear="status = 'all'; houseId = 'all'"
  >
    <div v-if="accommodations.length > 1" class="sheet-block">
      <span class="sheet-label">Property</span>
      <div class="m-chips">
        <button type="button" class="m-chip" :class="{ 'm-chip--on': houseId === 'all' }" @click="houseId = 'all'">
          All
        </button>
        <button
          v-for="h in accommodations"
          :key="h.id"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': houseId === h.id }"
          @click="houseId = h.id"
        >
          {{ h.name }}
        </button>
      </div>
    </div>
    <div class="sheet-block">
      <span class="sheet-label">Status</span>
      <div class="m-chips">
        <button
          v-for="f in STATUS_FILTERS"
          :key="f.key"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': status === f.key }"
          @click="status = f.key"
        >
          {{ f.label }}
        </button>
      </div>
    </div>
  </BottomSheet>
</template>

<script setup lang="ts">
// The list's filters: status and house.
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { useAnnouncements } from './announcements'

const {
  accommodations,
  STATUS_FILTERS,
  status,
  houseId,
  filtersOpen,
} = useAnnouncements()
</script>
