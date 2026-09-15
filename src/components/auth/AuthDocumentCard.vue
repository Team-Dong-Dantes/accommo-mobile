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

        <div class="doc-actions">
          <template v-if="model">
            <q-btn flat dense no-caps class="doc-action" label="Replace" @click="pick" />
            <q-btn flat dense no-caps class="doc-action doc-action--quiet" label="Remove" @click="clear" />
          </template>
          <!-- The icon goes in the slot, not the `icon` prop: that prop feeds
               Quasar's QIcon, which renders an Iconify name as literal text. -->
          <q-btn v-else flat dense no-caps class="doc-action" @click="openCamera">
            <IconifyIcon icon="lucide:camera" width="15" class="q-mr-xs" />
            Take a photo
          </q-btn>
        </div>
      </div>
    </template>
  </q-field>

  <input ref="inputEl" type="file" :accept="accept" hidden @change="onPicked" />
</template>

<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { format, type QField } from 'quasar'
import { capturePhoto } from '@/utils/camera'
import { useNotify } from '@/utils/notify'

// One card per document, used by the student's proof-of-enrolment screen and by
// the manager's verification documents — the same control, so it stays one
// component rather than drifting into two.
//
// It replaced a pair of dashed boxes that were identical apart from a small icon
// and a label beginning "Tap to upload", and whose filled state was a filename
// and a byte count. Neither told anyone whether the photo they had just taken
// was legible, which is the only thing that matters here: OSAS rejects
// unreadable copies, and the applicant does not find out for days.

const { humanStorageSize } = format

const model = defineModel<File | null>()

withDefaults(
  defineProps<{
    /** What the document is, e.g. "School ID". */
    title: string
    /** One line on what makes a copy acceptable. */
    hint?: string
    icon?: string
    accept?: string
    /** Passed to the QField, so a required document blocks the form. */
    rules?: Array<(val: File | null) => boolean | string>
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
  if (file) model.value = file
  // Cleared so picking the same file twice in a row still fires a change.
  if (inputEl.value) inputEl.value.value = ''
}

function clear() {
  model.value = null
}

async function openCamera() {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (file) model.value = file
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
.doc-action--quiet {
  color: var(--m-muted);
}
</style>
