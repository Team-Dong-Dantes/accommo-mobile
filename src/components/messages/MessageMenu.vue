<template>
  <!-- Anchored to the long-pressed element: reactions above it, actions below.
       Lives inside whatever fixed layer opened it (the chat, the page), so the
       caller can lift the anchor above the dim backdrop. -->
  <div class="mm-backdrop" :class="{ 'mm-backdrop--dim': dim }" @click="emit('close')" @contextmenu.prevent="emit('close')" />
  <div v-if="react" class="mm-react" :style="pos.react" role="menu" aria-label="React">
    <button
      v-for="e in REACTIONS"
      :key="e"
      type="button"
      role="menuitem"
      class="mm-emoji"
      :class="{ 'mm-emoji--on': e === mine }"
      :aria-label="`React ${e}`"
      @click="emit('react', e === mine ? '' : e)"
    >
      {{ e }}
    </button>
  </div>
  <div class="mm-list" :style="pos.list" role="menu" aria-label="Message actions">
    <button
      v-for="a in actions"
      :key="a.key"
      type="button"
      role="menuitem"
      :class="{ 'mm-item--danger': a.danger }"
      @click="emit('pick', a.key)"
    >
      <IconifyIcon :icon="a.icon" width="16" />
      {{ a.label }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { REACTIONS } from '@/utils/chat'

export interface MenuAction {
  key: string
  label: string
  icon: string
  danger?: boolean
}

const props = withDefaults(
  defineProps<{
    anchor: DOMRect
    actions: MenuAction[]
    /** Which side of the screen the anchor hugs; the menu lines up with it. */
    align?: 'start' | 'end'
    /** Show the reaction bar. */
    react?: boolean
    /** My current reaction, highlighted; tapping it again removes it. */
    mine?: string | undefined
    dim?: boolean
  }>(),
  { align: 'start', react: false, mine: undefined, dim: false },
)

const emit = defineEmits<{ close: []; pick: [key: string]; react: [emoji: string] }>()

// Sizes the CSS below draws; the menu is placed before it renders.
const BAR_H = 48
const ROW_H = 40
const GAP = 8
const TOP = 48 // clears the status bar
const EDGE = 12

const pos = computed(() => {
  const r = props.anchor
  const vh = window.innerHeight
  const vw = window.innerWidth
  const listH = props.actions.length * ROW_H + 12
  // A tall photo or the last message leaves no room below: the list pins to the
  // bottom edge over the anchor instead of running off-screen.
  const listTop = Math.min(r.bottom + GAP, vh - EDGE - listH)
  const reactTop = Math.max(r.top - GAP - BAR_H, TOP)
  const side = props.align === 'end'
    ? { right: `${Math.max(vw - r.right, EDGE)}px` }
    : { left: `${Math.max(r.left, EDGE)}px` }
  return {
    react: { top: `${reactTop}px`, ...side },
    list: { top: `${Math.max(listTop, TOP)}px`, ...side },
  }
})

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') emit('close')
}
onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))
</script>

<style scoped>
.mm-backdrop {
  position: fixed;
  inset: 0;
  z-index: 20;
}
.mm-backdrop--dim {
  background: rgba(15, 23, 42, 0.35);
  animation: mm-fade 140ms ease-out both;
}
.mm-react,
.mm-list {
  position: fixed;
  z-index: 22;
  border: 1px solid var(--m-border);
  background: var(--m-surface);
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.16);
  animation: mm-in 160ms ease-out both;
}
.mm-react {
  display: flex;
  height: 48px;
  align-items: center;
  gap: 2px;
  padding: 0 6px;
  border-radius: 999px;
}
.mm-emoji {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  font-size: 22px;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.mm-emoji--on {
  background: var(--m-primary-soft);
}
.mm-list {
  display: flex;
  min-width: 168px;
  flex-direction: column;
  padding: 6px;
  border-radius: var(--m-radius-sm);
}
.mm-list button {
  display: flex;
  height: 40px;
  align-items: center;
  gap: 10px;
  padding: 0 10px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  text-align: left;
}
.mm-list button:hover {
  background: var(--m-primary-soft);
}
.mm-list .mm-item--danger {
  color: var(--m-danger);
}
@keyframes mm-in {
  from {
    opacity: 0;
    transform: scale(0.94);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}
@keyframes mm-fade {
  from {
    opacity: 0;
  }
}
</style>
