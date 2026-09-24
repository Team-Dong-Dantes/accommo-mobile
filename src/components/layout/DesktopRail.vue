<template>
  <!-- The admin console's sidebar, for the web build on a computer: a 68px rail
       of icons that opens over the page on hover. Everything the hamburger menu
       holds on a phone is out on the rail here — a mouse has no reason to open a
       menu to reach OSAS or Settings. -->
  <nav
    class="desktop-rail"
    :class="{ 'is-open': open }"
    aria-label="Main"
    @pointerenter="onPointer($event, true)"
    @pointerleave="onPointer($event, false)"
  >
    <div class="rail-head">
      <span class="rail-mark" role="img" aria-label="Accommo"></span>
      <span class="rail-brand">accommo</span>
    </div>

    <template v-for="(group, g) in groups" :key="g">
      <div v-if="g === groups.length - 1" class="rail-spacer" />
      <div v-else-if="g > 0" class="rail-sep" />
      <button
        v-for="row in group"
        :key="row.key"
        type="button"
        class="rail-row"
        :class="{ active: row.active, danger: row.danger }"
        :aria-label="row.label"
        :aria-current="row.active ? 'page' : undefined"
        @click="row.go()"
      >
        <span class="rail-icon">
          <q-avatar v-if="row.avatar" size="24px" class="rail-avatar" text-color="white">
            <q-img v-if="avatarUrl" :src="avatarUrl" alt="" />
            <span v-else>{{ initials }}</span>
          </q-avatar>
          <IconifyIcon v-else :icon="row.icon" width="20" />
          <span v-if="row.badge" class="rail-badge">{{ row.badge > 9 ? '9+' : row.badge }}</span>
          <span v-else-if="row.dot" class="rail-dot" />
        </span>
        <span class="rail-label">{{ row.label }}</span>
      </button>
    </template>
  </nav>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import type { BottomTab, QuickAction } from '@/types/app-types'

const props = defineProps<{
  tabs: readonly BottomTab[]
  active: string
  actions: readonly QuickAction[]
  accountActions: readonly QuickAction[]
  path: string
  avatarUrl: string | null
  initials: string
}>()

const emit = defineEmits<{ select: [name: string]; navigate: [route: string] }>()

// Hover opens it, and only a mouse's hover: reading pointerType per event is
// what the admin sidebar settled on, so a tap never half-opens the rail.
const open = ref(false)
function onPointer(e: PointerEvent, entering: boolean) {
  if (e.pointerType === 'mouse') open.value = entering
}

interface Row {
  key: string
  icon: string
  label: string
  active: boolean
  go: () => void
  avatar?: boolean | undefined
  badge?: number | undefined
  dot?: boolean | undefined
  danger?: boolean | undefined
}

const on = (route: string) => props.path === route || props.path.startsWith(`${route}/`)

const groups = computed<Row[][]>(() => {
  const actionRows = (list: readonly QuickAction[]): Row[] =>
    list.map((a) => ({
      key: a.route,
      icon: a.icon,
      label: a.label,
      active: !a.danger && on(a.route),
      avatar: a.avatar,
      dot: a.dot,
      danger: a.danger,
      go: () => emit('navigate', a.route),
    }))
  const actions = actionRows(props.actions)
  const account = actionRows(props.accountActions)
  // activeBottomTab falls back to Home for any page that is not a tab, so a tab
  // only lights up when none of the rail's other rows owns the current page.
  const elsewhere = [...actions, ...account].some((r) => r.active)
  const tabs: Row[] = props.tabs
    .filter((t) => t.name !== 'menu')
    .map((t) => ({
      key: t.name,
      icon: t.icon,
      label: t.label,
      active: !elsewhere && props.active === t.name,
      badge: t.badge,
      dot: t.dot,
      go: () => emit('select', t.name),
    }))
  return [tabs, actions, account]
})
</script>

<style scoped>
.desktop-rail {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 0;
  z-index: 60;
  display: flex;
  width: var(--m-rail);
  flex-direction: column;
  gap: 2px;
  padding: 0 10px 14px;
  overflow: hidden;
  border-right: 1px solid var(--m-border);
  background: var(--m-surface);
  transition: width 0.2s ease, box-shadow 0.2s ease;
}
/* Opens over the page, not beside it: the stage keeps its 68px inset, so
   nothing reflows under the pointer. */
.desktop-rail.is-open {
  width: 248px;
  box-shadow: 8px 0 28px rgba(15, 23, 42, 0.12);
}

.rail-head {
  display: flex;
  height: 68px;
  flex: 0 0 auto;
  align-items: center;
  gap: 12px;
  /* Bleeds to the rail's edges so the rule runs full width; the 20px inset puts
     the mark's centre on the icons' axis (34px). */
  margin: 0 -10px 8px;
  padding-inline: 20px;
  border-bottom: 1px solid var(--m-border);
}
/* public/accommo-logo.svg as a mask, as SideRail does — the artwork is solid
   white and would vanish as an <img> on this surface. */
.rail-mark {
  width: 28px;
  height: 28px;
  flex: 0 0 auto;
  background-color: var(--m-primary);
  -webkit-mask: url(/accommo-logo.svg) no-repeat center / contain;
  mask: url(/accommo-logo.svg) no-repeat center / contain;
}
.rail-brand {
  color: var(--m-ink);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.03em;
}

/* Icons sit at a fixed left inset, so opening the rail only reveals the labels
   beside them — nothing the eye was tracking moves. */
.rail-row {
  position: relative;
  display: flex;
  height: 40px;
  flex: 0 0 auto;
  align-items: center;
  gap: 12px;
  padding: 0 0 0 13px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  text-align: left;
  white-space: nowrap;
  transition: background-color 0.12s ease, color 0.12s ease;
}
.rail-row:hover:not(.active) {
  background: var(--m-bg);
  color: var(--m-ink);
}
.rail-row.active {
  background: var(--m-primary-soft);
  color: var(--m-primary);
}
.rail-row.danger {
  color: var(--m-danger);
}
.rail-row:focus-visible {
  outline: 2px solid var(--m-primary);
  outline-offset: -2px;
}

.rail-icon {
  position: relative;
  display: inline-flex;
  width: 22px;
  flex: 0 0 auto;
  justify-content: center;
}
.rail-label,
.rail-brand {
  opacity: 0;
  transition: opacity 0.15s ease;
}
.rail-label {
  font-size: 13px;
  font-weight: 600;
}
.is-open .rail-label,
.is-open .rail-brand {
  opacity: 1;
}

.rail-sep {
  height: 1px;
  flex: 0 0 auto;
  margin: 8px 4px;
  background: var(--m-border);
}
.rail-spacer {
  flex: 1 1 auto;
}

.rail-avatar {
  background: var(--m-primary);
  font-size: 10px;
  font-weight: 800;
}
.rail-badge {
  position: absolute;
  top: -6px;
  right: -9px;
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
.rail-dot {
  position: absolute;
  top: -2px;
  right: -3px;
  width: 8px;
  height: 8px;
  border: 1.5px solid var(--m-surface);
  border-radius: 50%;
  background: var(--m-danger, #b42318);
}

@media (prefers-reduced-motion: reduce) {
  .desktop-rail,
  .rail-label,
  .rail-brand {
    transition: none;
  }
}
</style>
