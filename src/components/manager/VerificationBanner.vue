<template>
  <!-- Renders nothing once the account is verified (or while its status is
       unknown), so screens can place it unconditionally. -->
  <div v-if="state" class="vbanner" :class="`vbanner--${state.tone}`" role="status">
    <IconifyIcon :icon="state.icon" width="17" class="vbanner-icon" />
    <div class="vbanner-body">
      <p class="vbanner-title">{{ state.title }}</p>
      <p class="vbanner-text">{{ state.text }}</p>
    </div>
    <button type="button" class="vbanner-action" @click="router.push(state.to)">{{ state.action }}</button>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useAuthStore } from '@/stores/auth'

// Why a landlord/landlady can use the app but not add accommodations yet, and
// what to do about it. Unverified accounts sign in straight after registering;
// only adding accommodations, rooms and facilities waits for OSAS (the database
// refuses those inserts until then). Shown on the screens where that matters:
// the dashboard, My Properties and the profile.

const router = useRouter()
const auth = useAuthStore()

const state = computed(() => {
  const status = auth.accountStatus
  if (status === 'pending') {
    return {
      tone: 'info',
      icon: 'lucide:hourglass',
      title: 'OSAS is verifying your account',
      text: 'You can add accommodations and rooms once it is approved.',
      action: 'View requirements',
      to: '/manager/osas',
    }
  }
  if (status === 'rejected' || status === 'reviewing') {
    return {
      tone: 'warn',
      icon: 'lucide:triangle-alert',
      title: 'OSAS needs changes to your application',
      text: 'Update it to be verified. You can add accommodations and rooms once it is approved.',
      action: 'Update application',
      to: '/register/manager?resubmit=true',
    }
  }
  return null
})
</script>

<style scoped>
.vbanner {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border: 1px solid transparent;
  border-radius: var(--m-radius);
}
.vbanner--info {
  border-color: color-mix(in srgb, var(--m-info) 30%, var(--m-border));
  background: var(--m-info-soft);
}
.vbanner--warn {
  border-color: color-mix(in srgb, var(--m-warning) 30%, var(--m-border));
  background: var(--m-warning-soft);
}
.vbanner-icon {
  flex: 0 0 auto;
}
.vbanner--info .vbanner-icon { color: var(--m-info); }
.vbanner--warn .vbanner-icon { color: var(--m-warning); }
.vbanner-body {
  min-width: 0;
  flex: 1 1 auto;
}
.vbanner-title {
  margin: 0;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 800;
}
.vbanner-text {
  margin: 2px 0 0;
  color: var(--m-text);
  font-size: 12px;
  line-height: 1.4;
}
.vbanner-action {
  flex: 0 0 auto;
  padding: 7px 12px;
  border: 0;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
}
</style>
