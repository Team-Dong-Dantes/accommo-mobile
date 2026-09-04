<template>
  <q-btn unelevated class="google-btn full-width" v-bind="$attrs">
    <img :src="GOOGLE_ICON" width="20" class="q-mr-sm" />
    <slot>Continue with Google</slot>
  </q-btn>
</template>

<script setup lang="ts">
import { EXTERNAL_URLS } from '@/utils/config';
const GOOGLE_ICON = EXTERNAL_URLS.GOOGLE_ICON;
</script>

<style scoped>
.google-btn {
  height: 56px;
  border-radius: 16px;
  background: #f5f5f5;
  color: #222;
  font-weight: 600;
}
</style>
