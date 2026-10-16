<template>
  <div
    v-if="hasMapToken"
    class="map-region"
    :class="{ 'map-region--full': mapExpanded, 'map-region--desk': deskMap, 'map-region--picked': selectedId }"
    :style="mapRegionStyle"
  >
    <div ref="mapEl" class="map-el" aria-label="Map of accommodations" />
    <button v-if="!mapExpanded && !deskMap" type="button" class="map-expand-btn" @click="toggleMapExpanded(true)">
      <IconifyIcon icon="lucide:maximize-2" width="15" />
      <span>Map view</span>
    </button>
  </div>

  <!-- Full map: the preview button above is now covered by the fixed
       full-screen map, so "List view" is the way back — parked just under
       the header where the rail/info card below can never cover it. "My
       location" lives at the left end of the search dock instead. Desktop
       has no list view or dock, so only the locate button, in the map's
       top-right corner. -->
  <div
    v-if="hasMapToken && (mapExpanded || deskMap)"
    class="map-top"
    :class="{ 'map-top--desk': deskMap }"
    :style="deskMap ? undefined : { top: (headerReservedPx + 16) + 'px' }"
  >
    <button v-if="!deskMap" type="button" class="map-collapse-btn" @click="toggleMapExpanded(false)">
      <IconifyIcon icon="lucide:x" width="16" />
      <span>List view</span>
    </button>
    <button
      v-if="deskMap"
      type="button"
      class="map-locate-btn"
      :class="{ 'map-locate-btn--on': located }"
      :disabled="locating"
      aria-label="Show my location"
      @click="locateMe"
    >
      <IconifyIcon
        :icon="locating ? 'lucide:loader-circle' : 'lucide:locate-fixed'"
        :class="{ 'map-locate-spin': locating }"
        width="17"
      />
    </button>
  </div>

  <!-- One carousel, synced both ways with the pins: swiping a card flies
       the map to its pin, tapping a pin scrolls to its card. Picking one
       hides the other pins; the card's X brings them back. Desktop has
       the list beside it, so it shows only the picked place. -->
  <div
    v-if="hasMapToken && (mapExpanded || (deskMap && selected))"
    class="map-float"
    :class="{ 'map-float--desk': deskMap }"
  >
    <div ref="mapRailEl" class="map-rail" @scrollend="onRailSettled">
      <!-- A div, not a button: it holds the X button, and buttons can't nest. -->
      <div
        v-for="item in railItems"
        :key="item.id"
        :data-id="item.id"
        role="button"
        tabindex="0"
        class="map-card"
        :class="{ 'map-card--on': item.id === selectedId, 'map-card--dim': !fitsMe(item) }"
        @click="open(item.id)"
        @keydown.enter="open(item.id)"
      >
        <span class="map-card-shot">
          <img v-if="item.image" :src="item.image" :alt="item.name" loading="lazy" />
          <PhotoEmpty v-else :size="20" />
        </span>
        <span class="map-card-body">
          <span class="map-card-head">
            <span class="map-card-name">{{ item.name }}</span>
            <button
              v-if="item.id === selectedId"
              type="button"
              class="map-card-x"
              aria-label="Show all pins"
              @click.stop="clearSelectedPin"
            >
              <IconifyIcon icon="lucide:x" width="14" />
            </button>
          </span>
          <span class="map-card-rent" :class="{ 'map-card-rent--full': !item.vacancies }">
            <template v-if="!item.vacancies">Full right now</template>
            <template v-else-if="item.minVacantRent">from {{ formatPeso(item.minVacantRent) }}<span class="map-card-per">/mo</span></template>
            <template v-else>Rent on request</template>
          </span>
          <span v-if="walkText(item)" class="map-card-line">
            <IconifyIcon icon="lucide:footprints" width="12" />
            {{ walkText(item) }}
          </span>
          <span class="map-card-tags">
            <span v-if="item.vacancies" class="map-card-tag map-card-tag--ok">{{ item.vacancies }} free</span>
            <span v-if="item.genderPolicy" class="map-card-tag">{{ item.genderPolicy }}</span>
            <span v-if="item.buildingType" class="map-card-tag">{{ item.buildingType }}</span>
          </span>
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// The map: Mapbox in .map-el, the full-map controls, and the card rail
// synced with the pins. The page teleports it into the desktop card's map half.
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import { formatPeso } from '@/utils/format'
import { useDiscover } from './discover'

const {
  clearSelectedPin,
  deskMap,
  fitsMe,
  hasMapToken,
  headerReservedPx,
  locateMe,
  located,
  locating,
  mapEl,
  mapExpanded,
  mapRailEl,
  mapRegionStyle,
  onRailSettled,
  open,
  railItems,
  selected,
  selectedId,
  toggleMapExpanded,
  walkText,
} = useDiscover()
</script>

<style scoped src="./pins.css"></style>

<style scoped>
/* Map + expand button — plain in-flow block, part of the page's normal
   scroll like any other section. */
