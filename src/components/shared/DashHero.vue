<template>
  <component :is="to ? RouterLink : 'div'" :to="to" class="hero">
    <span class="hero-top">
      <span>{{ label }}</span>
      <span>{{ right }}</span>
    </span>
    <span class="hero-big">
      <span class="hero-num">{{ big }}</span>
      <span v-if="of" class="hero-of">{{ of }}</span>
    </span>
    <StackBar :segments="segments" :height="12" aria-hidden="true" />
    <span class="hero-legend">
      <span v-for="l in legend" :key="l.label" class="hero-key">
        <i :style="{ background: `var(--m-${l.tone})` }" />{{ l.label }} <b>{{ l.value }}</b>
      </span>
    </span>
  </component>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router'
import StackBar from '@/components/shared/StackBar.vue'

// The dashboards' top card: a month (or step) at a glance. `to` makes it a link.
defineProps<{
  label: string
  right?: string
  big: string
  /** Small text after the big number, e.g. "/ ₱2,800 sent". */
  of?: string
  segments: { value: number; tone: string }[]
  legend: { label: string; value: string; tone: string }[]
  to?: string
}>()
</script>

<style scoped>
.hero {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 16px 20px;
  border-radius: var(--m-radius-lg);
  background: var(--m-surface);
  color: inherit;
  text-decoration: none;
}
.hero-top {
  display: flex;
  justify-content: space-between;
  color: var(--m-muted);
  font-size: 14px;
}
.hero-big {
  display: flex;
  align-items: baseline;
  gap: 8px;
}
.hero-num {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 40px;
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.02em;
}
.hero-of {
  color: var(--m-muted);
  font-size: 16px;
}
.hero-legend {
  display: flex;
  /* One line: the hero's height must not depend on the amounts. */
  overflow: hidden;
  gap: 14px;
  white-space: nowrap;
  color: var(--m-muted);
  font-size: 12.5px;
}
.hero-key {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.hero-key i {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.hero-key b {
  color: var(--m-ink);
}
</style>
