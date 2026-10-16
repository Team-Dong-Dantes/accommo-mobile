<template>
  <div class="acr">
    <h2 class="acr-title">Accreditation</h2>

    <AccreditationStatus />

    <!-- Every past decision, newest first: what was asked, what OSAS said. -->
    <div v-if="history.length" class="hist">
      <button type="button" class="hist-toggle" :aria-expanded="showHistory" @click="showHistory = !showHistory">
        <IconifyIcon icon="lucide:history" width="16" />
        Review history ({{ history.length }})
        <IconifyIcon :icon="showHistory ? 'lucide:chevron-up' : 'lucide:chevron-down'" width="15" />
      </button>
      <ol v-if="showHistory" class="hist-list">
        <li v-for="r in history" :key="r.id" class="hist-item">
          <span class="hist-dot" :class="`hist-dot--${r.decision}`" />
          <span class="hist-body">
            <span class="hist-head">
              {{ KIND_LABEL[r.kind] }} · <b>{{ DECISION_LABEL[r.decision ?? ''] }}</b>
            </span>
            <span class="hist-when">{{ r.decided_at ? longDate(r.decided_at) : '' }}</span>
            <span v-if="r.flagged_docs?.length" class="hist-line">Flagged: {{ r.flagged_docs.map(permitLabel).join(', ') }}</span>
            <span v-if="r.note" class="hist-line">“{{ r.note }}”</span>
            <span v-if="r.message" class="hist-line">You wrote: “{{ r.message }}”</span>
          </span>
        </li>
      </ol>
    </div>

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
import { DECISION_LABEL, KIND_LABEL } from '@/components/manager/accreditation/model'
import { Icon as IconifyIcon } from '@iconify/vue'
import PermitUploadSheet from '@/components/manager/PermitUploadSheet.vue'
import { permitLabel } from '@/utils/permits'
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
  showHistory,
  replaceOpen,
  replaceType,
  history,
  lastReturned,
  flagged,
  longDate,
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
.hist { display: flex; flex-direction: column; gap: 6px; }
/* A centred pill like .pill-btn, tinted so it reads as an action rather than
   fine print under the status box. */
.hist-toggle {
  display: inline-flex;
  align-self: center;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  padding: 0 16px;
  border: 1px solid var(--m-primary);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.hist-list { display: flex; flex-direction: column; margin: 0; padding: 0 0 0 6px; list-style: none; }
.hist-item {
  position: relative;
  display: flex;
  gap: 10px;
  padding: 0 0 12px 12px;
  border-left: 2px solid var(--m-border);
}
.hist-item:last-child { border-left-color: transparent; }
.hist-dot {
  position: absolute;
  top: 3px;
  left: -6px;
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: var(--m-border);
}
.hist-dot--approved { background: var(--m-success); }
.hist-dot--returned { background: var(--m-warning); }
.hist-dot--rejected { background: var(--m-danger); }
.hist-body { display: flex; flex-direction: column; gap: 2px; font-size: 12.5px; }
.hist-head { color: var(--m-ink); }
.hist-when { color: var(--m-muted); font-size: 11px; }
.hist-line { color: var(--m-muted); line-height: 1.4; }
</style>
