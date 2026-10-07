<template>
  <!-- QField for the same reason AuthConsent uses one: the card is custom markup
       that still has to be a field of the screen's QForm, so a required document
       fails validation and paints an error like any input would. -->
  <q-field
    ref="fieldEl"
    :model-value="model"
    :rules="rules"
    lazy-rules="ondemand"
    borderless
    hide-bottom-space
    class="doc-field"
  >
    <template #control>
      <div class="doc-card" :class="{ 'doc-card--filled': !!model }">
        <button type="button" class="doc-main" @click="pick">
          <!-- The whole point of the redesign: you can see the photo is
               readable before you send it. OSAS bouncing an unreadable ID is
               what the entire resubmission flow exists to handle, and a
               filename told you nothing about legibility. -->
          <span v-if="previewUrl" class="doc-thumb">
            <img :src="previewUrl" alt="" />
          </span>
          <span v-else class="doc-icon" :class="{ 'doc-icon--empty': !model }">
            <IconifyIcon :icon="model ? 'lucide:file-text' : icon" width="20" />
          </span>

          <span class="doc-copy">
            <span class="doc-title">{{ title }}</span>
            <span v-if="model" class="doc-meta">{{ model.name }} · {{ humanStorageSize(model.size) }}</span>
            <span v-else class="doc-hint">{{ hint }}</span>
          </span>

          <span v-if="!model" class="doc-add"><IconifyIcon icon="lucide:plus" width="18" /></span>
        </button>

        <!-- What the phone read off a scan, so a blurred ID or last term's
             assessment is caught now rather than by OSAS days later. A hint,
             never a gate: it can misread, and OSAS decides. -->
        <div v-if="model && (checking || findings.length)" class="doc-check" aria-live="polite">
          <span v-if="checking" class="doc-check-row">
            <q-spinner size="14px" class="doc-check-icon" />Checking your document…
          </span>
          <span v-else-if="issues.length === 0" class="doc-check-row doc-check-row--ok">
            <IconifyIcon icon="lucide:circle-check" width="15" class="doc-check-icon" />
            {{ okSummary }}
          </span>
          <template v-else>
            <span v-for="f in issues" :key="f.label" class="doc-check-row doc-check-row--warn">
              <IconifyIcon icon="lucide:circle-alert" width="15" class="doc-check-icon" />
              <span><b>{{ f.label }}:</b> {{ f.detail }}</span>
            </span>
            <span class="doc-check-note">Retake it if it's unclear. You can still send it as it is; OSAS checks it either way.</span>
          </template>
        </div>

        <div class="doc-actions">
          <template v-if="model">
            <q-btn flat dense no-caps class="doc-action" @click="openCamera">
              <IconifyIcon icon="lucide:scan-line" width="15" class="q-mr-xs" />
              Retake
            </q-btn>
            <q-btn flat dense no-caps class="doc-action" label="Replace" @click="pick" />
            <q-btn flat dense no-caps class="doc-action doc-action--quiet" label="Remove" @click="clear" />
          </template>
          <!-- The icon goes in the slot, not the `icon` prop: that prop feeds
               Quasar's QIcon, which renders an Iconify name as literal text. -->
          <q-btn v-else flat dense no-caps class="doc-action" @click="openCamera">
            <IconifyIcon icon="lucide:scan-line" width="15" class="q-mr-xs" />
            Scan it
          </q-btn>
        </div>
      </div>
    </template>
  </q-field>

  <input ref="inputEl" type="file" :accept="accept" hidden @change="onPicked" />
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { format, type QField } from 'quasar'
import { readDocumentText, scanDocument } from '@/utils/camera'
import type { DocFinding } from '@/utils/docReading'
import { useNotify } from '@/utils/notify'

// One card per document, used by the student's proof-of-enrolment screen and by
// the landlord/landlady's verification documents — the same control, so it stays one
// component rather than drifting into two.
//
// It replaced a pair of dashed boxes that were identical apart from a small icon
// and a label beginning "Tap to upload", and whose filled state was a filename
// and a byte count. Neither told anyone whether the photo they had just taken
// was legible, which is the only thing that matters here: OSAS rejects
// unreadable copies, and the applicant does not find out for days.

const { humanStorageSize } = format

const model = defineModel<File | null>()
/** The text read off the current scan; null for a picked file or nothing read. */
const text = defineModel<string | null>('text', { default: null })

