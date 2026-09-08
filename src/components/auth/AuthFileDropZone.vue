<template>
  <div class="file-dropzone-block">
    <q-file v-model="model" borderless color="teal-9" class="file-dropzone" v-bind="$attrs">
      <template #prepend><slot name="prepend" /></template>
      <template #append>
        <q-btn
          round
          flat
          dense
          icon="material-icons:photo_camera"
          color="teal-9"
          class="camera-icon-btn"
          @click.stop="openCamera"
        />
        <slot name="append" />
      </template>
    </q-file>
  </div>
</template>

<script setup lang="ts">
import { capturePhoto } from '@/utils/camera';
import { useNotify } from '@/utils/notify';

const model = defineModel<File | null>();
const notify = useNotify();

async function openCamera() {
  const { file, error } = await capturePhoto();
  if (error) notify.error(error);
  if (file) model.value = file;
}
</script>

<style scoped>
.file-dropzone-block {
  position: relative;
}

.file-dropzone {
  border-radius: 16px;
}

.file-dropzone :deep(.q-field__control) {
  min-height: 72px;
  background: var(--m-bg);
  border: 2px dashed var(--m-border);
  border-radius: 16px;
  padding: 0 16px;
  transition: all 0.3s ease;
}

.file-dropzone:hover :deep(.q-field__control) {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
}

.file-dropzone :deep(svg.iconify) {
  width: 20px !important;
  height: 20px !important;
}

.camera-icon-btn {
  margin-left: 4px;
}
</style>
