<template>
  <q-page class="getstarted-page">
    <div class="getstarted-content">
      <div class="mascot-area">
        <img
          src="https://img.icons8.com/fluency/256/home.png"
          alt="Accommo"
          class="mascot-img"
        />
      </div>
      <div class="tagline">Find your home away from home.</div>
    </div>
    <div class="getstarted-actions">
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
.getstarted-page {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  height: 100%;
  padding: 0 24px;
}

.getstarted-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  gap: 24px;
  max-width: 400px;
  width: 100%;
}

.mascot-area {
  width: min(160px, 40vw);
  height: min(160px, 40vw);
  background: rgba(255, 255, 255, 0.15);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(8px);
  border: 2px solid rgba(255, 255, 255, 0.3);
}

.mascot-img {
  width: 60%;
  height: 60%;
  object-fit: contain;
}

.tagline {
  font-size: clamp(14px, 3.5vw, 18px);
  color: rgba(255, 255, 255, 0.85);
  text-align: center;
  line-height: 1.5;
  padding: 0 16px;
}

.getstarted-actions {
  width: 100%;
  max-width: 400px;
  padding-bottom: max(24px, env(safe-area-inset-bottom, 24px));
}

.glass-btn {
  background: rgba(255, 255, 255, 0.25) !important;
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.4);
  color: white !important;
  height: 56px;
  border-radius: 16px;
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.15);
  transition: opacity 0.3s ease;
}

.fade-out-btn {
  opacity: 0 !important;
  pointer-events: none;
}

@media (max-height: 600px) {
  .mascot-area {
    width: 100px;
    height: 100px;
  }
  .tagline {
    font-size: 13px;
  }
  .getstarted-content {
    gap: 16px;
  }
}

@media (min-width: 600px) {
  .getstarted-page {
    padding: 0 48px;
  }
  .mascot-area {
    width: 200px;
    height: 200px;
  }
}
</style>
