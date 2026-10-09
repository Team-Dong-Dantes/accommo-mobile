<template>
  <!-- Desktop profile's left-half menu: jumps the details half to a block, and
       follows along as that half is scrolled by hand. -->
  <nav class="p-nav" aria-label="Profile sections">
    <button
      v-for="s in sections"
      :key="s.id"
      type="button"
      class="p-nav-item"
      :class="{ 'p-nav-item--on': s.id === active }"
      :aria-current="s.id === active ? 'true' : undefined"
      @click="jump(s.id)"
    >
      <IconifyIcon :icon="s.icon" width="16" />
      <span class="p-nav-label">{{ s.label }}</span>
      <span v-if="s.badge" class="p-nav-badge">{{ s.badge }}</span>
    </button>
  </nav>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

/** `id` is the DOM id of the section's block, in the half that scrolls. */
const props = defineProps<{ sections: { id: string; label: string; icon: string; badge?: string }[] }>()

const active = ref(props.sections[0]?.id ?? '')
let scroller: HTMLElement | null = null
// Held from a click until its smooth scroll ends, so a last block too short to
// reach the top is not handed back to the one above it on the way down. Any
// hand scroll releases it too, since a jump that moved nothing never ends.
let jumping = false

function jump(id: string) {
  active.value = id
  jumping = true
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function spy() {
  if (jumping || !scroller) return
  const top = scroller.getBoundingClientRect().top
  let on = props.sections[0]?.id ?? ''
  for (const s of props.sections) {
    const el = document.getElementById(s.id)
    if (el && el.getBoundingClientRect().top - top <= 32) on = s.id
  }
  // Scrolled to the end: the last blocks may be too short to ever reach the
  // top, and the end is where they are.
  if (scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 2) on = props.sections.at(-1)?.id ?? on
  active.value = on
}

function settle() {
  jumping = false
}

onMounted(() => {
  // The details half (.desk-col) is what scrolls, not the page.
  scroller = document.getElementById(props.sections[0]?.id ?? '')?.closest<HTMLElement>('.desk-col') ?? null
  scroller?.addEventListener('scroll', spy, { passive: true })
  scroller?.addEventListener('scrollend', settle)
  scroller?.addEventListener('wheel', settle, { passive: true })
  scroller?.addEventListener('touchstart', settle, { passive: true })
})
onBeforeUnmount(() => {
  scroller?.removeEventListener('scroll', spy)
  scroller?.removeEventListener('scrollend', settle)
  scroller?.removeEventListener('wheel', settle)
  scroller?.removeEventListener('touchstart', settle)
})
</script>

<style scoped>
.p-nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}
.p-nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 40px;
  padding: 0 12px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  color: var(--m-muted);
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
  transition: background 0.12s, color 0.12s;
}
.p-nav-item:hover {
  background: var(--m-bg);
  color: var(--m-ink);
}
.p-nav-item--on {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.p-nav-label {
  flex: 1;
}
.p-nav-badge {
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10px;
  font-weight: 700;
}
</style>
