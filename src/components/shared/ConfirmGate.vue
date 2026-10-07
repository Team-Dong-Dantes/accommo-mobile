<template>
  <!-- Mounted once in MainLayout: a floating card centred over a dimmed
       backdrop, asking whatever confirmAction() was given. -->
  <div v-if="prompt" class="gate">
    <div class="gate-backdrop" @click="settleConfirm(false)" />

    <div class="gate-card">
      <div class="gate-head">
        <span class="gate-icon">
          <IconifyIcon icon="lucide:help-circle" width="18" />
        </span>
        <h3 class="gate-title">{{ prompt.title }}</h3>
        <p v-if="prompt.message" class="gate-message">{{ prompt.message }}</p>
      </div>

      <div class="gate-actions">
        <button type="button" class="gate-ghost" @click="settleConfirm(false)">
          Cancel
        </button>
        <button type="button" class="gate-primary" @click="settleConfirm(true)">
          Confirm
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import { prompt, settleConfirm } from '@/utils/confirmAction'
</script>

<style scoped>
/* A floating card in the middle of the screen, not a bottom sheet: this is a
   stop-and-answer moment, so it sits where the eye already is rather than
   sliding up from the thumb rail like the routine sheets do. */
.gate {
  position: fixed;
  inset: 0;
  /* Above Quasar's dialog layer (6000) and anything stacked just over it, or
     the card opens UNDERNEATH an open q-dialog and the button appears to do
     nothing. Below Notify (9500), so an error toast still lands on top. */
  z-index: 8000;
  display: grid;
  place-items: center;
  padding: var(--m-page-gutter);
}
.gate-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
}

.gate-card {
  position: relative;
  display: flex;
  width: 100%;
  max-width: 340px;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 22px 20px 18px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-lg);
  background: var(--m-surface);
  box-shadow: 0 18px 48px rgba(15, 23, 42, 0.22);
  text-align: center;
}

.gate-head {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}
.gate-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.gate-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
.gate-message {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}

.gate-actions {
  display: flex;
  justify-content: center;
  gap: 8px;
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
