<template>
  <!-- Set a PIN, reset a forgotten one, or turn it off. One sheet for all three:
       they differ only in which proof is asked for. There is no "change" — see
       the note on `mode` below. -->
  <q-dialog :model-value="modelValue" position="bottom" @update:model-value="close">
    <q-card class="sheet">
      <span class="sheet-grip" aria-hidden="true" />
      <div class="sheet-head">
        <span class="sheet-icon"><IconifyIcon :icon="mode === 'off' ? 'lucide:lock-open' : 'lucide:lock'" width="18" /></span>
        <h3 class="sheet-title">{{ title }}</h3>
      </div>
      <p class="sheet-hint">{{ hint }}</p>

      <!-- Step one of a reset: proof of the mailbox. The old PIN is never asked
           for — it is exactly what someone who has forgotten it cannot supply. -->
      <label v-if="mode === 'forgot' && step === 'code'" class="field">
        <span class="field-label">E-mail code</span>
        <input
          v-model="code"
          class="field-input"
          inputmode="numeric"
          maxlength="8"
          placeholder="From your inbox"
          @input="error = ''"
        />
      </label>

      <!-- Turning protection off is the one action the current PIN still gates. -->
      <label v-if="mode === 'off'" class="field">
        <span class="field-label">Current PIN</span>
        <input v-model="current" class="field-input" type="password" inputmode="numeric" maxlength="6" @input="clean('current')" />
      </label>

      <!-- Step two, and the whole of the first-time setup. -->
      <template v-if="mode !== 'off' && step === 'pin'">
        <label class="field">
          <span class="field-label">{{ mode === 'forgot' ? 'New PIN' : 'PIN' }}</span>
          <input v-model="next" class="field-input" type="password" inputmode="numeric" maxlength="6" placeholder="6 digits" @input="clean('next')" />
        </label>
        <label class="field">
          <span class="field-label">Confirm</span>
          <input v-model="confirm" class="field-input" type="password" inputmode="numeric" maxlength="6" @input="clean('confirm')" />
        </label>
      </template>

      <p v-if="error" class="sheet-error">{{ error }}</p>

      <div class="sheet-actions">
        <button type="button" class="ghost" :disabled="busy" @click="close(false)">{{ cancelLabel ?? 'Cancel' }}</button>
        <button type="button" :class="mode === 'off' ? 'danger' : 'primary'" :disabled="busy || !canSubmit" @click="submit">
          {{ actionLabel }}
        </button>
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { usePinStore } from '@/stores/pin'
import { useAuthStore } from '@/stores/auth'
import { useNotify } from '@/utils/notify'
import { errorMessage } from '@/utils/errors'

const props = defineProps<{
  modelValue: boolean
  /**
   * 'set'    the first PIN -- no e-mail step, the owner is already signed in
   *          and holds nothing yet to protect
   * 'forgot' replace it -- the mailbox is the only proof, in two steps. There is
   *          deliberately no "change the PIN you remember" path: it would be
   *          this same flow with one extra field that guards nothing, since
   *          anyone able to supply the old PIN can use this one instead
   * 'off'    remove it -- the one place the current PIN is still the barrier
   */
  mode: 'set' | 'forgot' | 'off'
  /** Where the code is sent. */
  email: string
  /** "Skip for now" when offered during sign-up rather than chosen in Settings. */
  cancelLabel?: string
}>()

const emit = defineEmits<{ 'update:modelValue': [boolean]; done: [] }>()

const pin = usePinStore()
const auth = useAuthStore()
const notify = useNotify()

const current = ref('')
const next = ref('')
const confirm = ref('')
const code = ref('')
const error = ref('')
const busy = ref(false)

/**
 * A reset walks send -> code -> pin; everything else opens straight on the PIN
 * fields. The mail is not sent until the button is pressed: opening a sheet by
 * accident should not put a code in someone's inbox, and a code they did not
 * ask for reads like an attack on the account.
 */
const step = ref<'send' | 'code' | 'pin'>('pin')

const title = computed(() =>
  props.mode === 'set' ? 'Set a PIN' : props.mode === 'forgot' ? 'Reset your PIN' : 'Turn off your PIN',
)

const hint = computed(() => {
  if (props.mode === 'off') {
    return 'Money and tenancy actions will stop asking for a PIN, and the app will no longer lock itself.'
  }
  if (props.mode === 'forgot') {
    if (step.value === 'send') {
      return `We will send a code to ${props.email}. Confirming the mailbox is how we know the request is really yours.`
    }
    return step.value === 'code'
      ? `Enter the code we sent to ${props.email}.`
      : 'Mailbox confirmed. Choose a new PIN.'
  }
  return 'Six digits. You will be asked for it before accepting tenants, verifying payments, and when the app has been closed for a while.'
})

