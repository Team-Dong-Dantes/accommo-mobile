<template>
  <!-- The tick boxes of a pay sheet: one row per thing owed. -->
  <div class="pil">
    <button
      v-for="it in items"
      :key="it.key"
      type="button"
      class="pil-row"
      :aria-pressed="it.on"
      @click="it.toggle"
    >
      <span class="pil-box" :class="{ 'pil-box--on': it.on }">
        <IconifyIcon v-if="it.on" icon="lucide:check" width="13" />
      </span>
      <span class="pil-body">
        <span class="pil-name">{{ it.name }}</span>
        <span class="pil-note" :class="{ 'pil-note--late': it.late }">{{ it.note }}</span>
      </span>
      <span class="pil-amt">{{ formatPesoExact(it.amount) }}</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import { formatPesoExact } from '@/utils/format'
import type { PayItem } from '@/utils/usePayItems'

defineProps<{ items: PayItem[] }>()
</script>

<style scoped>
.pil {
  overflow: hidden;
  flex: 0 0 auto;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.pil-row {
  display: flex;
  width: 100%;
  min-height: 54px;
  align-items: center;
  gap: 12px;
  padding: 8px 14px;
  border: 0;
  background: none;
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.pil-row + .pil-row {
  border-top: 1px solid var(--m-border);
}
.pil-box {
  display: inline-flex;
  width: 22px;
  height: 22px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border: 2px solid #c9ced6;
  border-radius: 7px;
  color: #fff;
}
.pil-box--on {
  border-color: var(--m-primary);
  background: var(--m-primary);
}
.pil-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.pil-name {
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
}
.pil-note {
  color: var(--m-muted);
  font-size: 12.5px;
}
.pil-note--late {
  color: var(--m-danger);
  font-weight: 600;
}
.pil-amt {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
</style>
