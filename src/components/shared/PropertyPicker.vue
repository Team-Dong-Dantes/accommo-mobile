<template>
  <template v-if="options.length >= 2">
    <button type="button" class="pp" @click="open = true">
      {{ current }}
      <IconifyIcon icon="lucide:chevron-down" width="14" />
    </button>
    <BottomSheet v-model="open" title="Property" clear-label="" done-label="">
      <div role="radiogroup" aria-label="Property" class="pp-list">
        <button
          v-for="o in options"
          :key="o.value"
          type="button"
          role="radio"
          class="pp-row"
          :aria-checked="o.value === modelValue"
          @click="pick(o.value)"
        >
          {{ o.label }}
          <IconifyIcon v-if="o.value === modelValue" icon="lucide:check" width="18" />
        </button>
      </div>
    </BottomSheet>
  </template>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'

// A pill that opens a radio list of properties. Hidden for one property or none.
// The caller includes its own "All properties" option if it wants one.
const props = defineProps<{ modelValue: string; options: { value: string; label: string }[] }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const open = ref(false)
const current = computed(() => props.options.find((o) => o.value === props.modelValue)?.label ?? props.options[0]?.label ?? '')
function pick(v: string) {
  emit('update:modelValue', v)
  open.value = false
}
</script>

<style scoped>
.pp {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  min-height: 32px;
  padding: 0 10px 0 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
}
.pp-list {
  display: flex;
  flex-direction: column;
}
.pp-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 48px;
  padding: 0 4px;
  border: 0;
  border-bottom: 1px solid var(--m-border);
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
}
.pp-row[aria-checked='true'] {
  color: var(--m-primary-dark);
}
</style>
