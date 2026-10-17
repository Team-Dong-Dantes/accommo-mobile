<template>
  <!-- Where a review with OSAS stands, and the one thing to do about it. Shared
       by a listing's accreditation and an account's own verification. -->
  <div class="box" :class="tone && `box--${tone}`">
    <span class="box-head"><IconifyIcon :icon="icon" width="16" /> {{ title }}</span>
    <slot />
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

defineProps<{ icon: string; title: string; tone?: 'warn' | 'danger' | '' }>()
</script>

<style scoped>
.box {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.box--warn { border-color: color-mix(in srgb, var(--m-warning) 45%, var(--m-border)); }
.box--danger { border-color: color-mix(in srgb, var(--m-danger) 40%, var(--m-border)); }
.box-head {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.box-head :deep(svg) { color: var(--m-primary-dark); }
.box--warn .box-head :deep(svg) { color: var(--m-warning); }
.box--danger .box-head :deep(svg) { color: var(--m-danger); }

/* What callers put inside — styled here so every box reads the same. */
:slotted(.box-text) { margin: 0; color: var(--m-muted); font-size: 12.5px; line-height: 1.45; }
:slotted(.box-text--strong) { color: var(--m-ink); font-weight: 600; }
:slotted(.quote) {
  margin: 0;
  padding: 8px 10px;
  border-left: 3px solid var(--m-warning);
  border-radius: 0 var(--m-radius-sm) var(--m-radius-sm) 0;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 13px;
  line-height: 1.45;
}
.box--danger :slotted(.quote) { border-left-color: var(--m-danger); }
:slotted(.note-input) {
  box-sizing: border-box;
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
  resize: vertical;
}
:slotted(.main-btn) {
  min-height: 46px;
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
}
:slotted(.main-btn:disabled) { background: var(--m-border); color: var(--m-muted); cursor: not-allowed; }
:slotted(.pill-btn) {
  align-self: flex-start;
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
:slotted(.pill-btn--danger) { border-color: var(--m-danger); background: var(--m-danger-soft); color: var(--m-danger); }
:slotted(.pill-btn:disabled) { opacity: 0.6; }
</style>
