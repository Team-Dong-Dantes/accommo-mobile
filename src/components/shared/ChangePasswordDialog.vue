<template>
  <q-dialog v-model="open" @hide="reset">
    <q-card flat class="pw">
      <h2 class="pw-title">Change password</h2>
      <p class="pw-sub">You stay signed in on this device.</p>

      <input
        v-model="password"
        class="pw-input"
        type="password"
        placeholder="New password"
        autocomplete="new-password"
      />
      <input
        v-model="confirm"
        class="pw-input"
        type="password"
        placeholder="Confirm new password"
        autocomplete="new-password"
        @keyup.enter="submit"
      />

      <p v-if="problem" class="pw-error">{{ problem }}</p>

      <div class="pw-actions">
        <button type="button" class="pw-btn pw-btn--ghost" :disabled="busy" @click="open = false">
          Cancel
        </button>
        <button type="button" class="pw-btn pw-btn--go" :disabled="busy" @click="submit">
          {{ busy ? 'Saving…' : 'Update' }}
        </button>
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from '@/utils/supabase'

const open = defineModel<boolean>({ default: false })

const $q = useQuasar()
const password = ref('')
const confirm = ref('')
const problem = ref('')
const busy = ref(false)

function reset() {
  password.value = ''
  confirm.value = ''
  problem.value = ''
  busy.value = false
}

async function submit() {
  problem.value = ''
  if (password.value.length < 8) {
    problem.value = 'Use at least 8 characters.'
    return
  }
  if (password.value !== confirm.value) {
    problem.value = 'The two passwords do not match.'
    return
  }

  busy.value = true
  try {
    const { error } = await supabase.auth.updateUser({ password: password.value })
    if (error) throw error
    open.value = false
    $q.notify({ type: 'positive', message: 'Password updated.' })
  } catch (e) {
    problem.value = e instanceof Error ? e.message : 'Could not update your password.'
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.pw {
  width: 100%;
  max-width: 340px;
  padding: 16px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.pw-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.pw-sub {
  margin: 3px 0 12px;
  color: var(--m-muted);
  font-size: 12.5px;
}
.pw-input {
  width: 100%;
  min-height: 44px;
  margin-bottom: 8px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.pw-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.pw-error {
  margin: 2px 0 0;
  color: var(--m-danger);
  font-size: 12px;
}
.pw-actions {
  display: flex;
  gap: 8px;
  margin-top: 12px;
}
.pw-btn {
  flex: 1 1 0;
  min-height: 44px;
  border: 1px solid transparent;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pw-btn:disabled {
  opacity: 0.6;
}
.pw-btn--ghost {
  border-color: var(--m-border);
  background: var(--m-surface);
  color: var(--m-text);
}
.pw-btn--go {
  background: var(--m-primary);
  color: #fff;
}
</style>