const props = withDefaults(
  defineProps<{
    /** What the document is, e.g. "School ID". */
    title: string
    /** One line on what makes a copy acceptable. */
    hint?: string
    icon?: string
    accept?: string
    /** Passed to the QField, so a required document blocks the form. */
    rules?: Array<(val: File | null) => boolean | string>
    /** Checks what a scan says. Without it nothing is read. */
    check?: (text: string) => DocFinding[]
  }>(),
  {
    hint: '',
    icon: 'lucide:file-up',
    accept: 'image/*,.pdf',
    rules: () => [],
  },
)

const notify = useNotify()
const inputEl = ref<HTMLInputElement | null>(null)
const fieldEl = ref<QField | null>(null)
const previewUrl = ref<string | null>(null)
const checking = ref(false)
const findings = ref<DocFinding[]>([])
const issues = computed(() => findings.value.filter((f) => !f.ok))
/** 'Name, student number and school match.' */
const okSummary = computed(() => {
  const parts = findings.value.map((f, i) => (i ? f.label.toLowerCase() : f.label))
  const last = parts.pop()
  return (parts.length ? `${parts.join(', ')} and ${last}` : last) + ' match.'
})

/** Forget the last reading: the file it came from is gone. */
function forgetReading() {
  text.value = null
  findings.value = []
}

/**
 * A thumbnail for an image, nothing for a PDF — which gets the file icon
 * instead, since there is no cheap way to render its first page and a blank grey
 * box would be a worse lie than an honest icon.
 *
 * Object URLs are revoked on replace and on unmount; left alone they hold the
 * whole file in memory for the life of the tab.
 */
watch(
  model,
  (file) => {
    if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
    previewUrl.value = file && file.type.startsWith('image/') ? URL.createObjectURL(file) : null
    if (file) fieldEl.value?.resetValidation()
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
})

function pick() {
  inputEl.value?.click()
}

function onPicked(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0] ?? null
  if (file) {
    model.value = file
    forgetReading()
  }
  // Cleared so picking the same file twice in a row still fires a change.
  if (inputEl.value) inputEl.value.value = ''
}

function clear() {
  model.value = null
  forgetReading()
}

async function openCamera() {
  const { file, error, path } = await scanDocument()
  if (error) notify.error(error)
  if (!file) return
  model.value = file
  forgetReading()
  if (!path || !props.check) return
  checking.value = true
  const read = await readDocumentText(path)
  checking.value = false
  // Replaced or removed while it was reading: that answer is for another file.
  if (model.value !== file) return
  text.value = read
  // Nothing read at all checks as empty text, which says it was unreadable.
  findings.value = props.check(read ?? '')
}

</script>

<style scoped>
.doc-field :deep(.q-field__control) {
  min-height: 0;
  padding: 0;
}
.doc-field :deep(.q-field__native) {
  padding: 0;
}

/* Dashed while it is an invitation, solid once it is an answer — the same
   language the old drop zone used, kept because it was the part that worked. */
.doc-card {
  width: 100%;
  border: 1.5px dashed var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  overflow: hidden;
}
.doc-card--filled {
  border-style: solid;
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
}

.doc-main {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 0;
  background: none;
  cursor: pointer;
  text-align: left;
}

.doc-thumb,
.doc-icon {
  display: grid;
  overflow: hidden;
  width: 52px;
  height: 52px;
  flex: 0 0 auto;
  border-radius: 10px;
  place-items: center;
}
.doc-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.doc-icon {
  background: var(--m-surface);
  color: var(--m-primary-dark);
}
.doc-icon--empty {
  color: var(--m-muted);
}

.doc-copy {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.doc-title {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.doc-hint {
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.4;
}
.doc-meta {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.doc-add {
  display: grid;
  width: 28px;
  height: 28px;
  flex: 0 0 auto;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary);
  place-items: center;
}

/* Named actions rather than bare icons: "Replace" and "Remove" are different
   enough consequences to be worth spelling out. */
.doc-actions {
  display: flex;
  gap: 4px;
  padding: 0 8px 8px;
}
.doc-action {
  min-height: 34px;
  border-radius: 9px;
  color: var(--m-primary);
  font-size: 12.5px;
  font-weight: 700;
}
.doc-check {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 0 12px 8px;
  font-size: 12px;
  line-height: 1.4;
}
.doc-check-row {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  color: var(--m-muted);
}
.doc-check-row--ok {
  color: var(--m-success);
}
.doc-check-row--warn {
  color: var(--m-ink);
}
.doc-check-row--warn .doc-check-icon {
  color: var(--m-warning);
}
.doc-check-icon {
  flex: 0 0 auto;
  margin-top: 1px;
}
.doc-check-note {
  color: var(--m-muted);
  font-size: 11.5px;
}
.doc-action--quiet {
  color: var(--m-muted);
}
</style>
