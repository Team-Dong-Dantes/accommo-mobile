<template>
  <div class="terms">
    <!-- QField, so the box is a required field of the step's QForm: pressing
         Next runs its rule and paints the same error the inputs do. -->
    <q-field
      ref="fieldEl"
      :model-value="accepted"
      :rules="[(v: boolean) => v || 'Accept the Terms of Service to continue']"
      lazy-rules="ondemand"
      borderless
      hide-bottom-space
      class="terms-field"
    >
      <template #control>
        <q-checkbox :model-value="accepted" dense size="sm" color="primary" @update:model-value="onToggle">
          <span class="terms-text" :class="{ 'terms-text--locked': !hasRead }">
            I agree to the
            <button type="button" class="terms-link" @click.stop.prevent="open = true">
              Terms of Service &amp; policies
            </button>
          </span>
        </q-checkbox>
      </template>
    </q-field>

    <q-dialog v-model="open">
      <q-card class="terms-card">
        <div class="terms-head">
          <span class="terms-head-title">Policies &amp; guidelines</span>
        </div>

        <div ref="bodyEl" class="terms-body" @scroll="onScroll">
          <PoliciesList @loaded="onLoaded" />
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
import { nextTick, ref } from 'vue'
import type { QField } from 'quasar'
import { useNotify } from '@/utils/notify'
import PoliciesList from '@/components/shared/PoliciesList.vue'

// Consent gate on the first registration step — the last point both the email
// and the Google path pass through before an account row exists. The dialog
// reads the live OSAS policies (anon-readable, so it works signed-out).
//
// The box refuses to tick until the documents have actually been scrolled
// through — the tap is caught and answered with a toast instead, so "I agree"
// can't be set on unread terms. Content that fits
// without scrolling counts as read the moment it renders — including the empty
// state, which is what OSAS having published nothing looks like. Without that
// escape hatch an empty policy list would lock every new account out of
// registration.

const notify = useNotify()

const accepted = defineModel<boolean>({ required: true })
const open = ref(false)
const hasRead = ref(false)
const bodyEl = ref<HTMLElement | null>(null)
const fieldEl = ref<QField | null>(null)

function onToggle(value: boolean) {
  if (!hasRead.value) {
    notify.info('Read the Terms of Service to the end before agreeing.')
    return
  }
  accepted.value = value
  // Ticking clears the required-field error straight away; unticking leaves it
  // to the next validate() rather than scolding mid-edit.
  if (value) fieldEl.value?.resetValidation()
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
