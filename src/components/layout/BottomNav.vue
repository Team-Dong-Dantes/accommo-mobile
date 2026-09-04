<template>
  <div class="bottom-nav">
    <button
      v-for="tab in tabs"
      :key="tab.name"
      type="button"
      class="bottom-nav-item"
      :class="{ active: active === tab.name }"
      :aria-label="tab.label"
      @click="emit('select', tab.name)"
    >
      <q-avatar v-if="tab.avatar" size="26px" class="profile-avatar-mini" text-color="white">
        <q-img v-if="avatarUrl" :src="avatarUrl" alt="Profile" />
        <span v-else>{{ initials }}</span>
      </q-avatar>
      <IconifyIcon v-else :icon="tab.icon" width="22" />
    </button>
  </div>
</template>

<script setup lang="ts">
import type { BottomTab } from '@/types/app-types'

defineProps<{
  tabs: readonly BottomTab[]
  active: string
  avatarUrl: string | null
  initials: string
}>()

const emit = defineEmits<{ select: [name: string] }>()
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
  padding: 0;
  border: 0;
  background: transparent;
  appearance: none;
  -webkit-appearance: none;
  outline: none;
  color: #9ca3af;
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
  color: #00897b;
}
.profile-avatar-mini {
  width: 24px;
  height: 24px;
  background: #00897b;
  font-size: 10.5px;
  font-weight: 800;
}
</style>
