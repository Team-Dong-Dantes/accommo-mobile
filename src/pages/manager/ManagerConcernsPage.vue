<template>
  <!-- Beside its list rather than over it on a landscape tablet; see
       `.page-split` in app.scss. -->
  <q-page class="cp" :class="{ 'page-split': isTablet, 'page-wide desk-split': isDesktop }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: search pinned at the top of the list, not floating over it. -->
      <SearchDock
        v-if="isDesktop && !loading && !error"
        v-model="query"
        inline
        class="desk-search"
        :filter-count="filter !== 'all' ? 1 : 0"
        placeholder="Search boarder or concern"
        search-label="Search concerns"
        @open-filters="filtersOpen = true"
      />
      <div v-if="loading" class="stack">
        <div class="group">
          <div v-for="n in 3" :key="n" class="row">
            <q-skeleton type="circle" size="36px" />
            <span class="row-body">
              <span class="row-top">
                <q-skeleton type="text" width="40%" height="14px" />
                <q-skeleton type="text" width="50px" height="16px" />
              </span>
              <q-skeleton type="text" width="70%" height="12px" />
              <q-skeleton type="text" width="30%" height="11px" />
            </span>
          </div>
        </div>
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load concerns" :detail="error" :retry="load" inset />
      </div>

      <EmptyState
        v-else-if="!rows.length"
        icon="lucide:message-square-warning"
        title="No concerns right now"
        message="Maintenance, safety and billing concerns from your boarders land in this inbox."
      />

      <EmptyState
        v-else-if="!visibleRows.length"
        variant="compact"
        icon="lucide:search-x"
        title="Nothing matches"
        message="Try a different search or filter."
      />

      <div v-else class="stack">
        <div class="group">
          <button v-for="c in visibleRows" :key="c.id" type="button" class="row" @click="openDetail(c)">
            <span class="row-avatar" :class="c.avatarColor ? [`bg-${c.avatarColor}`, 'text-white'] : []">
              <img v-if="c.avatarUrl" :src="c.avatarUrl" alt="" class="row-avatar-img" @error="c.avatarUrl = null" />
              <template v-else>{{ initialsOf(c.studentName) }}</template>
            </span>
            <span class="row-body">
              <span class="row-top">
                <span class="row-name">{{ c.studentName }}</span>
                <span class="row-chip" :class="`row-chip--${statusColor(CONCERN_STATUS, c.status)}`">{{ statusText(CONCERN_STATUS, c.status) }}</span>
              </span>
              <span class="row-desc">{{ CONCERN_CATEGORY_LABEL[c.category] || c.category }} · {{ c.where }}</span>
              <span class="row-when">{{ since(c.reportedAt) }}</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chevron" />
          </button>
        </div>
      </div>
    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band -->
    <SearchDock
      v-if="!loading && !error && !isDesktop"
      v-model="query"
      :filter-count="filter !== 'all' ? 1 : 0"
      placeholder="Search boarder or concern"
      search-label="Search concerns"
      @open-filters="filtersOpen = true"
    />

    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      @clear="filter = 'all'"
    >
      <div class="sheet-block">
        <span class="sheet-label">Status</span>
        <div class="m-chips">
          <button
            v-for="f in FILTERS"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': filter === f.key }"
            @click="filter = f.key"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
    </BottomSheet>

    <ConcernDetail />
  </q-page>
</template>

<script setup lang="ts">
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { CONCERN_CATEGORY_LABEL, CONCERN_STATUS, initialsOf, statusColor, statusText } from '@/utils/format'
import ConcernDetail from '@/components/manager/concerns/ConcernDetail.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { FILTERS } from '@/components/manager/concerns/model'
import { Icon as IconifyIcon } from '@iconify/vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import { isDesktop, isTablet } from '@/utils/useTabletMode'
import { since } from '@/utils/notifications'
import { provideManagerConcerns } from '@/components/manager/concerns/managerConcerns'

// The page is the inbox, its search and filters. The open concern lives in
// components/manager/concerns/.
const {
  loading,
  error,
  rows,
  query,
  filter,
  filtersOpen,
  visibleRows,
  openDetail,
  load,
  onPull,
} = provideManagerConcerns()
</script>

<style scoped src="@/components/shared/concernList.css"></style>

<style scoped>
.row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .row:first-child {
  border-top: 0;
}
.row-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}
.row-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.row-name {
  min-width: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.row-desc {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
