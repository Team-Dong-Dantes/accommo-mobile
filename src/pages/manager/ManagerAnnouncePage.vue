<template>
  <!-- Laid out like Concerns: on a tablet or computer the list sits beside the
       announcement you pick (see `.page-split` / `.desk-split` in app.scss). -->
  <q-page
    class="ann-page"
    :class="isTablet ? { 'page-split': true, 'page-wide desk-split': isDesktop } : 'ann-page--phone'"
  >
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: search pinned at the top of the list, not floating over it. -->
      <SearchDock
        v-if="isDesktop && !loading && mine.length"
        v-model="query"
        inline
        class="desk-search"
        :filter-count="filterCount"
        placeholder="Search announcements"
        search-label="Search announcements"
        @open-filters="filtersOpen = true"
      />
      <div v-if="loading" class="stack">
        <q-skeleton type="rect" height="120px" class="sk" />
        <q-skeleton type="rect" height="70px" class="sk" />
      </div>

      <EmptyState
        v-else-if="!accommodations.length"
        icon="lucide:building-2"
        title="No accommodation yet"
        message="Add an accommodation first — announcements go to the boarders of one of your houses."
      />

      <div v-else class="stack">
        <section class="sec">
          <EmptyState
            v-if="!mine.length"
            variant="compact"
            icon="lucide:megaphone"
            title="Nothing sent yet"
            message="Notices you send your boarders are listed here."
          />
          <EmptyState
            v-else-if="!visible.length"
            variant="compact"
            icon="lucide:search-x"
            title="Nothing matches"
            message="Try a different search or filter."
          />
          <div v-for="a in visible" :key="a.id" class="item" :class="{ 'item--on': a.id === selectedId }">
            <!-- Opens beside the list on a tablet or computer; a phone keeps
                 the plain list it always had. -->
            <component
              :is="isTablet ? 'button' : 'div'"
              :type="isTablet ? 'button' : undefined"
              class="item-text"
              @click="isTablet && (selectedId = a.id)"
            >
              <span class="item-title">{{ a.title }}</span>
              <span class="item-meta">{{ houseName(a.accommodation_id) }} · {{ statusOf(a) }}</span>
            </component>
            <button type="button" class="item-act" aria-label="Remove announcement" @click="remove(a)">
              <IconifyIcon icon="lucide:trash-2" width="16" />
            </button>
          </div>
        </section>
      </div>

      <!-- Tablet and computer: the action is the footer of the list panel. -->
      <div v-if="isTablet && !loading && accommodations.length" class="new-bar desk-foot">
        <button type="button" class="fab fab--inline" @click="composeOpen = true">
          <IconifyIcon icon="lucide:megaphone" width="17" />
          New announcement
        </button>
      </div>
    </q-pull-to-refresh>

    <!-- Desktop: the form takes the right half, beside the list, rather than
         covering the whole screen. Its own close button puts the half back. -->
    <AnnouncementCompose
      v-if="composeOpen && isDesktop"
      class="desk-compose"
      :accommodations="accommodations"
      :submitting="sending"
      @close="composeOpen = false"
      @submit="send"
    />

    <AnnouncementDetail v-else-if="isTablet" />

    <!-- Outside the pull container: a fixed action must not travel with the
         gesture. Hidden while composing, since the overlay covers it anyway.
         Search rides the same band, with New announcement as its leading
         action (as Report a concern does on the student's Concerns). -->
    <SearchDock
      v-if="!isTablet && !loading && accommodations.length && !composeOpen"
      v-model="query"
      :filter-count="filterCount"
      :no-filters="!mine.length"
      placeholder="Search announcements"
      search-label="Search announcements"
      @open-filters="filtersOpen = true"
    >
      <template #action>
        <button type="button" class="dock-btn" aria-label="New announcement" @click="composeOpen = true">
          <IconifyIcon icon="lucide:megaphone" width="17" />
          <span class="dock-btn-label">New announcement</span>
        </button>
      </template>
    </SearchDock>

    <AnnouncementFilters />

    <AnnouncementCompose
      v-if="composeOpen && !isDesktop"
      :accommodations="accommodations"
      :submitting="sending"
      @close="composeOpen = false"
      @submit="send"
    />
  </q-page>
</template>

<script setup lang="ts">
import AnnouncementCompose from '@/components/manager/AnnouncementCompose.vue'
import AnnouncementDetail from '@/components/manager/announcements/AnnouncementDetail.vue'
import AnnouncementFilters from '@/components/manager/announcements/AnnouncementFilters.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import { isDesktop, isTablet } from '@/utils/useTabletMode'
import { provideAnnouncements } from '@/components/manager/announcements/announcements'

// The page is the list, its search and the compose form. The open
// announcement and the filters live in components/manager/announcements/.
const {
  loading,
  sending,
  composeOpen,
  accommodations,
  mine,
  selectedId,
  houseName,
  statusOf,
  query,
  filtersOpen,
  filterCount,
  visible,
  onPull,
  send,
  remove,
} = provideAnnouncements()
</script>

<style scoped>
/* Phone only: room round the list and under it for the floating button. The
   split layouts (tablet, desktop) set their own spacing. */
.ann-page--phone { padding: 12px 12px calc(86px + env(safe-area-inset-bottom, 0px)); }
.page-split .stack { padding: 12px; }
/* The announcement open beside the list. */
.item--on { border-color: var(--m-primary); background: var(--m-primary-soft); }
.item-text {
  padding: 0;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
}
button.item-text { cursor: pointer; }
/* Desktop: "New announcement" pinned to the foot of the list's half — at the
   bottom of the half even when the list is short (margin-top: auto in a column
   that is at least the half's height), and stuck there when it is long. */
.page-split :deep(.q-pull-to-refresh__content) {
  display: flex;
  min-height: 100%;
  flex-direction: column;
}
.new-bar {
  position: sticky;
  bottom: 0;
  margin-top: auto;
  z-index: 3;
  padding: 10px 12px 12px;
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
/* .new-bar in front: .fab (the phone's floating button) is declared further down
   with the same weight and would otherwise pin this one to the window. */
.new-bar .fab--inline {
  position: static;
  width: 100%;
  justify-content: center;
  box-shadow: none;
}
.stack { display: flex; flex-direction: column; gap: 12px; }
.sk { border-radius: var(--m-radius); }
.sec { display: flex; flex-direction: column; gap: 6px; }
.item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.item-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.item-title {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.item-meta { color: var(--m-muted); font-size: 11px; font-weight: 600; }
.item-act {
  flex: 0 0 auto;
  border: 0;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
}
/* Matches the floating .dock band on the concerns pages: same bottom offset,
   same safe-area handling, so the action sits where the eye already expects
   a primary control on these screens. */
.fab {
  position: fixed;
  left: var(--m-page-gutter);
  bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  z-index: 60;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 52px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  box-shadow: var(--m-shadow);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
</style>
