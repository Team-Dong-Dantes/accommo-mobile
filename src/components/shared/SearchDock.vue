<template>
  <div
    class="dock"
    :class="{ 'dock--above-nav': aboveNav, 'dock--inline': inline, 'dock--searching': expanded, 'dock--no-filters': noFilters }"
  >
    <!-- Leading action, e.g. "Report a concern". Give it class="dock-btn" and
         wrap its text in .dock-btn-label; the label folds away while the
         search field is open so the field gets the room. -->
    <slot name="action" />
    <!-- Search and filter joined in one pill at the right edge, search first.
         Only the icons show until search is tapped; then the pill grows
         leftward to full width and the field opens between the two. -->
    <div class="dock-pill" :class="{ 'dock-pill--open': expanded }">
      <!-- mousedown.prevent keeps focus in the field, so tapping the icon
           while open doesn't blur-collapse and re-expand it. -->
      <button
        type="button"
        class="dock-seg"
        aria-label="Search"
        :aria-expanded="expanded"
        @mousedown.prevent
        @click="expand"
      >
        <IconifyIcon icon="lucide:search" width="20" />
      </button>
      <input
        ref="field"
        :value="modelValue"
        class="dock-input"
        type="search"
        :tabindex="expanded ? 0 : -1"
        :placeholder="placeholder"
        :aria-label="searchLabel || placeholder"
        @input="emit('update:modelValue', ($event.target as HTMLInputElement).value)"
        @blur="open = !!modelValue"
      />
      <span v-if="!noFilters" class="dock-sep" aria-hidden="true" />
      <button
        v-if="!noFilters"
        type="button"
        class="dock-seg"
        :class="{ 'dock-seg--on': filterCount > 0 }"
        aria-label="Filters"
        @click="emit('open-filters')"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="20" />
        <span v-if="filterCount > 0" class="dock-dot">{{ filterCount }}</span>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { isTablet } from '@/utils/useTabletMode'

// The floating search-and-filter dock used by the eight list screens. All eight
// had byte-identical markup and CSS; the only thing that ever differed was the
// placeholder and how each screen counted its active filters.
//
// `aboveNav` is the one real distinction, and it is not cosmetic: a screen that
// is a bottom-nav tab has the footer underneath it and must clear it, while a
// secondary page (MainLayout hides the footer via `v-if="!isSubPage"`) sits on
// the safe-area inset instead. Each page used to hard-code one of the two
// offsets, so a screen that changed category silently got the wrong one.
const props = defineProps<{
  modelValue: string
  /** Number shown in the badge; 0 hides it and leaves the button inactive. */
  filterCount: number
  placeholder: string
  /** Screen-reader label for the input. Falls back to the placeholder. */
  searchLabel?: string
  /** True on bottom-nav tab screens, which must clear the footer. */
  aboveNav?: boolean
  /** In the page's flow instead of floating at the bottom — for desktop, where
   *  a pointer reaches the top of a column as easily as a thumb the bottom. */
  inline?: boolean
  /** Search only: hides the filter button for tabs with nothing to filter. */
  noFilters?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  'open-filters': []
}>()

// Starts open when there's already a query (e.g. coming back to the page), and
// only folds back up on blur once the field is empty.
const open = ref(!!props.modelValue)
// Tablet mode has the width to spare, so the field is always out there.
const expanded = computed(() => open.value || isTablet.value)
const field = ref<HTMLInputElement>()
function expand() {
  open.value = true
  void nextTick(() => field.value?.focus())
}
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
/* The footer is 52px plus the gesture-bar inset (MainLayout), so the dock has
   to add the inset too. A bare 68px left the 16px gap only on phones with no
   inset; on gesture-navigation phones the inset ate it and the dock sat on
   the nav bar. 86 = 52 bar + 18 for the raised centre button that sticks out
   of it (BottomNav's .bottom-nav-fab) + the 16px gap. */
.dock--above-nav {
  bottom: calc(86px + env(safe-area-inset-bottom, 0px));
}
.dock--inline {
  position: static;
}

/* Frosted glass, matching the pull-to-refresh puller and the map buttons —
   62% surface over a blur, hairline border at 55%. See app.scss. */
.dock-pill {
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
}
.dock-pill {
  box-sizing: border-box;
  display: flex;
  align-items: center;
  width: 107px; /* two 52px segments + divider + border */
  height: 52px;
  min-width: 107px;
  flex: 0 1 auto; /* open, it fills what the leading action leaves */
  margin-left: auto; /* sits at the right edge; grows leftward when opened */
  border-radius: 999px;
  transition:
    width 0.32s cubic-bezier(0.2, 0.8, 0.2, 1),
    border-color 0.2s;
}
.dock-pill--open {
  width: 100%;
}
.dock--no-filters .dock-pill:not(.dock-pill--open) {
  width: 54px; /* one 52px segment + border */
  min-width: 54px;
}
.dock-pill:focus-within {
  border-color: var(--m-primary);
}
.dock-input {
  width: 0;
  min-width: 0;
  height: 100%;
  flex: 1 1 0;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  opacity: 0;
  transition: opacity 0.2s;
}
.dock-pill--open .dock-input {
  opacity: 1;
  transition-delay: 0.12s;
}
.dock-input::placeholder {
  color: var(--m-muted);
  opacity: 0.85;
}
.dock-input:focus {
  outline: none;
}
.dock-seg {
  position: relative;
  display: grid;
  width: 52px;
  height: 50px;
  flex: 0 0 52px;
  place-items: center;
  padding: 0;
  border: none;
  border-radius: 999px;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.dock-seg--on {
  color: var(--m-primary-dark);
}
.dock-sep {
  width: 1px;
  height: 20px;
  flex: 0 0 1px;
  background: var(--m-border);
}
@media (prefers-reduced-motion: reduce) {
  .dock-pill,
  .dock-input,
  :slotted(.dock-btn-label) {
    transition: none;
  }
}

/* `:slotted` so the optional leading action gets the treatment — slot content
   compiles in the parent's scope and this component's scoped CSS would
   otherwise never reach it. Same look as the announcements page's .fab, at the
   pill's height. */
:slotted(.dock-btn) {
  display: inline-flex;
  height: 52px;
  flex: 0 0 auto;
  align-items: center;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  box-shadow: var(--m-shadow);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
:slotted(.dock-btn:disabled) {
  opacity: 0.5;
}
:slotted(.dock-btn-label) {
  max-width: 180px;
  overflow: hidden;
  margin-left: 7px;
  white-space: nowrap;
  transition:
    max-width 0.32s cubic-bezier(0.2, 0.8, 0.2, 1),
    margin-left 0.32s,
    opacity 0.2s;
}
.dock--searching :slotted(.dock-btn-label) {
  max-width: 0;
  margin-left: 0;
  opacity: 0;
}
.dock-dot {
  position: absolute;
  top: 4px;
  right: 4px;
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
