<template>
  <q-dialog v-model="open" @hide="reset">
    <q-card flat class="pw">
      <template v-if="!sent">
        <h2 class="pw-title">Change password</h2>
        <p class="pw-sub">We'll email you a link to set a new password. You stay signed in on this device.</p>

        <p v-if="problem" class="pw-error">{{ problem }}</p>

        <div class="pw-actions">
          <button type="button" class="pw-btn pw-btn--ghost" :disabled="busy" @click="open = false">
            Cancel
          </button>
          <button type="button" class="pw-btn pw-btn--go" :disabled="busy" @click="submit">
            {{ busy ? 'Sending…' : 'Send reset link' }}
          </button>
        </div>
      </template>

      <template v-else>
        <h2 class="pw-title">Check your inbox</h2>
        <p class="pw-sub">We sent a password reset link to {{ email }}. Follow it to set a new password.</p>
        <div class="pw-actions">
          <button type="button" class="pw-btn pw-btn--go" @click="open = false">Done</button>
        </div>
      </template>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '@/utils/supabase'

const open = defineModel<boolean>({ default: false })

const problem = ref('')
const busy = ref(false)
const sent = ref(false)
const email = ref('')

function reset() {
  problem.value = ''
  busy.value = false
  sent.value = false
  email.value = ''
}

async function submit() {
  problem.value = ''
  busy.value = true
  try {
    const { data } = await supabase.auth.getUser()
    const userEmail = data.user?.email
    if (!userEmail) throw new Error('No email on file for this account.')

    const { error } = await supabase.auth.resetPasswordForEmail(userEmail, {
      redirectTo: window.location.origin + '/#/login',
    })
    if (error) throw error

    email.value = userEmail
    sent.value = true
  } catch (e) {
    problem.value = e instanceof Error ? e.message : 'Could not send reset link.'
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
  line-height: 1.4;
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
