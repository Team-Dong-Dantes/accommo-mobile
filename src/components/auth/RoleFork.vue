<template>
  <div class="fork" :class="`fork--${variant}`">
    <button type="button" class="role" @click="emit('pick', 'student')">
      <span class="role-label">I'm a student</span>
      <IconifyIcon icon="lucide:arrow-right" width="19" height="19" class="role-arrow" />
    </button>

    <button type="button" class="role" @click="emit('pick', 'manager')">
      <span class="role-label">I manage a property</span>
      <IconifyIcon icon="lucide:arrow-right" width="19" height="19" class="role-arrow" />
    </button>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

/** `glass` sits on the splash hero photo, `solid` on a white sheet. */
withDefaults(defineProps<{ variant?: 'solid' | 'glass' }>(), { variant: 'solid' })
const emit = defineEmits<{ pick: [role: 'student' | 'manager'] }>()
</script>

<style scoped>
/* Rules and type, no boxes. With nothing but a hairline to signal that these
   are tappable, the rows are given a generous height and a clear press state —
   that, and the arrow, is what carries the affordance. */
.fork {
  display: flex;
  flex-direction: column;
}

.role {
  display: flex;
  width: 100%;
  min-height: 62px;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 16px 2px;
  border: 0;
  border-top: 1px solid var(--rule);
  background: transparent;
  color: inherit;
  cursor: pointer;
  font-family: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
  transition: background-color 0.15s ease, padding-left 0.15s ease;
}
.role:last-child {
  border-bottom: 1px solid var(--rule);
}
.role:hover {
  padding-left: 8px;
}
.role:active {
  background-color: var(--press);
}

.role-label {
  min-width: 0;
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.01em;
  line-height: 1.2;
}

.role-arrow {
  flex: 0 0 auto;
  opacity: 0.6;
}

.fork--glass {
  --rule: rgba(255, 255, 255, 0.32);
  --press: rgba(255, 255, 255, 0.14);
  color: #fff;
}
.fork--solid {
  --rule: var(--m-border);
  --press: var(--m-primary-soft);
  color: var(--m-ink);
}

@media (prefers-reduced-motion: reduce) {
  .role { transition: none; }
  .role:hover { padding-left: 2px; }
}
</style>
