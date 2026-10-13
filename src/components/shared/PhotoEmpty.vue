<template>
  <!-- The one look for a missing photo, everywhere in the app: flat gray, an
       image-off icon, and on card- and hero-sized slots a "No photo" label.
       Fills its slot, which must be positioned; overlays placed after it
       (type tags, vacancy flags) still sit on top. -->
  <span class="photo-empty" aria-hidden="true">
    <IconifyIcon icon="lucide:image-off" :width="size" />
    <span v-if="label" class="photo-empty-label">No photo</span>
  </span>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

withDefaults(defineProps<{ size?: number; label?: boolean }>(), { size: 18, label: false })
</script>

<style scoped>
.photo-empty {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  border-radius: inherit;
  background: var(--m-border);
  color: var(--m-muted);
}
.photo-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }
</style>
