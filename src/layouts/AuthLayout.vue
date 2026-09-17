<template>
  <!-- Three shells, not two. On a phone, and on a tablet held in portrait, the
       auth screens hold the column they were drawn for. In landscape they get
       the room: the sign-in, role pick and register screens split the photo and
       the form into two halves, and the splash — which is a photograph with a
       sentence on it, not a form — keeps the picture full-bleed and only reins
       its text in to a readable measure. -->
  <q-layout view="lHh Lpr lFf" class="window-height overflow-hidden" :class="authShell">
    <q-page-container class="auth-layout-bg relative-position">
      <div class="hero-section shadow-5" :class="{
        'splash-mode': isSplash,
        'login-mode': isLogin,
        'register-mode': isRegister,
      }" :style="{ '--hero-bg': `url(${EXTERNAL_URLS.ISU_BACKGROUND})`, '--auth-vh': authVh }">
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
            <!-- Keyed by path, not just by component: /register and
                 /register/manager resolve to the same RegisterPage, and without
                 this Vue would reuse the instance between them — the role would
                 change but onMounted, which detects Google mode and a manager's
                 resubmission, would never run again. -->
            <component :is="Component" :key="route.path" />
          </transition>
        </router-view>
      </div>
    </q-page-container>
  </q-layout>
</template>


<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { EXTERNAL_URLS } from '@/utils/config';
import { isTablet } from '@/utils/useTabletMode';

const route = useRoute();

/**
 * A viewport height the on-screen keyboard cannot change.
 *
 * Focusing a field opens the keyboard, which shrinks the layout viewport and so
 * recalculates every `dvh` unit on the screen — including the hero's
 * `top: calc(100dvh - 220px)` on register. The hero carries a 0.7s transition,
 * so the ISU photo and the wordmark visibly slid away each time someone tapped
 * an input. The APK avoids this already (src/boot/keyboard.ts sets Capacitor's
 * resize mode to "none"), but that plugin is inert in a browser, which is where
 * `quasar dev` is used.
 *
 * A height-only resize on a phone is the keyboard; a width change is a real
 * layout change (rotation) worth re-measuring. `.content-wrapper` deliberately
 * stays on `dvh` — the scroll area *should* shrink so a focused field can
 * scroll into view. Only the decorative hero is pinned.
 */
const authVh = ref('100dvh');
let lastWidth = 0;

function measure() {
  lastWidth = window.innerWidth;
  authVh.value = `${window.innerHeight}px`;
}

function onResize() {
  if (window.innerWidth === lastWidth) return;
  measure();
}

onMounted(() => {
  measure();
  window.addEventListener('resize', onResize);
});
onUnmounted(() => window.removeEventListener('resize', onResize));

const isSplash = computed(() => route.path === '/');

/**
 * Which of the three auth shells is on screen. One class rather than several
 * booleans because they are mutually exclusive by definition, and the CSS that
 * reads them (app.scss) is easier to follow keyed on one name each.
 */
const authShell = computed(() => {
  if (!isTablet.value) return 'shell-column';
  return isSplash.value ? 'auth-wide' : 'auth-split';
});
const isLogin = computed(() => route.path === '/login');

// CHANGED: Now triggers for BOTH '/register' and '/register/manager'
const isRegister = computed(() => route.path.startsWith('/register'));

// Controls the direction of the animation
const transitionName = ref('splash-to-login');

