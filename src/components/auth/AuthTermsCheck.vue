<template>
  <div class="terms">
    <!-- QField, so the boxes are a required field of the step's QForm: pressing
         Next runs its rule and paints the same error the inputs do. -->
    <q-field
      ref="fieldEl"
      :model-value="accepted"
      :rules="[() => accepted || missingMessage]"
      lazy-rules="ondemand"
      borderless
      hide-bottom-space
      class="terms-field"
    >
      <template #control>
        <div class="terms-boxes">
          <q-checkbox
            :model-value="termsAccepted"
            dense
            size="sm"
            color="primary"
            @update:model-value="(v: boolean) => onToggle('terms', v)"
          >
            <span class="terms-text" :class="{ 'terms-text--locked': !hasRead }">
              I agree to the
              <button type="button" class="terms-link" @click.stop.prevent="open = true">
                Terms of Service
              </button>
            </span>
          </q-checkbox>

          <q-checkbox
            :model-value="privacyAccepted"
            dense
            size="sm"
            color="primary"
            @update:model-value="(v: boolean) => onToggle('privacy', v)"
          >
            <span class="terms-text" :class="{ 'terms-text--locked': !hasRead }">
              I consent to my personal data being processed as described in the
              <button type="button" class="terms-link" @click.stop.prevent="open = true">
                Privacy Notice
              </button>
            </span>
          </q-checkbox>
        </div>
      </template>
    </q-field>

    <q-dialog v-model="open">
      <q-card class="terms-card">
        <div class="terms-head">
          <span class="terms-head-title">Terms of Service &amp; Privacy</span>
        </div>

        <div ref="bodyEl" class="terms-body" @scroll="onScroll">
          <LegalDocuments @loaded="onLoaded" />
        </div>

        <div class="terms-foot">
          <q-btn
            v-close-popup
            unelevated
            rounded
            no-caps
            color="primary"
            label="Done"
            class="q-px-lg"
            :disable="!hasRead"
          />
        </div>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import type { QField } from 'quasar'
import { useNotify } from '@/utils/notify'
import LegalDocuments from '@/components/shared/LegalDocuments.vue'

// Consent gate on the first registration step — the last point both the email
// and the Google path pass through before an account row exists.
//
// Two boxes, not one. Accepting the Terms of Service is agreeing to a contract;
// consenting to the processing of personal data is a separate decision, and the
// Data Privacy Act (RA 10173) treats it as one the person is entitled to make on
// its own. The two are stamped into their own columns on `users`.
//
// The exposed model stays a single boolean meaning "both given", so the two
// register screens keep reading one `agreedToTerms` flag and calling validate()
// exactly as before.
//
// The documents come from the bundle, not the database. That is what makes this
// dialog trustworthy: it cannot render empty because a row is missing, and it
// cannot fail because the network dropped at the one moment consent is being
// given. OSAS guidelines are a different thing entirely — regulations that
// apply rather than a contract anyone signs — and live on the Policies screen
// under Settings.
//
// Neither box ticks until the documents have actually been scrolled through —
// the tap is caught and answered with a toast instead, so consent can't be given
// on unread terms.

const notify = useNotify()

const accepted = defineModel<boolean>({ required: true })
const open = ref(false)
const hasRead = ref(false)
const termsAccepted = ref(false)
const privacyAccepted = ref(false)
const bodyEl = ref<HTMLElement | null>(null)
const fieldEl = ref<QField | null>(null)

/** Names the box that is still missing rather than a generic complaint. */
const missingMessage = computed(() => {
  if (!termsAccepted.value && !privacyAccepted.value) return 'Accept both to continue'
  if (!termsAccepted.value) return 'Accept the Terms of Service to continue'
  return 'Consent to the Privacy Notice to continue'
})

function onToggle(which: 'terms' | 'privacy', value: boolean) {
  if (!hasRead.value) {
    notify.info('Read both documents to the end before agreeing.')
    return
  }
  if (which === 'terms') termsAccepted.value = value
  else privacyAccepted.value = value

  accepted.value = termsAccepted.value && privacyAccepted.value
  // Completing consent clears the required-field error straight away; unticking
  // leaves it to the next validate() rather than scolding mid-edit.
  if (accepted.value) fieldEl.value?.resetValidation()
}

/** Lets the Google button paint the same error without validating the whole step. */
defineExpose({ validate: () => fieldEl.value?.validate() })

function markReadIfShort() {
  const el = bodyEl.value
  if (el && el.scrollHeight <= el.clientHeight + 4) hasRead.value = true
}

function onLoaded() {
  void nextTick(markReadIfShort)
}

function onScroll() {
  const el = bodyEl.value
  if (!el) return
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 24) hasRead.value = true
}
</script>

<style scoped>
.terms { margin-top: 14px; }
.terms-field :deep(.q-field__control) { min-height: 0; padding: 0; }
.terms-field :deep(.q-field__native) { padding: 0; }
.terms-boxes {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 6px;
}
.terms-text { color: var(--m-text, #4a4a4a); font-size: 12.5px; line-height: 1.4; }
.terms-text--locked { opacity: 0.75; }
.terms-link {
  padding: 0;
  border: 0;
  background: none;
  color: var(--q-primary);
  font: inherit;
  font-weight: 700;
  text-decoration: underline;
  cursor: pointer;
}
.terms-card {
  display: flex;
  width: min(520px, 92vw);
  max-height: 78vh;
  flex-direction: column;
  border-radius: 16px;
}
.terms-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 10px 12px 16px;
  border-bottom: 1px solid var(--m-border, #e6e6e6);
}
.terms-head-title { font-size: 15px; font-weight: 700; }
.terms-body { overflow-y: auto; padding: 12px; }
.terms-foot {
  display: flex;
  min-height: 52px;
  align-items: center;
  justify-content: flex-end;
  padding: 8px 14px;
  border-top: 1px solid var(--m-border, #e6e6e6);
}
</style>
