<template>
  <button type="button" class="edit-btn" @click="emit('click')">
    <IconifyIcon icon="lucide:pencil" width="14" />
    Edit
  </button>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

const emit = defineEmits<{ click: [] }>()
</script>

<style scoped>
.edit-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 12px;
  font-weight: 600;
  color: var(--m-primary-dark);
  cursor: pointer;
  transition: background 0.15s;
}
.edit-btn:hover {
  background: var(--m-primary-soft);
}
</style>
