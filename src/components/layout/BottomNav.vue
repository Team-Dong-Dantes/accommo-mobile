<template>
  <div class="bottom-nav">
    <button
      v-for="tab in tabs"
      :key="tab.name"
      type="button"
      class="bottom-nav-item"
      :class="{ active: active === tab.name, 'bottom-nav-item--featured': tab.featured }"
      :aria-label="tab.label"
      @click="onSelect(tab.name)"
    >
      <!-- Raised above the bar; the label stays in the bar with the others. -->
      <span v-if="tab.featured" class="bottom-nav-fab" aria-hidden="true">
        <IconifyIcon :icon="tab.icon" width="24" />
      </span>
      <q-avatar v-else-if="tab.avatar" size="26px" class="profile-avatar-mini" text-color="white">
        <q-img v-if="avatarUrl" :src="avatarUrl" alt="Profile" />
        <span v-else>{{ initials }}</span>
        <span v-if="tab.dot" class="bottom-nav-dot bottom-nav-dot--avatar" />
      </q-avatar>
      <span v-else class="bottom-nav-icon" :class="{ 'bottom-nav-icon--spin': tab.name === 'menu' && menuOpen }">
        <IconifyIcon :icon="tab.name === 'menu' && menuOpen ? 'lucide:x' : tab.icon" width="22" />
        <span v-if="tab.badge" class="bottom-nav-badge">{{ tab.badge > 9 ? '9+' : tab.badge }}</span>
        <span v-else-if="tab.dot" class="bottom-nav-dot" />
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
  menuOpen?: boolean
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
  transition: transform 200ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
.bottom-nav-icon--spin {
  transform: rotate(90deg);
}
@media (prefers-reduced-motion: reduce) {
  .bottom-nav-icon {
    transition: none;
  }
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
.bottom-nav-dot {
  position: absolute;
  top: -2px;
  right: -4px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--m-danger, #b42318);
  border: 1.5px solid var(--m-surface);
}
.profile-avatar-mini {
  position: relative;
  width: 24px;
  height: 24px;
  background: var(--m-primary);
  font-size: 10.5px;
  font-weight: 800;
}
.bottom-nav-dot--avatar {
  top: -1px;
  right: -1px;
}
/* The centre tab: a teal disc lifted 28px out of the bar. Its 4px ring is the
   bar's own surface colour, so the disc reads as sitting in a notch cut into
   the bar rather than pasted on top of it, in light and dark alike. The label
   keeps the baseline every other tab's label sits on. */
.bottom-nav-item--featured {
  justify-content: flex-end;
  padding-bottom: 5px;
}
.bottom-nav-item--featured:active {
  transform: none;
}
.bottom-nav-fab {
  position: absolute;
  top: -28px;
  left: 50%;
  display: grid;
  width: 56px;
  height: 56px;
  place-items: center;
  margin-left: -28px;
  border: 4px solid var(--m-surface);
  border-radius: 50%;
  background: linear-gradient(145deg, var(--m-primary), var(--m-primary-dark));
  color: #fff;
  box-shadow: 0 6px 14px rgba(0, 105, 92, 0.32);
  transition: transform 0.16s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.16s ease;
}
.bottom-nav-item--featured:active .bottom-nav-fab {
  transform: scale(0.92);
  box-shadow: 0 3px 8px rgba(0, 105, 92, 0.28);
}
.bottom-nav-item--featured.active .bottom-nav-label {
  font-weight: 700;
}
@media (prefers-reduced-motion: reduce) {
  .bottom-nav-fab {
    transition: none;
  }
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