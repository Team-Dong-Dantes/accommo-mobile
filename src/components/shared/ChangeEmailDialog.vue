<template>
  <AppModal v-model="open" :title="sent ? 'Check both inboxes' : 'Change email'" size="sm" @hide="reset">
    <template v-if="!sent">
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
    </template>

    <p v-else class="ce-sub">
      We sent a confirmation link to <strong>{{ currentEmail }}</strong> (to unbind it) and another to
      <strong>{{ email }}</strong> (to bind it). Your email only changes once both are confirmed.
    </p>

    <template #footer>
      <template v-if="!sent">
        <button type="button" class="ce-btn ce-btn--ghost" :disabled="busy" @click="open = false">
          Cancel
        </button>
        <button type="button" class="ce-btn ce-btn--go" :disabled="busy" @click="submit">
          {{ busy ? 'Sending…' : 'Send confirmations' }}
        </button>
      </template>
      <button v-else type="button" class="ce-btn ce-btn--go" @click="open = false">Done</button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import AppModal from '@/components/shared/AppModal.vue'
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
.ce-sub {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}
.ce-input {
  width: 100%;
  min-height: 44px;
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
