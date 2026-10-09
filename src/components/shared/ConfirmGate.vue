<template>
  <!-- Mounted once in MainLayout: asks whatever confirmAction() was given. -->
  <AppModal
    :model-value="!!prompt"
    :title="shown?.title"
    icon="lucide:help-circle"
    size="sm"
    @update:model-value="(open: boolean) => !open && settleConfirm(false)"
  >
    <p v-if="shown?.message" class="gate-message">{{ shown.message }}</p>
    <template #footer>
      <button type="button" class="gate-ghost" @click="settleConfirm(false)">
        Cancel
      </button>
      <button type="button" class="gate-primary" @click="settleConfirm(true)">
        Confirm
      </button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import AppModal from '@/components/shared/AppModal.vue'
import { prompt, settleConfirm, type ConfirmPrompt } from '@/utils/confirmAction'

// The last question asked, kept through the close animation so the card does
// not go blank as it leaves.
const shown = ref<ConfirmPrompt | null>(null)
watch(prompt, (p) => {
  if (p) shown.value = p
})
</script>

<style scoped>
/* This used to be a hand-rolled fixed overlay at z-index 8000, so it would not
   open UNDERNEATH an open q-dialog and leave the button appearing to do
   nothing. As an AppModal it is a q-dialog itself, and Quasar stacks the most
   recently opened dialog on top. */
.gate-message {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}
.gate-ghost {
  min-height: 42px;
  padding: 0 18px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.gate-primary {
  min-height: 42px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
</style>
