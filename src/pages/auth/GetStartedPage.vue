<template>
  <q-page class="getstarted-page">
    <q-btn
      unelevated
      class="glass-btn full-width"
      :class="{ 'fade-out-btn': isClicked }"
      @click="handleGetStarted"
    >
      <span class="text-weight-bold text-subtitle1">GET STARTED</span>
      <IconifyIcon icon="material-icons:arrow_forward" class="q-ml-sm" width="20" />
    </q-btn>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();
const isClicked = ref(false);

function handleGetStarted() {
  isClicked.value = true;

  setTimeout(() => {
    void router.push('/login');
  }, 300);
}
</script>

<style scoped>
.getstarted-page {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  min-height: 100vh;
  padding: clamp(16px, 4vw, 32px);
}

.glass-btn {
  background: rgba(255, 255, 255, 0.25) !important;
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.4);
  color: white !important;
  height: clamp(48px, 8vh, 64px);
  border-radius: clamp(12px, 2vw, 20px);
  font-size: clamp(14px, 2.5vw, 18px);
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.15);
  transition: opacity 0.3s ease;
}

.fade-out-btn {
  opacity: 0 !important;
  pointer-events: none;
}
</style>
