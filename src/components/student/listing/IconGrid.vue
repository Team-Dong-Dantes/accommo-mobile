<template>
  <div class="icon-grid">
    <span v-for="item in items" :key="item.key" class="icon-item">
      <span class="icon-circle"><IconifyIcon :icon="item.icon" width="19" /></span>
      <small>{{ item.label }}</small>
    </span>
  </div>
</template>

<script setup lang="ts">
// Amenities or facilities as a grid of round icons with a label under each.
import { Icon as IconifyIcon } from '@iconify/vue'

export interface IconGridItem {
  key: string
  icon: string
  label: string
}

defineProps<{ items: IconGridItem[] }>()
</script>

<style scoped>
/* Icon grid — amenities / in-room facilities */
.icon-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(68px, 1fr));
  gap: 16px 6px;
}
.icon-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  text-align: center;
}
.icon-circle {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 50%;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.icon-item small {
  color: var(--m-text);
  font-size: 11px;
  font-weight: 600;
  line-height: 1.2;
}
</style>
