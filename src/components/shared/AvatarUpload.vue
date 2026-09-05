<template>
  <div class="avatar-upload" :style="{ '--au-size': `${size}px`, '--au-bg': background }" @click="pick">
    <img v-if="modelValue" :src="modelValue" alt="Avatar" class="avatar-upload-img" />
    <span v-else class="avatar-upload-initials">{{ initials || '?' }}</span>
    <span class="avatar-upload-overlay">
      <IconifyIcon icon="lucide:camera" :width="Math.round(size * 0.22)" />
    </span>
  </div>
  <input ref="inputEl" type="file" accept="image/*" class="avatar-upload-hidden" @change="onSelected" />
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { uploadAvatar } from '@/utils/upload'
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

function pick() {
  inputEl.value?.click()
}

async function onSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return

  try {
    const url = await uploadAvatar(file, props.userId)
    emit('update:modelValue', url)
    notify.success('Avatar updated.')
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not upload avatar.')
  }
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
.avatar-upload:hover .avatar-upload-overlay {
  opacity: 1;
}
.avatar-upload-hidden {
  display: none;
}
</style>
