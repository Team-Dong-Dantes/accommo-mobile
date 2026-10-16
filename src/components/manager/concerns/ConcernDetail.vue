<template>
  <SplitDetail
    v-model:open="detailOpen"
    icon="lucide:message-square-warning"
    hint="Pick a concern to read it and reply"
  >
    <div v-if="selected" class="detail-sheet" :class="{ 'detail-sheet--pane': isTablet }">
      <div class="detail-head">
        <span class="detail-avatar" :class="selected.avatarColor ? [`bg-${selected.avatarColor}`, 'text-white'] : []">
          <img v-if="selected.avatarUrl" :src="selected.avatarUrl" alt="" class="detail-avatar-img" @error="selected.avatarUrl = null" />
          <template v-else>{{ initialsOf(selected.studentName) }}</template>
        </span>
        <span class="detail-headbody">
          <span class="detail-name">{{ selected.studentName }}</span>
          <span class="detail-where">{{ selected.where }}</span>
        </span>
        <span class="detail-chip" :class="`detail-chip--${statusColor(CONCERN_STATUS, selected.status)}`">
          {{ statusText(CONCERN_STATUS, selected.status) }}
        </span>
      </div>

      <p class="detail-label">{{ CONCERN_CATEGORY_LABEL[selected.category] || selected.category }} · {{ since(selected.reportedAt) }}</p>
      <p class="detail-text">{{ selected.description || 'No description given.' }}</p>
      <img v-if="selected.photoUrl" :src="selected.photoUrl" alt="" class="detail-photo" />

      <label class="field">
        <span class="field-label">Response to boarder</span>
        <textarea v-model="response" class="field-input field-textarea" rows="3" placeholder="What are you doing about this?" />
      </label>

      <div class="actions">
        <button v-if="selected.status === 'open'" type="button" class="act-btn act-btn--ghost" :disabled="deciding" @click="decide('acknowledged')">
          Acknowledge
        </button>
        <button v-if="selected.status === 'open' || selected.status === 'acknowledged'" type="button" class="act-btn act-btn--ghost" :disabled="deciding" @click="decide('in_progress')">
          In progress
        </button>
        <button v-if="selected.status !== 'resolved' && selected.status !== 'rejected'" type="button" class="act-btn act-btn--ghost" :disabled="deciding" @click="decide('rejected')">
          Reject
        </button>
        <button v-if="selected.status !== 'resolved' && selected.status !== 'rejected'" type="button" class="act-btn" :disabled="deciding" @click="decide('resolved')">
          Resolve
        </button>
      </div>
      <button
        v-if="selected.status !== 'resolved' && selected.status !== 'rejected' && !selected.escalatedTicketNo"
        type="button"
        class="escalate-btn"
        :disabled="escalating"
        @click="escalate"
      >
        <IconifyIcon icon="lucide:arrow-up-right" width="14" />
        Escalate to OSAS
      </button>
      <p v-if="selected.escalatedTicketNo" class="detail-final">
        Escalated to OSAS as {{ ticketLabel(selected.escalatedTicketNo) }}.
      </p>
      <p v-if="selected.status === 'resolved' || selected.status === 'rejected'" class="detail-final">
        This concern is closed.
      </p>
    </div>
  </SplitDetail>
</template>

<script setup lang="ts">
// One concern opened: who reported it, what, and the landlord/landlady's
// response and decision.
import { CONCERN_CATEGORY_LABEL, CONCERN_STATUS, initialsOf, statusColor, statusText, ticketLabel } from '@/utils/format'
import { Icon as IconifyIcon } from '@iconify/vue'
import SplitDetail from '@/components/shared/SplitDetail.vue'
import { isTablet } from '@/utils/useTabletMode'
import { since } from '@/utils/notifications'
import { useManagerConcerns } from './managerConcerns'

const {
  detailOpen,
  selected,
  response,
  deciding,
  escalating,
  decide,
  escalate,
} = useManagerConcerns()
</script>

<style scoped src="@/components/shared/concernDetail.css"></style>

<style scoped>
.detail-head {
  display: flex;
  align-items: center;
  gap: 10px;
}
.detail-avatar {
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
.detail-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.detail-headbody {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.detail-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.detail-where {
  color: var(--m-muted);
  font-size: 11.5px;
}
.detail-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
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
.detail-final {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  text-align: center;
}
.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.field-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.field-textarea {
  min-height: 70px;
  padding: 10px 12px;
  resize: vertical;
}
.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.act-btn {
  flex: 1 1 auto;
  min-height: 44px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.act-btn:disabled {
  opacity: 0.6;
}
.act-btn--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.escalate-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 40px;
  margin-top: 2px;
  border: 1px dashed var(--m-border);
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.escalate-btn:disabled {
  opacity: 0.6;
}
</style>
