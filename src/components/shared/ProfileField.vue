<template>
  <!-- Read mode is a compact label/value row; edit mode stacks so the input
       gets the full width and stays comfortable to type into. -->
  <div class="pf" :class="{ 'pf--edit': isEditing }">
    <span class="pf-label">{{ label }}</span>

    <template v-if="isEditing">
      <select
        v-if="type === 'select'"
        class="pf-input"
        :value="modelValue"
        :disabled="!options.length"
        @change="emit('update:modelValue', ($event.target as HTMLSelectElement).value)"
      >
        <option value="">{{ placeholder || 'Select…' }}</option>
        <option v-for="opt in options" :key="opt" :value="opt">{{ opt }}</option>
      </select>

      <input
        v-else
        class="pf-input"
        :type="type"
        :value="modelValue"
        :placeholder="placeholder"
        :inputmode="type === 'tel' ? 'tel' : undefined"
        @input="emit('update:modelValue', ($event.target as HTMLInputElement).value)"
      />
    </template>

    <span v-else class="pf-value" :class="{ 'pf-value--empty': !modelValue }">
      {{ modelValue || placeholder || 'Not set' }}
    </span>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    label: string
    modelValue: string
    /** Whether the parent page is currently in edit mode. */
    editing?: boolean
    /** Shown but never editable — e.g. e-mail and student ID, which are verified elsewhere. */
    readonly?: boolean
    type?: 'text' | 'tel' | 'select'
    options?: string[]
    placeholder?: string
  }>(),
  { editing: false, readonly: false, type: 'text', options: () => [], placeholder: '' },
)

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const isEditing = computed(() => props.editing && !props.readonly)
</script>

<style scoped>
.pf {
  display: flex;
  min-height: 40px;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 7px 12px;
  border-bottom: 1px solid var(--m-border);
}
.pf:last-child { border-bottom: 0; }
.pf--edit { flex-direction: column; align-items: stretch; gap: 4px; }

.pf-label { flex: 0 0 auto; color: var(--m-muted); font-size: 12.5px; font-weight: 600; }
.pf--edit .pf-label { font-size: 11.5px; }

.pf-value {
  min-width: 0;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pf-value--empty { color: var(--m-muted); font-weight: 500; font-style: italic; }

.pf-input {
  width: 100%;
  min-height: 42px;
  padding: 0 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
}
.pf-input:focus { border-color: var(--m-primary); outline: none; }
select.pf-input { appearance: none; padding-right: 30px; }
</style>
