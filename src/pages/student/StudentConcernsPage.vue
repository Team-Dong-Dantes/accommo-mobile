<template>
  <!-- Beside its list rather than over it on a landscape tablet; see
       `.page-split` in app.scss. -->
  <q-page class="cp" :class="{ 'page-split': isTablet, 'page-wide desk-split': isDesktop }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: search (and the report button) pinned at the top of the
           list, not floating over it. -->
      <SearchDock
        v-if="isDesktop && !loading && !error"
        v-model="query"
        inline
        class="desk-search"
        :filter-count="filter !== 'all' ? 1 : 0"
        placeholder="Search concerns"
        search-label="Search concerns"
        @open-filters="filtersOpen = true"
      />
      <!-- Says who answers, and where everything else goes (OSAS). -->
      <p class="scope-note">
        For problems with your room, rent or the house — your {{ myLandlord }} handles these.
        School or account matters go to <router-link to="/student/support" class="scope-note-link">OSAS</router-link>.
      </p>
      <div v-if="loading" class="stack">
        <div class="group">
          <div v-for="n in 3" :key="n" class="row">
            <span class="row-body">
              <span class="row-top">
                <q-skeleton type="text" width="35%" height="13px" />
                <q-skeleton type="text" width="50px" height="16px" />
              </span>
              <q-skeleton type="text" width="75%" height="12px" />
              <q-skeleton type="text" width="45%" height="11px" />
            </span>
          </div>
        </div>
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your concerns" :detail="error" :retry="load" inset />
      </div>

      <EmptyState
        v-else-if="!rows.length"
        icon="lucide:message-square-warning"
        title="No concerns yet"
        :message="`Maintenance, safety and billing issues you raise will show up here, with each one's status and your ${myLandlord}'s response.`"
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
            <span class="row-body">
              <span class="row-top">
                <span class="row-cat">{{ CONCERN_CATEGORY_LABEL[c.category] || c.category }}</span>
                <span class="row-chip" :class="`row-chip--${statusColor(CONCERN_STATUS, c.status)}`">{{ statusText(CONCERN_STATUS, c.status) }}</span>
              </span>
              <span class="row-desc">{{ c.description || 'No description' }}</span>
              <span class="row-when">{{ c.where }} · {{ since(c.reportedAt) }}</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chevron" />
          </button>
        </div>
      </div>

      <!-- Desktop: the list half's footer. -->
      <div v-if="isDesktop && !loading && !error" class="desk-foot">
        <button type="button" class="desk-foot-btn" :disabled="!activeLease" @click="openNew">
          <IconifyIcon icon="lucide:plus" width="17" />
          Report a concern
        </button>
      </div>
    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band -->
    <SearchDock
      v-if="!loading && !error && !isDesktop"
      v-model="query"
      :filter-count="filter !== 'all' ? 1 : 0"
      placeholder="Search concerns"
      search-label="Search concerns"
      @open-filters="filtersOpen = true"
    >
      <template #action>
        <button
          type="button"
          class="dock-btn"
          :disabled="!activeLease"
          aria-label="Report a concern"
          @click="openNew"
        >
          <IconifyIcon icon="lucide:plus" width="17" />
          <span class="dock-btn-label">Report a concern</span>
        </button>
      </template>
    </SearchDock>

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

    <ConcernReportSheet />
  </q-page>
</template>

<script setup lang="ts">
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { CONCERN_CATEGORY_LABEL, CONCERN_STATUS, statusColor, statusText } from '@/utils/format'
import ConcernDetail from '@/components/student/concerns/ConcernDetail.vue'
import ConcernReportSheet from '@/components/student/concerns/ConcernReportSheet.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { FILTERS } from '@/components/student/concerns/model'
import { Icon as IconifyIcon } from '@iconify/vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import { isDesktop, isTablet } from '@/utils/useTabletMode'
import { since } from '@/utils/notifications'
import { provideStudentConcerns } from '@/components/student/concerns/studentConcerns'

// The page is the list, its search and filters. The open concern and the
// report form live in components/student/concerns/.
const {
  myLandlord,
  loading,
  error,
  rows,
  query,
  filter,
  filtersOpen,
  activeLease,
  visibleRows,
  openDetail,
  openNew,
  load,
  onPull,
} = provideStudentConcerns()
</script>

<style scoped src="@/components/shared/concernList.css"></style>

<style scoped>
.scope-note {
  margin: 0;
  padding: 12px var(--m-page-gutter) 0;
  color: var(--m-muted);
  font-size: 12px;
}
.scope-note-link {
  color: var(--m-primary);
  font-weight: 600;
}
.row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 8px;
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
.row-cat {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.row-desc {
  overflow: hidden;
  color: var(--m-text);
  font-size: 12.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
