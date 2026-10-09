<template>
  <AppModal
    :model-value="modelValue"
    :title="title"
    icon="lucide:triangle-alert"
    tone="danger"
    size="sm"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <p class="cds-body">{{ body }}</p>
    <template #footer>
      <button type="button" class="cds-cancel" :disabled="busy" @click="emit('update:modelValue', false)">
        Cancel
      </button>
      <button type="button" class="cds-confirm" :disabled="busy" @click="emit('confirm')">
        {{ busy ? busyLabel : confirmLabel }}
      </button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import AppModal from '@/components/shared/AppModal.vue'

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
 * confirm, and bending it to cover both would make it worse at each. Both sit
 * on AppModal, which draws the sheet itself.
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
.cds-body {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.5;
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
