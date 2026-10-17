<template>
  <q-page class="ad" :class="{ 'page-wide': split }">
    <!-- Desktop: the loaded shape — the way back above a card of two halves,
         photo and overview left, rooms right. -->
    <div v-if="loading && split" class="stack">
      <div class="desk-back-row">
        <button type="button" class="desk-panel-back" aria-label="Back to properties" @click="router.push('/manager/properties')">
          <IconifyIcon icon="lucide:arrow-left" width="20" />
        </button>
        <span class="desk-panel-title">Properties</span>
      </div>
      <div class="desk-card">
        <div class="desk-col">
          <q-skeleton type="rect" height="220px" square class="sk-hero" />
          <q-skeleton type="rect" height="90px" class="sk" />
        </div>
        <div class="desk-col">
          <q-skeleton v-for="n in 2" :key="n" type="rect" height="90px" class="sk" />
        </div>
      </div>
    </div>

    <div v-else-if="loading" class="stack">
      <q-skeleton type="rect" height="220px" square />
      <div class="tabs">
        <q-skeleton type="rect" width="88px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="80px" height="38px" class="m-sk-tab" />
      </div>
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load this accommodation" :detail="error" :retry="load" />
    </div>

    <div v-else class="stack">
      <!-- Desktop keeps the plain app header, so the way back to Properties
           sits just above the card's left half. -->
      <div v-if="split" class="desk-back-row">
        <button type="button" class="desk-panel-back" aria-label="Back to properties" @click="router.push('/manager/properties')">
          <IconifyIcon icon="lucide:arrow-left" width="20" />
        </button>
        <span class="desk-panel-title">Properties</span>
      </div>
      <!-- Desktop: the two halves of a card — the photo, overview and settings
           on the left, rooms on the right, each scrolling on its own. On a phone
           .col-left is display: contents and nothing here changes. -->
      <div :class="split ? 'desk-card' : 'tabbed'">
        <div :class="split ? 'desk-col' : 'col-left'">
        <div class="hero">
          <div class="hero-media">
            <img v-if="coverUrl" :src="coverUrl" alt="" class="hero-img" />
            <PhotoEmpty v-else :size="28" label />
            <div class="hero-scrim" />
          </div>
          <button type="button" class="hero-edit" aria-label="Manage property photos" @click="coverSheetOpen = true">
            <IconifyIcon icon="lucide:camera" width="16" />
          </button>
          <div class="head">
            <span class="head-name">{{ acc.name || 'Unnamed accommodation' }}</span>
            <span class="head-chip" :class="`head-chip--${STATUS_TONE[acc.status] || 'grey'}`">{{ STATUS_LABEL[acc.status] || acc.status }}</span>
          </div>
        </div>

        <div v-if="!split" class="tabs">
          <button
            v-for="t in TABS"
            :key="t.key"
            type="button"
            class="m-tab"
            :class="{ 'm-tab--on': tab === t.key }"
            @click="tab = t.key"
          >
            {{ t.label }}
          </button>
        </div>

        <div class="panel">
        <component :is="panelsIs" v-bind="panelsProps" class="m-panels">
        <!-- OVERVIEW -->
        <component :is="panelIs" name="overview" class="sec">
          <OverviewPanel />
        </component>

        <!-- ROOMS & FACILITIES, both floor-accurate. On desktop the content
             moves to the right half; the Teleport sits inside the panel so
             QTabPanels still finds a panel named "rooms" on a phone. -->
        <component :is="panelIs" name="rooms" class="sec" :class="{ 'sec--moved': split }">
          <Teleport :to="rightCol" :disabled="!split || !rightCol">
          <RoomsPanel />
          </Teleport>
        </component>

        <!-- SETTINGS -->
        <component :is="panelIs" name="settings" class="sec">
          <SettingsPanel />
        </component>
        </component>
        </div>
        </div>

        <div v-if="split" ref="rightCol" class="desk-col col-right" />
      </div>
    </div>

    <DetailDialogs />
    <RoomDialog />
    <FacilityDialog />
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { STATUS_LABEL, STATUS_TONE, TABS } from './accommodation/model'
import { provideAccommodationDetail } from './accommodation/detail'
import OverviewPanel from './accommodation/OverviewPanel.vue'
import RoomsPanel from './accommodation/RoomsPanel.vue'
import SettingsPanel from './accommodation/SettingsPanel.vue'
import DetailDialogs from './accommodation/DetailDialogs.vue'
import RoomDialog from './accommodation/RoomDialog.vue'
import FacilityDialog from './accommodation/FacilityDialog.vue'

