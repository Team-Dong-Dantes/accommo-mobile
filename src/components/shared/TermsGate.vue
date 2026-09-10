<template>
  <q-dialog v-model="open" persistent>
    <q-card class="gate-card">
      <div class="gate-head">
        <span class="gate-title">Our policies were updated</span>
        <span class="gate-sub">Please read and accept them to keep using accommo.</span>
      </div>

      <div ref="bodyEl" class="gate-body" @scroll="onScroll">
        <PoliciesList @loaded="onLoaded" />
      </div>

      <div class="gate-actions">
        <button type="button" class="gate-out" :disabled="saving" @click="signOutInstead">Sign out</button>
        <span v-if="!hasRead" class="gate-note">Scroll to the end to accept</span>
        <q-btn
          v-else
          unelevated
          rounded
          no-caps
          color="primary"
          :loading="saving"
          label="I accept"
          class="q-px-lg"
          @click="accept"
        />
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import PoliciesList from '@/components/shared/PoliciesList.vue'

// Re-consent gate. A policy that takes effect after the date on this account's
// acceptance means the terms they agreed to are no longer the terms in force,
// so ask again — once, blocking, at the top of the shell.
//
// Silent when OSAS has published nothing, and for an account whose acceptance
// is already newer than every live policy, so the common case costs two small
// queries and renders nothing.
//
// Accepting is gated on scrolling through the documents, same as the checkbox
// on the register screens. Content short enough not to scroll counts as read
// as soon as it renders, so the button can never be unreachable.

const router = useRouter()
const notify = useNotify()

const open = ref(false)
const saving = ref(false)
const userId = ref('')
const hasRead = ref(false)
const bodyEl = ref<HTMLElement | null>(null)

function onLoaded() {
  void nextTick(() => {
    const el = bodyEl.value
    if (el && el.scrollHeight <= el.clientHeight + 4) hasRead.value = true
  })
}

function onScroll() {
  const el = bodyEl.value
  if (!el) return
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 24) hasRead.value = true
}

onMounted(async () => {
  const { data } = await authUser()
  const uid = data?.user?.id
  if (!uid) return
  userId.value = uid

  const [{ data: row }, { data: newest }] = await Promise.all([
    supabase.from('users').select('terms_accepted_at').eq('id', uid).maybeSingle(),
    supabase
      .from('policies')
      .select('effective_date')
      .order('effective_date', { ascending: false })
      .limit(1)
      .maybeSingle(),
  ])

  // RLS hides archived and not-yet-effective policies from this reader, so
  // `newest` is the latest document actually in force.
  if (!newest) return

  const acceptedAt = row?.terms_accepted_at
  if (acceptedAt && new Date(acceptedAt) >= new Date(newest.effective_date)) return

  open.value = true
})

async function accept() {
  saving.value = true
  const { error } = await supabase
    .from('users')
    .update({ terms_accepted_at: new Date().toISOString() })
    .eq('id', userId.value)
  saving.value = false
  if (error) {
    notify.error(error.message)
    return
  }
  open.value = false
}

async function signOutInstead() {
  await supabase.auth.signOut()
  void router.push('/login')
}
</script>

<style scoped>
.gate-card {
  display: flex;
  width: min(520px, 92vw);
  max-height: 82vh;
  flex-direction: column;
  border-radius: 16px;
}
.gate-head { padding: 16px 16px 10px; }
.gate-title { display: block; color: var(--m-ink); font-size: 15.5px; font-weight: 700; }
.gate-sub { display: block; margin-top: 3px; color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.gate-body { overflow-y: auto; padding: 0 12px 12px; }
.gate-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 14px 14px;
  border-top: 1px solid var(--m-border);
}
.gate-note { color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.gate-out {
  padding: 6px 4px;
  border: 0;
  background: none;
  color: var(--m-muted);
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  cursor: pointer;
}
</style>
