<template>
  <q-dialog
    :model-value="modelValue"
    position="bottom"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div class="sheet">
      <div class="sheet-head">
        <h2 class="sheet-title">{{ title }}</h2>
        <button v-if="clearLabel" type="button" class="sheet-clear" @click="emit('clear')">
          {{ clearLabel }}
        </button>
      </div>

      <slot />

      <button
        v-if="doneLabel"
        type="button"
        class="sheet-done"
        @click="emit('update:modelValue', false)"
      >
        {{ doneLabel }}
      </button>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
// The filter sheet the eight list screens open from their SearchDock: a
// bottom-anchored panel with a title, a reset link, the screen's own controls,
// and a full-width confirm button that just closes it.
//
// Bespoke sheets elsewhere (the QR scanner, the PIN dialog, the application
// review) share the `.sheet` prefix but not this structure, and are left alone —
// they are different panels, not copies of this one.
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
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 14px;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
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
