<template>
  <SplitDetail
    v-model:open="detailOpen"
    icon="lucide:megaphone"
    hint="Pick an announcement to read it"
  >
    <q-card v-if="selected" flat class="detail-sheet">
      <h2 class="detail-title">{{ selected.title }}</h2>
      <p class="detail-meta">{{ houseName(selected.accommodation_id) }} · {{ statusOf(selected) }}</p>
      <img v-if="selected.image_url" :src="selected.image_url" alt="" class="detail-img" />
      <p v-if="selected.summary" class="detail-summary">{{ selected.summary }}</p>
      <p class="detail-body">{{ selected.body }}</p>
      <div v-if="selected.event_at || selected.deadline_at || selected.location" class="detail-facts">
        <div v-if="selected.event_at" class="fact">
          <span class="fact-label">When</span>
          <span>{{ formatDate(selected.event_at) }}<template v-if="selected.event_end"> – {{ formatDate(selected.event_end) }}</template></span>
        </div>
        <div v-if="selected.deadline_at" class="fact">
          <span class="fact-label">Deadline</span>
          <span>{{ formatDate(selected.deadline_at) }}</span>
        </div>
        <div v-if="selected.location" class="fact">
          <span class="fact-label">Where</span>
          <span>{{ selected.location }}</span>
        </div>
      </div>
      <button type="button" class="detail-remove" @click="remove(selected)">
        <IconifyIcon icon="lucide:trash-2" width="15" />
        Remove announcement
      </button>
    </q-card>
  </SplitDetail>
</template>

<script setup lang="ts">
// One announcement opened: what was sent, to which house, and removing it.
import { Icon as IconifyIcon } from '@iconify/vue'
import SplitDetail from '@/components/shared/SplitDetail.vue'
import { formatDate } from '@/utils/format'
import { useAnnouncements } from './announcements'

const {
  selected,
  detailOpen,
  houseName,
  statusOf,
  remove,
} = useAnnouncements()
</script>

<style scoped>
.detail-sheet {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 18px;
  background: var(--m-surface);
}
.detail-title { margin: 0; color: var(--m-ink); font-size: 18px; font-weight: 700; }
.detail-meta { margin: 0; color: var(--m-muted); font-size: 12px; font-weight: 600; }
.detail-img { width: 100%; max-height: 260px; object-fit: cover; border-radius: var(--m-radius); }
.detail-summary { margin: 0; color: var(--m-ink); font-size: 14px; font-weight: 600; }
.detail-body { margin: 0; color: var(--m-text); font-size: 14px; line-height: 1.55; white-space: pre-line; }
.detail-facts {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
}
.fact { display: flex; justify-content: space-between; gap: 12px; padding: 9px 12px; font-size: 13px; }
.fact + .fact { border-top: 1px solid var(--m-border); }
.fact-label { color: var(--m-muted); font-weight: 600; }
.detail-remove {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  margin-top: 6px;
  padding: 8px 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: transparent;
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
</style>
