<template>
  <component
    :is="hasTrailing ? 'div' : 'button'"
    class="settings-row"
    :class="{ 'settings-row--danger': danger }"
    v-bind="hasTrailing ? {} : { type: 'button' }"
    @click="!hasTrailing && emit('click')"
  >
    <IconifyIcon :icon="icon" width="18" class="settings-row-icon" />
    <span class="settings-row-label">{{ label }}</span>
    <span class="settings-row-trailing">
      <slot name="trailing">
        <IconifyIcon icon="lucide:chevron-right" width="16" class="settings-row-chevron" />
      </slot>
    </span>
  </component>
</template>

<script setup lang="ts">
import { useSlots, computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

defineProps<{
  icon: string
  label: string
  danger?: boolean
}>()

const emit = defineEmits<{ click: [] }>()

const slots = useSlots()
const hasTrailing = computed(() => !!slots.trailing)
</script>

<style scoped>
.settings-row {
  display: flex;
  align-items: center;
  gap: var(--m-space-3);
  width: 100%;
  min-height: 48px;
  padding: var(--m-space-3) 2px;
  border: none;
  border-bottom: 1px solid var(--m-border);
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.settings-row:last-child {
  border-bottom: none;
}
.settings-row-icon {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.settings-row-label {
  flex: 1 1 auto;
  font-size: 14px;
  font-weight: 600;
}
.settings-row-trailing {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  color: var(--m-muted);
}
.settings-row--danger .settings-row-icon,
.settings-row--danger .settings-row-label {
  color: var(--m-danger);
}
</style>
