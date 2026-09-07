<template>
  <div v-if="open" class="menu-layer">
    <div class="menu-backdrop" @click="close" />
    <q-card :id="menuId" class="menu-card" role="menu" aria-label="Menu">
      <button
        v-for="action in accountActions"
        :key="action.route + action.label"
        type="button"
        role="menuitem"
        class="menu-row"
        @click="navigate(action.route)"
      >
        <span class="menu-row-icon">
          <q-avatar v-if="action.avatar" size="30px" text-color="white" class="menu-row-avatar">
            <q-img v-if="avatarUrl" :src="avatarUrl" alt="" />
            <span v-else>{{ initials }}</span>
          </q-avatar>
          <IconifyIcon v-else :icon="action.icon" width="17" />
        </span>
        <span class="menu-row-label">{{ action.label }}</span>
      </button>

      <span class="menu-divider">Quick actions</span>

      <button
        v-for="action in actions"
        :key="action.route + action.label"
        type="button"
        role="menuitem"
        class="menu-row"
        @click="navigate(action.route)"
      >
        <span class="menu-row-icon menu-row-icon--accent">
          <IconifyIcon :icon="action.icon" width="17" />
          <span v-if="action.dot" class="menu-row-dot" />
        </span>
        <span class="menu-row-label">{{ action.label }}</span>
      </button>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import type { QuickAction } from '@/types/app-types'
import { hapticLight } from '@/utils/haptics'

defineProps<{
  accountActions: readonly QuickAction[]
  actions: readonly QuickAction[]
  open: boolean
  menuId: string
  avatarUrl: string | null
  initials: string
}>()

const emit = defineEmits<{ 'update:open': [value: boolean]; navigate: [route: string] }>()

function close() {
  hapticLight()
  emit('update:open', false)
}

function navigate(route: string) {
  hapticLight()
  emit('navigate', route)
}
</script>

<style scoped>
.menu-layer {
  position: fixed;
  z-index: 2001;
  top: 0;
  right: 0;
  bottom: calc(52px + env(safe-area-inset-bottom, 0px));
  left: 0;
}
.menu-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.32);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
}
.menu-card {
  position: absolute;
  right: 12px;
  bottom: 16px;
  display: flex;
  width: 236px;
  flex-direction: column;
  padding: 6px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-lg, var(--m-radius));
  background: var(--m-surface);
  box-shadow: 0 16px 36px rgba(15, 23, 42, 0.2);
  overflow: hidden;
  transform-origin: bottom right;
  animation: menu-in 200ms cubic-bezier(0.22, 0.61, 0.36, 1) both;
}
.menu-divider {
  margin: 6px 8px 2px;
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.menu-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  min-height: 44px;
  padding: 6px 8px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
  transition: background-color 120ms ease-out;
}
.menu-row:hover,
.menu-row:active {
  background: var(--m-bg);
}
.menu-row:focus-visible {
  outline: 2px solid var(--m-primary);
  outline-offset: -2px;
}
.menu-row-icon {
  position: relative;
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
}
.menu-row-icon--accent {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.menu-row-avatar {
  background: var(--m-primary);
  font-size: 10.5px;
  font-weight: 800;
}
.menu-row-dot {
  position: absolute;
  top: -1px;
  right: -1px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--m-danger, #b42318);
  border: 1.5px solid var(--m-surface);
}
.menu-row-label {
  flex: 1;
  min-width: 0;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
@keyframes menu-in {
  from {
    opacity: 0;
    transform: scale(0.92);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}
@media (prefers-reduced-motion: reduce) {
  .menu-card {
    animation: none;
  }
}
</style>
