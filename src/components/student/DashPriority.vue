<template>
  <div class="pri" :class="`pri--${task ? task.tone : 'clear'}`">
    <div class="pri-top">
      <span class="pri-icon">
        <IconifyIcon :icon="task ? task.icon : 'lucide:check'" width="19" />
      </span>
      <span class="pri-kind">{{ task ? task.kind : 'All clear' }}</span>
      <span v-if="task?.when" class="pri-when">{{ task.when }}</span>
    </div>

    <p class="pri-label">{{ task ? task.label : 'Nothing needs you' }}</p>
    <p class="pri-hint">
      {{ task ? task.hint : 'Rent, manager replies and OSAS updates land here first' }}
    </p>

    <button
      v-if="task && task.action"
      type="button"
      class="pri-action"
      @click="emit('go', task.route)"
    >
      {{ task.action }}
      <IconifyIcon icon="lucide:arrow-right" width="16" />
    </button>
    <span v-else-if="task" class="pri-wait">
      <IconifyIcon icon="lucide:clock" width="13" />
      Nothing for you to do yet
    </span>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import type { Task } from './dashboard'

defineProps<{ task: Task | null }>()
const emit = defineEmits<{ go: [route: string] }>()
</script>

<style scoped>
.pri {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 13px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.pri--danger {
  border-color: color-mix(in srgb, var(--m-danger) 28%, var(--m-border));
  background: color-mix(in srgb, var(--m-danger-soft) 60%, var(--m-surface));
}
.pri--warn {
  border-color: color-mix(in srgb, var(--m-warning) 30%, var(--m-border));
  background: color-mix(in srgb, var(--m-warning-soft) 55%, var(--m-surface));
}
.pri--info { border-color: color-mix(in srgb, var(--m-info) 24%, var(--m-border)); }
.pri--clear { border-color: color-mix(in srgb, var(--m-success) 24%, var(--m-border)); }

.pri-top { display: flex; align-items: center; gap: 8px; }
.pri-icon { display: grid; width: 28px; height: 28px; flex: 0 0 28px; place-items: center; border-radius: 999px; }
.pri--danger .pri-icon { background: var(--m-danger-soft); color: var(--m-danger); }
.pri--warn .pri-icon { background: var(--m-warning-soft); color: var(--m-warning); }
.pri--info .pri-icon { background: var(--m-info-soft); color: var(--m-info); }
.pri--clear .pri-icon { background: var(--m-success-soft); color: var(--m-success); }

.pri-kind { flex: 1 1 auto; font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; }
.pri--danger .pri-kind { color: var(--m-danger); }
.pri--warn .pri-kind { color: var(--m-warning); }
.pri--info .pri-kind { color: var(--m-info); }
.pri--clear .pri-kind { color: var(--m-success); }
.pri-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11.5px; font-weight: 600; }

.pri-label {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 19px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.18;
  text-wrap: pretty;
}
.pri-hint { margin: 3px 0 0; color: var(--m-muted); font-size: 12.5px; line-height: 1.35; text-wrap: pretty; }

.pri-action {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 7px;
  min-height: 44px;
  margin-top: 12px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.pri-action:active { transform: scale(0.97); }

.pri-wait {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-top: 10px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}

@media (prefers-reduced-motion: reduce) {
  .pri-action { transition: none; }
}
</style>
