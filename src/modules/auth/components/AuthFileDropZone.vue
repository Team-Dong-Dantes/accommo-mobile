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

    <!-- Hidden camera-only input: opens the device camera on mobile -->
    <q-file
      ref="cameraRef"
      v-model="model"
      accept="image/*"
      capture="environment"
      class="hidden-camera"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const model = defineModel<File | null>();

const cameraRef = ref<{ pickFiles: () => void } | null>(null);

function openCamera() {
  cameraRef.value?.pickFiles();
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
  background: #fafafa;
  border: 2px dashed #b2dfdb;
  border-radius: 16px;
  padding: 0 16px;
  transition: all 0.3s ease;
}

.file-dropzone:hover :deep(.q-field__control) {
  border-color: #009688;
  background: #e0f2f1;
}

.file-dropzone :deep(svg.iconify) {
  width: 20px !important;
  height: 20px !important;
}

.camera-icon-btn {
  margin-left: 4px;
}

/* Keep the camera input in the DOM (so pickFiles() works) but invisible */
.hidden-camera {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
  overflow: hidden;
  pointer-events: none;
  z-index: -1;
}
</style>
