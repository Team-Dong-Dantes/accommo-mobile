<template>
  <section class="photo-picker">
    <div class="picker-heading"><div><strong>{{ label }}</strong><p>{{ hint }}</p></div><label class="upload-button"><IconifyIcon icon="lucide:camera" width="17" aria-hidden="true" /> Add photos<input type="file" accept="image/jpeg,image/png,image/webp" multiple @change="emit('select', $event)" /></label></div>
    <div v-if="photos.length" class="photo-grid"><figure v-for="(photo, index) in photos" :key="photo.preview"><img :src="photo.preview" :alt="`${label} ${index + 1}`" /><button type="button" :aria-label="`Remove photo ${index + 1}`" @click="emit('remove', index)"><IconifyIcon icon="lucide:x" width="16" aria-hidden="true" /></button><figcaption v-if="showCover && index === 0">Cover</figcaption></figure></div>
    <div v-else class="photo-empty"><IconifyIcon icon="lucide:image-plus" width="20" aria-hidden="true" /><span>No photos added yet</span></div>
  </section>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
interface Photo { file: File | null; preview: string; id?: string }
withDefaults(defineProps<{ label: string; hint: string; photos: Photo[]; showCover?: boolean }>(), {
  showCover: false,
})
const emit = defineEmits<{ select: [event: Event]; remove: [index: number] }>()
</script>

<style scoped>
.photo-picker { display: grid; gap: 10px; }.picker-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }.picker-heading strong { color: var(--m-ink); font-size: 12px; font-weight: 800; }.picker-heading p { margin: 3px 0 0; color: var(--m-muted); font-size: 11px; line-height: 1.4; }.upload-button { display: inline-flex; min-height: 40px; flex: 0 0 auto; align-items: center; gap: 6px; padding: 0 10px; border: 1px solid var(--m-border); border-radius: 8px; background: var(--m-surface); color: var(--m-primary-dark); font-size: 11px; font-weight: 800; cursor: pointer; }.upload-button input { position: absolute; width: 1px; height: 1px; opacity: 0; }.photo-empty { display: flex; min-height: 74px; align-items: center; justify-content: center; gap: 8px; border: 1px dashed var(--m-border); border-radius: 8px; background: var(--m-bg); color: var(--m-muted); font-size: 11px; font-weight: 700; }.photo-grid { display: grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap: 8px; }.photo-grid figure { position: relative; aspect-ratio: 1; margin: 0; overflow: hidden; border: 1px solid var(--m-border); border-radius: 8px; background: var(--m-bg); }.photo-grid img { width: 100%; height: 100%; object-fit: cover; }.photo-grid button { position: absolute; top: 4px; right: 4px; display: grid; width: 28px; height: 28px; place-items: center; border: 0; border-radius: 50%; background: rgba(23,32,42,.7); color: #fff; }.photo-grid figcaption { position: absolute; bottom: 0; left: 0; padding: 3px 5px; background: rgba(23,32,42,.72); color: #fff; font-size: 9px; font-weight: 800; }.upload-button:focus-within,.photo-grid button:focus-visible { outline: 2px solid var(--m-primary); outline-offset: 2px; }
</style>
