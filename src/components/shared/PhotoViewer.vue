<template>
  <!-- Full-screen photo viewer. Tapping the backdrop closes it, which is what
       a thumb reaches for first on a phone. Open while `modelValue` holds a URL. -->
  <q-dialog :model-value="!!modelValue" maximized @update:model-value="close">
    <div class="viewer" @click="close">
      <img :src="modelValue" alt="Photo" class="viewer-img" />
      <button type="button" class="viewer-close" aria-label="Close photo" @click.stop="close">
        <IconifyIcon icon="lucide:x" width="20" />
      </button>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

defineProps<{ modelValue: string }>()
const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()

function close() {
  emit('update:modelValue', '')
}
</script>

<style scoped>
.viewer {
  display: grid;
  width: 100%;
  height: 100%;
  place-items: center;
  padding: 16px;
  background: rgba(0, 0, 0, 0.92);
}
.viewer-img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}
.viewer-close {
  position: absolute;
  top: calc(12px + env(safe-area-inset-top));
  right: 12px;
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
</style>
