<template>
  <div class="rt">
    <template v-if="reviews.length">
      <RatingSummary :ratings="reviews.map((r) => r.rating)" />
      <div class="rt-chips">
        <button
          v-for="c in chips"
          :key="c.key"
          type="button"
          class="rt-chip"
          :class="{ 'rt-chip--on': chip === c.key }"
          :aria-pressed="chip === c.key"
          @click="chip = c.key"
        >
          {{ c.label }}<b>{{ c.count }}</b>
        </button>
      </div>
      <section v-if="groups.length" class="rt-list">
        <template v-for="(g, gi) in groups" :key="g.label">
          <div class="rt-group" :class="{ 'rt-group--next': gi > 0 }">
            <span class="rt-group-name">{{ g.label }}</span>
            <span class="rt-group-avg"><IconifyIcon icon="lucide:star" width="13" class="rt-star" />{{ g.avg }}</span>
          </div>
          <button v-for="r in g.items" :key="r.id" type="button" class="rt-row" @click="open(r, g.label)">
            <span class="rt-body">
              <span class="rt-top">
                <StarRating :model-value="r.rating" :size="14" />
                <span class="rt-date">{{ formatDate(r.createdAt) }}</span>
              </span>
              <span v-if="r.comment" class="rt-comment">{{ r.comment }}</span>
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="15" class="rt-chev" />
          </button>
        </template>
      </section>
      <EmptyState v-else variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search or filter." />
    </template>
    <EmptyState v-else variant="compact" icon="lucide:star" title="No ratings yet" message="Ratings from past boarders will show up here." />

    <RatingDetailSheet v-model="detailOpen" :review="detail" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import StarRating from '@/components/shared/StarRating.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import RatingSummary from '@/components/shared/RatingSummary.vue'
import RatingDetailSheet from '@/components/shared/RatingDetailSheet.vue'
import { formatDate } from '@/utils/format'
import { withinDateFilter, type DateFilter, type Review } from './managerHistory'

// RT-Landlord. Reviews are anonymous to the person being reviewed (review_inbox
// carries no reviewer), so a row shows stars, date and comment only — grouped
// by who it is about: you, or one of your properties.
const props = defineProps<{ reviews: Review[]; query: string; dateFilter: DateFilter }>()

const chip = ref('all')
const groupOf = (r: Review) => (r.kind === 'user' ? 'About you' : r.source)

const chips = computed(() => {
  const names = [...new Set(props.reviews.filter((r) => r.kind === 'property').map((r) => r.source))]
  const count = (f: (r: Review) => boolean) => props.reviews.filter(f).length
  return [
    { key: 'all', label: 'All', count: props.reviews.length },
    ...(props.reviews.some((r) => r.kind === 'user') ? [{ key: 'user', label: 'About you', count: count((r) => r.kind === 'user') }] : []),
    ...names.map((n) => ({ key: `p:${n}`, label: n, count: count((r) => r.source === n && r.kind === 'property') })),
  ]
})

const inChip = (r: Review) =>
  chip.value === 'all' || (chip.value === 'user' ? r.kind === 'user' : r.kind === 'property' && r.source === chip.value.slice(2))

const groups = computed(() => {
  const q = props.query.trim().toLowerCase()
  const byLabel = new Map<string, Review[]>()
  for (const r of props.reviews) {
    if (!inChip(r)) continue
    if (!withinDateFilter(r.createdAt, props.dateFilter)) continue
    if (q && !`${groupOf(r)} ${r.comment}`.toLowerCase().includes(q)) continue
    byLabel.set(groupOf(r), [...(byLabel.get(groupOf(r)) ?? []), r])
  }
  return [...byLabel.entries()]
    .sort(([a], [b]) => (a === 'About you' ? -1 : b === 'About you' ? 1 : a.localeCompare(b)))
    .map(([label, items]) => ({ label, items, avg: (items.reduce((n, r) => n + r.rating, 0) / items.length).toFixed(1) }))
})

const detailOpen = ref(false)
const detail = ref<{ rating: number; comment: string | null; createdAt: string; about: string } | null>(null)
function open(r: Review, about: string) {
  detail.value = { rating: r.rating, comment: r.comment || null, createdAt: r.createdAt, about }
  detailOpen.value = true
}
</script>

<style scoped>
.rt {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.rt-chips {
  display: flex;
  gap: 6px;
  overflow-x: auto;
  scrollbar-width: none;
}
.rt-chip {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  cursor: pointer;
}
.rt-chip b {
  font-weight: 800;
}
.rt-chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.rt-list {
  display: flex;
  flex-direction: column;
  margin: 0 -14px;
  border-top: 1px solid var(--m-border);
  border-bottom: 1px solid var(--m-border);
}
.rt-group {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--m-bg);
}
.rt-group--next {
  border-top: 1px solid var(--m-border);
}
.rt-group-name {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.rt-group-avg {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-left: auto;
  color: var(--m-text);
  font-size: 12px;
  font-weight: 700;
}
.rt-star {
  color: #f59e0b;
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
  font: inherit;
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.rt-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 4px;
}
.rt-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.rt-date {
  color: var(--m-muted);
  font-size: 11.5px;
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
  flex: 0 0 auto;
  margin-top: 2px;
  color: var(--m-muted);
}
</style>
