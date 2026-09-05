<template>
  <div class="p-block">
    <div class="p-block-header">
      <IconifyIcon :icon="icon" width="18" class="p-block-icon" :style="{ color: accent }" />
      <h2 class="p-block-title">{{ title }}</h2>
      <span v-if="badge" class="p-block-badge">{{ badge }}</span>
      <slot name="actions" />
    </div>
    <div class="p-block-body">
      <slot />
    </div>
    <slot name="foot" />
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

withDefaults(
  defineProps<{
    icon: string
    title: string
    badge?: string
    accent?: string
  }>(),
  { accent: 'var(--m-primary-dark)' },
)
</script>

<style scoped>
.p-block + .p-block {
  border-top: 1px solid var(--m-border);
}
.p-block-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--m-border);
}
.p-block-icon {
  opacity: 0.7;
}
.p-block-title {
  margin: 0;
  flex: 1;
  font-size: 13px;
  font-weight: 700;
  color: var(--m-ink);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.p-block-badge {
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10px;
  font-weight: 700;
}
.p-block-body {
  padding: 4px 0;
}
.p-block-body > * {
  padding: 8px 14px;
  border-bottom: 1px solid var(--m-border);
}
.p-block-body > *:last-child {
  border-bottom: none;
}
</style>
