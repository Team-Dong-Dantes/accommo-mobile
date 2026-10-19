<template>
  <SearchDock
    v-if="split"
    v-model="query"
    inline
    class="desk-search"
    :filter-count="filter !== 'all' || selectedAccId !== 'all' ? 1 : 0"
    placeholder="Search boarders or rooms"
    search-label="Search boarders"
    @open-filters="filtersOpen = true"
  />
  <!-- Both start by picking from the list below: a boarder to log a payment
       for, a room with an open bed to add a walk-in student to. -->
  <div class="top-actions">
    <button
      v-if="picking !== 'room'"
      type="button"
      class="top-pay-btn"
      :class="{ 'top-pay-btn--ghost': picking === 'payment' }"
      @click="togglePicking('payment')"
    >
      <IconifyIcon :icon="picking === 'payment' ? 'lucide:x' : 'lucide:hand-coins'" width="16" />
      {{ picking === 'payment' ? 'Cancel' : 'Log a payment' }}
    </button>
    <button
      v-if="picking !== 'payment'"
      type="button"
      class="top-pay-btn top-pay-btn--ghost"
      @click="togglePicking('room')"
    >
      <IconifyIcon :icon="picking === 'room' ? 'lucide:x' : 'lucide:user-plus'" width="16" />
      {{ picking === 'room' ? 'Cancel' : 'Add a student' }}
    </button>
  </div>
  <p v-if="picking" class="picking-hint">
    <IconifyIcon icon="lucide:pointer" width="14" />
    {{ picking === 'payment' ? 'Tap a boarder below to log their payment.' : 'Tap a room with an open bed to add a student to it.' }}
  </p>

  <section v-for="acc in visibleAccommodations" :key="acc.id" class="acc">
    <button type="button" class="acc-head" @click="toggleAcc(acc.id)">
      <span class="acc-thumb" :class="`acc-thumb--${occupancyTone(accSummary.get(acc.id)?.occupancyPct ?? 0)}`">
        <img v-if="acc.coverUrl" :src="acc.coverUrl" alt="" />
        <PhotoEmpty v-else />
      </span>
      <span class="acc-head-body">
        <span class="acc-title-row">
          <h2 class="acc-title">{{ acc.name }}</h2>
          <span v-if="accAlertCounts.get(acc.id)" class="acc-badge">{{ accAlertCounts.get(acc.id) }} to review</span>
        </span>
        <span class="acc-stats-row">
          <span class="acc-stats">{{ accStatsLine(acc) }}</span>
          <span v-if="accTenants.get(acc.id)?.length" class="acc-faces" aria-hidden="true">
            <span
              v-for="l in accTenants.get(acc.id)!.slice(0, 4)"
              :key="l.id"
              class="acc-face"
              :class="l.avatarColor ? [`bg-${l.avatarColor}`, 'text-white'] : []"
            >
              <img v-if="l.avatarUrl" :src="l.avatarUrl" alt="" @error="l.avatarUrl = null" />
              <template v-else>{{ initialsOf(l.studentName) }}</template>
            </span>
            <span v-if="accTenants.get(acc.id)!.length > 4" class="acc-face acc-face--more">
              +{{ accTenants.get(acc.id)!.length - 4 }}
            </span>
          </span>
        </span>
        <!-- How full the property is, readable before you expand it. -->
        <span class="acc-occ-track">
          <span
            class="acc-occ-fill"
            :style="{ width: (accSummary.get(acc.id)?.occupancyPct ?? 0) + '%' }"
          />
        </span>
      </span>
      <IconifyIcon icon="lucide:chevron-down" width="18" class="acc-chevron" :class="{ 'acc-chevron--open': !collapsedAccIds.has(acc.id) }" />
    </button>
    <q-slide-transition>
      <TenantRooms v-show="!collapsedAccIds.has(acc.id)" :acc="acc" />
    </q-slide-transition>
  </section>
</template>

<script setup lang="ts">
// The Boarders tab: each accommodation, its rooms and who is in them.
import { Icon as IconifyIcon } from '@iconify/vue'
import { initialsOf } from '@/utils/format'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import TenantRooms from './TenantRooms.vue'
import { useTenants } from './tenants'

const {
  split,
  query,
  filter,
  filtersOpen,
  selectedAccId,
  collapsedAccIds,
  toggleAcc,
  accAlertCounts,
  accSummary,
  accTenants,
  visibleAccommodations,
  accStatsLine,
  occupancyTone,
  picking,
  togglePicking,
} = useTenants()
</script>

<style scoped>
.top-actions {
  display: flex;
  gap: 8px;
}
.top-pay-btn {
  display: flex;
  flex: 1;
  min-height: 44px;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.top-pay-btn--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-ink);
}
.picking-hint {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: -4px 2px 0;
  color: var(--m-muted);
  font-size: 12px;
  text-align: center;
}
/* One connected card — the header and its rooms share this border/radius
   instead of floating as separate boxes with a gap between them. */
.acc {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.acc-head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 0;
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
/* Sits under the stats line inside the header, so the property's fullness
   reads as part of its summary rather than a strip across the card. */
.acc-occ-track {
  display: block;
  height: 4px;
  margin-top: 7px;
  border-radius: 999px;
  background: var(--m-border);
  overflow: hidden;
}
.acc-occ-fill {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--m-primary);
  transition: width 0.3s ease;
}
.acc-thumb {
  position: relative;
  display: grid;
  width: 46px;
  height: 46px;
  flex: 0 0 46px;
  place-items: center;
  overflow: hidden;
  border: 2px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.acc-thumb--green {
  border-color: var(--m-success);
}
.acc-thumb--amber {
  border-color: var(--m-warning);
}
.acc-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.acc-head-body {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 0;
}
.acc-title-row {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 8px;
}
.acc-title {
  min-width: 0;
  margin: 0;
  line-height: 1.3;
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.acc-stats-row {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-top: 1px;
}
.acc-stats {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.acc-faces {
  display: flex;
  flex: 0 0 auto;
  padding-left: 6px;
}
.acc-face {
  display: grid;
  width: 24px;
  height: 24px;
  margin-left: -6px;
  place-items: center;
  overflow: hidden;
  border: 2px solid var(--m-surface);
  border-radius: 50%;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 8.5px;
  font-weight: 800;
}
.acc-face img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.acc-face--more {
  background: var(--m-bg);
  color: var(--m-muted);
}
.acc-badge {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10.5px;
  font-weight: 800;
  white-space: nowrap;
}
.acc-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
  transition: transform 0.2s ease;
}
.acc-chevron--open {
  transform: rotate(180deg);
}
/* The panel has no side padding, so the lists run edge to edge as flat
   sections; only the loose controls and headings keep an inset. */
.panel :is(.acc, .group) {
  border-right: 0;
  border-left: 0;
  border-radius: 0;
}
/* Flat properties butt together, split by a page-coloured band instead of
   .tab-panel's 14px gap, which read as an empty white row between borders. */
.panel .acc + .acc {
  margin-top: -14px;
  border-top: 8px solid var(--m-bg);
}
/* Listed one by one, not as `.panel :is(...)`: in that form Vue scopes .panel
   instead of the target, and the inset leaks into child components' headers. */
.panel .top-actions,
.panel .picking-hint,
.panel .sec-title,
.panel .sec-head {
  margin-right: 12px;
  margin-left: 12px;
}
</style>
