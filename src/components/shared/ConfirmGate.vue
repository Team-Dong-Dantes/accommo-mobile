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
    <ul v-if="shown?.checks?.length" class="gate-checks">
      <li v-for="c in shown.checks" :key="c">
        <IconifyIcon icon="lucide:check" width="16" class="gate-check-icon" />
        <span>{{ c }}</span>
      </li>
    </ul>
    <label v-if="shown?.typeToConfirm" class="gate-type">
      <span class="gate-type-label">Type <b class="gate-word">{{ shown.typeToConfirm }}</b> to continue</span>
      <input v-model="typed" type="text" autocapitalize="characters" autocomplete="off" spellcheck="false" class="gate-type-input" />
    </label>
    <template #footer>
      <button type="button" class="gate-ghost" @click="settleConfirm(false)">
        {{ shown?.typeToConfirm ? 'Back' : 'Cancel' }}
      </button>
      <button type="button" class="gate-primary" :disabled="!ready" @click="settleConfirm(true)">
        {{ shown?.confirmLabel ?? 'Confirm' }}
      </button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import { prompt, settleConfirm, type ConfirmPrompt } from '@/utils/confirmAction'

// The last question asked, kept through the close animation so the card does
// not go blank as it leaves.
const shown = ref<ConfirmPrompt | null>(null)
const typed = ref('')
watch(prompt, (p) => {
  if (p) {
    shown.value = p
    typed.value = ''
  }
})
const ready = computed(() => !shown.value?.typeToConfirm || typed.value.trim().toUpperCase() === shown.value.typeToConfirm)
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
.gate-checks {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0;
  padding: 12px 14px;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  font-size: 13.5px;
  list-style: none;
}
.gate-checks li {
  display: flex;
  gap: 8px;
}
.gate-check-icon {
  flex: 0 0 auto;
  margin-top: 1px;
  color: var(--m-success);
}
.gate-type {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.gate-type-label {
  color: var(--m-text);
  font-size: 13.5px;
}
.gate-word {
  font-family: var(--m-font-mono);
  letter-spacing: 0.06em;
}
.gate-type-input {
  min-height: 52px;
  padding: 0 14px;
  border: 2px solid var(--m-primary);
  border-radius: var(--m-radius-sm);
  outline: 0;
  background: var(--m-surface);
  color: var(--m-ink);
  font-family: var(--m-font-mono);
  font-size: 18px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.gate-primary:disabled {
  opacity: 0.45;
  cursor: default;
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