.map-region {
  position: relative;
  z-index: 5;
  min-height: 0;
  overflow: hidden;
  transition: height 260ms cubic-bezier(0.22, 0.61, 0.36, 1);
}
/* Expanded, the map is a real overlay rather than a very tall in-flow box.
   As an in-flow box the page simply carried on scrolling underneath it and
   you reached the listings while the map was meant to be full-screen; locking
   `documentElement`'s overflow was an attempt to hold that back and did not
   survive contact with a touch screen. Out of flow there is nothing left to
   scroll: the box covers the viewport and mapbox owns every gesture on it.
   Sits under the bottom nav (z-index 50 in MainLayout) and under the collapse
   button, floating rail and search dock, which are already fixed above it. */
.map-region--full {
  position: fixed;
  top: 0;
  right: 0;
  left: 0;
  z-index: 40;
}
/* Desktop: fills the right half it is teleported into. */
.map-region--desk {
  height: 100%;
}
.map-el {
  width: 100%;
  height: 100%;
}
.map-expand-btn {
  position: absolute;
  right: 12px;
  bottom: 12px;
  z-index: 6;
  display: flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 14px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  white-space: nowrap;
  box-shadow: var(--m-shadow);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
/* Floating "List view" + "my location" — the expanded map covers everything
   below the header, so this is the way back: parked just under it, always in
   reach regardless of scroll position. */
.map-top {
  position: fixed;
  left: 50%;
  z-index: 65;
  display: flex;
  gap: 8px;
  transform: translateX(-50%);
}
.map-top--desk {
  position: absolute;
  top: 14px;
  right: 14px;
  left: auto;
  z-index: 6;
  transform: none;
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
.map-collapse-btn {
  gap: 6px;
  height: 36px;
  padding: 0 14px 0 12px;
  font-size: 12.5px;
  font-weight: 700;
  white-space: nowrap;
}
.map-locate-btn {
  justify-content: center;
  width: 36px;
  height: 36px;
  padding: 0;
}
.map-locate-btn--on {
  color: var(--m-primary);
}
.map-locate-spin {
  animation: map-locate-spin 0.8s linear infinite;
}
/* Floating recommendations rail — full-map mode only, sitting just above
   the docked search/filter band. No card behind it: it's a bare positioning
   slot, and each item (property or room) carries its own card look, so nothing
   doubles up once an item is selected and swapped for the single info card. */
.map-float {
  position: fixed;
  right: 0;
  bottom: 136px;
  left: 0;
  z-index: 60;
  padding: 0 var(--m-page-gutter);
}
/* Desktop: the picked pin's card sits inside the map half, not the window. */
.map-float--desk {
  position: absolute;
  right: 14px;
  bottom: 14px;
  left: 14px;
  z-index: 6;
  padding: 0;
}
/* The synced carousel: one card centred at a time, its neighbours peeking. */
.map-rail {
  display: flex;
  gap: 10px;
  padding: 4px calc(50% - 150px);
  margin: 0 calc(var(--m-page-gutter) * -1);
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
  -webkit-overflow-scrolling: touch;
}
.map-rail::-webkit-scrollbar {
  display: none;
}
.map-float--desk .map-rail {
  padding: 0;
  margin: 0;
}
.map-card {
  display: flex;
  flex: 0 0 300px;
  /* Without this a flex item never shrinks below its content, so a long
     name stretched the card instead of truncating. */
  min-width: 0;
  gap: 10px;
  padding: 8px;
  scroll-snap-align: center;
  border: 1.5px solid color-mix(in srgb, var(--m-border) 45%, transparent);
  border-radius: var(--m-radius-lg, var(--m-radius));
  background: color-mix(in srgb, var(--m-surface) 88%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.18);
  cursor: pointer;
  font: inherit;
  text-align: left;
  transition: border-color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.map-float--desk .map-card {
  flex: 1 1 auto;
}
.map-card--on {
  border-color: var(--m-primary);
}
.map-card--dim {
  opacity: 0.6;
}
.map-card-shot {
  position: relative;
  display: grid;
  width: 92px;
  height: 92px;
  flex: 0 0 auto;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm, 10px);
  background: var(--m-border);
}
.map-card-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.map-card-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 3px;
}
.map-card-head {
  display: flex;
  align-items: flex-start;
  gap: 6px;
}
.map-card-name {
  min-width: 0;
  flex: 1 1 auto;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.map-card-x {
  display: grid;
  width: 24px;
  height: 24px;
  flex: 0 0 auto;
  place-items: center;
  margin: -2px -2px 0 0;
  padding: 0;
  border: 0;
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-ink) 8%, transparent);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.map-card-rent {
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.map-card-rent--full {
  color: var(--m-muted);
}
.map-card-per {
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
}
.map-card-line {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.map-card-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: auto;
}
.map-card-tag {
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 700;
}
.map-card-tag--ok {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
@keyframes map-locate-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
