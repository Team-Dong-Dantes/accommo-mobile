<template>
  <div class="compose">
    <header class="bar">
      <button type="button" class="bar-icon" aria-label="Discard" @click="emit('close')">
        <IconifyIcon icon="lucide:x" width="20" />
      </button>
      <span class="bar-title">New ticket</span>

      <label v-if="attachment" class="bar-icon" :class="{ 'bar-icon--busy': uploading }" aria-label="Attach a screenshot">
        <IconifyIcon :icon="uploading ? 'lucide:loader' : 'lucide:paperclip'" width="19" />
        <input type="file" accept="image/*" class="bar-file" :disabled="uploading" @change="onFileSelected" />
      </label>

      <button type="button" class="bar-send" :disabled="!canSend" @click="submit">
        {{ submitting ? 'Sending…' : 'Send' }}
      </button>
    </header>

    <div class="fields">
      <!-- Fixed recipient: a ticket only ever goes one place, and naming it is
           what makes the screen read as mail rather than a bug report form. -->
      <div class="row">
        <span class="row-label">To</span>
        <span class="row-fixed">
          <IconifyIcon icon="lucide:shield-check" width="14" />
          OSAS
        </span>
      </div>

      <div class="row row--wrap">
        <span class="row-label">Category</span>
        <span class="chips">
          <button
            v-for="c in categories"
            :key="c.value"
            type="button"
            class="chip"
            :class="{ 'chip--on': form.category === c.value }"
            @click="form.category = c.value"
          >
            {{ c.label }}
          </button>
        </span>
      </div>

      <div class="row">
        <span class="row-label">Subject</span>
        <input v-model="form.subject" type="text" class="row-input" placeholder="Short summary" maxlength="120" />
      </div>

      <div v-if="form.photoUrl" class="row">
        <span class="row-label">Attached</span>
        <span class="row-fixed">
          <IconifyIcon icon="lucide:image" width="14" />
          {{ fileName || 'Screenshot' }}
        </span>
        <button type="button" class="row-clear" aria-label="Remove attachment" @click="clearFile">
          <IconifyIcon icon="lucide:x" width="15" />
        </button>
      </div>
    </div>

    <textarea
      v-model="form.description"
      class="body"
      placeholder="What happened? Include dates, document names and anything OSAS needs to check."
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { errorMessage } from '@/utils/errors'
import { uploadDocument } from '@/utils/upload'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { useNotify } from '@/utils/notify'

export interface TicketDraft {
  category: string
  subject: string
  description: string
  photoUrl: string
}

const props = defineProps<{
  /** Category options, in DB-value order; the first is the default. */
  categories: { value: string; label: string }[]
  /** Offer a screenshot attachment (student side only). */
  attachment?: boolean
  /** Parent owns the insert, so it owns the in-flight flag too. */
  submitting?: boolean
}>()

const emit = defineEmits<{ close: []; submit: [TicketDraft] }>()

const notify = useNotify()
const uploading = ref(false)
const fileName = ref('')
const form = reactive<TicketDraft>({
  category: props.categories[0]?.value ?? 'other',
  subject: '',
  description: '',
  photoUrl: '',
})

// Both halves are required before Send lights up. The old sheet only checked
// the subject, and only after the button was pressed, so OSAS regularly got
// tickets with no description at all.
const canSend = computed(
  () => Boolean(form.subject.trim() && form.description.trim()) && !uploading.value && !props.submitting,
)

async function onFileSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploading.value = true
  try {
    form.photoUrl = await uploadDocument(file, '', 'ticket_photo')
    fileName.value = file.name
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload that screenshot.'))
  } finally {
    uploading.value = false
    input.value = ''
  }
}

function clearFile() {
  form.photoUrl = ''
  fileName.value = ''
}

function submit() {
  if (!canSend.value) return
  emit('submit', {
    category: form.category,
    subject: form.subject.trim(),
    description: form.description.trim(),
    photoUrl: form.photoUrl,
  })
}

// Full-screen like the thread, so the shell's nav and FAB step aside.
onMounted(() => { chatFullscreen.value = true })
onUnmounted(() => { chatFullscreen.value = false })
</script>

<style scoped>
.compose {
  position: fixed;
  inset: 0;
  z-index: 3000;
  display: flex;
  flex-direction: column;
  background: var(--m-surface);
}

.bar {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  padding: calc(8px + env(safe-area-inset-top)) 12px 8px;
  border-bottom: 1px solid var(--m-border);
}
.bar-icon {
  position: relative;
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.bar-icon--busy {
  color: var(--m-muted);
  pointer-events: none;
}
.bar-file {
  position: absolute;
  inset: 0;
  opacity: 0;
  cursor: pointer;
}
.bar-title {
  flex: 1 1 auto;
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
}
.bar-send {
  flex: 0 0 auto;
  padding: 8px 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.bar-send:disabled {
  opacity: 0.4;
}

/* Borderless hairline-separated rows, the way a mail composer stacks
   To / Subject above the body. */
.fields {
  flex: 0 0 auto;
}
.row {
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 10px;
  padding: 6px var(--m-page-gutter);
  border-bottom: 1px solid var(--m-border);
}
.row--wrap {
  align-items: flex-start;
  padding-top: 10px;
  padding-bottom: 10px;
}
.row-label {
  flex: 0 0 68px;
  padding-top: 2px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.row-fixed {
  display: inline-flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 5px;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.row-clear {
  display: grid;
  width: 28px;
  height: 28px;
  flex: 0 0 28px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
}
.row-input {
  min-width: 0;
  flex: 1 1 auto;
  border: 0;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
  font-weight: 600;
}
.row-input::placeholder {
  color: var(--m-muted);
  font-weight: 500;
}
.row-input:focus {
  outline: none;
}

/* Chips instead of a native <select>: four options fit on one screen, and
   picking one is a single tap rather than a system picker. */
.chips {
  display: flex;
  flex: 1 1 auto;
  flex-wrap: wrap;
  gap: 6px;
}
.chip {
  padding: 6px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-weight: 700;
}

.body {
  flex: 1 1 auto;
  padding: 14px var(--m-page-gutter) calc(14px + env(safe-area-inset-bottom));
  border: 0;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
  line-height: 1.55;
  resize: none;
}
.body::placeholder {
  color: var(--m-muted);
}
.body:focus {
  outline: none;
}
</style>
