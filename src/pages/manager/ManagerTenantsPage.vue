<template>
  <q-page class="tp" :class="{ 'page-wide': split }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded card's two halves, tenants left and payments right. -->
      <div v-if="loading && split" class="stack">
        <div class="desk-card">
          <div class="desk-col">
            <q-skeleton type="rect" height="40px" class="sk sk-pill" />
            <div v-for="n in 2" :key="n" class="acc">
              <div class="acc-head">
                <q-skeleton type="rect" size="36px" />
                <span class="acc-head-body">
                  <q-skeleton type="text" width="55%" height="15px" />
                  <q-skeleton type="text" width="35%" height="12px" />
                </span>
              </div>
            </div>
          </div>
          <div class="desk-col">
            <h2 class="sec-title">Monthly rent</h2>
            <q-skeleton type="rect" height="70px" class="sk" />
          </div>
        </div>
      </div>

      <div v-else-if="loading" class="stack">
        <div class="tabs">
          <q-skeleton v-for="n in 3" :key="n" type="rect" width="88px" height="38px" class="m-sk-tab" />
        </div>
        <div v-for="n in 2" :key="n" class="acc">
          <div class="acc-head">
            <q-skeleton type="rect" size="36px" />
            <span class="acc-head-body">
              <q-skeleton type="text" width="55%" height="15px" />
              <q-skeleton type="text" width="35%" height="12px" />
            </span>
          </div>
        </div>
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your boarders" :detail="error" :retry="load" inset />
      </div>

      <EmptyState
        v-else-if="!accommodations.length"
        icon="lucide:users"
        title="No boarders yet"
        message="When a student applies for one of your rooms and you accept them, they show up here grouped by room — empty beds included, plus any applications still waiting on you."
      />

      <div v-else class="stack">
        <div class="m-tabbed">
        <div v-if="!split" class="tabs" role="tablist" aria-label="My Boarders">
          <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'tenants' }" @click="activeTab = 'tenants'">
            Boarders
          </button>
          <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'payments' }" @click="activeTab = 'payments'">
            Monthly rent
            <span v-if="toConfirm" class="tab-dot">{{ toConfirm }}</span>
          </button>
          <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'history' }" @click="activeTab = 'history'">
            Rent history
          </button>
        </div>

        <!-- Desktop has the room for both at once, so the tabs go and the same
             two panels sit side by side. The markup is shared: on desktop the
             panels are plain divs, elsewhere the swipeable QTabPanels. -->
        <div :class="split ? 'desk-card' : 'panel'">
        <component :is="panelsIs" v-bind="panelsProps" :class="split ? 'desk-contents' : 'm-panels'">
          <component :is="panelIs" name="tenants" :class="split ? 'desk-col' : 'tab-panel'">
            <TenantsList />
          </component>

          <!-- On desktop the right column holds both, switched by its own m-tab pair. -->
          <component :is="panelIs" v-show="!split || activeTab !== 'history'" name="payments" :class="split ? 'desk-col' : 'tab-panel'">
            <div v-if="split" class="desk-tabs" role="tablist" aria-label="Rent">
              <button type="button" class="m-tab m-tab--on" role="tab" aria-selected="true">
                Monthly rent
                <span v-if="toConfirm" class="tab-dot">{{ toConfirm }}</span>
              </button>
              <button type="button" class="m-tab" role="tab" aria-selected="false" @click="activeTab = 'history'">Rent history</button>
            </div>
            <CollectionsPanel :version="loadVersion" :query="query" @changed="load(true)" @count="(n: number) => (toConfirm = n)" />
          </component>

          <component :is="panelIs" v-show="!split || activeTab === 'history'" name="history" :class="split ? 'desk-col' : 'tab-panel'">
            <div v-if="split" class="desk-tabs" role="tablist" aria-label="Rent">
              <button type="button" class="m-tab" role="tab" aria-selected="false" @click="activeTab = 'payments'">
                Monthly rent
                <span v-if="toConfirm" class="tab-dot">{{ toConfirm }}</span>
              </button>
              <button type="button" class="m-tab m-tab--on" role="tab" aria-selected="true">Rent history</button>
            </div>
            <RentHistoryPanel :version="loadVersion" :query="query" />
          </component>
        </component>
        </div>
        </div>
      </div>
