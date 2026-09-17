<template>
  <div class="consent">
    <!-- QField, so the boxes are a required field of the screen's QForm:
         pressing Continue runs its rule and paints the same error the inputs do. -->
    <q-field
      ref="fieldEl"
      :model-value="accepted"
      :rules="[() => accepted || missingMessage]"
      lazy-rules="ondemand"
      borderless
      hide-bottom-space
      class="consent-field"
    >
      <template #control>
        <div class="consent-rows">
          <div
            v-for="doc in LEGAL_DOCUMENTS"
            :key="doc.id"
            class="consent-row"
            :class="{ 'consent-row--locked': !read[doc.id] }"
          >
            <q-checkbox
              :model-value="agreed[doc.id]"
              dense
              size="sm"
              color="primary"
              :aria-label="CONSENT_TEXT[doc.id] + ' ' + doc.title"
              @update:model-value="(v: boolean) => onToggle(doc.id, v)"
            />

            <div class="consent-copy">
              <span class="consent-text">
                {{ CONSENT_TEXT[doc.id] }}
                <button type="button" class="consent-link" @click.stop.prevent="openDoc = doc.id">
                  {{ doc.title }}
                </button>
              </span>
              <!-- Only once it has been read. The unread state used to spell out
                   "Tap the title, read it, then accept" under every row, which is
                   instructions for a link that is already underlined and already
                   opens when the locked box is tapped. -->
              <span v-if="read[doc.id]" class="consent-status">
                <IconifyIcon icon="lucide:check" width="12" />
                Read in full
              </span>
            </div>
          </div>
        </div>
      </template>
    </q-field>

    <q-dialog :model-value="openDoc !== null" @update:model-value="openDoc = null">
      <q-card v-if="openDocument" class="doc-card">
        <div class="doc-head">
          <span class="doc-title">{{ openDocument.title }}</span>
          <span v-if="!read[openDocument.id]" class="doc-hint">Scroll to the end</span>
        </div>

        <div ref="bodyEl" class="doc-body" @scroll="onScroll">
          <LegalDocuments :ids="[openDocument.id]" @loaded="onLoaded" />
        </div>

        <!-- "I accept", the same word the re-consent gate uses, and it means it:
             the button that says you accept is the one that records it. A button
             here that only closed the dialog would send you back to a box you
             still had to tick, having already said the thing the box says. -->
        <div class="doc-foot">
          <q-btn
            unelevated
            rounded
            no-caps
            color="primary"
            label="I accept"
            class="q-px-lg"
            :disable="!read[openDocument.id]"
            @click="acceptOpenDocument"
          />
        </div>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import type { QField } from 'quasar'
import LegalDocuments from '@/components/shared/LegalDocuments.vue'
import { LEGAL_DOCUMENTS, type LegalDocumentId } from '@/constants/legal'

// The consent gate, inline at the foot of the first screen — under the name and
// sex fields, above the button that leaves. It sits there rather than on a
// screen of its own because consent is an ordinary part of this form, and rather
// than in a sheet because a sheet made it an interruption. What it must not be
// is the first thing anyone reads: the screen asks for a name first, and this
// closes it.
//
// It gates finishing, not starting. The Google button on this same screen is
// deliberately pressable without it — a product decision, taken knowing that
// OAuth writes a name and e-mail before anyone has agreed to anything. What
// these boxes still hold is the screen's Continue, and handleRegister()'s
// backstop before markRegistered() stamps the two consent columns.
//
// Two boxes, not one. Accepting the Terms of Service is agreeing to a contract;
// consenting to the processing of personal data is a separate decision, and the
// Data Privacy Act (RA 10173) treats it as one the person is entitled to make on
// its own. The two are stamped into their own columns on `users`.
//
// Two documents as well, each behind its own dialog and its own scroll. One
// dialog holding both meant a single flick to the bottom unlocked consent to the
// pair of them, and the Privacy Notice — second in the stack — was never really
// in front of anyone who scrolled quickly. Reading is tracked per document:
// finishing the Terms unlocks the Terms box and nothing else.
//
// Neither box is ticked for you. RA 10173 wants consent freely given and
// specific, and a box nobody touched is neither.
//
// The documents come from the bundle, not the database. That is what makes this
// trustworthy: it cannot render empty because a row is missing, and it cannot
// fail because the network dropped at the one moment consent is being given.
// OSAS guidelines are a different thing entirely — regulations that apply rather
// than a contract anyone signs — and live on the Policies screen under Settings.

