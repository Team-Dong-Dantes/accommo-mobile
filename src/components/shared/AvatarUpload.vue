<template>
  <div class="avatar-upload" :style="{ '--au-size': `${size}px`, '--au-bg': background }" @click="pick">
    <img v-if="displayUrl && !failed" :src="displayUrl" alt="" class="avatar-upload-img" @error="failed = true" />
    <span v-else class="avatar-upload-initials">{{ initials || '?' }}</span>
    <span class="avatar-upload-overlay" :class="{ 'avatar-upload-overlay--busy': preview }">
      <q-spinner v-if="preview" :size="`${Math.round(size * 0.3)}px`" />
      <IconifyIcon v-else icon="lucide:camera" :width="Math.round(size * 0.22)" />
    </span>
  </div>
  <input ref="inputEl" type="file" accept="image/*" class="avatar-upload-hidden" @change="onSelected" />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { uploadAvatar, whenLoaded } from '@/utils/upload'
import { AVATAR, resolveAsset } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'

const props = withDefaults(
  defineProps<{
    modelValue: string | null
    initials?: string
    userId: string
    size?: number
    background?: string
  }>(),
  { initials: '?', size: 72, background: 'var(--m-primary)' },
)

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const notify = useNotify()
const inputEl = ref<HTMLInputElement | null>(null)

// The stored value is the original upload — a multi-megapixel phone photo.
// This component was the one avatar in the app painting it raw, so the profile
// hero showed an uncropped picture squeezed into a circle while every other
// surface showed the square-cropped version. Display only; what is emitted and
// saved stays the original URL.
// While a new photo uploads, the picked file itself is shown.
const preview = ref('')
const displayUrl = computed(() => preview.value || resolveAsset(props.modelValue, AVATAR))

// Fall back to the initials when the photo won't load, the way every other
// avatar in the app already does. Without this the broken <img> rendered its
// alt text instead — which is what showed up as a literal "Avatar" on the
// profile for anyone whose picture is a Google-hosted URL (the browser
// blocks those with ERR_BLOCKED_BY_ORB).
const failed = ref(false)
watch(
  () => props.modelValue,
  () => {
    failed.value = false
  },
)

function pick() {
  if (!preview.value) inputEl.value?.click()
}

async function onSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return

  const local = URL.createObjectURL(file)
  preview.value = local
  failed.value = false
  try {
    const url = await uploadAvatar(file, props.userId)
    notify.success('Avatar updated.')
    // Swap only once the uploaded copy is loaded, so the circle never goes blank.
    await whenLoaded(resolveAsset(url, AVATAR))
    emit('update:modelValue', url)
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not upload avatar.')
  }
  preview.value = ''
  URL.revokeObjectURL(local)
  input.value = ''
}
</script>

<style scoped>
.avatar-upload {
  position: relative;
  flex: 0 0 var(--au-size);
  width: var(--au-size);
  height: var(--au-size);
  border-radius: 999px;
  border: 3px solid var(--m-surface);
  background: var(--au-bg);
  cursor: pointer;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}
.avatar-upload-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.avatar-upload-initials {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: calc(var(--au-size) * 0.39);
  font-weight: 700;
  color: #fff;
}
.avatar-upload-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.35);
  color: #fff;
  opacity: 0;
  transition: opacity 0.2s;
}
.avatar-upload:hover .avatar-upload-overlay,
.avatar-upload-overlay--busy {
  opacity: 1;
}
.avatar-upload-hidden {
  display: none;
}
</style>
