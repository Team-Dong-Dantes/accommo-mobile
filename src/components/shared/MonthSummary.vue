<template>
  <!-- The month at a glance: one number, one bar, what's left in words. The
       landlord/landlady's Payments tab and both sides of a single stay use it. -->
  <section class="ms">
    <div class="ms-top">
      <span class="ms-label">{{ formatMonth(totals.month) }}</span>
      <slot name="action" />
    </div>
    <div class="ms-big-row">
      <span class="ms-big">{{ formatPesoExact(totals.collected) }}</span>
      <span class="ms-of">{{ ofLine }}</span>
    </div>
    <div class="ms-bar" aria-hidden="true">
      <span v-for="s in segments" :key="s.key" class="ms-seg" :class="`ms-seg--${s.key}`" :style="{ flex: s.value }" />
    </div>
    <div v-if="left > 0.009" class="ms-legend">
      <span v-if="totals.toConfirm > 0.009"><i class="ms-dot ms-dot--confirm" />To confirm {{ formatPesoExact(totals.toConfirm) }}</span>
      <span v-if="totals.overdue > 0.009"><i class="ms-dot ms-dot--overdue" />Overdue {{ formatPesoExact(totals.overdue) }}</span>
      <span v-if="totals.toCome > 0.009"><i class="ms-dot ms-dot--come" />Still to come {{ formatPesoExact(totals.toCome) }}</span>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { formatMonth, formatPesoExact } from '@/utils/format'
import type { MonthTotals } from '@/utils/collections'

// `verb`: what the landlord/landlady "collected", what a student "paid".
const props = withDefaults(defineProps<{ totals: MonthTotals; verb?: 'collected' | 'paid' }>(), { verb: 'collected' })

const left = computed(() => props.totals.toConfirm + props.totals.overdue + props.totals.toCome)
const expected = computed(() => props.totals.collected + left.value)
const ofLine = computed(() => {
  if (expected.value < 0.01) return `nothing due in ${formatMonth(props.totals.month).split(' ')[0]}`
  if (left.value < 0.01) return `${props.verb}, all of it`
  return `${props.verb} of ${formatPesoExact(expected.value)}`
})
const segments = computed(() => {
  const t = props.totals
  const list = [
    { key: 'paid', value: t.collected },
    { key: 'confirm', value: t.toConfirm },
    { key: 'overdue', value: t.overdue },
    { key: 'come', value: t.toCome },
  ].filter((s) => s.value > 0.009)
  return list.length ? list : [{ key: 'come', value: 1 }]
})
</script>

<style scoped>
.ms {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.ms-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.ms-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.ms-big-row {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px 8px;
}
.ms-big {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 34px;
  font-weight: 700;
  letter-spacing: -0.03em;
}
.ms-of {
  color: var(--m-muted);
  font-size: 14px;
}
.ms-bar {
  display: flex;
  height: 10px;
  gap: 3px;
}
.ms-seg {
  border-radius: 2px;
}
.ms-seg:first-child {
  border-top-left-radius: 6px;
  border-bottom-left-radius: 6px;
}
.ms-seg:last-child {
  border-top-right-radius: 6px;
  border-bottom-right-radius: 6px;
}
.ms-seg--paid { background: var(--m-success); }
.ms-seg--confirm { background: var(--m-info); }
.ms-seg--overdue { background: var(--m-danger); }
.ms-seg--come { background: var(--m-border); }
.ms-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 14px;
  color: var(--m-text);
  font-size: 12.5px;
}
.ms-legend span {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.ms-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.ms-dot--confirm { background: var(--m-info); }
.ms-dot--overdue { background: var(--m-danger); }
.ms-dot--come {
  background: var(--m-border);
  box-shadow: inset 0 0 0 1px #c9ced6;
}
</style>
