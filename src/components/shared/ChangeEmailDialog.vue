<template>
  <q-dialog v-model="open" @hide="reset">
    <q-card flat class="ce">
      <template v-if="!sent">
        <h2 class="ce-title">Change email</h2>
        <p class="ce-sub">
          This unbinds <strong>{{ currentEmail || 'your current email' }}</strong> and binds the new address you enter below —
          we'll send a confirmation link to both, and each must be confirmed before the change takes effect.
        </p>

        <input
          v-model="email"
          class="ce-input"
          type="email"
          placeholder="New email address"
          autocomplete="email"
          @keyup.enter="submit"
        />

        <p v-if="problem" class="ce-error">{{ problem }}</p>

        <div class="ce-actions">
          <button type="button" class="ce-btn ce-btn--ghost" :disabled="busy" @click="open = false">
            Cancel
          </button>
          <button type="button" class="ce-btn ce-btn--go" :disabled="busy" @click="submit">
            {{ busy ? 'Sending…' : 'Send confirmations' }}
          </button>
        </div>
      </template>

      <template v-else>
        <h2 class="ce-title">Check both inboxes</h2>
        <p class="ce-sub">
          We sent a confirmation link to <strong>{{ currentEmail }}</strong> (to unbind it) and another to
          <strong>{{ email }}</strong> (to bind it). Your email only changes once both are confirmed.
        </p>
        <div class="ce-actions">
          <button type="button" class="ce-btn ce-btn--go" @click="open = false">Done</button>
        </div>
      </template>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/utils/supabase'

const open = defineModel<boolean>({ default: false })

const email = ref('')
const currentEmail = ref('')
const problem = ref('')
const busy = ref(false)
const sent = ref(false)

onMounted(async () => {
  const { data } = await supabase.auth.getUser()
  currentEmail.value = data.user?.email ?? ''
})

function reset() {
  email.value = ''
  problem.value = ''
  busy.value = false
  sent.value = false
}

async function submit() {
  problem.value = ''
  if (!/^\S+@\S+\.\S+$/.test(email.value)) {
    problem.value = 'Enter a valid email address.'
    return
  }

  busy.value = true
  try {
    const { error } = await supabase.auth.updateUser({ email: email.value })
    if (error) throw error
    sent.value = true
  } catch (e) {
    problem.value = e instanceof Error ? e.message : 'Could not update your email.'
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.ce {
  width: 100%;
  max-width: 340px;
  padding: 16px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.ce-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.ce-sub {
  margin: 3px 0 12px;
  color: var(--m-muted);
  font-size: 12.5px;
}
.ce-input {
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
.ce-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.ce-error {
  margin: 2px 0 0;
  color: var(--m-danger);
  font-size: 12px;
}
.ce-actions {
  display: flex;
  gap: 8px;
  margin-top: 12px;
}
.ce-btn {
  flex: 1 1 0;
  min-height: 44px;
  border: 1px solid transparent;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.ce-btn:disabled {
  opacity: 0.6;
}
.ce-btn--ghost {
  border-color: var(--m-border);
  background: var(--m-surface);
  color: var(--m-text);
}
.ce-btn--go {
  background: var(--m-primary);
  color: #fff;
}
</style>
