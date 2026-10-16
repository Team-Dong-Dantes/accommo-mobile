<template>
  <q-page class="disc">
    <!-- Desktop: search pinned at the top of the list half, not floating. -->
    <SearchDock
      v-if="isDesktop && !loading && !error"
      v-model="query"
      inline
      class="desk-search"
      :filter-count="activeFilterCount"
      placeholder="Search accommodations, rooms, landlords/landladies"
      search-label="Search accommodations, rooms, landlords/landladies"
      @open-filters="filtersOpen = true"
    />
    <div v-if="loading" class="stack">
      <section class="sec">
        <q-skeleton type="text" width="90px" height="16px" />
        <div class="rail">
          <div v-for="n in 2" :key="n" class="sk-car rail-item">
            <q-skeleton type="rect" class="sk-car-shot" />
            <q-skeleton type="text" width="70%" height="14px" />
            <q-skeleton type="text" width="45%" height="11px" />
          </div>
        </div>
      </section>
      <section class="sec">
        <q-skeleton type="text" width="60px" height="16px" />
        <div class="grid">
          <div v-for="n in 4" :key="n" class="sk-tile">
            <q-skeleton type="rect" class="sk-tile-shot" />
            <q-skeleton type="text" width="70%" height="13px" />
            <q-skeleton type="text" width="45%" height="11px" />
          </div>
        </div>
      </section>
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load listings" :detail="error" :retry="load" />
    </div>

    <template v-else>
      <!-- Desktop: the map is the card's right half (MainLayout's
           #desk-map-slot), beside the list rather than a strip above it. -->
      <Teleport v-if="!deskMap || active" to="#desk-map-slot" :disabled="!deskMap" defer>
      <DiscoverMap />
      </Teleport>

    <DiscoverResults />
    </template>

    <!-- Search sits on the FAB's baseline so the two read as one control band -->
    <SearchDock
      v-if="!loading && !error && !isDesktop"
      v-model="query"
      :filter-count="activeFilterCount"
      placeholder="Search accommodations, rooms, landlords/landladies"
      search-label="Search accommodations, rooms, landlords/landladies"
      above-nav
      @open-filters="filtersOpen = true"
    >
      <!-- Full map: "my location" at the dock's left end, in thumb reach. -->
      <template v-if="mapExpanded && hasMapToken" #action>
        <button
          type="button"
          class="map-locate-btn map-locate-btn--dock"
          :class="{ 'map-locate-btn--on': located }"
          :disabled="locating"
          @click="locateMe"
        >
          <IconifyIcon
            :icon="locating ? 'lucide:loader-circle' : 'lucide:locate-fixed'"
            :class="{ 'map-locate-spin': locating }"
            width="20"
          />
          <span class="dock-btn-label">My location</span>
        </button>
      </template>
    </SearchDock>

    <!-- Filters — apply to the room grid, the page's main content -->
    <DiscoverFilters />
  </q-page>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import { isDesktop } from '@/utils/useTabletMode'
import { provideDiscover } from '@/components/student/discover/discover'
import DiscoverMap from '@/components/student/discover/DiscoverMap.vue'
import DiscoverResults from '@/components/student/discover/DiscoverResults.vue'
import DiscoverFilters from '@/components/student/discover/DiscoverFilters.vue'

// The page is the shell — loading, the search docks, where the map goes. The
// map, the results and the filters live in components/student/discover/, all
// reading the state this page provides (and keeps alive; see MainLayout).
const {
  active,
  activeFilterCount,
  deskMap,
  error,
  filtersOpen,
  hasMapToken,
  load,
  loading,
  locateMe,
  located,
  locating,
  mapExpanded,
  query,
} = provideDiscover()
</script>

<style scoped>
.disc {
  background: var(--m-bg);
}
.map-collapse-btn,
.map-locate-btn {
  display: flex;
  align-items: center;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  color: var(--m-ink);
  box-shadow: 0 3px 12px rgba(15, 23, 42, 0.35);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.map-locate-btn {
  justify-content: center;
  width: 36px;
  height: 36px;
  padding: 0;
}
/* In the search dock: the dock's 52px height, and its shadow rather than the
   heavier one the map-top buttons need over busy map tiles. The label is the
   dock's .dock-btn-label, which folds away while the search field is open. */
.map-locate-btn--dock {
  width: auto;
  height: 52px;
  flex: 0 0 auto;
  padding: 0 16px;
  box-shadow: var(--m-shadow);
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.map-locate-btn--on {
  color: var(--m-primary);
}
.map-locate-spin {
  animation: map-locate-spin 0.8s linear infinite;
}
.stack {
  display: flex;
  flex-direction: column;
 
  /* Clears the docked search, which sits on the FAB's baseline. */
  padding: 8px var(--m-page-gutter) 126px;
}
/* Desktop: no docked search or FAB below the list to clear. */
.stack--desk {
  padding-bottom: 18px;
}
.sk-car,
.sk-tile {
  display: flex;
  flex-direction: column;
  gap: 5px;
}
.sk-car-shot,
.sk-tile-shot {
  width: 100%;
  aspect-ratio: 16 / 10;
  border-radius: var(--m-radius-sm);
}
/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */
/* Filter sheet */
/* Sections */
.sec {
  display: flex;
  flex-direction: column;

}
/* Property carousel */
.rail {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 2px;
}
.rail-item {
  flex: 0 0 62%;
  scroll-snap-align: start;
}
.rail--desk .rail-item {
  flex-basis: calc((100% - 8px) / 2);
}
/* Room grid — two per row */
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
@keyframes map-locate-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
