<template>
  <div class="rt">
    <template v-if="reviews.length">
      <RatingSummary :ratings="reviews.map((r) => r.rating)" />
      <p class="rt-note"><IconifyIcon icon="lucide:eye-off" width="16" />Landlords rate you after a stay ends. Their names stay hidden.</p>
      <section class="rt-section">
        <div class="rt-head">
          <span class="rt-title">From past landlords</span>
          <button type="button" class="rt-pill" @click="sheet = true">
            {{ DATE_FILTERS.find((f) => f.key === date)?.label }}
            <IconifyIcon icon="lucide:chevron-down" width="14" />
          </button>
        </div>
        <template v-if="shown.length">
          <button v-for="r in shown" :key="r.id" type="button" class="rt-row" @click="openReview(r)">
            <span class="rt-col">
              <span class="rt-line">
                <StarRating :model-value="r.rating" :size="13" />
                <span class="rt-date">{{ formatDate(r.createdAt) }}</span>
              </span>
              <span class="rt-author">A past landlord/landlady</span>
              <span v-if="r.comment" class="rt-comment">{{ r.comment }}</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="15" class="rt-chev" />
          </button>
        </template>
        <EmptyState v-else variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search or date." />
      </section>
    </template>
    <EmptyState v-else variant="compact" icon="lucide:star" title="No ratings yet" message="Ratings a landlord/landlady leaves after a stay will show up here." />

    <BottomSheet v-model="sheet" title="Date" clear-label="" done-label="Done">
      <div class="m-chips">
        <button v-for="f in DATE_FILTERS" :key="f.key" type="button" class="m-chip" :class="{ 'm-chip--on': date === f.key }" @click="date = f.key">
          {{ f.label }}
        </button>
      </div>
    </BottomSheet>
    <RatingDetailSheet v-model="detailOpen" :review="picked && { ...picked, about: 'a past landlord/landlady' }" />
  </div>
</template>

<script lang="ts">
export interface ManagerReview {
  id: string
  rating: number
  comment: string
  createdAt: string
}
</script>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import StarRating from '@/components/shared/StarRating.vue'
import RatingSummary from '@/components/shared/RatingSummary.vue'
import RatingDetailSheet from '@/components/shared/RatingDetailSheet.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { formatDate } from '@/utils/format'

// Ratings landlords left about this student (RT-Student). The summary counts all
// of them; the date pill and the search only narrow the list below it.
const props = defineProps<{ reviews: ManagerReview[]; query: string }>()

const DATE_FILTERS = [
  { key: 'all', label: 'All time' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 3 months' },
  { key: 'year', label: 'This year' },
] as const
const date = ref<(typeof DATE_FILTERS)[number]['key']>('all')
const sheet = ref(false)

function within(iso: string): boolean {
  if (date.value === 'all') return true
  const then = new Date(iso)
  if (date.value === 'year') return then.getFullYear() === new Date().getFullYear()
  return Date.now() - then.getTime() <= (date.value === '30d' ? 30 : 90) * 86400000
}
const shown = computed(() => {
  const q = props.query.trim().toLowerCase()
  return props.reviews.filter((r) => within(r.createdAt) && (!q || r.comment.toLowerCase().includes(q)))
})

const detailOpen = ref(false)
const picked = ref<ManagerReview | null>(null)
function openReview(r: ManagerReview) {
  picked.value = r
  detailOpen.value = true
}
</script>

<style scoped>
.rt {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.rt-note {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 12.5px;
}
.rt-section {
  display: flex;
  flex-direction: column;
  margin: 0 -14px;
  border-top: 1px solid var(--m-border);
  border-bottom: 1px solid var(--m-border);
}
.rt-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 6px 12px;
  background: var(--m-bg);
}
.rt-title {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.rt-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  min-height: 32px;
  padding: 0 10px 0 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
}
.rt-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  width: 100%;
  padding: 12px 8px 12px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.rt-col {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 4px;
}
.rt-line {
  display: flex;
  align-items: center;
  gap: 8px;
}
.rt-date {
  color: var(--m-muted);
  font-size: 11.5px;
}
.rt-author {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.rt-comment {
  display: -webkit-box;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  color: var(--m-text);
  font-size: 13px;
  line-height: 1.4;
}
.rt-chev {
  margin-top: 2px;
  color: var(--m-muted);
}
</style>