// The page is the shell — loading states, the hero, the tabs (or desktop's two
// halves). What is inside each tab and every sheet lives in ./accommodation/,
// all reading the one state this page provides.
const { router, loading, error, acc, coverUrl, coverSheetOpen, load } = provideAccommodationDetail()

type TabKey = (typeof TABS)[number]['key']
// ?tab= opens on a given tab — the OSAS page links straight to Settings.
const askedTab = TABS.find((t) => t.key === router.currentRoute.value.query.tab)?.key
const tab = ref<TabKey>(askedTab ?? 'overview')
// Desktop lays the tabs out as the halves of a card instead (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)
const rightCol = ref<HTMLElement | null>(null)

onMounted(load)
</script>

<style scoped src="./accommodation/rows.css"></style>

<style scoped>
.ad {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 14px;
  padding: 0 var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
/* Cover hero — capped to a fixed height (the "limit"), image always fills
   it edge to edge (no letterbox margins), title overlaid on top. The tab
   strip below is pulled up over its bottom edge with a negative margin. */
.hero {
  position: relative;
  flex: 0 0 auto;
  height: 220px;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.hero-media { position: absolute; inset: 0; overflow: hidden; }
.hero-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.5) 0%, rgba(0, 0, 0, 0) 45%);
}
.hero-edit {
  position: absolute;
  top: 10px;
  right: var(--m-page-gutter);
  z-index: 2;
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.55);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.head {
  position: absolute;
  left: var(--m-page-gutter);
  right: 54px;
  top: 14px;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 8px;
}
.head-name {
  min-width: 0;
  overflow: hidden;
  color: #fff;
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.35);
}
.head-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.head-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.head-chip--amber {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.head-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.head-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.tabbed {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  margin: 0 calc(var(--m-page-gutter) * -1);
}
/* Pulled up over the hero's bottom edge so the tab strip (and the card it
   feeds into) reads as one block rising out of the photo. */
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  padding: 0 var(--m-page-gutter);
  margin-top: -56px;
  /* -2px (not -1px): at fractional device-pixel ratios (real phones, not
     desktop @1x) an exact 1px overlap can round the wrong way and leave a
     hairline gap of the page background between the active tab and the
     panel. The active tab's background already equals the panel's, so the
     extra 1px of overlap is invisible — it just guarantees full coverage. */
  margin-bottom: -2px;
}
/* Same border + background as the active tab, and no top radius where the
   two meet — one seam-free block from tab strip down through the card. */
.panel {
  display: flex;
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 14px var(--m-page-gutter);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.sec {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
/* The photo runs to the half's edges; the card's rounding clips its corner. */
.desk-card .hero {
  margin: -14px -18px 0;
}
.desk-card .desk-col:first-child {
  gap: 0;
}
/* The loading photo, bleeding the same way and spaced as the overview is. */
.desk-card .sk-hero {
  width: auto;
  margin: -14px -18px 14px;
}
/* Overview and settings are content in the half, not a second card. */
.desk-card .panel {
  flex: none;
  margin-top: 14px;
  padding: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
}
/* Every panel renders on desktop, so overview and settings stack. */
.desk-card .m-panels {
  display: flex;
  flex-direction: column;
  gap: 22px;
}
.desk-card .col-right {
  gap: 22px;
}
/* Rooms' emptied tab shell, left behind once its content moved right. */
.sec--moved {
  display: none;
}
</style>
