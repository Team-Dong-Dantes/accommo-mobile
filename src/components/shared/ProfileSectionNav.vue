<template>
  <!-- Desktop profile's left-half menu: picks the one block the details half
       shows. It used to scroll-spy a half holding every block at once, which
       read as tabs that did nothing but scroll. -->
  <nav class="p-nav" aria-label="Profile sections">
    <button
      v-for="s in sections"
      :key="s.id"
      type="button"
      class="p-nav-item"
      :class="{ 'p-nav-item--on': s.id === active }"
      :aria-current="s.id === active ? 'true' : undefined"
      @click="active = s.id"
    >
      <IconifyIcon :icon="s.icon" width="16" />
      <span class="p-nav-label">{{ s.label }}</span>
      <span v-if="s.badge" class="p-nav-badge">{{ s.badge }}</span>
    </button>
  </nav>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

/** `id` is the DOM id of the section's block; `v-model` is the shown one. */
defineProps<{ sections: { id: string; label: string; icon: string; badge?: string }[] }>()
const active = defineModel<string>({ required: true })
</script>

<style scoped>
.p-nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}
.p-nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 40px;
  padding: 0 12px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  color: var(--m-muted);
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
  transition: background 0.12s, color 0.12s;
}
.p-nav-item:hover {
  background: var(--m-bg);
  color: var(--m-ink);
}
.p-nav-item--on {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.p-nav-label {
  flex: 1;
}
.p-nav-badge {
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10px;
  font-weight: 700;
}
</style>
