<template>
  <div class="bottom-nav">
    <button
      v-for="tab in tabs"
      :key="tab.name"
      type="button"
      class="bottom-nav-item"
      :class="{ active: active === tab.name }"
      :aria-label="tab.label"
      @click="onSelect(tab.name)"
    >
      <q-avatar v-if="tab.avatar" size="26px" class="profile-avatar-mini" text-color="white">
        <q-img v-if="avatarUrl" :src="avatarUrl" alt="Profile" />
        <span v-else>{{ initials }}</span>
      </q-avatar>
      <span v-else class="bottom-nav-icon">
        <IconifyIcon :icon="tab.icon" width="22" />
        <span v-if="tab.badge" class="bottom-nav-badge">{{ tab.badge > 9 ? '9+' : tab.badge }}</span>
      </span>
      <span class="bottom-nav-label">{{ tab.label }}</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import type { BottomTab } from '@/types/app-types'
import { hapticLight } from '@/utils/haptics'

defineProps<{
  tabs: readonly BottomTab[]
  active: string
  avatarUrl: string | null
  initials: string
}>()

const emit = defineEmits<{ select: [name: string] }>()

function onSelect(name: string) {
  hapticLight()
  emit('select', name)
}
</script>

<style scoped>
.bottom-nav {
  display: flex;
  height: 100%;
  align-items: stretch;
}
.bottom-nav-item {
  position: relative;
  display: flex;
  min-width: 0;
  flex: 1 1 0;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  padding: 4px 0;
  border: 0;
  background: transparent;
  appearance: none;
  -webkit-appearance: none;
  outline: none;
  color: var(--m-muted);
  cursor: pointer;
  font-family: inherit;
  -webkit-tap-highlight-color: transparent;
  user-select: none;
  transition: color 0.12s ease, transform 0.12s ease;
}
.bottom-nav-item:active {
  transform: scale(0.9);
}
.bottom-nav-item.active {
  color: var(--m-primary);
}
.bottom-nav-icon {
  position: relative;
  display: inline-flex;
}
.bottom-nav-badge {
  position: absolute;
  top: -5px;
  right: -8px;
  display: grid;
  min-width: 15px;
  height: 15px;
  place-items: center;
  padding: 0 3px;
  border-radius: 999px;
  background: var(--m-danger, #b42318);
  color: #fff;
  font-size: 9px;
  font-weight: 800;
}
.profile-avatar-mini {
  width: 24px;
  height: 24px;
  background: var(--m-primary);
  font-size: 10.5px;
  font-weight: 800;
}
.bottom-nav-label {
  font-size: 10px;
  font-weight: 500;
  letter-spacing: 0.02em;
  line-height: 1.2;
  color: inherit;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}
</style>