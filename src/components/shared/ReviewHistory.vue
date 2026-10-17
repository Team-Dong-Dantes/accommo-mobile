<template>
  <!-- Every past step with OSAS, newest first, behind a toggle. Shared by a
       listing's accreditation and an account's own verification. -->
  <div v-if="items.length" class="hist">
    <button type="button" class="hist-toggle" :aria-expanded="open" @click="open = !open">
      <IconifyIcon icon="lucide:history" width="16" />
      Review history ({{ items.length }})
      <IconifyIcon :icon="open ? 'lucide:chevron-up' : 'lucide:chevron-down'" width="15" />
    </button>
    <ol v-if="open" class="hist-list">
      <li v-for="r in items" :key="r.id" class="hist-item">
        <span class="hist-dot" :class="`hist-dot--${r.tone}`" />
        <span class="hist-body">
          <span class="hist-head">{{ r.title }} · <b>{{ r.verdict }}</b></span>
          <span class="hist-when">{{ r.when }}</span>
          <span v-for="(line, i) in r.lines" :key="i" class="hist-line">{{ line }}</span>
        </span>
      </li>
    </ol>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

export interface HistoryItem {
  id: string
  title: string
  verdict: string
  /** approved | returned | rejected | sent */
  tone: string
  when: string
  lines: string[]
}

defineProps<{ items: HistoryItem[] }>()
const open = ref(false)
</script>

<style scoped>
.hist { display: flex; flex-direction: column; gap: 6px; }
/* A centred pill, tinted so it reads as an action rather than fine print. */
.hist-toggle {
  display: inline-flex;
  align-self: center;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  padding: 0 16px;
  border: 1px solid var(--m-primary);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.hist-list { display: flex; flex-direction: column; margin: 0; padding: 0 0 0 6px; list-style: none; }
.hist-item {
  position: relative;
  display: flex;
  gap: 10px;
  padding: 0 0 12px 12px;
  border-left: 2px solid var(--m-border);
}
.hist-item:last-child { border-left-color: transparent; }
.hist-dot {
  position: absolute;
  top: 3px;
  left: -6px;
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: var(--m-border);
}
.hist-dot--approved { background: var(--m-success); }
.hist-dot--returned { background: var(--m-warning); }
.hist-dot--rejected { background: var(--m-danger); }
.hist-dot--sent { background: var(--m-primary); }
.hist-body { display: flex; flex-direction: column; gap: 2px; font-size: 12.5px; }
.hist-head { color: var(--m-ink); }
.hist-when { color: var(--m-muted); font-size: 11px; }
.hist-line { color: var(--m-muted); line-height: 1.4; }
</style>