const actionLabel = computed(() => {
  if (busy.value) return step.value === 'send' ? 'Sending…' : step.value === 'code' ? 'Checking…' : 'Saving…'
  if (step.value === 'send') return 'Send code'
  if (step.value === 'code') return 'Verify'
  return props.mode === 'off' ? 'Turn off' : 'Save PIN'
})

const canSubmit = computed(() => {
  if (step.value === 'send') return true
  if (step.value === 'code') return code.value.trim().length >= 4
  if (props.mode === 'off') return current.value.length === 6
  return next.value.length === 6 && confirm.value.length === 6
})

function clean(which: 'current' | 'next' | 'confirm') {
  const strip = (v: string) => v.replace(/\D/g, '').slice(0, 6)
  if (which === 'current') current.value = strip(current.value)
  if (which === 'next') next.value = strip(next.value)
  if (which === 'confirm') confirm.value = strip(confirm.value)
  error.value = ''
}

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    current.value = ''
    next.value = ''
    confirm.value = ''
    code.value = ''
    error.value = ''
    step.value = props.mode === 'forgot' ? 'send' : 'pin'
  },
)

function close(open = false) {
  if (busy.value) return
  emit('update:modelValue', open)
}

async function submit() {
  if (!canSubmit.value || busy.value) return

  // Step one: ask for the mail, only now that it has actually been requested.
  if (step.value === 'send') {
    busy.value = true
    try {
      await auth.sendEmailOtp(props.email)
      step.value = 'code'
    } catch (e) {
      error.value = errorMessage(e, 'Could not send a code to your e-mail.')
    } finally {
      busy.value = false
    }
    return
  }

  // Step two: confirming the code mints a fresh session, which is the only proof
  // set_pin() accepts for replacing an existing PIN.
  if (step.value === 'code') {
    busy.value = true
    try {
      await auth.verifyEmailOtp(props.email, code.value.trim())
      step.value = 'pin'
    } catch (e) {
      error.value = errorMessage(e, 'That code did not work.')
    } finally {
      busy.value = false
    }
    return
  }

  if (props.mode !== 'off' && next.value !== confirm.value) {
    error.value = 'Those two PINs do not match.'
    return
  }

  busy.value = true
  try {
    if (props.mode === 'off') {
      // A wrong PIN comes back as `false`, not an exception: the server has to
      // commit the failed attempt against the lockout, and a raise would roll
      // that increment straight back.
      const { data, error: rpcError } = await supabase.rpc('clear_pin', { p_current: current.value })
      if (rpcError) throw new Error(rpcError.message)
      if (data === false) {
        error.value = 'That is not your current PIN.'
        return
      }
      pin.hasPin = false
      pin.lock()
      notify.success('PIN turned off.')
    } else {
      // The server enforces the 6-digit rule too; this form only spares the user
      // a round trip for the obvious mistakes.
      const { error: rpcError } = await supabase.rpc('set_pin', { p_pin: next.value })
      if (rpcError) throw new Error(rpcError.message)
      pin.hasPin = true
      notify.success(props.mode === 'set' ? 'PIN set.' : 'PIN reset.')
    }
    emit('done')
    emit('update:modelValue', false)
  } catch (e) {
    error.value = errorMessage(e, 'Could not save that PIN.')
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 10px;
  padding: 8px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom, 0px));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.sheet-grip {
  width: 38px;
  height: 4px;
  align-self: center;
  margin-bottom: 4px;
  border-radius: 999px;
  background: var(--m-border);
}
.sheet-head {
  display: flex;
  align-items: center;
  gap: 10px;
}
.sheet-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
.sheet-hint {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.field {
  display: flex;
  align-items: center;
  gap: 10px;
}
.field-label {
  flex: 0 0 92px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.field-input {
  min-width: 0;
  flex: 1 1 auto;
  padding: 9px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 16px;
  letter-spacing: 4px;
}
.sheet-error {
  margin: 0;
  color: var(--m-danger);
  font-size: 12.5px;
}
.sheet-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 4px;
}
.ghost,
.primary,
.danger {
  min-height: 44px;
  padding: 0 18px;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.ghost {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.primary {
  border: 0;
  background: var(--m-primary);
  color: #fff;
}
.danger {
  border: 0;
  background: var(--m-danger);
  color: #fff;
}
.ghost:disabled,
.primary:disabled,
.danger:disabled {
  opacity: 0.6;
}
</style>
