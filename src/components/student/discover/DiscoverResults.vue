<template>
<div class="stack" :class="{ 'stack--desk': isDesktop }">
  <section v-if="filteredProperties.length" class="sec">
    <div class="sec-head">
      <h2 class="sec-title">Accommodations</h2>
      <div class="sec-actions">
        <!-- A mouse has no swipe, so desktop gets arrows for the rail. -->
        <template v-if="isDesktop">
          <button type="button" class="rail-arrow" aria-label="Previous accommodations" @click="slideRail(-1)">
            <IconifyIcon icon="lucide:chevron-left" width="16" />
          </button>
          <button type="button" class="rail-arrow" aria-label="Next accommodations" @click="slideRail(1)">
            <IconifyIcon icon="lucide:chevron-right" width="16" />
          </button>
        </template>
        <button type="button" class="sec-more" @click="router.push('/student/properties')">
          View all
        </button>
      </div>
    </div>
    <div ref="railEl" class="rail" :class="{ 'rail--desk': isDesktop }">
      <PropertyCard
        v-for="item in filteredProperties.slice(0, 10)"
        :key="item.id"
        variant="carousel"
        class="rail-item"
        :id="item.id"
        :name="item.name"
        :address="item.address"
        :image="item.image"
        :monogram="item.monogram"
        :distance="item.distance"
        :vacancies="item.vacancies"
        :building-type="item.buildingType"
        :gender-policy="item.genderPolicy"
        @open="open"
      />
    </div>
  </section>

  <!-- Managers only surface once a search narrows to them -->
  <section v-if="query.trim() && filteredManagers.length" class="sec">
    <h2 class="sec-title">Landlords/Landladies</h2>
    <div class="mgrs">
      <button
        v-for="m in filteredManagers"
        :key="m.id"
        type="button"
        class="mgr-row"
        @click="openManager(m.id)"
      >
        <span class="mgr-avatar">
          <img v-if="m.avatarUrl" :src="m.avatarUrl" alt="" class="mgr-avatar-img" @error="m.avatarUrl = null" />
          <template v-else>{{ m.initials }}</template>
        </span>
        <span class="mgr-body">
          <span class="mgr-name">{{ m.name }}</span>
          <span class="mgr-sub">
            {{ m.propertyCount ? `${m.propertyCount} ${m.propertyCount === 1 ? 'accommodation' : 'accommodations'}` : 'New manager' }}
          </span>
        </span>
      </button>
    </div>
  </section>

  <section class="sec">
    <h2 class="sec-title">Rooms</h2>
    <div v-if="filteredRooms.length" class="grid">
      <button
        v-for="room in filteredRooms"
        :key="room.id"
        type="button"
        class="tile"
        @click="openRoom(room.id)"
      >
        <span class="tile-shot">
          <img v-if="room.image" :src="room.image" :alt="room.label" loading="lazy" />
          <PhotoEmpty v-else :size="22" label />
          <span class="tile-flag">{{ room.label }}</span>
        </span>
        <span class="tile-body">
          <span class="tile-name-row">
            <span class="tile-name">{{ room.typeLabel }}</span>
            <span v-if="room.meta" class="tile-name-meta">{{ room.meta }}</span>
          </span>
          <span class="tile-where">{{ room.propertyName }}</span>
          <span v-if="room.rent" class="tile-rent">
            {{ formatPeso(room.rent) }}<span class="tile-per">/mo{{ room.rentBasis === 'person' ? ' per person' : '' }}</span>
          </span>
          <span v-else class="tile-rent tile-rent--none">Rent on request</span>
        </span>
      </button>
    </div>
    <p v-else class="none">
      {{ query.trim() ? 'No rooms match your search.' : 'No rooms published yet.' }}
    </p>
  </section>

  <p
    v-if="query.trim() && !filteredProperties.length && !filteredManagers.length && !filteredRooms.length"
    class="none"
  >
    Nothing matches "{{ query.trim() }}".
  </p>
</div>
</template>

<script setup lang="ts">
// The list under the map: accommodations, landlords/landladies a search
// narrows to, and the room grid.
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import PropertyCard from '@/components/student/PropertyCard.vue'
import { formatPeso } from '@/utils/format'
import { isDesktop } from '@/utils/useTabletMode'
import { useDiscover } from './discover'

const {
  filteredManagers,
  filteredProperties,
  filteredRooms,
  open,
  openManager,
  openRoom,
  query,
  railEl,
  router,
  slideRail,
} = useDiscover()
</script>

<style scoped>
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
/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */
/* Filter sheet */
/* Sections */
.sec {
  display: flex;
  flex-direction: column;

}
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sec-title {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.sec-more {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
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
.rail--desk {
  scrollbar-width: none;
}
.rail--desk::-webkit-scrollbar {
  display: none;
}
.rail--desk .rail-item {
  flex-basis: calc((100% - 8px) / 2);
}
.sec-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
.rail-arrow {
  display: grid;
  width: 28px;
  height: 28px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
}
.rail-arrow:hover {
  background: var(--m-bg);
}
/* Landlords and landladies */
.mgrs {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.mgr-row {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.mgr-avatar {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.mgr-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.mgr-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.mgr-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.mgr-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
/* Room grid — two per row */
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.tile {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  padding: 0;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.tile-shot {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 1 / 1;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.tile-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.tile-flag {
  position: absolute;
  top: 7px;
  left: 7px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
}
.tile-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 8px 9px 10px;
}
.tile-name-row {
  display: flex;
  align-items: center;
  gap: 6px;
}
.tile-name {
  min-width: 0;
  flex: 1 1 auto;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.25;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.tile-where {
  color: var(--m-muted);
  font-size: 11px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tile-name-meta {
  flex: 0 0 auto;
  margin-left: auto;
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 10px;
  font-weight: 700;
  white-space: nowrap;
}
.tile-rent {
  margin-top: 2px;
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.tile-rent--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 11.5px;
  font-weight: 600;
}
.tile-per {
  font-size: 10.5px;
  font-weight: 600;
  opacity: 0.7;
}
.none {
  margin: 0;
  padding: 14px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
</style>
