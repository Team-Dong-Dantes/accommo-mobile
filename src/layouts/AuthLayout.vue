<template>
  <!-- Three shells, not two. On a phone, and on a tablet held in portrait, the
       auth screens hold the column they were drawn for. In landscape they get
       the room: the sign-in, role pick and register screens split the photo and
       the form into two halves, and the splash — which is a photograph with a
       sentence on it, not a form — keeps the picture full-bleed and only reins
       its text in to a readable measure. -->
  <q-layout
    view="lHh Lpr lFf"
    class="window-height overflow-hidden"
    :class="authShell"
    :style="{ '--auth-vh': authVh, '--hero-scale': heroScale }"
  >
    <q-page-container class="auth-layout-bg relative-position">
      <!-- The photograph and the wordmark are siblings, not parent and child,
           so each can move on its own transform; see .hero-photo below. -->
      <div class="hero-section" :class="{
        'splash-mode': isSplash,
        'login-mode': isLogin,
        'register-mode': isRegister,
      }">
        <div class="hero-photo shadow-5" :style="{ '--hero-bg': `url(${EXTERNAL_URLS.ISU_BACKGROUND})` }">
          <div class="hero-overlay hero-overlay--band" />
          <div class="hero-overlay hero-overlay--splash" />
        </div>
        <div class="hero-content">
          <div class="logo-text">accommo</div>
          <div class="hero-subtitle">Verified boarding houses · ISU Echague</div>
        </div>
        <!-- Landscape only (app.scss). The photograph half carries the pitch
             on every auth screen, the splash included — so the sentence has
             one home on this shell instead of living inside GetStartedPage
             and vanishing the moment you leave it. -->
        <p class="hero-pitch">{{ PITCH_LINE }}</p>
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
import { EXTERNAL_URLS, PITCH_LINE } from '@/utils/config';
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
// How far the photo band (400px, 300px on short screens — the same breakpoint
// as the max-height media query below) is scaled up to fill the splash. A
// number, not a calc(): dividing a length by a length is too new for the
// WebViews this APK installs on.
const heroScale = ref(1);
let lastWidth = 0;

function measure() {
  lastWidth = window.innerWidth;
  authVh.value = `${window.innerHeight}px`;
  heroScale.value = window.innerHeight / (window.innerHeight <= 600 ? 300 : 400);
}

function onResize() {
  if (window.innerWidth === lastWidth) return;
  measure();
}

onMounted(() => {
  measure();
  window.addEventListener('resize', onResize);
  // Tells MainLayout that whoever ends up inside the app authenticated during
  // this process rather than arriving on a session restored from disk, so it
  // does not meet the resume lock the moment it finishes signing in. See the
  // launch lock in MainLayout for the other half; sessionStorage is the signal
  // because the WebView clears it when the process dies and keeps it across
  // navigations and reloads, which is exactly the distinction being drawn.
  try {
    sessionStorage.setItem('accommo.authed.here', '1');
  } catch {
    // Storage unavailable: the launch lock simply asks for the PIN, which is
    // the safe side to fail on.
  }
});
onUnmounted(() => window.removeEventListener('resize', onResize));

const isSplash = computed(() => route.path === '/');

/**
 * Which shell is on screen: the phone's column, or the landscape card.
 *
 * Landscape used to be two shells — `auth-wide` for the splash, `auth-split`
 * for the forms — because the splash was a full-bleed photograph while the
 * forms cut the window in half. All four screens now share one 60/40 split, so
 * there is nothing to tell the splash apart from: one class covers them all,
 * and the halves are therefore identical across every navigation.
 */
const authShell = computed(() => (isTablet.value ? 'auth-split' : 'shell-column'));
const isLogin = computed(() => route.path === '/login');


// CHANGED: Now triggers for BOTH '/register' and '/register/manager'
const isRegister = computed(() => route.path.startsWith('/register'));

// Controls the direction of the animation
const transitionName = ref('splash-to-login');

