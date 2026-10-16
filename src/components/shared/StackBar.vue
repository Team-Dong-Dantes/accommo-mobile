<template>
  <!-- Proportional bar; a segment's tone is a --m-* colour name (success, info, danger…). -->
  <div class="stack" :style="{ height: `${height}px` }" role="img" :aria-label="label">
    <span
      v-for="(s, i) in shown"
      :key="i"
      class="stack-seg"
      :style="{ flex: s.value, background: `var(--m-${s.tone})` }"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    segments: { value: number; tone: string }[]
    height?: number
    /** Screen-reader summary; the bar alone says nothing. */
    label?: string
  }>(),
  { height: 10 },
)
const shown = computed(() => props.segments.filter((s) => s.value > 0))
</script>

<style scoped>
.stack {
  display: flex;
  gap: 3px;
}
.stack-seg {
  min-width: 4px;
  border-radius: 2px;
}
.stack-seg:first-child {
  border-top-left-radius: 6px;
  border-bottom-left-radius: 6px;
}
.stack-seg:last-child {
  border-top-right-radius: 6px;
  border-bottom-right-radius: 6px;
}
</style>
