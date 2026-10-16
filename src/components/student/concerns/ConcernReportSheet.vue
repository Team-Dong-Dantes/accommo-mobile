<template>
  <AppModal v-model="newOpen" title="Report a concern">
    <label class="field">
      <span class="field-label">Category</span>
      <AppSelect v-model="form.category" :options="CONCERN_CATEGORY_LABEL" placeholder="Category" class="field-input" />
    </label>
    <label class="field">
      <span class="field-label">Description</span>
      <textarea v-model="form.description" class="field-input field-textarea" rows="4" placeholder="What's going on?" />
    </label>
    <label class="field">
      <span class="field-label">Photo (optional)</span>
      <span class="file-picker" :class="{ 'file-picker--chosen': form.photo }">
        <IconifyIcon :icon="form.photo ? 'lucide:file-check' : 'lucide:camera'" width="16" />
        <span class="file-picker-text">{{ form.photo ? form.photo.name : 'Attach a photo' }}</span>
        <input type="file" accept="image/*" class="file-picker-input" @change="onPhotoSelected" />
      </span>
    </label>
    <template #footer>
      <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="submitting" label="Submit" @click="submit" />
    </template>
  </AppModal>
</template>

<script setup lang="ts">
// Reporting a new concern.
import AppModal from '@/components/shared/AppModal.vue'
import AppSelect from '@/components/shared/AppSelect.vue'
import { CONCERN_CATEGORY_LABEL } from '@/utils/format'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useStudentConcerns } from './studentConcerns'

const {
  newOpen,
  submitting,
  form,
  onPhotoSelected,
  submit,
} = useStudentConcerns()
</script>

<style scoped>
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
.field-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background-color: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.field-textarea {
  min-height: 90px;
  padding: 10px 12px;
  resize: vertical;
}
.new-submit {
  flex: 1;
  min-height: 48px;
  font-weight: 700;
}
</style>