</q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band.
         Outside the pull-to-refresh wrapper on purpose: it transforms its
         content while you pull, which would drag this fixed dock along. -->
    <SearchDock
      v-if="!loading && !error && !split"
      v-model="query"
      :filter-count="filter !== 'all' || selectedAccId !== 'all' ? 1 : 0"
      :no-filters="activeTab !== 'tenants'"
      placeholder="Search boarders or rooms"
      search-label="Search boarders"
      above-nav
      @open-filters="filtersOpen = true"
    />

    <TenantsSheets />
</q-page>
</template>

<script setup lang="ts">
import CollectionsPanel from '@/components/manager/CollectionsPanel.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import RentHistoryPanel from '@/components/manager/RentHistoryPanel.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import TenantsList from '../../components/manager/tenants/TenantsList.vue'
import TenantsSheets from '../../components/manager/tenants/TenantsSheets.vue'
import { provideTenants } from '../../components/manager/tenants/tenants'

// The page is the shell — loading, the tabs (or desktop's two halves), the
// rent panels and the search dock. The list and its sheets live in
// components/manager/tenants/.
const {
  loading,
  error,
  accommodations,
  activeTab,
  split,
  panelsIs,
  panelIs,
  panelsProps,
  loadVersion,
  toConfirm,
  query,
  filter,
  filtersOpen,
  selectedAccId,
  load,
  onPull,
} = provideTenants()
</script>

<style scoped>
.tp {
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
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
  margin: 0 var(--m-page-gutter);
}
/* A half has its own padding. */
.desk-col > .sk {
  margin: 0;
}
/* Stands in for the desk search pinned atop the left half. */
.sk-pill {
  border-radius: 999px;
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
.acc-head-body {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 0;
}
.room {
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--m-border);
}
/* Same underline-tab convention used elsewhere in the app (e.g. the tenant
   profile's Overview/Payments/History tabs) — reused here, not reinvented. */
/* Same rounded-top pill tabs feeding into a bordered panel as
   accommodation detail's own tabs (just without the frosted-glass-over-photo
   colors, since there's no hero image behind these). */
/* No gap here (unlike .stack) — the -2px overlap below needs the tabs and
   panel to actually touch, which a flex gap on their shared parent would
   otherwise add back in on top of. */
/* QPullToRefresh wraps the page body in two plain <div>s of its own, which
   land between the q-page and .stack and break the flex chain the bottom-flush
   panel needs — .stack's flex:1 measures against a block box that just hugs its
   content, so the card stops wherever the content happens to end. Passing the
   chain through them costs nothing: neither div clips or scrolls. */
:deep(.q-pull-to-refresh),
:deep(.q-pull-to-refresh__content) {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
}
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  /* -2px, not -1px: an exact 1px overlap can round the wrong way at
     fractional device-pixel ratios (real phones, not desktop @1x) and leave
     a hairline gap of page background under the active tab. The active
     tab's background already equals the panel's, so the extra 1px of
     overlap is invisible — it just guarantees full coverage. */
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
}
.tab-dot {
  display: inline-grid;
  min-width: 16px;
  height: 16px;
  margin-left: 6px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  font-size: 9.5px;
  font-weight: 800;
}
/* Its own card, distinct from .stack's background — the active tab's
   background matches this, so the -1px overlap above fuses them with no
   visible seam, while the unselected tab still shows the border. */
.panel {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  margin: 0 calc(var(--m-page-gutter) * -1);
  /* The dock-clearance reserve lives here, not on .stack — this way the
     card's own background still stretches to the true bottom of the page
     instead of stopping short with a gap of plain page background. */
  padding: 14px 0 126px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
/* The half's header, like the search beside it: pulled out to the half's
   edges and stuck to its top, with a rule under it that the active tab covers,
   so the folder opens into the panel instead of floating above it. */
.desk-tabs {
  position: sticky;
  top: -14px;
  z-index: 3;
  display: flex;
  gap: 4px;
  margin: -14px -18px 0;
  padding: 12px 18px 0;
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
}
.desk-tabs .m-tab {
  margin-bottom: -1px;
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 14px;
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
.panel .sec-head .sec-title {
  margin: 0;
}
.sec-title {
  margin: 0;
  line-height: 1.3;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
</style>
