<template>
  <q-page class="sp" :class="{ 'page-wide': isDesktop }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded card's two halves, stay left and payments right. -->
      <div v-if="loading && isDesktop" class="stack">
        <div class="desk-card">
          <div v-for="title in ['My Stay', 'Payments']" :key="title" class="desk-col">
            <h2 class="split-head">{{ title }}</h2>
            <q-skeleton type="rect" height="120px" class="sk" />
            <q-skeleton type="rect" height="90px" class="sk" />
          </div>
        </div>
      </div>

      <div v-else-if="loading" class="stack">
        <q-skeleton type="rect" height="200px" square class="sk-hero" />
        <q-skeleton type="rect" height="120px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your stay" :detail="error" :retry="load" />
      </div>

      <EmptyState
        v-else-if="!lease && !payments.length"
        icon="lucide:home"
        title="No active stay"
        message="Once a landlord/landlady accepts your application, your tenancy details, rent and landlord/landlady contact will show up here."
      >
        <template #actions>
          <q-btn unelevated rounded no-caps color="primary" label="Browse rooms" @click="router.push('/student/discover')" />
        </template>
      </EmptyState>

      <div v-else class="stack">
        <div class="m-tabbed" :class="{ 'stay-both': isTablet, 'm-tabbed--hero': lease && !isDesktop }">
          <StayHero
            v-if="lease && !isDesktop"
            :name="lease.accommodationName"
            :room="lease.roomLabel"
            :address="lease.address"
            :status="lease.status"
            :photo-url="lease.photoUrl"
          />
          <!-- A phone shows one panel at a time and needs the strip to choose.
               On a tablet both are up, so there is nothing left to pick. -->
          <div v-if="!isTablet" class="tabs">
            <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'stay' }" @click="activeTab = 'stay'">
              My Stay
            </button>
            <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'payments' }" @click="activeTab = 'payments'">
              Payments
            </button>
          </div>

          <div :class="isDesktop ? 'desk-card' : 'panel'">
            <!-- Sliding QTabPanels on a phone; on a tablet, where both halves are
                 up side by side, plain divs (useDeskPanels keyed on isTablet). -->
            <component :is="panelsIs" v-bind="panelsProps" :class="isDesktop ? 'desk-contents' : 'm-panels'">
              <component :is="panelIs" name="stay" :class="isDesktop ? 'desk-col' : 'tab-panel'">
                <StayPanel />
              </component>

              <component :is="panelIs" name="payments" :class="isDesktop ? 'desk-col' : 'tab-panel'">
                <StayPayments />
              </component>
            </component>
          </div>
        </div>
      </div>
    </q-pull-to-refresh>
    <StaySheets />
  </q-page>
</template>

<script setup lang="ts">
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import StayHero from '@/components/student/StayHero.vue'
import StayPanel from '@/components/student/stay/StayPanel.vue'
import StayPayments from '@/components/student/stay/StayPayments.vue'
import StaySheets from '@/components/student/stay/StaySheets.vue'
import { isDesktop, isTablet } from '@/utils/useTabletMode'
import { provideStay } from '@/components/student/stay/stay'

// The page is the shell — loading, the tab strip (or tablet's two halves).
// The panels and sheets live in components/student/stay/.
const {
  router,
  loading,
  error,
  lease,
  payments,
  activeTab,
  panelsIs,
  panelIs,
  panelsProps,
  load,
  onPull,
} = provideStay()
</script>

<style scoped>
.sp {
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
}
/* Default tabbing design (see AccommodationDetail.vue) — edge-to-edge tabs
   and a panel stretched flush to the true bottom of the page (same
   full-bleed + bottom-flush technique as ManagerTenantsPage.vue): the whole
   flex chain (.sp -> .stack -> .tabbed -> .panel) has to carry flex:1;
   min-height:0 for this to work, not just the panel itself. */
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
     a hairline gap of page background under the active tab. */
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
}
.panel {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  margin: 0 calc(var(--m-page-gutter) * -1);
  padding: 14px 14px 20px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
/* The hero runs edge to edge under the app header, and the tab strip is
   pulled up over its bottom edge so the panel rises out of the photo — the
   same recipe as AccommodationDetail.vue. .m-tabbed has no gap, so the two
   negative margins are all that sits between them. */
.sk-hero {
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
  width: auto;
}
.m-tabbed--hero > .stay-hero {
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
}
.m-tabbed--hero > .tabs {
  margin-top: -56px;
}
/* Desktop: the hero heads the stay half instead, as a card of its own. */
.desk-col > .stay-hero {
  height: 180px;
  border-radius: var(--m-radius);
}
/* Both panels at once on a landscape tablet. The tab strip is gone, so the panel
   squares off the top corners it was using to fuse into it, and each half names
   itself where its tab used to. */
.stay-both .panel {
  border-radius: var(--m-radius);
}
.stay-both .m-panels {
  display: grid;
  gap: 20px;
  grid-template-columns: 1fr 1fr;
  align-items: start;
}
.stay-both .tab-panel + .tab-panel {
  padding-left: 20px;
  border-left: 1px solid var(--m-border);
}
.split-head {
  margin: 0 0 2px;
  line-height: 1.3;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
}
</style>
