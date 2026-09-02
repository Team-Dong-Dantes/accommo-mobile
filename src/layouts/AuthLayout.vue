<template>
  <q-layout view="lHh Lpr lFf" class="window-height overflow-hidden">
    <q-page-container class="auth-layout-bg relative-position">
      <div class="hero-section shadow-5" :class="{
        'splash-mode': isSplash,
        'login-mode': isLogin,
        'register-mode': isRegister,
      }" :style="{ '--hero-bg': `url(${EXTERNAL_URLS.ISU_BACKGROUND})` }">
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
import { EXTERNAL_URLS } from '@/shared/utils/config';
import { transitionDir } from '@/shared/utils/transition';

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
    // CHANGED: Role picker sets a horizontal direction (Student=left, Landlord=right).
    if (to.startsWith('/register')) {
      const dir = transitionDir.value;
      transitionDir.value = null;
      if (dir === 'left') {
        transitionName.value = 'slide-left';
      } else if (dir === 'right') {
        transitionName.value = 'slide-right';
      } else {
        transitionName.value = 'slide-down';
      }
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
  height: 100dvh;
  overflow: hidden;
  position: relative;
}

.hero-section {
  position: fixed;
  top: -80px;
  left: 0;
  width: 100%;
  height: 400px;
  background-image: var(--hero-bg, url('https://isu.edu.ph/wp-content/uploads/2024/11/ISU-Aerial.jpg'));
  background-size: cover;
  background-position: 46% center;
  z-index: 1;
  pointer-events: none;
  transition: all 0.7s cubic-bezier(0.25, 1, 0.3, 1);
  transform: translateZ(0);
  will-change: transform;
}

.hero-section.splash-mode {
  top: 0;
  height: 100vh;
  height: 100dvh;
  min-height: 100dvh;
  max-height: 100dvh;
  pointer-events: auto;
}

.hero-section.register-mode {
  top: calc(100dvh - 220px);
  height: 400px;
  min-height: 200px;
}

.hero-overlay {
  height: 1000px;
  background: linear-gradient(135deg, rgba(0, 150, 136, 0.95), rgba(0, 121, 107, 0.85));
  position: relative;
}

.hero-content {
  position: absolute;
  left: 0;
  top: 120px;
  width: 100%;
  padding: 0 24px;
  color: white;
  transition: all 0.7s cubic-bezier(0.25, 1, 0.3, 1);
}

.hero-section.splash-mode .hero-content {
  top: 45%;
  transform: translateY(-50%);
  text-align: center;
}

.hero-section.register-mode .hero-content {
  top: 125px;
}

.hero-section.register-mode .hero-subtitle {
  margin-top: 0px;
}

.logo-text {
  font-size: 38px;
  font-weight: 700;
  line-height: 1;
  transition: font-size 0.7s cubic-bezier(0.25, 1, 0.3, 1);
}

.hero-section.splash-mode .logo-text {
  font-size: 56px;
}

.hero-subtitle {
  font-size: 14px;
  opacity: 0.95;
}

@media (max-height: 600px) {
  .hero-section {
    height: 300px;
  }
  .hero-content {
    top: 60px;
  }
}

.content-wrapper {
  position: fixed;
  inset: 0;
  z-index: 10;
  height: 100vh;
  height: 100dvh;
  width: 100%;
  overflow-y: auto;
  overflow-x: hidden;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior-y: contain;
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
  height: 100%;
}

/* Login card slides UP from the bottom at 100% opacity */
.splash-to-login-enter-from {
  transform: translateY(100dvh);
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
.slide-down-leave-active,
.slide-left-enter-active,
.slide-left-leave-active,
.slide-right-enter-active,
.slide-right-leave-active {
  transition: transform 0.7s cubic-bezier(0.25, 1, 0.3, 1);
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.slide-up-enter-from {
  transform: translateY(100dvh);
}

.slide-up-leave-to {
  transform: translateY(-100dvh);
}

.slide-down-enter-from {
  transform: translateY(-100dvh);
}

.slide-down-leave-to {
  transform: translateY(100dvh);
}

/* Horizontal pick from the role screen: Student slides LEFT, Landlord slides RIGHT. */
.slide-left-enter-from {
  transform: translateX(100%);
}
.slide-left-leave-to {
  transform: translateX(-100%);
}
.slide-right-enter-from {
  transform: translateX(-100%);
}
.slide-right-leave-to {
  transform: translateX(100%);
}
</style>