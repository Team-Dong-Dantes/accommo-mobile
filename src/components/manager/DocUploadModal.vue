<template>
  <!-- A document already on file is never edited in place; replacing it
       always goes through this fresh form. -->
  <AppModal :model-value="modelValue" :title="title" @update:model-value="emit('update:modelValue', $event)">
    <label class="field">
      <span class="field-label">File</span>
      <span class="file-picker" :class="{ 'file-picker--chosen': form.file }">
        <IconifyIcon :icon="form.file ? 'lucide:file-check' : 'lucide:upload'" width="16" />
        <span class="file-picker-text">{{ form.file ? form.file.name : 'Choose file' }}</span>
        <input type="file" accept="image/*,application/pdf" class="file-picker-input" @change="onFileSelected" />
      </span>
    </label>
    <label class="field">
      <span class="field-label">Expiration date</span>
      <DateTimeField v-model="form.expiresAt" mode="date" placeholder="Pick an expiry date" />
    </label>
    <template #footer>
      <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="loading" label="Upload" @click="emit('submit', { ...form })" />
    </template>
  </AppModal>
</template>

<script setup lang="ts">
// The OSAS page's upload form, shared by property permits and the
// landlord/landlady's own account documents: both take a file and an expiry.
import { reactive, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'

export interface DocUpload {
  file: File | null
  expiresAt: string
}

const props = defineProps<{ modelValue: boolean; title?: string | undefined; loading: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [open: boolean]; submit: [DocUpload] }>()

const form = reactive<DocUpload>({ file: null, expiresAt: '' })

watch(() => props.modelValue, (open) => {
  if (!open) return
  form.file = null
  form.expiresAt = ''
})

function onFileSelected(event: Event) {
  const input = event.target as HTMLInputElement
  form.file = input.files?.[0] || null
}
</script>

<style scoped>
.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.file-picker {
  position: relative;
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 8px;
  padding: 0 12px;
  border: 1px dashed var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-muted);
  cursor: pointer;
}
.file-picker--chosen {
  border-style: solid;
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.file-picker-text {
  flex: 1;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.file-picker-input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}
.new-submit {
  flex: 1;
  min-height: 48px;
  font-weight: 700;
}
</style>
