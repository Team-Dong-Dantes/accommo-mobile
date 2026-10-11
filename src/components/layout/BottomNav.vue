<template>
  <div class="bottom-nav">
    <!-- The bar's own surface, with a notch cut round the centre button and the
         hairline following it. Sides stretch; the notch is a fixed-width piece so
         it stays a true circle at any screen width. -->
    <div class="bottom-nav-bg" aria-hidden="true">
      <span class="bottom-nav-bg-side" />
      <span class="bottom-nav-bg-notch">
        <svg width="94" height="52" viewBox="0 0 94 52">
          <path class="bottom-nav-bg-fill" d="M0 0 C7 0 9.8 2.2 11.9 6 A36 36 0 0 0 82.1 6 C84.2 2.2 87 0 94 0 V52 H0 Z" />
          <path class="bottom-nav-bg-line" d="M0 0.5 C7 0.5 9.8 2.7 11.9 6.5 A36 36 0 0 0 82.1 6.5 C84.2 2.7 87 0.5 94 0.5" />
        </svg>
      </span>
      <span class="bottom-nav-bg-side" />
    </div>
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
  position: relative;
  display: flex;
  height: 100%;
  align-items: stretch;
}
/* Runs down over the footer's safe-area padding so the surface reaches the
   screen's edge. */
.bottom-nav-bg {
  position: absolute;
  top: 0;
  right: 0;
  bottom: calc(-1 * env(safe-area-inset-bottom, 0px));
  left: 0;
  display: flex;
  pointer-events: none;
}
.bottom-nav-bg-side {
  flex: 1 1 0;
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.bottom-nav-bg-notch {
  display: flex;
  flex: 0 0 94px;
  flex-direction: column;
}
.bottom-nav-bg-notch svg {
  display: block;
  flex: 0 0 auto;
}
/* Below the 52px drawing, on a phone with a home indicator. */
.bottom-nav-bg-notch::after {
  content: '';
  flex: 1;
  margin-top: -1px;
  background: var(--m-surface);
}
.bottom-nav-bg-fill {
  fill: var(--m-surface);
}
.bottom-nav-bg-line {
  fill: none;
  stroke: var(--m-border);
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
/* The centre tab: a flat disc docked in the bar's notch, centred 2px above the
   bar's top edge with 7px of air all round. Ink while you are elsewhere, teal on
   its own screen. The hairline ring inset 4px is the one detail; no gradient,
   gloss or coloured glow. The label keeps the baseline every other tab's label
   sits on, just under the notch. */
.bottom-nav-item--featured {
  justify-content: flex-end;
  padding-bottom: 5px;
}
.bottom-nav-item--featured:active {
  transform: none;
}
.bottom-nav-fab {
  --fab-bg: #17202a;
  --fab-ring: rgba(255, 255, 255, 0.16);
  position: absolute;
  top: -31px;
  left: 50%;
  display: grid;
  width: 58px;
  height: 58px;
  place-items: center;
  margin-left: -29px;
  border-radius: 50%;
  background: var(--fab-bg);
  color: #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.12), 0 6px 14px rgba(15, 23, 42, 0.1);
  transition: transform 0.16s cubic-bezier(0.34, 1.56, 0.64, 1), background-color 0.16s ease;
}
.bottom-nav-fab::after {
  content: '';
  position: absolute;
  inset: 4px;
  border: 1px solid var(--fab-ring);
  border-radius: 50%;
}
/* Ink is the light theme's text colour; on a dark bar it is lifted one step so
   it still reads as a button rather than a hole. */
:global(:root.dark) .bottom-nav-fab {
  --fab-bg: #353c48;
}
.bottom-nav-item--featured.active .bottom-nav-fab {
  --fab-bg: var(--m-primary-dark);
  --fab-ring: rgba(255, 255, 255, 0.26);
}
.bottom-nav-item--featured:active .bottom-nav-fab {
  transform: scale(0.94);
}
.bottom-nav-item--featured.active {
  color: var(--m-primary-dark);
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