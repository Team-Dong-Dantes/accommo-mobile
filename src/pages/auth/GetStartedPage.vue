<template>
  <q-page>
    <div class="fixed-bottom q-px-xl" style="padding-bottom: 60px; z-index: 10">
      <q-btn
        unelevated
        class="glass-btn full-width"
        :class="{ 'fade-out-btn': isClicked }"
        @click="handleGetStarted"
      >
        <span class="text-weight-bold text-subtitle1">GET STARTED</span>
        <q-icon name="arrow_forward" class="q-ml-sm" size="20px" />
      </q-btn>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();
const isClicked = ref(false);

function handleGetStarted() {
  // Trigger the CSS fade-out class
  isClicked.value = true;

  // Wait 300ms for the button to fade out, THEN change pages
  setTimeout(() => {
    void router.push('/login');
  }, 300);
}
</script>

<style scoped>
.glass-btn {
  background: rgba(255, 255, 255, 0.25) !important;
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.4);
  color: white !important;
  height: 60px;
  border-radius: 16px;
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.15);

  /* Required to make the fade-out smooth when clicked */
  transition: opacity 0.3s ease;
}

/* Applied instantly when clicked */
.fade-out-btn {
  opacity: 0 !important;
  pointer-events: none;
}
</style>
