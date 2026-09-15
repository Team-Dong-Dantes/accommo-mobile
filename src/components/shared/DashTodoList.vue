<template>
  <section v-if="tasks.length || doneCount" class="sec">
    <div class="sec-head">
      <h2 class="sec-title">{{ title }}</h2>
    </div>

    <div class="steps">
      <div v-for="t in tasks" :key="t.id" class="step">
        <span class="step-icon" :class="`step-icon--${t.tone}`">
          <IconifyIcon :icon="t.icon" width="15" />
        </span>
        <span class="step-text">
          <span class="step-label">{{ t.label }}</span>
          <span v-if="t.hint" class="step-hint">{{ t.hint }}</span>
        </span>
        <button v-if="t.action" type="button" class="step-action" @click="emit('go', t.route)">
          {{ t.action }}
        </button>
        <span v-else class="step-wait">Waiting</span>
      </div>

      <div v-if="doneCount" class="step step--done">
        <span class="step-icon step-icon--done"><IconifyIcon icon="lucide:check" width="15" /></span>
        <span class="step-label">{{ doneCount }} already done</span>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import type { Task } from './dashboard'

withDefaults(defineProps<{ tasks: Task[]; doneCount: number; title?: string }>(), {
  title: 'To do',
})
const emit = defineEmits<{ go: [route: string] }>()
</script>

<style scoped>
.sec { display: flex; flex-direction: column; gap: 5px; }
.sec-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; padding: 0 2px; }
.sec-title { margin: 0; color: var(--m-ink); font-size: 12.5px; font-weight: 700; letter-spacing: 0.02em; text-transform: uppercase; }

.steps { display: flex; flex-direction: column; gap: 3px; }
.step {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 11px;
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
}
.step--done { opacity: 0.7; }
.step-icon { display: grid; width: 26px; height: 26px; flex: 0 0 26px; place-items: center; border-radius: 999px; }
.step-icon--done { background: var(--m-success-soft); color: var(--m-success); }
.step-icon--info { background: var(--m-info-soft); color: var(--m-info); }
.step-icon--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.step-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.step-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.step-label { color: var(--m-ink); font-size: 13px; font-weight: 600; }
.step-hint { color: var(--m-muted); font-size: 11.5px; }
.step-wait { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 700; }
.step-action {
  flex: 0 0 auto;
  min-height: 32px;
  padding: 0 11px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
</style>
