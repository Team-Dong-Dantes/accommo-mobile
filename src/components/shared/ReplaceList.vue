<template>
  <!-- The documents OSAS wants again, each with its own way to send a new file. -->
  <div class="flag-list">
    <div v-for="f in items" :key="f.type" class="flag-row">
      <span class="flag-icon" :class="f.replaced ? 'flag-icon--done' : 'flag-icon--todo'">
        <IconifyIcon :icon="f.replaced ? 'lucide:check' : 'lucide:file-warning'" width="15" />
      </span>
      <span class="flag-body">
        <span class="flag-name">{{ f.label }}</span>
        <span class="flag-when">{{ f.replaced ? 'Replaced' : todo }}</span>
      </span>
      <button type="button" class="flag-btn" :disabled="busy" @click="emit('replace', f.type)">
        {{ f.replaced ? 'Change' : 'Replace' }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

export interface ReplaceItem {
  type: string
  label: string
  replaced: boolean
}

withDefaults(defineProps<{ items: ReplaceItem[]; todo?: string; busy?: boolean }>(), { todo: 'Needs a new file', busy: false })
const emit = defineEmits<{ replace: [type: string] }>()
</script>

<style scoped>
.flag-list {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.flag-row { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-top: 1px solid var(--m-border); }
.flag-row:first-child { border-top: 0; }
.flag-icon {
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border-radius: 999px;
}
.flag-icon--todo { background: var(--m-warning-soft); color: var(--m-warning); }
.flag-icon--done { background: var(--m-success-soft); color: var(--m-success); }
.flag-body { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 1px; }
.flag-name { color: var(--m-ink); font-size: 13px; font-weight: 700; }
.flag-when { color: var(--m-muted); font-size: 11px; }
.flag-btn {
  min-height: 36px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.flag-btn:disabled { opacity: 0.6; }
</style>
