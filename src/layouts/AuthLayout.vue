<template>
  <q-layout view="lHh Lpr lFf" class="window-height overflow-hidden">
    <q-page-container class="auth-layout-bg relative-position">
      <div class="hero-section shadow-5" :class="{
        'splash-mode': isSplash,
        'login-mode': isLogin,
        'register-mode': isRegister,
      }">
        <div class="hero-overlay">
          <div class="hero-content">
            <div class="logo-text">accommo</div>
            <div class="hero-subtitle">Verified boarding houses · ISU Echague</div>
          </div>
        </div>
      </div>

      <div class="content-wrapper">
        <router-view v-slot="{ Component }">
          <transition :name="transitionName">
            <component :is="Component" />
          </transition>
        </router-view>
      </div>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();

const isSplash = computed(() => route.path === '/');
const isLogin = computed(() => route.path === '/login');

// CHANGED: Now triggers for BOTH '/register' and '/register/landlord'
const isRegister = computed(() => route.path.startsWith('/register'));

// Controls the direction of the animation
const transitionName = ref('splash-to-login');

// Watches the route to dynamically switch transitions
watch(
  () => route.path,
  (to, from) => {
    // CHANGED: Check if it starts with /register so landlords get the slide-down too
    if (to.startsWith('/register')) {
      transitionName.value = 'slide-down';
    } else if (from === '/' && to === '/login') {
      // The hybrid transition: Login slides up, Splash fades out
      transitionName.value = 'splash-to-login';
    } else {
      transitionName.value = 'slide-up';
    }
  },
);
</script>

<style scoped>
.auth-layout-bg {
  background: #f5f5f5;
  height: 100vh;
  overflow: hidden;
  position: relative;
}

.hero-section {
  position: absolute;
  top: -80px;
  left: 0;
  width: 100%;
  height: 50vh;
  min-height: 300px;
  max-height: 500px;
  background-image: url('https://isu.edu.ph/wp-content/uploads/2024/11/ISU-Aerial.jpg');
  background-size: cover;
  background-position: 46% center;
  z-index: 1;
  transition: all 0.7s cubic-bezier(0.25, 1, 0.3, 1);
}

.hero-section.splash-mode {
  height: 100vh;
  min-height: 100vh;
  max-height: 100vh;
}

.hero-section.register-mode {
  top: calc(100vh - 50vh);
  height: 50vh;
  min-height: 200px;
}

.hero-overlay {
  height: 100%;
  background: linear-gradient(135deg, rgba(0, 150, 136, 0.95), rgba(0, 121, 107, 0.85));
  position: relative;
}

.hero-content {
  position: absolute;
  left: 0;
  top: clamp(60px, 15vh, 140px);
  width: 100%;
  padding: 0 clamp(16px, 4vw, 48px);
  color: white;
  transition: all 0.7s cubic-bezier(0.25, 1, 0.3, 1);
}

.hero-section.splash-mode .hero-content {
  top: 45%;
  transform: translateY(-50%);
  text-align: center;
}

.hero-section.register-mode .hero-content {
  top: clamp(40px, 8vh, 100px);
}

.logo-text {
  font-size: clamp(28px, 8vw, 56px);
  font-weight: 700;
  line-height: 1;
  transition: font-size 0.7s cubic-bezier(0.25, 1, 0.3, 1);
}

.hero-section.splash-mode .logo-text {
  font-size: clamp(36px, 10vw, 72px);
}

.hero-subtitle {
  margin-top: clamp(6px, 1.5vh, 14px);
  font-size: clamp(12px, 2.5vw, 16px);
  opacity: 0.95;
}

@media (max-height: 600px) {
  .hero-section {
    height: 40vh;
    min-height: 200px;
  }
  .hero-content {
    top: 40px;
  }
}

@media (min-width: 768px) {
  .hero-section {
    height: 45vh;
  }
}

.content-wrapper {
  position: relative;
  z-index: 10;
  height: 100vh;
  width: 100%;
}

/* =======================================================
   1. CUSTOM: SPLASH -> LOGIN (No fade-in for Login!)
   ======================================================= */
.splash-to-login-enter-active,
.splash-to-login-leave-active {
  transition: all 0.7s cubic-bezier(0.25, 1, 0.3, 1);
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100vh;
}

/* Login card slides UP from the bottom at 100% opacity */
.splash-to-login-enter-from {
  transform: translateY(100vh);
}

/* Splash screen fades out and STAYS in place (doesn't slide up) */
.splash-to-login-leave-to {
  opacity: 0;
  transform: translateY(0);
}

/* =======================================================
   2. STANDARD SLIDE ANIMATIONS (Login <-> Register)
   ======================================================= */
.slide-up-enter-active,
.slide-up-leave-active,
.slide-down-enter-active,
.slide-down-leave-active {
  transition: transform 0.7s cubic-bezier(0.25, 1, 0.3, 1);
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100vh;
}

.slide-up-enter-from {
  transform: translateY(100vh);
}

.slide-up-leave-to {
  transform: translateY(-100vh);
}

.slide-down-enter-from {
  transform: translateY(-100vh);
}

.slide-down-leave-to {
  transform: translateY(100vh);
}
</style>
