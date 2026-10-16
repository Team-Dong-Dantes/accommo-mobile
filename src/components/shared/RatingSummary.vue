<template>
  <section class="rs" aria-label="Rating summary">
    <div class="rs-avg">
      <span class="rs-big">{{ avg.toFixed(1) }}</span>
      <span role="img" :aria-label="`${avg.toFixed(1)} out of 5 stars`"><StarRating :model-value="avg" :size="16" /></span>
      <span class="rs-count">{{ ratings.length }} rating{{ ratings.length === 1 ? '' : 's' }}</span>
    </div>
    <div class="rs-dist">
      <div v-for="d in dist" :key="d.n" class="rs-line">
        <span class="rs-n">{{ d.n }}</span>
        <span class="rs-track"><span class="rs-fill" :style="{ width: d.pct }" /></span>
        <span class="rs-c">{{ d.c }}</span>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import StarRating from '@/components/shared/StarRating.vue'

// Average, count and the 5-to-1 spread of a list of ratings. Both History
// screens use it; the caller decides which ratings go in.
const props = defineProps<{ ratings: number[] }>()

const avg = computed(() => (props.ratings.length ? props.ratings.reduce((n, r) => n + r, 0) / props.ratings.length : 0))
const dist = computed(() =>
  [5, 4, 3, 2, 1].map((n) => {
    const c = props.ratings.filter((r) => Math.round(r) === n).length
    return { n, c, pct: `${props.ratings.length ? (c / props.ratings.length) * 100 : 0}%` }
  }),
)
</script>

<style scoped>
.rs {
  display: flex;
  align-items: center;
  gap: 18px;
}
.rs-avg {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
}
.rs-big {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 44px;
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.03em;
}
.rs-count {
  color: var(--m-muted);
  font-size: 12px;
}
.rs-dist {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 4px;
}
.rs-line {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11.5px;
}
.rs-n {
  width: 8px;
  color: var(--m-muted);
  font-weight: 700;
}
.rs-track {
  flex: 1;
  height: 6px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-border);
}
.rs-fill {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: #f5a623;
}
.rs-c {
  width: 12px;
  color: var(--m-text);
  font-weight: 700;
  text-align: right;
}
</style>