// Watches the route to dynamically switch transitions
watch(
  () => route.path,
  (to, from) => {
    // Sign in and create an account are alternatives to each other, not one
    // inside the other, so moving between them travels sideways where the rest
    // of auth travels vertically. Both destinations the "Create account" link
    // can reach are covered: the start screen, which is where the role fork
    // lives, and /register itself, where guard.ts sends an unregistered Google
    // account.
    if (from === '/login' && (to === '/' || to.startsWith('/register'))) {
      transitionName.value = 'slide-right';
    // Everything else into registration still drops in from the top, one
    // vertical idea shared with the hero settling into its band at the bottom.
    // The role picked no longer chooses a horizontal direction: the sheet is
    // rounded at its bottom edge because it hangs from the top, and sliding it
    // sideways fought that shape — and the hero, which moves down at the same time.
    } else if (to.startsWith('/register')) {
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
  background: var(--m-bg);
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
  /* Solid brand ground underneath: the photo is fetched from isu.edu.ph, so a
     slow or unreachable campus site would otherwise leave the first frame of
     the app blank. ponytail: bundle the image locally to drop the dependency. */
  background-color: var(--m-primary-dark);
  background-image: var(--hero-bg, url('https://isu.edu.ph/wp-content/uploads/2024/11/ISU-Aerial.jpg'));
  background-size: cover;
  background-position: 46% center;
  z-index: 1;
  pointer-events: none;
  transition: all 0.7s cubic-bezier(0.25, 1, 0.3, 1);
  transform: translateZ(0);
  will-change: transform;
}

/* --auth-vh, not dvh: see the measurement in <script>. A keyboard opening must
   not move the photograph. */
.hero-section.splash-mode {
  top: 0;
  height: 100vh;
  height: var(--auth-vh);
  min-height: var(--auth-vh);
  max-height: var(--auth-vh);
  pointer-events: auto;
}

/* The register sheet needs the height more than the photograph does: with a
   question, the Google button, four name fields and two consent rows, 160px of
   campus at the foot was the difference between fitting and scrolling. It gives
   up 48px of that — not all of it, because the wordmark and its line have to
   stay legible in what is left. The sheet and this offset are a pair: 112px of
   strip, with the hero content raised to sit inside it. */
.hero-section.register-mode {
  top: calc(var(--auth-vh) - 184px);
  height: 400px;
  min-height: 200px;
}

/* Login and register. The wash used to be 95%/85% teal, which painted the
   aerial out completely — the cost of a remote photo with none of the picture.
   A tint plus a scrim weighted to the top (where the wordmark sits) keeps the
   text well past AA while letting the campus show through.

   PinGate.vue's lock screen hand-copies this gradient so it can stand in for
   the login screen. Change one and the other must follow.

   Height was 1000px inside a 400px hero — the overlay overhung by 600px, which
   the sheet hid but which left every gradient stop landing somewhere
   unpredictable. At 100% the percentages mean what they say. */
.hero-overlay {
  position: relative;
  height: 100%;
  background:
    linear-gradient(
      180deg,
      rgba(0, 44, 37, 0.74) 0%,
      rgba(0, 44, 37, 0.52) 34%,
      rgba(0, 44, 37, 0.34) 62%,
      rgba(0, 44, 37, 0.26) 100%
    ),
    linear-gradient(135deg, rgba(0, 150, 136, 0.52), rgba(0, 121, 107, 0.4));
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

/* Splash only. Login and register keep the near-opaque teal above — the PIN
   lock screen mirrors it rule for rule, and drifting one drifts the other.
   Here the photograph is the point, so the wash drops to a tint and a
   bottom-weighted scrim carries the text contrast instead. */
.hero-section.splash-mode .hero-overlay {
  height: 100%;
  background:
    linear-gradient(
      180deg,
      rgba(0, 51, 43, 0.34) 0%,
      rgba(0, 51, 43, 0.12) 26%,
      rgba(0, 44, 37, 0.78) 66%,
      rgba(0, 33, 28, 0.95) 100%
    ),
    linear-gradient(135deg, rgba(0, 150, 136, 0.42), rgba(0, 121, 107, 0.3));
}

/* The wordmark moves to the corner and shrinks; the pitch belongs to the page
   below, which can place it against the dark end of the scrim. */
.hero-section.splash-mode .hero-content {
  top: calc(env(safe-area-inset-top) + 20px);
  transform: none;
  text-align: left;
}

.hero-section.splash-mode .hero-subtitle {
  display: none;
}

/* Raised with the hero, so the wordmark lands just under the sheet's rounded
   edge rather than off the bottom of the screen. */
.hero-section.register-mode .hero-content {
  top: 90px;
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
  font-size: 26px;
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

/* Named for the direction of travel, like the two above: both screens move to
   the right together, so the one arriving starts off the left edge and the one
   leaving exits stage right.

   A percentage, not 100dvw: it is of the element itself, so each page travels
   exactly its own width whatever the shell around it is doing. */
.slide-right-enter-from {
  transform: translateX(-100%);
}

.slide-right-leave-to {
  transform: translateX(100%);
}
</style>