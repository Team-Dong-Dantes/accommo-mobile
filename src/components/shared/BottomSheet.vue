<template>
  <AppModal
    :model-value="modelValue"
    :title="title"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <template v-if="clearLabel" #actions>
      <button type="button" class="sheet-clear" @click="emit('clear')">
        {{ clearLabel }}
      </button>
    </template>

    <slot />

    <template v-if="doneLabel" #footer>
      <button type="button" class="sheet-done" @click="emit('update:modelValue', false)">
        {{ doneLabel }}
      </button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import AppModal from '@/components/shared/AppModal.vue'

// The filter sheet the eight list screens open from their SearchDock: an
// AppModal with a title, a reset link, the screen's own controls, and a
// full-width confirm button that just closes it.
//
// Other modals (the QR scanner, the application review) are AppModals too but
// not this structure — they are different panels, not copies of this one.
withDefaults(
  defineProps<{
    modelValue: boolean
    title: string
    /** Reset link in the header. Pass an empty string to hide it. */
    clearLabel?: string
    /**
     * Confirm button label — some screens count their results into it. Empty
     * hides the button, for sheets that supply their own action row.
     */
    doneLabel?: string
  }>(),
  {
    clearLabel: 'Reset',
    doneLabel: 'Done',
  },
)

const emit = defineEmits<{
  'update:modelValue': [open: boolean]
  clear: []
}>()
</script>

<style scoped>
.sheet-clear {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.sheet-done {
  flex: 1;
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}

/* The body is slotted, so it compiles in the parent's scope and this block
   would never reach it without `:slotted`. These three are the layout classes
   every filter sheet's controls are written against. */
:slotted(.sheet-block) {
  display: flex;
  flex-direction: column;
  gap: 7px;
}
:slotted(.sheet-label) {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
:slotted(.sheet-row) {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
</style>
