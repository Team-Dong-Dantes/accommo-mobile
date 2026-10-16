<template>
  <div class="pb">
    <button type="button" class="pb-btn pb-btn--prev" aria-label="Previous" :disabled="!canPrev" @click="emit('prev')">
      <IconifyIcon icon="lucide:chevron-left" width="18" />
    </button>
    <span class="pb-label">{{ label }}</span>
    <button type="button" class="pb-btn" aria-label="Next" :disabled="!canNext" @click="emit('next')">
      <IconifyIcon icon="lucide:chevron-right" width="18" />
    </button>
    <span class="pb-gap" />
    <slot />
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

// ‹ OCTOBER 2026 › with a slot at the right edge (the property picker).
defineProps<{ label: string; canPrev: boolean; canNext: boolean }>()
const emit = defineEmits<{ prev: []; next: [] }>()
</script>

<style scoped>
.pb {
  display: flex;
  align-items: center;
  gap: 2px;
}
.pb-btn {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.pb-btn--prev {
  margin-left: -8px;
}
.pb-btn:disabled {
  color: var(--m-border);
  cursor: default;
}
.pb-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.pb-gap {
  flex: 1;
}
</style>
