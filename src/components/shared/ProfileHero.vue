<template>
  <div class="p-hero">
    <button v-if="actionIcon" type="button" class="p-hero-action" :style="{ color: accent }" :aria-label="actionLabel" :title="actionLabel" @click="emit('action')">
      <IconifyIcon :icon="actionIcon" width="18" />
    </button>

    <div class="p-hero-cover">
      <img v-if="coverSrc && !coverFailed" :src="coverSrc" alt="" class="p-hero-cover-img" @error="coverFailed = true" />
      <button type="button" class="p-hero-cover-btn" aria-label="Change cover photo" title="Change cover photo" :disabled="coverBusy" @click="coverInput?.click()">
        <q-spinner v-if="coverBusy" size="16px" />
        <IconifyIcon v-else icon="lucide:camera" width="16" />
      </button>
      <input ref="coverInput" type="file" accept="image/jpeg,image/png,image/webp" hidden @change="onCover" />
    </div>

    <div class="p-hero-top">
      <span class="p-hero-avatar" :style="{ marginTop: `-${avatarSize / 2}px` }">
        <AvatarUpload v-model="avatarUrl" :initials="initials" :user-id="userId" :size="avatarSize" :background="avatarBackground" />
      </span>
      <div class="p-hero-meta">
        <div class="p-hero-row">
          <h1 class="p-hero-name">{{ name }}</h1>
          <span class="p-hero-tag" :class="`p-hero-tag--${statusTone}`">
            <IconifyIcon :icon="statusIcon" width="12" />
            {{ statusLabel }}
          </span>
        </div>
        <p class="p-hero-subtitle">{{ subtitle }}</p>
      </div>
    </div>

    <div class="p-hero-info">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import AvatarUpload from '@/components/shared/AvatarUpload.vue'
import { uploadCover } from '@/utils/upload'
import { COVER, resolveAsset } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'

const avatarUrl = defineModel<string | null>('avatarUrl', { default: null })
const coverUrl = defineModel<string | null>('coverUrl', { default: null })

const props = withDefaults(
  defineProps<{
    initials?: string
    userId: string
    avatarSize?: number
    avatarBackground?: string
    accent?: string
    name: string
    subtitle: string
    statusTone: string
    statusLabel: string
    /** The status's own icon; without one the tone picks a generic one. */
    statusIconName?: string
    /** Omit to show no corner action. */
    actionIcon?: string
    actionLabel?: string
  }>(),
  {
    actionIcon: '',
    actionLabel: '',
    statusIconName: '',
    initials: '?',
    avatarSize: 56,
    avatarBackground: 'var(--m-primary)',
    accent: 'var(--m-primary-dark)',
  },
)

const emit = defineEmits<{ action: [] }>()

const notify = useNotify()
const coverInput = ref<HTMLInputElement | null>(null)
const coverBusy = ref(false)
// Stored value is the original upload; display a hero-sized copy.
const coverSrc = computed(() => resolveAsset(coverUrl.value, COVER))
const coverFailed = ref(false)
watch(coverUrl, () => {
  coverFailed.value = false
})

async function onCover(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  coverBusy.value = true
  try {
    coverUrl.value = await uploadCover(file, props.userId)
    notify.success('Cover photo updated.')
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not upload cover photo.')
  } finally {
    coverBusy.value = false
    input.value = ''
  }
}

const statusIcon = computed(() => {
  if (props.statusIconName) return props.statusIconName
  if (props.statusTone === 'good') return 'lucide:check-circle'
  if (props.statusTone === 'warn') return 'lucide:clock'
  return 'lucide:alert-circle'
})
</script>

<style scoped>
.p-hero {
  position: relative;
  background: var(--m-surface);
  border-radius: var(--m-radius);
  border: 1px solid var(--m-border);
  overflow: hidden;
}
.p-hero-action {
  position: absolute;
  z-index: 1;
  top: 8px;
  right: 8px;
  display: flex;
  width: 44px;
  height: 44px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  cursor: pointer;
}
.p-hero-action:hover {
  background: var(--m-primary-soft);
}
/* Same empty-state gradient as PersonProfile's hero, so a profile without a
   cover looks the same from both sides. */
.p-hero-cover {
  position: relative;
  height: 110px;
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.p-hero-cover-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.p-hero-cover-btn {
  position: absolute;
  right: 8px;
  bottom: 8px;
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.55);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
/* The avatar rides half over the cover's bottom edge (margin set inline from
   avatarSize); the name stays below the edge, on the card. */
.p-hero-top {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 0 14px 14px;
}
.p-hero-avatar {
  position: relative;
  display: flex;
  flex: none;
}
.p-hero-meta {
  flex: 1;
  min-width: 0;
  padding-top: 8px;
}
.p-hero-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}
.p-hero-name {
  margin: 0;
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  color: var(--m-ink);
  line-height: 1.2;
}
.p-hero-subtitle {
  margin: 2px 0 0;
  font-size: 13px;
  color: var(--m-muted);
}
.p-hero-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 10px;
  border-radius: 999px;
  white-space: nowrap;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.p-hero-tag--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.p-hero-tag--idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.p-hero-tag--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.p-hero-tag--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.p-hero-info {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  padding: 12px 14px;
  border-top: 1px solid var(--m-border);
}
</style>
