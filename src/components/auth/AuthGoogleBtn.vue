<template>
  <q-btn unelevated class="google-btn full-width" v-bind="$attrs">
    <img :src="GOOGLE_ICON" width="20" class="q-mr-sm" alt="" />
    <slot>Continue with Google</slot>
  </q-btn>
</template>

<script setup lang="ts">
import { EXTERNAL_URLS } from '@/utils/config';
const GOOGLE_ICON = EXTERNAL_URLS.GOOGLE_ICON;
</script>

<style scoped>
/* A surface ground rather than the fields' --m-bg: next to a column of inputs
   this has to read as a button, and matching their fill made it look like one
   more thing to type into. */
.google-btn {
  height: 56px;
  border: 1px solid var(--m-border);
  border-radius: 14px;
  background: var(--m-surface);
  color: var(--m-ink);
  font-weight: 600;
  transition: background 0.15s ease, border-color 0.15s ease, transform 0.12s ease;
}
.google-btn:hover {
  border-color: var(--m-primary);
  background: var(--m-bg);
}
.google-btn:active {
  transform: scale(0.985);
}

@media (prefers-reduced-motion: reduce) {
  .google-btn { transition: none; }
}
</style>
