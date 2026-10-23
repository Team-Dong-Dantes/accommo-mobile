<template>
  <!-- The boxes are decoration over ONE real input: a single field keeps the
       caret, paste, autofill and the numeric keyboard all behaving normally,
       where six separate inputs would fight each of them. The label makes the
       whole row a tap target for it. -->
  <label
    class="pin-cells"
    :class="{ 'pin-cells--bad': invalid, 'pin-cells--busy': disabled, 'pin-cells--lg': large }"
  >
    <span
      v-for="i in length"
      :key="i"
      class="pin-cell"
      :class="{
        'pin-cell--filled': value.length >= i,
        'pin-cell--active': value.length === i - 1 && !disabled,
      }"
    >
      <span v-if="value.length >= i" class="pin-cell-dot" />
    </span>

    <input
      ref="field"
      :value="value"
      class="pin-input"
      type="password"
      inputmode="numeric"
      autocomplete="off"
      :maxlength="length"
      :disabled="disabled"
      :aria-label="ariaLabel"
      @input="onInput"
    />
  </label>
</template>

<script setup lang="ts">
import { ref } from 'vue'

// The six-cell PIN row, shared by the lock screen and the register form so the
// two cannot drift into different ideas of what entering a PIN looks like. The
// component owns only the display and the digits-only rule; what a completed PIN
// *means* — verify it, confirm it, submit — stays with whoever is asking.

const value = defineModel<string>({ default: '' })

const props = withDefaults(
  defineProps<{
    length?: number
    disabled?: boolean
    /** Shakes the row — a wrong PIN, not a malformed one. */
    invalid?: boolean
    /** Taller, full-width cells for the lock screen. */
    large?: boolean
    ariaLabel?: string
  }>(),
  { length: 6, disabled: false, invalid: false, large: false, ariaLabel: 'PIN' },
)

const field = ref<HTMLInputElement | null>(null)

function onInput(event: Event) {
  const el = event.target as HTMLInputElement
  // Digits only, however the characters arrived — keyboard, paste, autofill.
  const next = el.value.replace(/\D/g, '').slice(0, props.length)
  value.value = next
  // Put the sanitised value back on the element too, or a rejected character
  // stays visible in a field whose model no longer contains it.
  if (el.value !== next) el.value = next
}

defineExpose({ focus: () => field.value?.focus() })
</script>

<style scoped>
.pin-cells {
  position: relative;
  display: flex;
  width: 100%;
  justify-content: center;
  gap: 8px;
}
.pin-cells--bad {
  animation: pin-shake 320ms ease-in-out;
}
/* Verifying: the cells go quiet so a slow check doesn't read as a dead tap. */
.pin-cells--busy {
  opacity: 0.55;
}

.pin-cell {
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
.pin-cells--lg .pin-cell {
  max-width: none;
  height: 54px;
}
.pin-cell--filled {
  border-color: var(--m-primary);
  background: var(--m-surface);
}
/* The cell awaiting the next digit, so the caret is not missed. */
.pin-cell--active {
  border-color: var(--m-primary);
  box-shadow: 0 0 0 3px var(--m-primary-soft);
}
.pin-cell-dot {
  width: 11px;
  height: 11px;
  border-radius: 999px;
  background: var(--m-primary-dark);
}

/* The field itself is invisible but focusable, so the keyboard opens. */
.pin-input {
  position: absolute;
  inset: 0;
  border: 0;
  background: transparent;
  color: transparent;
  caret-color: transparent;
  font-size: 16px; /* keeps iOS from zooming on focus */
  outline: none;
}

@keyframes pin-shake {
  0%, 100% { transform: translateX(0); }
  20% { transform: translateX(-6px); }
  40% { transform: translateX(6px); }
  60% { transform: translateX(-4px); }
  80% { transform: translateX(4px); }
}

@media (prefers-reduced-motion: reduce) {
  .pin-cells--bad { animation: none; }
  .pin-cell { transition: none; }
}
</style>
