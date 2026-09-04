<template>
  <div v-if="open" class="quick-action-layer">
    <div class="quick-action-backdrop" @click="emit('update:open', false)" />
    <div :id="menuId" class="quick-action-menu" role="menu" aria-label="Quick actions">
      <button
        v-for="action in actions"
        :key="action.route"
        type="button"
        role="menuitem"
        @click="emit('navigate', action.route)"
      >
        <span class="quick-action-icon"><IconifyIcon :icon="action.icon" width="18" /></span>
        <span>{{ action.label }}</span>
      </button>
    </div>
  </div>
  <button
    type="button"
    class="bottom-fab"
    :class="{ 'bottom-fab--open': open }"
    :aria-expanded="open"
    :aria-controls="menuId"
    aria-label="Open quick actions"
    @click="emit('update:open', !open)"
  >
    <IconifyIcon icon="lucide:plus" width="20" />
  </button>
</template>

<script setup lang="ts">
import type { QuickAction } from '@/types/app-types'

defineProps<{
  actions: readonly QuickAction[]
  open: boolean
  menuId: string
}>()

const emit = defineEmits<{ 'update:open': [value: boolean]; navigate: [route: string] }>()
</script>

<style scoped>
.bottom-fab {
  position: fixed;
  right: 16px;
  bottom: 68px;
  z-index: 60;
  display: grid;
  width: 44px;
  height: 44px;
  padding: 0;
  place-items: center;
  border: 1px solid var(--m-primary-dark);
  border-radius: 50%;
  background: var(--m-primary-dark);
  box-shadow: 0 4px 12px rgba(0, 105, 92, 0.22);
  color: #fff;
  cursor: pointer;
  transition: background-color 180ms ease-out, box-shadow 180ms ease-out;
}
.bottom-fab svg { transition: transform 260ms cubic-bezier(0.34, 1.56, 0.64, 1); }
.bottom-fab--open { border-color: var(--m-danger); background: var(--m-danger); box-shadow: 0 4px 12px rgba(180, 35, 24, 0.24); }
.bottom-fab--open svg { transform: rotate(45deg); }
.bottom-fab:focus-visible,
.quick-action-menu button:focus-visible { outline: 2px solid var(--m-primary); outline-offset: 3px; }
.quick-action-layer { position: fixed; z-index: 55; top: 0; right: 0; bottom: calc(64px + env(safe-area-inset-bottom, 0px)); left: 0; }
.quick-action-backdrop { position: absolute; inset: 0; background: rgba(23, 32, 42, 0.28); backdrop-filter: blur(5px); -webkit-backdrop-filter: blur(5px); }
.quick-action-menu { position: absolute; right: 12px; bottom: 72px; display: flex; flex-direction: column; align-items: flex-end; gap: var(--m-space-2); animation: quick-actions-in 200ms ease-out both; }
.quick-action-menu button { display: flex; min-height: 44px; align-items: center; gap: var(--m-space-2); padding: var(--m-space-1) var(--m-space-2) var(--m-space-1) var(--m-space-1); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08); color: var(--m-ink); cursor: pointer; font: inherit; font-size: 13px; font-weight: 700; text-align: left; }
.quick-action-menu button:hover { background: var(--m-primary-soft); }
.quick-action-icon { display: grid; width: 36px; height: 36px; place-items: center; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); color: var(--m-primary-dark); }
@keyframes quick-actions-in { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
@media (prefers-reduced-motion: reduce) {
  .bottom-fab, .bottom-fab svg { transition: none; }
  .quick-action-menu { animation: none; }
}
</style>
