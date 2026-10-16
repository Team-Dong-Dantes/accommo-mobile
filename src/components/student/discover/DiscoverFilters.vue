<template>
  <BottomSheet
    v-model="filtersOpen"
    title="Filters"
    :done-label="`Show ${filteredRooms.length} ${filteredRooms.length === 1 ? 'room' : 'rooms'}`"
    @clear="resetFilters"
  >
    <label class="sheet-row">
      <span class="sheet-label">Only available rooms</span>
      <q-toggle v-model="filters.vacantOnly" color="primary" dense />
    </label>

    <div class="sheet-block">
      <span class="sheet-label">Monthly rent up to {{ formatPeso(filters.maxRent) }}</span>
      <q-slider
        v-model="filters.maxRent"
        :min="rentBounds.min"
        :max="rentBounds.max"
        :step="500"
        color="primary"
        class="q-px-sm"
      />
    </div>

    <div class="sheet-block">
      <span class="sheet-label">Room type</span>
      <div class="m-chips">
        <button
          v-for="type in roomTypeOptions"
          :key="type"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': filters.roomTypes.includes(type) }"
          @click="toggle(filters.roomTypes, type)"
        >
          {{ roomTypeLabel(type) }}
        </button>
      </div>
    </div>

    <div class="sheet-block">
      <span class="sheet-label">Must have</span>
      <div class="m-chips">
        <button
          v-for="f in SEARCH_FEATURES"
          :key="f.key"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': filters.amenities.includes(f.key) }"
          @click="toggle(filters.amenities, f.key)"
        >
          <IconifyIcon :icon="f.icon" width="13" />
          {{ f.label }}
        </button>
      </div>
    </div>
  </BottomSheet>
</template>

<script setup lang="ts">
// The room grid's filters, in a bottom sheet.
import { Icon as IconifyIcon } from '@iconify/vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { formatPeso } from '@/utils/format'
import { SEARCH_FEATURES, roomTypeLabel } from '@/utils/listings'
import { useDiscover } from './discover'

const {
  filteredRooms,
  filters,
  filtersOpen,
  rentBounds,
  resetFilters,
  roomTypeOptions,
  toggle,
} = useDiscover()
</script>

<style scoped>
.m-chip {
  min-height: 36px;
  padding: 0 13px;
}
</style>
