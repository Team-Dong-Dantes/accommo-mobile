<template>
  <!-- Nothing open: the card shrinks to one line instead of holding the top of the screen. -->
  <div v-if="!lead" class="clear">
    <span class="clear-icon"><IconifyIcon icon="lucide:check" width="16" /></span>
    <span class="clear-text">
      <span class="clear-label">{{ emptyLabel }}</span>
      <span class="clear-hint">{{ emptyHint }}</span>
    </span>
  </div>

  <section v-else class="up">
    <h2 class="up-title">
      Up next
      <span class="up-count">{{ total || tasks.length }}</span>
    </h2>

    <div class="card">
      <!-- The most urgent task, at full size with its own button. -->
      <div class="lead" :class="`lead--${lead.tone}`">
        <div class="lead-top">
          <span class="lead-icon"><IconifyIcon :icon="lead.icon" width="16" /></span>
          <span class="lead-kind">{{ lead.kind }}</span>
          <span v-if="lead.when" class="lead-when">{{ lead.when }}</span>
        </div>
        <p class="lead-label">{{ lead.label }}</p>
        <p v-if="lead.hint" class="lead-hint">{{ lead.hint }}</p>
        <button v-if="lead.action" type="button" class="lead-action" @click="emit('go', lead.route)">
          {{ lead.action }}
          <IconifyIcon icon="lucide:arrow-right" width="16" />
        </button>
        <span v-else class="lead-wait">
          <IconifyIcon icon="lucide:clock" width="13" />
          Nothing for you to do yet
        </span>
      </div>

      <!-- Everything else, one hairline row each. -->
      <div v-for="t in rest" :key="t.id" class="trow">
        <span class="trow-icon" :class="`trow-icon--${t.tone}`">
          <IconifyIcon :icon="t.icon" width="15" />
        </span>
        <span class="trow-text">
          <span class="trow-label">{{ t.label }}</span>
          <span v-if="t.hint" class="trow-hint">{{ t.hint }}</span>
        </span>
        <button v-if="t.action" type="button" class="trow-action" @click="emit('go', t.route)">
          {{ t.action }}
        </button>
        <span v-else class="trow-wait">Waiting</span>
      </div>

      <div v-if="doneCount" class="done">
        <IconifyIcon icon="lucide:check" width="13" />
        {{ doneCount }} done
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import type { Task } from './dashboard'

// Open tasks only, already ranked. The first becomes the large lead row; the
// all-clear copy is per screen, like DashPriority's. `total` is the full count
// when the caller passes only the first few.
const props = withDefaults(
  defineProps<{ tasks: Task[]; total?: number; doneCount?: number; emptyLabel?: string; emptyHint?: string }>(),
  {
    total: 0,
    doneCount: 0,
    emptyLabel: 'All clear',
    emptyHint: 'Rent, landlord/landlady replies and OSAS updates land here first',
  },
)
const emit = defineEmits<{ go: [route: string] }>()

const lead = computed(() => props.tasks[0] ?? null)
const rest = computed(() => props.tasks.slice(1))
</script>

<style scoped>
/* One type scale: 11 / 12 / 13 / 15 / 20. */
.up { display: flex; flex-direction: column; gap: 6px; }
.up-title {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.03em;
  line-height: 1.4;
  text-transform: uppercase;
}
.up-count {
  display: grid;
  min-width: 20px;
  height: 20px;
  place-items: center;
  padding: 0 6px;
  border-radius: 999px;
  background: var(--m-ink);
  color: var(--m-surface);
  font-size: 11px;
  letter-spacing: 0;
}

.card {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}

.lead { display: flex; flex-direction: column; padding: 14px 14px 16px; }
.lead--danger { background: color-mix(in srgb, var(--m-danger-soft) 70%, var(--m-surface)); }
.lead--warn { background: color-mix(in srgb, var(--m-warning-soft) 70%, var(--m-surface)); }
.lead--info { background: color-mix(in srgb, var(--m-info-soft) 60%, var(--m-surface)); }
.lead-top { display: flex; align-items: center; gap: 8px; }
.lead-icon { display: grid; width: 28px; height: 28px; flex: 0 0 28px; place-items: center; border-radius: 999px; background: var(--m-surface); }
.lead--danger .lead-icon, .lead--danger .lead-kind { color: var(--m-danger); }
.lead--warn .lead-icon, .lead--warn .lead-kind { color: var(--m-warning); }
.lead--info .lead-icon, .lead--info .lead-kind { color: var(--m-info); }
.lead-kind { flex: 1 1 auto; font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; }
.lead-when { flex: 0 0 auto; color: var(--m-muted); font-size: 12px; font-weight: 600; }
.lead-label {
  margin: 10px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  text-wrap: pretty;
}
.lead-hint { margin: 4px 0 0; color: var(--m-text); font-size: 13px; line-height: 1.4; text-wrap: pretty; }
.lead-action {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 8px;
  min-height: 44px;
  margin-top: 14px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 15px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.lead-action:active { transform: scale(0.97); }
.lead-wait { display: inline-flex; align-items: center; gap: 6px; margin-top: 12px; color: var(--m-muted); font-size: 12px; font-weight: 600; }

.trow {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 56px;
  padding: 8px 12px 8px 14px;
  border-top: 1px solid var(--m-border);
}
.trow-icon { display: grid; width: 28px; height: 28px; flex: 0 0 28px; place-items: center; border-radius: 999px; }
.trow-icon--info { background: var(--m-info-soft); color: var(--m-info); }
.trow-icon--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.trow-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.trow-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.trow-label { color: var(--m-ink); font-size: 13px; font-weight: 600; line-height: 1.3; }
.trow-hint {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.trow-wait { flex: 0 0 auto; color: var(--m-muted); font-size: 12px; font-weight: 600; }
.trow-action {
  flex: 0 0 auto;
  min-height: 36px;
  padding: 0 12px;
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

.done {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 14px;
  border-top: 1px solid var(--m-border);
  color: var(--m-success);
  font-size: 12px;
  font-weight: 700;
}

.clear {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.clear-icon { display: grid; width: 28px; height: 28px; flex: 0 0 28px; place-items: center; border-radius: 999px; background: var(--m-success-soft); color: var(--m-success); }
.clear-text { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.clear-label { color: var(--m-ink); font-size: 13px; font-weight: 700; }
.clear-hint { color: var(--m-muted); font-size: 12px; line-height: 1.3; }

@media (prefers-reduced-motion: reduce) {
  .lead-action { transition: none; }
}
</style>
