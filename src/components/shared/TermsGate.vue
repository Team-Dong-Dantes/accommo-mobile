<template>
  <q-dialog v-model="open" persistent>
    <q-card class="gate-card">
      <div class="gate-head">
        <span class="gate-title">{{ staleDocs.length > 1 ? 'Our terms were updated' : `Our ${staleDocs[0]?.title} was updated` }}</span>
        <span class="gate-sub">
          Please read and accept {{ staleDocs.length > 1 ? 'the updated documents' : 'the updated document' }} to keep using accommo.
        </span>
      </div>

      <div ref="bodyEl" class="gate-body" @scroll="onScroll">
        <LegalDocuments :ids="staleIds" @loaded="onLoaded" />
      </div>

      <div class="gate-boxes">
        <q-checkbox
          v-for="doc in staleDocs"
          :key="doc.id"
          v-model="acceptedIds[doc.id]"
          dense
          size="sm"
          color="primary"
          :disable="!hasRead"
          :label="doc.id === 'privacy' ? 'I consent to my personal data being processed as described above' : 'I agree to the Terms of Service'"
          class="gate-box"
        />
      </div>

      <div class="gate-actions">
        <button type="button" class="gate-out" :disabled="saving" @click="signOutInstead">Sign out</button>
        <span v-if="!hasRead" class="gate-note">Scroll to the end to accept</span>
        <span v-else-if="!allAccepted" class="gate-note">Tick every box to continue</span>
        <q-btn
          v-if="hasRead"
          unelevated
          rounded
          no-caps
          color="primary"
          :loading="saving"
          :disable="!allAccepted"
          label="I accept"
          class="q-px-lg"
          @click="accept"
        />
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import LegalDocuments from '@/components/shared/LegalDocuments.vue'
import { LEGAL_DOCUMENTS, type LegalDocument, type LegalDocumentId } from '@/constants/legal'

// Re-consent gate. A bundled document whose effective date is later than this
// account's acceptance of *that document* means the version they agreed to is no
// longer the one in force, so ask again — once, blocking, at the top of the
// shell.
//
// Per-document on purpose. The Terms and the Privacy Notice have their own
// effective dates and their own columns on `users`, so revising one never
// re-asks for the other, and accepting one never silently restamps the other.
// OSAS publishing or editing a guideline can never trigger this at all:
// guidelines are not part of the agreement.
//
// The comparison is against constants from the bundle, so the common case costs
// one small query and renders nothing.

const router = useRouter()
const notify = useNotify()

const open = ref(false)
const saving = ref(false)
const userId = ref('')
const hasRead = ref(false)
const bodyEl = ref<HTMLElement | null>(null)
const staleDocs = ref<LegalDocument[]>([])
const acceptedIds = reactive<Record<string, boolean>>({})

const staleIds = computed<LegalDocumentId[]>(() => staleDocs.value.map((d) => d.id))
const allAccepted = computed(() => staleDocs.value.every((d) => acceptedIds[d.id]))

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

  const { data: row } = await supabase
    .from('users')
    .select('terms_accepted_at, privacy_accepted_at')
    .eq('id', uid)
    .maybeSingle()
  if (!row) return

  // Stale means never accepted, or accepted a version older than the one this
  // build ships.
  staleDocs.value = LEGAL_DOCUMENTS.filter((doc) => {
    const acceptedAt = row[doc.acceptedColumn]
    return !acceptedAt || new Date(acceptedAt) < new Date(doc.effectiveDate)
  })
  if (!staleDocs.value.length) return

  for (const doc of staleDocs.value) acceptedIds[doc.id] = false
  open.value = true
})

async function accept() {
  saving.value = true
  // Only the stale columns are written — re-accepting the Privacy Notice must
  // not move the date on Terms the user accepted months ago.
  const now = new Date().toISOString()
  const patch: Partial<Record<LegalDocument['acceptedColumn'], string>> = {}
  for (const doc of staleDocs.value) patch[doc.acceptedColumn] = now

  const { error } = await supabase.from('users').update(patch).eq('id', userId.value)
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
.gate-boxes {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 0 14px 4px;
}
.gate-box :deep(.q-checkbox__label) {
  color: var(--m-text);
  font-size: 12px;
  line-height: 1.4;
}
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
