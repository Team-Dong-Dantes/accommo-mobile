<template>
  <transition name="offline">
    <div v-if="!online" class="offline-bar" role="status">
      <IconifyIcon icon="lucide:wifi-off" width="14" />
      <span>No internet connection</span>
    </div>
  </transition>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

// ponytail: navigator.onLine only reflects the device's network interface,
// not real internet reachability (a captive portal still reads "online").
// Good enough for "phone has no radio/wifi at all"; upgrade to a periodic
// reachability ping only if that gap actually bites someone.
const online = ref(navigator.onLine)

function update() {
  online.value = navigator.onLine
}

onMounted(() => {
  window.addEventListener('online', update)
  window.addEventListener('offline', update)
})

onUnmounted(() => {
  window.removeEventListener('online', update)
  window.removeEventListener('offline', update)
})
</script>

<style scoped>
.offline-bar {
  position: fixed;
  top: 0;
  right: 0;
  left: 0;
  z-index: 7000;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: calc(env(safe-area-inset-top, 0px) + 6px) 12px 6px;
  background: var(--m-danger);
  color: #fff;
  font-size: 12.5px;
  font-weight: 700;
}
.offline-enter-active,
.offline-leave-active {
  transition: transform 0.2s ease;
}
.offline-enter-from,
.offline-leave-to {
  transform: translateY(-100%);
}
@media (prefers-reduced-motion: reduce) {
  .offline-enter-active,
  .offline-leave-active {
    transition: none;
  }
}
</style>
