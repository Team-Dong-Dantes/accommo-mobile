<template>
  <q-dialog :model-value="modelValue" position="bottom" @update:model-value="emit('update:modelValue', $event)">
    <q-card class="sheet">
      <span class="sheet-grip" aria-hidden="true" />
      <div class="sheet-header">
        <span class="sheet-header-icon"><IconifyIcon icon="lucide:file-up" width="18" /></span>
        <h3 class="sheet-title">{{ replacing ? 'Replace' : 'Upload' }} {{ permitLabel(docType).toLowerCase() }}</h3>
      </div>

      <p v-if="osasNote" class="sheet-note">
        <IconifyIcon icon="lucide:message-square-warning" width="14" />
        <span>{{ osasNote }}</span>
      </p>

      <div class="pick-row">
        <button type="button" class="pick-btn" :disabled="busy" @click="takePhoto">
          <IconifyIcon icon="lucide:camera" width="16" /> Take a photo
        </button>
        <label class="pick-btn" :class="{ 'pick-btn--disabled': busy }">
          <IconifyIcon icon="lucide:upload" width="16" /> Choose a file
          <input type="file" accept="image/*,application/pdf" class="file-hidden" :disabled="busy" @change="onPicked" />
        </label>
      </div>
      <p v-if="file" class="picked">
        <IconifyIcon :icon="file.type === 'application/pdf' ? 'lucide:file-text' : 'lucide:image'" width="14" />
        <span>{{ file.name }}</span>
      </p>
      <p class="hint">A clear photo of the whole permit, or the PDF. Photos must be at least 1000 px on the short side.</p>

      <label class="field">
        <span class="field-label">Expires on</span>
        <input v-model="expiresAt" type="date" class="field-input" :min="today" />
      </label>

      <div class="actions">
        <q-btn unelevated rounded no-caps color="primary" :loading="busy" :disabled="!file" label="Upload" @click="save" />
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
// One permit, picked, dated and saved as its next version. Used wherever a
// landlord/landlady replaces a permit outside the new-listing wizard: the
// "What OSAS needs" card and the accommodation's Permits list.
import { ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { capturePhoto } from '@/utils/camera'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { expiryProblem, permitLabel, savePermitVersion, uploadPermitFile } from '@/utils/permits'

const props = defineProps<{
  modelValue: boolean
  accommodationId: string
  docType: string
  /** A version already exists; this one supersedes it. */
  replacing?: boolean
  /** What OSAS said about the permit being replaced, if anything. */
  osasNote?: string | null
}>()
const emit = defineEmits<{ 'update:modelValue': [open: boolean]; saved: [docType: string] }>()

const notify = useNotify()
const file = ref<File | null>(null)
const expiresAt = ref('')
const busy = ref(false)
const today = new Date().toISOString().slice(0, 10)

watch(() => props.modelValue, (open) => {
  if (!open) return
  file.value = null
  expiresAt.value = ''
})

async function takePhoto() {
  const { file: shot, error } = await capturePhoto()
  if (error) notify.error(error)
  if (shot) file.value = shot
}

function onPicked(event: Event) {
  const input = event.target as HTMLInputElement
  file.value = input.files?.[0] ?? null
  input.value = ''
}

async function save() {
  if (!file.value || busy.value) return
  const problem = expiryProblem(expiresAt.value)
  if (problem) {
    notify.error(problem)
    return
  }
  busy.value = true
  try {
    const uploaded = await uploadPermitFile(file.value)
    await savePermitVersion(props.accommodationId, props.docType, uploaded, expiresAt.value)
    notify.success(`${permitLabel(props.docType)} uploaded.`)
    emit('saved', props.docType)
    emit('update:modelValue', false)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this permit.'))
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
/* The bottom-sheet look AccommodationDetail's own sheets use, so this one sits
   among them without a seam. */
.sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  max-height: 85vh;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
  overflow-y: auto;
}
.sheet-grip {
  display: block;
  width: 40px;
  height: 4px;
  margin: 0 auto;
  border-radius: 999px;
  background: var(--m-border);
}
.sheet-header { display: flex; align-items: center; gap: 10px; }
.sheet-header-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.sheet-note {
  display: flex;
  gap: 8px;
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-warning-soft);
  color: var(--m-ink);
  font-size: 12.5px;
  line-height: 1.4;
}
.sheet-note :deep(svg) { flex: 0 0 auto; margin-top: 1px; color: var(--m-warning); }
.pick-row { display: flex; gap: 8px; }
.pick-btn {
  display: inline-flex;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 44px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.pick-btn:disabled,
.pick-btn--disabled { opacity: 0.6; pointer-events: none; }
.file-hidden { display: none; }
.picked {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 600;
  overflow-wrap: anywhere;
}
.hint { margin: 0; color: var(--m-muted); font-size: 12px; }
.field { display: flex; flex-direction: column; gap: 4px; }
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.field-input {
  box-sizing: border-box;
  width: 100%;
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background-color: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.actions { display: flex; justify-content: flex-end; }
</style>
