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
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';

const model = defineModel<File | null>();

// A plain <input capture> silently falls back to the file picker in
// Capacitor's WebView because it never actually requests the runtime camera
// permission — the Camera plugin handles that permission prompt properly.
async function openCamera() {
  try {
    const photo = await Camera.getPhoto({
      source: CameraSource.Camera,
      resultType: CameraResultType.Uri,
      quality: 80,
    });
    if (!photo.webPath) return;
    const blob = await (await fetch(photo.webPath)).blob();
    const ext = photo.format || 'jpeg';
    model.value = new File([blob], `photo.${ext}`, { type: blob.type || `image/${ext}` });
  } catch {
    // User cancelled the camera (or denied permission) — no error toast for a cancel.
  }
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
