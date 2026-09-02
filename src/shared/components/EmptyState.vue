<template>
  <section class="empty-state" :aria-live="live" :role="role">
    <IconifyIcon v-if="icon" :icon="icon" width="28" aria-hidden="true" />
    <strong>{{ title }}</strong>
    <span v-if="message">{{ message }}</span>
    <slot />
  </section>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

withDefaults(defineProps<{
  icon?: string
  title: string
  message?: string
  live?: 'off' | 'polite' | 'assertive'
  role?: string
}>(), {
  icon: 'lucide:inbox',
  message: '',
  live: 'polite',
})
</script>

<style scoped>
.empty-state {
  display: grid;
  min-height: 180px;
  place-items: center;
  align-content: center;
  gap: var(--m-space-2);
  padding: var(--m-space-6);
  color: var(--m-muted);
  text-align: center;
}

.empty-state strong {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
  line-height: 1.25;
}

.empty-state > span {
  max-width: 34ch;
  font-size: 13px;
  line-height: 1.45;
}
</style>
