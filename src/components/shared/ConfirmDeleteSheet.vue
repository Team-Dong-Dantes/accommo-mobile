<template>
  <q-dialog
    :model-value="modelValue"
    position="bottom"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card class="cds">
      <span class="cds-grip" aria-hidden="true" />
      <div class="cds-header">
        <span class="cds-icon"><IconifyIcon icon="lucide:triangle-alert" width="18" /></span>
        <h3 class="cds-title">{{ title }}</h3>
      </div>
      <p class="cds-body">{{ body }}</p>
      <div class="cds-actions">
        <button type="button" class="cds-cancel" :disabled="busy" @click="emit('update:modelValue', false)">
          Cancel
        </button>
        <button type="button" class="cds-confirm" :disabled="busy" @click="emit('confirm')">
          {{ busy ? busyLabel : confirmLabel }}
        </button>
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

/**
 * "Are you sure you want to delete this?" as one component.
 *
 * AccommodationDetail carried three of these — accommodation, floor and room —
 * written out separately and identical but for their wording and which busy
 * flag they watched. Deleting a floor takes its rooms with it, so these sheets
 * are the last thing standing between a landlord/landlady and real data loss; three
 * copies meant three places for that warning to drift.
 *
 * Deliberately not built on BottomSheet: that one is the list-filter panel
 * (title, reset link, Done button), a different shape from a destructive
 * confirm, and bending it to cover both would make it worse at each.
 *
 * Styles are its own copy rather than inherited — scoped CSS does not cross
 * the component boundary.
 */
withDefaults(
  defineProps<{
    modelValue: boolean
    title: string
    /** What exactly is about to be destroyed, and that it cannot be undone. */
    body: string
    confirmLabel: string
    /** True while the delete is in flight; both buttons lock. */
    busy?: boolean
    busyLabel?: string
  }>(),
  { busy: false, busyLabel: 'Deleting…' },
)

const emit = defineEmits<{
  'update:modelValue': [open: boolean]
  confirm: []
}>()
</script>

<style scoped>
.cds {
  display: flex;
  width: 100%;
  max-width: 480px;
  max-height: 85vh;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
  overflow-y: auto;
}

.cds-grip {
  display: block;
  width: 40px;
  height: 4px;
  margin: 0 auto;
  border-radius: 999px;
  background: var(--m-border);
}

.cds-header {
  display: flex;
  align-items: center;
  gap: 10px;
}

.cds-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

.cds-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}

.cds-body {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.5;
}

.cds-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
}

.cds-cancel,
.cds-confirm {
  flex: 0 0 auto;
  min-height: 46px;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.cds-cancel {
  padding: 0 20px;
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}

.cds-confirm {
  padding: 0 16px;
  border: 1px solid var(--m-danger);
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

.cds-cancel:disabled,
.cds-confirm:disabled {
  opacity: 0.55;
  cursor: default;
}
</style>
