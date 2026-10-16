<template>
  <SplitDetail
    v-model:open="detailOpen"
    icon="lucide:message-square-warning"
    :hint="`Pick a concern to see its progress and your ${myLandlord}’s reply`"
  >
    <div v-if="selected" class="detail-sheet" :class="{ 'detail-sheet--pane': isTablet }">
      <div class="detail-head">
        <h3 class="detail-title">{{ CONCERN_CATEGORY_LABEL[selected.category] || selected.category }}</h3>
        <span class="detail-chip" :class="`detail-chip--${statusColor(CONCERN_STATUS, selected.status)}`">
          {{ statusText(CONCERN_STATUS, selected.status) }}
        </span>
      </div>

      <ul class="timeline">
        <li v-for="s in timeline" :key="s.key" class="tl-row">
          <span class="tl-rail">
            <span class="tl-dot" :class="{ 'tl-dot--done': s.done, 'tl-dot--bad': s.bad }" />
            <span class="tl-line" />
          </span>
          <span class="tl-body">
            <span class="tl-label" :class="{ 'tl-label--pending': !s.done }">{{ s.label }}</span>
            <span class="tl-when">{{ s.at ? `${since(s.at)} ago` : 'Pending' }}</span>
          </span>
        </li>
      </ul>

      <p class="detail-label">Your report</p>
      <p class="detail-text">{{ selected.description || 'No description given.' }}</p>
      <p class="detail-meta">{{ selected.where }}</p>
      <img v-if="selected.photoUrl" :src="selected.photoUrl" alt="" class="detail-photo" />

      <template v-if="selected.managerResponse">
        <p class="detail-label">{{ myLandlord }}'s response</p>
        <p class="detail-text">{{ selected.managerResponse }}</p>
      </template>

      <template v-if="selected.escalatedTicketNo">
        <p class="detail-label">Escalated to OSAS</p>
        <p class="detail-text">Your {{ myLandlord }} passed this to OSAS as {{ ticketLabel(selected.escalatedTicketNo) }}. OSAS may contact you about it.</p>
      </template>

      <q-btn unelevated rounded no-caps color="primary" class="detail-close" label="Close" @click="detailOpen = false" />
    </div>
  </SplitDetail>
</template>

<script setup lang="ts">
// One concern opened: its progress, the report, and the landlord/landlady's
// response.
import { CONCERN_CATEGORY_LABEL, CONCERN_STATUS, statusColor, statusText, ticketLabel } from '@/utils/format'
import SplitDetail from '@/components/shared/SplitDetail.vue'
import { isTablet } from '@/utils/useTabletMode'
import { since } from '@/utils/notifications'
import { useStudentConcerns } from './studentConcerns'

const {
  myLandlord,
  detailOpen,
  selected,
  timeline,
} = useStudentConcerns()
</script>

<style scoped src="@/components/shared/concernDetail.css"></style>

<style scoped>
.detail-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}
.detail-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.detail-chip {
  flex: 0 0 auto;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.detail-chip--amber,
.detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.detail-meta {
  margin: 0;
  color: var(--m-muted);
  font-size: 11.5px;
}
.detail-close {
  min-height: 46px;
  margin-top: 6px;
  font-weight: 700;
}
.timeline {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
}
.tl-row {
  display: flex;
  gap: 10px;
}
.tl-rail {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: center;
  width: 10px;
}
.tl-dot {
  width: 10px;
  height: 10px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: var(--m-border);
}
.tl-dot--done {
  background: var(--m-primary);
}
.tl-dot--bad {
  background: var(--m-danger);
}
.tl-line {
  width: 2px;
  flex: 1;
  margin: 2px 0;
  background: var(--m-border);
}
.tl-row:last-child .tl-line {
  display: none;
}
.tl-body {
  display: flex;
  flex: 1;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  padding-bottom: 12px;
}
.tl-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.tl-label--pending {
  color: var(--m-muted);
  font-weight: 600;
}
.tl-when {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 11px;
}
</style>
