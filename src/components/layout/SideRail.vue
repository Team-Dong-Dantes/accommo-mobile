<template>
  <nav class="side-rail" aria-label="Main">
    <div class="side-rail-mark" role="img" aria-label="Accommo"></div>

    <button
      v-for="tab in tabs"
      :key="tab.name"
      type="button"
      class="side-rail-item"
      :class="{ active: active === tab.name }"
      :aria-label="tab.label"
      :aria-current="active === tab.name ? 'page' : undefined"
      @click="onSelect(tab.name)"
    >
      <q-avatar v-if="tab.avatar" size="26px" class="profile-avatar-mini" text-color="white">
        <q-img v-if="avatarUrl" :src="avatarUrl" alt="Profile" />
        <span v-else>{{ initials }}</span>
        <span v-if="tab.dot" class="side-rail-dot side-rail-dot--avatar" />
      </q-avatar>
      <span
        v-else
        class="side-rail-icon"
        :class="{ 'side-rail-icon--spin': tab.name === 'menu' && menuOpen }"
      >
        <IconifyIcon :icon="tab.name === 'menu' && menuOpen ? 'lucide:x' : tab.icon" width="22" />
        <span v-if="tab.badge" class="side-rail-badge">{{ tab.badge > 9 ? '9+' : tab.badge }}</span>
        <span v-else-if="tab.dot" class="side-rail-dot" />
      </span>
      <span class="side-rail-label">{{ tab.label }}</span>
    </button>
  </nav>
</template>

<script setup lang="ts">
import type { BottomTab } from '@/types/app-types'
import { hapticLight } from '@/utils/haptics'

// The bottom nav, stood on its end for tablet landscape. Same props, same single
// `select` event, so MainLayout feeds it the identical displayTabs /
// activeBottomTab / goToTab it already feeds BottomNav — the shell does not know
// which one is on screen.
//
// A separate component rather than a mode flag on BottomNav: the two share their
// data but almost none of their layout (a row of equal flex children that fills
// its footer, against a fixed-width column that fills its screen edge), and the
// badge and avatar markup is the only real overlap. One component doing both
// would be two templates behind a v-if with a props contract stretched across
// them.
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
/* Fixed rather than a flex sibling so it survives the page stage scrolling, and
   so its width can be read off one place — the stage's left padding matches it. */
.side-rail {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 0;
  z-index: 60;
  display: flex;
  width: 88px;
  flex-direction: column;
  align-items: stretch;
  justify-content: center;
  gap: 4px;
  padding: 10px 8px calc(10px + env(safe-area-inset-bottom, 0px));
  border-right: 1px solid var(--m-border);
  background: var(--m-surface);
}

/* The brand mark — public/accommo-logo.svg, the same file accommo-web uses for
   its own sidebar. Painted as a CSS mask rather than dropped in an <img>
   because the artwork is a solid white glyph: an <img> would be invisible on
   this surface. Masking lets it take a theme token instead, which is the trick
   accommo-web already uses for the logo in its landing-page footer, and it
   means the mark follows dark mode for free.

   The header's wordmark is hidden in tablet mode (app.scss) so the brand is not
   stated twice, a hand's width apart. */
.side-rail-mark {
  position: absolute;
  top: 14px;
  left: 50%;
  width: 36px;
  height: 36px;
  /* Out of the flow, and translated rather than margined, so the tabs below are
     centred on the rail itself. Left in the flow it took 56px off the top and the
     tab group centred in what was left — near the middle, but visibly low.

     No padding and no border either: a mask clips the element’s whole box, so
     both would eat into the glyph instead of sitting around it. */
  transform: translateX(-50%);
  background-color: var(--m-primary);
  -webkit-mask: url(/accommo-logo.svg) no-repeat center / contain;
  mask: url(/accommo-logo.svg) no-repeat center / contain;
}

.side-rail-item {
  position: relative;
  display: flex;
  min-height: 60px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 8px 2px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  appearance: none;
  -webkit-appearance: none;
  outline: none;
  color: var(--m-muted);
  cursor: pointer;
  font-family: inherit;
  -webkit-tap-highlight-color: transparent;
  user-select: none;
  transition: color 0.12s ease, background-color 0.12s ease;
}
.side-rail-item:active {
  transform: scale(0.96);
}

/* A tinted pill, not just a colour change. On a rail the active item has to hold
   its own against the list beside it, where in a four-item footer the colour was
   enough. */
.side-rail-item.active {
  background: var(--m-primary-soft);
  color: var(--m-primary);
}

.side-rail-icon {
  position: relative;
  display: inline-flex;
  transition: transform 200ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
.side-rail-icon--spin {
  transform: rotate(90deg);
}
@media (prefers-reduced-motion: reduce) {
  .side-rail-icon {
    transition: none;
  }
}

.side-rail-badge {
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
.side-rail-dot {
  position: absolute;
  top: -2px;
  right: -4px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--m-danger, #b42318);
  border: 1.5px solid var(--m-surface);
}
.side-rail-dot--avatar {
  top: -1px;
  right: -1px;
}
.side-rail-label {
  max-width: 100%;
  overflow: hidden;
  color: inherit;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.01em;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.profile-avatar-mini {
  position: relative;
  width: 24px;
  height: 24px;
  background: var(--m-primary);
  font-size: 10.5px;
  font-weight: 800;
}
</style>