// Watches the route to dynamically switch transitions
watch(
  () => route.path,
  (to, from) => {
    // Landscape: both halves are identical on every auth screen and neither
    // moves, so a navigation has one thing to animate — the panel's
    // contents. One
    // transition covers all of them rather than a direction per route pair: the
    // cards are alternatives to each other, not steps through a space, and
    // sliding them sideways only asked which way was "forward" between a
    // sign-in and a registration. The phone's vertical moves below belong to
    // its sheet, which really does hang from an edge.
    if (isTablet.value) {
      transitionName.value = 'card';
      return;
    }
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

/* Every move between the auth screens is a transform or an opacity, nothing
   else. This used to transition `top`, `height`, `min-/max-height`, the
   wordmark's `top` and its `font-size` — layout properties, so each frame of
   the 0.7s re-laid out the page, re-scaled the cover photo to its new height
   and repainted it under two gradients and a shadow. A desktop browser hid
   that; a phone's WebView dropped frames all the way through. Transforms and
   opacity run on the compositor without touching layout or paint.

   The container is a transparent full-screen box; the photograph and the
   wordmark inside it move independently. */
.hero-section {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100vh;
  height: var(--auth-vh);
  z-index: 1;
  pointer-events: none;
}

.hero-section.splash-mode {
  pointer-events: auto;
}

/* The photograph keeps the login band's own geometry — 400px tall, hung 80px
   above the top edge — in every state, so `background-size: cover` crops it
   exactly as it always has there (PinGate's lock screen copies that crop) and
   never re-scales mid-move. The other screens are reached by transforming it:

   - splash: scaled up to the full screen height. Scaled from 46% across, the
     same 46% as the background-position, it lands on the very crop `cover`
     gives at full height, so the splash looks as it did when the box itself
     was resized.
   - register: slid down so the band sits behind the sheet's foot. */
.hero-photo {
  position: absolute;
  top: -80px;
  left: 0;
  width: 100%;
  height: 400px;
  /* Solid brand ground underneath: kept even though the photo is now bundled,
     so the first frame is brand-coloured rather than blank while it decodes. */
  background-color: var(--m-primary-dark);
  background-image: var(--hero-bg, url('/isu-aerial.jpg'));
  background-size: cover;
  background-position: 46% center;
  transform-origin: 46% 0;
  transition: transform 0.7s cubic-bezier(0.25, 1, 0.3, 1);
  will-change: transform;
}

/* --auth-vh, not dvh: see the measurement in <script>. A keyboard opening must
   not move the photograph. */
.hero-section.splash-mode .hero-photo {
  transform: translateY(80px) scale(var(--hero-scale, 1));
}

/* The register sheet needs the height more than the photograph does: with a
   question, the Google button, four name fields and two consent rows, 160px of
   campus at the foot was the difference between fitting and scrolling. It gives
   up 48px of that — not all of it, because the wordmark and its line have to
   stay legible in what is left. The sheet and this offset are a pair: 112px of
   strip, with the hero content raised to sit inside it.
   Band top at --auth-vh - 184px, moved from its resting -80px. */
.hero-section.register-mode .hero-photo {
  transform: translateY(calc(var(--auth-vh) - 104px));
}

/* Two washes, one per look, cross-faded. A gradient cannot be interpolated, so
   the single overlay this replaces snapped from one to the other mid-move. */
.hero-overlay {
  position: absolute;
  inset: 0;
  transition: opacity 0.7s cubic-bezier(0.25, 1, 0.3, 1);
}

/* Login and register. The wash used to be 95%/85% teal, which painted the
   aerial out completely. A tint plus a scrim weighted to the top (where the
   wordmark sits) keeps the text well past AA while letting the campus show
   through.

   PinGate.vue's lock screen hand-copies this gradient so it can stand in for
   the login screen. Change one and the other must follow. */
.hero-overlay--band {
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

/* Splash only. Here the photograph is the point, so the wash drops to a tint
   and a bottom-weighted scrim carries the text contrast instead. It scales
   with the photo, so its stops still span the whole screen. */
.hero-overlay--splash {
  opacity: 0;
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

.hero-section.splash-mode .hero-overlay--splash {
  opacity: 1;
}

.hero-section.splash-mode .hero-overlay--band {
  opacity: 0;
}

/* The wordmark block, placed by translateY alone. The offsets are the screen
   positions it always had: 120px into a band that starts at -80px on login,
   the top corner on the splash, 90px into the band on register. */
.hero-content {
  position: absolute;
  left: 0;
  top: 0;
  width: 100%;
  padding: 0 24px;
  color: white;
  transform: translateY(40px);
  transition: transform 0.7s cubic-bezier(0.25, 1, 0.3, 1);
  will-change: transform;
}

/* The wordmark moves to the corner and shrinks; the pitch belongs to the page
   below, which can place it against the dark end of the scrim. */
.hero-section.splash-mode .hero-content {
  transform: translateY(calc(env(safe-area-inset-top) + 20px));
}

/* Raised with the hero, so the wordmark lands just under the sheet's rounded
   edge rather than off the bottom of the screen. */
.hero-section.register-mode .hero-content {
  transform: translateY(calc(var(--auth-vh) - 94px));
}

/* Always laid out at 38px; the splash's 26px is a scale, so the text never
   re-flows mid-move. Scaled from its top-left, where it is anchored. */
.logo-text {
  font-size: 38px;
  font-weight: 700;
  line-height: 1;
  transform-origin: 0 0;
  transition: transform 0.7s cubic-bezier(0.25, 1, 0.3, 1);
}

.hero-section.splash-mode .logo-text {
  transform: scale(0.6842); /* 26 / 38 */
}

.hero-subtitle {
  font-size: 14px;
  opacity: 0.95;
  transition: opacity 0.35s ease-out;
}

.hero-section.splash-mode .hero-subtitle {
  opacity: 0;
}

/* Placed and revealed by app.scss on the landscape shell; the phone's hero is a
   400px band with no room for it. */
.hero-pitch {
  display: none;
}

/* Short screens: a 300px band (heroScale in <script> follows the same
   breakpoint), with the wordmark 60px into it. */
@media (max-height: 600px) {
  .hero-photo {
    height: 300px;
  }
  .hero-section:not(.splash-mode):not(.register-mode) .hero-content {
    transform: translateY(-20px);
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

/* Landscape only. The card rises a little and fades up; the one leaving fades
   out where it stands. Short and small on purpose — the photograph behind is
   motionless, so a long or far-travelling move would read as the card sliding
   over a still photo rather than as the screen changing.

   The outgoing card leaves faster than the incoming one arrives, so the two are
   not both half-opaque over the same patch of photograph for long. */
.card-enter-active,
.card-leave-active {
  transition: transform 0.42s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.3s ease-out;
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.card-enter-from {
  opacity: 0;
  transform: translateY(14px);
}

.card-leave-to {
  opacity: 0;
  transition-duration: 0.18s;
}

@media (prefers-reduced-motion: reduce) {
  .card-enter-active,
  .card-leave-active {
    transition: opacity 0.2s ease-out;
  }
  .card-enter-from {
    transform: none;
  }
}
</style>