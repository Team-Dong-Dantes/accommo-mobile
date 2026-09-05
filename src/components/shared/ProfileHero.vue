<template>
  <div class="p-hero">
    <button type="button" class="p-hero-action" :style="{ color: accent }" :aria-label="actionLabel" :title="actionLabel" @click="emit('action')">
      <IconifyIcon :icon="actionIcon" width="18" />
    </button>

    <div class="p-hero-top">
      <AvatarUpload v-model="avatarUrl" :initials="initials" :user-id="userId" :size="avatarSize" :background="avatarBackground" />
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
import { computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import AvatarUpload from '@/components/shared/AvatarUpload.vue'

const avatarUrl = defineModel<string | null>('avatarUrl', { default: null })

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
    actionIcon: string
    actionLabel: string
  }>(),
  {
    initials: '?',
    avatarSize: 56,
    avatarBackground: 'var(--m-primary)',
    accent: 'var(--m-primary-dark)',
  },
)

const emit = defineEmits<{ action: [] }>()

const statusIcon = computed(() => {
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
.p-hero-top {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 58px 14px 14px;
}
.p-hero-meta {
  flex: 1;
  min-width: 0;
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