/** The consent each box gives; the document's own title completes the sentence. */
const CONSENT_TEXT: Record<LegalDocumentId, string> = {
  terms: 'I agree to the',
  privacy: 'I consent to my personal data being processed as described in the',
}

const accepted = defineModel<boolean>({ required: true })
const openDoc = ref<LegalDocumentId | null>(null)
const read = reactive<Record<LegalDocumentId, boolean>>({ terms: false, privacy: false })
const agreed = reactive<Record<LegalDocumentId, boolean>>({ terms: false, privacy: false })
const bodyEl = ref<HTMLElement | null>(null)
const fieldEl = ref<QField | null>(null)

const openDocument = computed(() => LEGAL_DOCUMENTS.find((d) => d.id === openDoc.value) ?? null)

/** Names the box that is still missing rather than a generic complaint. */
const missingMessage = computed(() => {
  if (!agreed.terms && !agreed.privacy) return 'Accept both to continue'
  if (!agreed.terms) return 'Accept the Terms of Service to continue'
  return 'Consent to the Privacy Notice to continue'
})

function setAgreed(which: LegalDocumentId, value: boolean) {
  agreed[which] = value
  accepted.value = agreed.terms && agreed.privacy
  // Completing consent clears the required-field error straight away; unticking
  // leaves it to the next validate() rather than scolding mid-edit.
  if (accepted.value) fieldEl.value?.resetValidation()
}

function onToggle(which: LegalDocumentId, value: boolean) {
  // Tapping a locked box opens the document it is waiting on. Naming the
  // obstacle and then leaving the person to go find the link is not help.
  if (!read[which]) {
    openDoc.value = which
    return
  }
  setAgreed(which, value)
}

/** The dialog's "I accept": records this document's consent and closes it. */
function acceptOpenDocument() {
  const id = openDoc.value
  if (!id || !read[id]) return
  setAgreed(id, true)
  openDoc.value = null
}


// Arriving already consented — the register screen restores this after the
// Google redirect, which wipes its own state. They did read and tick both boxes
// on the way out, so showing them blank and asking again would be asking twice
// for the same consent.
onMounted(() => {
  if (!accepted.value) return
  agreed.terms = agreed.privacy = true
  read.terms = read.privacy = true
})

function markRead() {
  if (openDoc.value) read[openDoc.value] = true
}

function markReadIfShort() {
  const el = bodyEl.value
  if (el && el.scrollHeight <= el.clientHeight + 4) markRead()
}

function onLoaded() {
  void nextTick(markReadIfShort)
}

function onScroll() {
  const el = bodyEl.value
  if (!el) return
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 24) markRead()
}

// Each document opens at its own top. The dialog is reused between the two, so
// without this the second would inherit the first one's scroll position and
// arrive already at the bottom — marked read without being read.
watch(openDoc, (id) => {
  if (id) void nextTick(() => bodyEl.value?.scrollTo({ top: 0 }))
})
</script>

<style scoped>
.consent { margin-top: 10px; }
.consent-field :deep(.q-field__control) { min-height: 0; padding: 0; }
.consent-field :deep(.q-field__native) { padding: 0; }

/* One bordered group with a hairline between the two rows, the same shape as the
   field group it sits under. Two consents are two rows of one thing, not two
   loose checkboxes floating below the form. */
.consent-rows {
  width: 100%;
  border: 1px solid var(--m-border);
  border-radius: 14px;
  background: var(--m-bg);
  overflow: hidden;
}
.consent-row {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 9px 12px;
}
.consent-row + .consent-row {
  border-top: 1px solid var(--m-border);
}
.consent-row--locked .consent-text { opacity: 0.75; }

.consent-copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 3px;
  padding-top: 2px;
}
.consent-text { color: var(--m-text); font-size: 12px; line-height: 1.4; }
.consent-status {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
}
.consent-row:not(.consent-row--locked) .consent-status { color: var(--m-success); }

.consent-link {
  padding: 0;
  border: 0;
  background: none;
  color: var(--m-primary);
  font: inherit;
  font-weight: 700;
  text-decoration: underline;
  cursor: pointer;
}

.doc-card {
  display: flex;
  width: min(520px, 92vw);
  max-height: 78vh;
  flex-direction: column;
  border-radius: 16px;
}
.doc-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--m-border);
}
.doc-title { font-size: 15px; font-weight: 700; }
.doc-hint { color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.doc-body { overflow-y: auto; padding: 12px; }
.doc-foot {
  display: flex;
  min-height: 52px;
  align-items: center;
  justify-content: flex-end;
  padding: 8px 14px;
  border-top: 1px solid var(--m-border);
}
</style>
