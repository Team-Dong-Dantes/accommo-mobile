<template>
  <q-page class="history-page" :class="{ 'page-wide': split }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded shape — the way back live already above a card
           showing one tab at a time, with its own search. -->
      <div v-if="loading && split" class="stack">
        <div class="desk-back-row">
          <button type="button" class="desk-panel-back" :aria-label="backLabel" @click="goBack">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </button>
          <span class="desk-panel-title">{{ backLabel }}</span>
        </div>
        <div class="desk-card desk-card--tabbed">
          <div class="desk-col">
            <q-skeleton type="rect" height="40px" class="sk sk-search" />
            <q-skeleton type="rect" height="90px" class="sk" />
            <q-skeleton type="rect" height="90px" class="sk" />
          </div>
        </div>
      </div>

      <div v-else-if="loading" class="stack">
        <q-skeleton type="rect" height="40px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your history" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <!-- Desktop: the way back sits just above the card, as on an
             accommodation; the app header stays the plain one (see OWN_BACK
             in MainLayout). -->
        <div v-if="split" class="desk-back-row">
          <button type="button" class="desk-panel-back" :aria-label="backLabel" @click="goBack">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </button>
          <span class="desk-panel-title">{{ backLabel }}</span>
        </div>
        <div class="m-tabbed">
          <div class="tabs" role="tablist" aria-label="History">
            <button
              v-for="t in TABS"
              :key="t.key"
              type="button"
              role="tab"
              :aria-selected="tab === t.key"
              class="m-tab"
              :class="{ 'm-tab--on': tab === t.key }"
              @click="tab = t.key"
            >
              {{ t.label }}
            </button>
          </div>

          <!-- Desktop: still tabs, not halves side by side (ratings used to be
               moved in below payments). -->
          <div :class="split ? 'desk-card desk-card--tabbed' : 'panel'">
            <component :is="panelsIs" v-bind="panelsProps" :class="split ? 'desk-contents' : 'm-panels'">
              <component :is="panelIs" v-show="!split || tab === 'history'" name="history" :class="split ? 'desk-col' : 'tab-panel'">
                <!-- Desktop: each tab searches only itself. -->
                <SearchDock v-if="split" v-model="queries.history" inline no-filters class="desk-search" :filter-count="0" placeholder="Search boarding history" search-label="Search" />
                <BoardingHistoryTab :stays="stays" :query="queries.history" @rate="openReview" @payments="showPayments" />
              </component>

              <component :is="panelIs" v-show="!split || tab === 'reviews'" name="reviews" :class="split ? 'desk-col' : 'tab-panel'">
                <SearchDock v-if="split" v-model="queries.reviews" inline no-filters class="desk-search" :filter-count="0" placeholder="Search ratings" search-label="Search" />
                <StudentRatingsTab :reviews="reviewsFromManagers" :query="queries.reviews" />
              </component>

              <component :is="panelIs" v-show="!split || tab === 'payments'" name="payments" :class="split ? 'desk-col' : 'tab-panel'">
                <SearchDock v-if="split" v-model="queries.payments" inline no-filters class="desk-search" :filter-count="0" placeholder="Search month or method" search-label="Search" />
                <StudentPaymentsTab :payments="payments" :owed="owed" :query="queries.payments" :expand="expandLease" />
              </component>
            </component>
          </div>
        </div>
      </div>
    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band
         on a tab-shell page — but History is a subpage (no FAB, no bottom
         nav), so it just spans the full width instead of reserving FAB room.
         Outside the pull-to-refresh wrapper on purpose: it transforms its
         content while you pull, which would drag this fixed dock along.
         None of the three tabs has a filter button: their filters are pills
         inside the tab. -->
    <SearchDock
      v-if="!loading && !error && !split"
      v-model="queries[tab]"
      no-filters
      :filter-count="0"
      :placeholder="tab === 'payments' ? 'Search month or method' : tab === 'reviews' ? 'Search ratings' : 'Search boarding history'"
      search-label="Search"
    />

    <!-- Rate stay -->
    <AppModal v-model="reviewOpen" :title="reviewTarget ? `Rate your stay at ${reviewTarget.name}` : ''">
      <template v-if="reviewTarget">
        <div class="review-field">
          <span class="review-field-label">The place</span>
          <StarRating v-model="reviewForm.accRating" interactive :size="26" />
          <textarea v-model="reviewForm.accComment" class="review-textarea" rows="2" placeholder="What was it like? (optional)" />
        </div>

        <div class="review-field">
          <span class="review-field-label">The landlord/landlady</span>
          <StarRating v-model="reviewForm.managerRating" interactive :size="26" />
          <textarea v-model="reviewForm.managerComment" class="review-textarea" rows="2" placeholder="How were they to deal with? (optional)" />
        </div>
      </template>
      <template #footer>
        <q-btn unelevated rounded no-caps color="primary" class="review-submit" :loading="submittingReview" label="Submit" @click="submitReview" />
      </template>
    </AppModal>
  </q-page>
</template>

<script setup lang="ts">
import AppModal from '@/components/shared/AppModal.vue'
import BoardingHistoryTab from '@/components/student/BoardingHistoryTab.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import StarRating from '@/components/shared/StarRating.vue'
import StudentPaymentsTab from '@/components/student/StudentPaymentsTab.vue'
import StudentRatingsTab from '@/components/student/StudentRatingsTab.vue'
import { TABS } from '@/components/student/history/model'
import { useStudentHistory } from '@/components/student/history/state'

// History's data lives in components/student/history/; this page lays out its
// tabs (or desktop card), search and the rating sheet.
const {
  backLabel,
  goBack,
  loading,
  error,
  tab,
  split,
  panelsIs,
  panelIs,
  panelsProps,
  stays,
  reviewsFromManagers,
  payments,
  owed,
  expandLease,
  queries,
  showPayments,
  reviewOpen,
  submittingReview,
  reviewTarget,
  reviewForm,
  openReview,
  submitReview,
  load,
  onPull,
} = useStudentHistory()
</script>

<style scoped>
.history-page {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 12px;
  padding: 10px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
/* Stands in for a half's own search (.desk-search). */
.sk-search {
  border-radius: 999px;
}

/* Same rounded-top pill tabs fused into a bordered panel used by
   AccommodationDetail.vue / TenantProfile.vue / ManagerTenantsPage.vue —
   the default tabbed-section design for this app. */
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
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
}
.panel {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  margin: 0 calc(var(--m-page-gutter) * -1);
  /* Extra bottom room so the last row isn't hidden under the fixed dock —
     this page has no bottom nav/FAB to clear, just the dock itself. */
  padding: 14px 14px 84px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.review-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.review-field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.review-textarea {
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  resize: vertical;
}
.review-submit {
  flex: 1;
  min-height: 48px;
  font-weight: 700;
}
</style>
