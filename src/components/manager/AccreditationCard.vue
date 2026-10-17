<template>
  <div class="acr">
    <h2 class="acr-title">Accreditation</h2>

    <AccreditationStatus />

    <!-- Every past decision, newest first: what was asked, what OSAS said. -->
    <ReviewHistory :items="roundHistory(rounds)" />

    <PermitUploadSheet
      v-model="replaceOpen"
      :accommodation-id="accommodationId"
      :doc-type="replaceType"
      replacing
      :osas-note="lastReturned?.note ?? null"
      @saved="onPermitSaved"
    />

    <!-- Replacing the last flagged permit is the moment to send it back, so ask then. -->
    <AppModal v-model="resubmitPromptOpen" title="Send it back to OSAS?" icon="lucide:send" size="sm">
      <p class="box-text">
        {{ flagged.length
          ? 'Every permit OSAS flagged is replaced. OSAS won’t see it until you resubmit.'
          : 'Permit saved. When you’ve made the changes OSAS asked for, resubmit so OSAS reviews it again.' }}
      </p>
      <textarea v-model="message" class="note-input" rows="2" maxlength="1000" placeholder="Note for OSAS (optional)" />
      <template #footer>
        <button type="button" class="pill-btn rsp-later" :disabled="busy" @click="resubmitPromptOpen = false">Not yet</button>
        <button type="button" class="main-btn" :disabled="busy" @click="resubmitFromPrompt">
          {{ busy ? 'Sending…' : 'Resubmit to OSAS' }}
        </button>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import AccreditationStatus from './accreditation/AccreditationStatus.vue'
import AppModal from '@/components/shared/AppModal.vue'
import { roundHistory } from '@/components/manager/accreditation/model'
import ReviewHistory from '@/components/shared/ReviewHistory.vue'
import PermitUploadSheet from '@/components/manager/PermitUploadSheet.vue'
import { provideAccreditation } from './accreditation/accreditation'

// Its state lives in ./accreditation/; this is the card: the status box, the
// history of decisions and the permit sheets.
const props = defineProps<{
  accommodationId: string
  status: string
  appealUsed: boolean
  accreditationExpiresAt: string | null
  /** Latest version of each permit, as the parent loaded them. */
  docs: { doc_type: string; uploaded_at: string }[]
}>()
const emit = defineEmits<{
  /** The listing's status or details changed; reload it. */
  changed: []
  /** A permit was uploaded; reload the permits. */
  'docs-changed': []
  delete: []
}>()

const {
  message,
  busy,
  replaceOpen,
  replaceType,
  rounds,
  lastReturned,
  flagged,
  load,
  onPermitSaved,
  resubmitPromptOpen,
  permitReplaced,
  resubmitFromPrompt,
} = provideAccreditation({ props, emit })

defineExpose({ reload: load, flagged, permitReplaced })
</script>

<style scoped>
.acr { display: flex; flex-direction: column; gap: 10px; }
.acr-title {
  margin: 4px 0 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.box-text { margin: 0; color: var(--m-muted); font-size: 12.5px; line-height: 1.45; }
.note-input {
  box-sizing: border-box;
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
  resize: vertical;
}
.main-btn {
  min-height: 46px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.main-btn:disabled { background: var(--m-border); color: var(--m-muted); cursor: not-allowed; }
.pill-btn {
  align-self: flex-start;
  min-height: 36px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.flag-row .pill-btn { align-self: center; }
.pill-btn:disabled { opacity: 0.6; }
.rsp-later { align-self: center; min-height: 46px; }
</style>
