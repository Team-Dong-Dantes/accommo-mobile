<template>
  <span class="ca" :class="[{ 'ca--small': small }, lease.avatarColor && !failed ? [`bg-${lease.avatarColor}`, 'text-white'] : []]">
    <img v-if="lease.avatarUrl && !failed" :src="lease.avatarUrl" alt="" @error="failed = true" />
    <template v-else>{{ initialsOf(lease.studentName) }}</template>
  </span>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { initialsOf } from '@/utils/format'
import type { CollectionLease } from '@/utils/collections'

defineProps<{ lease: CollectionLease; small?: boolean }>()
const failed = ref(false)
</script>

<style scoped>
.ca {
  display: inline-flex;
  width: 38px;
  height: 38px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 50%;
  background: var(--m-border);
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.ca--small {
  width: 30px;
  height: 30px;
  border: 2px solid var(--m-bg);
  font-size: 11px;
}
.ca img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
