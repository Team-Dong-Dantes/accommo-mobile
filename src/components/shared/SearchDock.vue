<template>
  <div class="dock" :class="{ 'dock--above-nav': aboveNav }">
    <button
      type="button"
      class="dock-btn"
      :class="{ 'dock-btn--on': filterCount > 0 }"
      aria-label="Filters"
      @click="emit('open-filters')"
    >
      <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
      <span v-if="filterCount > 0" class="dock-dot">{{ filterCount }}</span>
    </button>
    <div class="dock-field">
      <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
      <input
        :value="modelValue"
        class="dock-input"
        type="search"
        :placeholder="placeholder"
        :aria-label="searchLabel || placeholder"
        @input="emit('update:modelValue', ($event.target as HTMLInputElement).value)"
      />
    </div>
    <!-- Trailing action, e.g. the "report a concern" plus button. Give it
         class="dock-btn" and it picks up the dock styling. -->
    <slot name="action" />
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

// The floating search-and-filter dock used by the eight list screens. All eight
// had byte-identical markup and CSS; the only thing that ever differed was the
// placeholder and how each screen counted its active filters.
//
// `aboveNav` is the one real distinction, and it is not cosmetic: a screen that
// is a bottom-nav tab has the footer underneath it and must clear it, while a
// secondary page (MainLayout hides the footer via `v-if="!isSubPage"`) sits on
// the safe-area inset instead. Each page used to hard-code one of the two
// offsets, so a screen that changed category silently got the wrong one.
defineProps<{
  modelValue: string
  /** Number shown in the badge; 0 hides it and leaves the button inactive. */
  filterCount: number
  placeholder: string
  /** Screen-reader label for the input. Falls back to the placeholder. */
  searchLabel?: string
  /** True on bottom-nav tab screens, which must clear the footer. */
  aboveNav?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  'open-filters': []
}>()
</script>

<style scoped>
.dock {
  position: fixed;
  bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  left: var(--m-page-gutter);
  right: var(--m-page-gutter);
  z-index: 60;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dock--above-nav {
  bottom: 68px;
}

/* Frosted glass, matching the pull-to-refresh puller and the map buttons —
   62% surface over a blur, hairline border at 55%. See app.scss. */
.dock-field {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 8px;
  height: 44px;
  padding: 0 14px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
}
.dock-field:focus-within {
  border-color: var(--m-primary);
}
.dock-icon {
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input::placeholder {
  color: var(--m-muted);
  opacity: 0.85;
}
.dock-input:focus {
  outline: none;
}

/* `:slotted` so the optional trailing action button gets the same treatment —
   slot content compiles in the parent's scope and this component's scoped CSS
   would otherwise never reach it. */
.dock-btn,
:slotted(.dock-btn) {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 50%;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.dock-btn:disabled,
:slotted(.dock-btn:disabled) {
  opacity: 0.5;
}
.dock-btn--on {
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.dock-dot {
  position: absolute;
  top: -2px;
  right: -2px;
  display: grid;
  min-width: 17px;
  height: 17px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}
</style>
