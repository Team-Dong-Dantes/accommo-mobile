<template>
  <div v-if="status === 'rejected' || status === 'needs_resubmission' || status === 'reviewing'" class="reject-banner">
    <IconifyIcon icon="lucide:triangle-alert" width="16" />
    <div>
      <p class="reject-title">{{ status === 'reviewing' ? 'More information needed' : status === 'needs_resubmission' ? 'OSAS asked for new requirements' : 'Verification rejected' }}</p>
      <p class="reject-text">{{ reason || 'OSAS needs a clearer copy — please re-upload below.' }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
// 'reviewing' is a soft reject: OSAS wants a better document and the account
// can still be verified once it arrives.
import { Icon as IconifyIcon } from '@iconify/vue'

defineProps<{ status: string; reason: string }>()
</script>

<style scoped>
.reject-banner {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 10px 12px;
  border: 1px solid var(--m-danger-soft);
  border-radius: var(--m-radius-sm);
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.reject-title {
  margin: 0;
  font-size: 12.5px;
  font-weight: 800;
}
.reject-text {
  margin: 2px 0 0;
  color: var(--m-text);
  font-size: 12px;
  line-height: 1.4;
}
</style>
