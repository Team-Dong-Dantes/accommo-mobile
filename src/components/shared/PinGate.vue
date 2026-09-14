<template>
  <!-- Mounted once in MainLayout. One component, three shapes: a floating card
       centred over a dimmed backdrop for an action, the same card asking in
       words when the account has no PIN to ask for, and the same card again on
       an opaque full-screen ground for the resume lock — the lock has no way
       out, which is the point of it. -->
  <div v-if="prompt" class="gate" :class="{ 'gate--lock': prompt.mode === 'lock' }">
    <div v-if="prompt.mode !== 'lock'" class="gate-backdrop" @click="cancel" />

    <div class="gate-card" :class="{ 'gate-card--lock': prompt.mode === 'lock' }">
      <div class="gate-head">
        <span class="gate-icon">
          <IconifyIcon :icon="prompt.mode === 'confirm' ? 'lucide:help-circle' : 'lucide:lock'" width="18" />
        </span>
        <h3 class="gate-title">{{ prompt.title }}</h3>
      </div>
      <p v-if="prompt.message" class="gate-message">{{ prompt.message }}</p>

      <!-- The boxes are decoration over ONE real input: a single field keeps the
           on-screen keyboard, paste and backspace behaving normally, which six
           separate inputs famously do not. -->
      <label v-if="prompt.mode !== 'confirm'" class="gate-cells" :class="{ 'gate-cells--bad': shake }">
        <span
          v-for="i in LENGTH"
          :key="i"
          class="gate-cell"
          :class="{
            'gate-cell--filled': code.length >= i,
            'gate-cell--active': code.length === i - 1 && !busy,
          }"
        >
          <span v-if="code.length >= i" class="gate-cell-dot" />
        </span>
        <input
          ref="field"
          v-model="code"
          class="gate-input"
          type="password"
          inputmode="numeric"
          autocomplete="one-time-code"
          :maxlength="LENGTH"
          :disabled="busy"
          aria-label="PIN"
          @input="onInput"
        />
      </label>

      <p v-if="error" class="gate-error">{{ error }}</p>

      <div class="gate-actions">
        <button v-if="prompt.mode !== 'lock'" type="button" class="gate-ghost" :disabled="busy" @click="cancel">
          Cancel
        </button>
        <button v-if="prompt.mode === 'confirm'" type="button" class="gate-primary" @click="settlePin(true)">
          Confirm
        </button>
        <button v-else type="button" class="gate-ghost" :disabled="busy" @click="emit('forgot')">
          Forgot your PIN?
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, nextTick } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { usePinStore } from '@/stores/pin'
import { prompt, settlePin } from '@/utils/requirePin'
import { errorMessage } from '@/utils/errors'

const LENGTH = 6

const emit = defineEmits<{ forgot: [] }>()

const pin = usePinStore()
const code = ref('')
const error = ref('')
const busy = ref(false)
const shake = ref(false)
const field = ref<HTMLInputElement | null>(null)

watch(prompt, async (next) => {
  if (!next) return
  code.value = ''
  error.value = ''
  await nextTick()
  field.value?.focus()
})

function onInput() {
  // Digits only, however the characters arrived (keyboard, paste, autofill).
  code.value = code.value.replace(/\D/g, '').slice(0, LENGTH)
  error.value = ''
  if (code.value.length === LENGTH) void submit()
}

async function submit() {
  if (busy.value) return
  busy.value = true
  try {
    if (await pin.verify(code.value)) {
      settlePin(true)
      return
    }
    // Wrong: clear and stay put. The server is counting attempts and will lock
    // the account itself, so there is nothing to enforce here.
    error.value = 'Incorrect PIN.'
    shake.value = true
    setTimeout(() => (shake.value = false), 400)
    code.value = ''
    field.value?.focus()
  } catch (e) {
    // A lockout arrives as a thrown error carrying the time it lifts.
    error.value = errorMessage(e, 'Could not check that PIN.')
    code.value = ''
  } finally {
    busy.value = false
  }
}

function cancel() {
  if (busy.value || prompt.value?.mode === 'lock') return
  settlePin(false)
}
</script>

<style scoped>
/* A floating card in the middle of the screen, not a bottom sheet: this is a
   stop-and-answer moment, so it sits where the eye already is rather than
   sliding up from the thumb rail like the routine sheets do. */
.gate {
  position: fixed;
  inset: 0;
  /* Above Quasar's dialog layer (6000) and anything stacked just over it.
     At a lower value the gate opened UNDERNEATH an open q-dialog — the leave
     confirmation, the decline-reason sheet, the delete confirmations — so the
     button appeared to do nothing at all. Deliberately below Notify (9500), so
     an error toast still lands on top of the card. */
  z-index: 8000;
  display: grid;
  place-items: center;
  padding: var(--m-page-gutter);
}
.gate--lock {
  align-items: center;
  background: var(--m-bg);
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
/* The resume lock owns the whole screen, so its card needs no shadow to lift
   off a backdrop that is not there. */
.gate-card--lock {
  border: 0;
  background: transparent;
  box-shadow: none;
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
/* Six boxes rather than bare dots: the familiar PIN-entry shape, so the number
   of digits expected is obvious before anything is typed. */
.gate-cells {
  position: relative;
  display: flex;
  width: 100%;
  justify-content: center;
  gap: 8px;
  padding: 14px 0 6px;
}
.gate-cells--bad {
  animation: gate-shake 320ms ease-in-out;
}
.gate-cell {
  display: grid;
  /* Shrinks rather than overflowing a 320px screen. */
  flex: 1 1 0;
  min-width: 0;
  max-width: 44px;
  height: 48px;
  place-items: center;
  border: 1.5px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  transition: border-color 120ms ease-out, background-color 120ms ease-out;
}
.gate-cell--filled {
  border-color: var(--m-primary);
  background: var(--m-surface);
}
/* The cell awaiting the next digit, so the caret is not missed. */
.gate-cell--active {
  border-color: var(--m-primary);
  box-shadow: 0 0 0 3px var(--m-primary-soft);
}
.gate-cell-dot {
  width: 11px;
  height: 11px;
  border-radius: 999px;
  background: var(--m-primary-dark);
}
/* The field itself is invisible but focusable, so the keyboard opens. */
.gate-input {
  position: absolute;
  inset: 0;
  border: 0;
  background: transparent;
  color: transparent;
  caret-color: transparent;
  font-size: 16px; /* keeps iOS from zooming on focus */
  outline: none;
}
.gate-error {
  margin: 0;
  color: var(--m-danger);
  font-size: 12.5px;
  text-align: center;
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
.gate-ghost:disabled {
  opacity: 0.6;
}
@keyframes gate-shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-6px); }
  75% { transform: translateX(6px); }
}
</style>
