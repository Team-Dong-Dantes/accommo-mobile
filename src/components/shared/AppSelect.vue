<template>
  <!-- The one dropdown for the whole app, in place of native <select>, AuthSelect
       and the raw q-selects. A field that opens a list in a sheet, the same way
       DateTimeField opens its calendar, so every pick in the app looks and works
       alike. The box itself is whatever class the screen puts on it (field-input,
       mx-input, …); `.picker-field` in app.scss only supplies a default and the
       contents. The sheet is teleported, so it is not really inside the button. -->
  <button
    type="button"
    class="picker-field"
    :class="{ 'picker-field--set': hasValue, 'picker-field--error': !!error }"
    :disabled="disable"
    :aria-label="label || placeholder || undefined"
    @click="showing = true"
  >
    <span class="picker-field__body">
      <span v-if="label" class="picker-field__label">{{ label }}</span>
      <span class="picker-field__text">{{ display || placeholder || (label ? '' : 'Select…') }}</span>
      <span v-if="error" class="picker-field__error">{{ error }}</span>
    </span>
    <IconifyIcon icon="lucide:chevron-down" width="18" class="picker-field__icon" />

    <AppModal v-model="showing" :title="label || placeholder || 'Select'" size="sm">
      <div class="sel-list" role="listbox">
        <button
          v-for="opt in items"
          :key="String(opt.value)"
          type="button"
          role="option"
          class="sel-opt"
          :class="{ 'sel-opt--on': opt.value === modelValue }"
          :aria-selected="opt.value === modelValue"
          @click="pick(opt.value)"
        >
          <span class="sel-opt-label">{{ opt.label }}</span>
          <IconifyIcon v-if="opt.value === modelValue" icon="lucide:check" width="16" />
        </button>
      </div>
    </AppModal>
  </button>
</template>

<script setup lang="ts" generic="T extends string | number">
import { computed, ref } from 'vue'
import { useFormChild } from 'quasar'
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'

const props = withDefaults(
  defineProps<{
    modelValue: T | null | undefined
    /** A list of values, a list of {label, value}, or a value → label map. */
    options: readonly (T | { label: string; value: T })[] | Record<string, string>
    label?: string
    placeholder?: string
    disable?: boolean
    /** Same contract as a Quasar field's rules; checked by a parent QForm. */
    rules?: Array<(val: T | null | undefined) => true | string>
    /** Show only a trailing "(ACRONYM)" when the value has one — the college list. */
    acronym?: boolean
  }>(),
  { label: '', placeholder: '', disable: false, rules: () => [], acronym: false },
)

const emit = defineEmits<{ 'update:modelValue': [T] }>()

const showing = ref(false)
const error = ref('')

const items = computed(() =>
  Array.isArray(props.options)
    ? props.options.map((o) => (typeof o === 'object' ? o : { label: String(o), value: o }))
    : Object.entries(props.options).map(([value, label]) => ({ label, value: value as T })),
)

const hasValue = computed(() => props.modelValue !== null && props.modelValue !== undefined && props.modelValue !== '')

const display = computed(() => {
  if (!hasValue.value) return ''
  const label = items.value.find((o) => o.value === props.modelValue)?.label ?? String(props.modelValue)
  return props.acronym ? (label.match(/\(([^)]+)\)\s*$/)?.[1] ?? label) : label
})

function validate(value = props.modelValue): boolean {
  for (const rule of props.rules) {
    const result = rule(value)
    if (result !== true) {
      error.value = result
      return false
    }
  }
  error.value = ''
  return true
}

useFormChild({ validate: () => validate(), resetValidation: () => (error.value = ''), requiresQForm: false })

function pick(value: T) {
  emit('update:modelValue', value)
  showing.value = false
  if (error.value) validate(value)
}
</script>

<style scoped>
.sel-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.sel-opt {
  display: flex;
  min-height: 48px;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border: 0;
  border-radius: 9px;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  line-height: 1.35;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.sel-opt-label {
  flex: 1 1 auto;
  min-width: 0;
}
.sel-opt--on {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-weight: 700;
}
</style>
