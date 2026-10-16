<template>
  <div class="act">
    <span class="act-icon" :style="{ background: `var(--m-${tone}-soft)`, color: `var(--m-${tone})` }">
      <IconifyIcon :icon="icon" width="20" />
    </span>
    <span class="act-text">
      <span class="act-title">{{ title }}</span>
      <span v-if="sub" class="act-sub">{{ sub }}</span>
    </span>
    <button v-if="button" type="button" class="act-btn" @click="emit('action')">{{ button }}</button>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

// The dashboards' one next-thing card: icon, what, and an optional button.
// `tone` is a --m-* colour family with a -soft partner (warning, danger, info, success, primary).
defineProps<{ icon: string; tone: string; title: string; sub?: string; button?: string }>()
const emit = defineEmits<{ action: [] }>()
</script>

<style scoped>
.act {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 64px;
  padding: 10px 12px 10px 14px;
  box-sizing: border-box;
  border-radius: 20px;
  background: var(--m-surface);
}
.act-icon {
  display: grid;
  flex: 0 0 40px;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 999px;
}
.act-text {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.act-title {
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 600;
}
.act-sub {
  color: var(--m-muted);
  font-size: 12.5px;
}
.act-btn {
  min-height: 40px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
}
</style>
