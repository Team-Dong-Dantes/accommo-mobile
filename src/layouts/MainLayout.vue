<template>
  <!-- .shell-column in phone mode, which includes a portrait tablet: one
       full-width column (see app.scss). Tablet landscape gets .shell-tablet and
       its panes. -->
  <q-layout view="hHh Lpr fFf" :class="isTablet ? 'shell-tablet' : 'shell-column'">
    <q-header
      v-if="!immersive"
      class="app-header"
      :class="{ 'is-scrolled': scrolled || hasFloatingMap, 'app-header--subpage': isSubPage }"
    >
      <div class="header-row q-px-md">
        <template v-if="subPage">
          <q-btn
            flat
            round
            dense
            class="setup-back-button"
            aria-label="Back"
            @click="goBack"
          >
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </q-btn>
          <h1 class="setup-page-title text-weight-bold">{{ pageTitleOverride ?? subPage.title }}</h1>
          <span class="header-balance" aria-hidden="true" />
        </template>

        <template v-else>
          <div class="app-title text-weight-bold">accommo</div>
          <h1 v-if="isDesktop" class="desk-page-title">{{ deskTitle }}</h1>
          <q-btn
            flat
            round
            dense
            class="header-notif-button"
            aria-label="Notifications"
            @click="goToNotifications"
          >
            <IconifyIcon icon="lucide:bell" width="22" />
            <span v-if="notifications.unread > 0" class="header-notif-dot" />
          </q-btn>
        </template>
      </div>

      <!-- Notice first: while it is up it hides the banner (app.scss, .fcard). -->
      <InAppNotice :role="role" />
      <BroadcastBanner :role="role" />
    </q-header>

    <q-page-container class="page-container">
      <!-- Tablet mode splits the stage in two: the list this screen belongs to
           on the left, the screen itself on the right. useShellPanes works it
           out from the same secondaryPages table the back button uses, so the
           pairing cannot drift from it. In phone mode panes.mode is always
           "single" and this renders exactly what it always did. -->
      <div class="page-stage" :class="{ 'page-stage--split': panes.mode === 'split' }">
        <!-- The list pane. Kept alive on its own so its scroll position and
             loaded data survive picking one item after another — without it,
             every tap would remount the list beside the detail. -->
        <div v-if="panes.mode === 'split'" class="pane pane--list">
          <keep-alive :max="4">
            <component :is="panes.listComponent" :key="panes.listPath" />
          </keep-alive>
        </div>

        <div :class="panes.mode === 'split' ? 'pane pane--detail' : null">
          <!-- Nothing picked yet. Naming what the pane is waiting for beats a
               blank half-screen, which reads as a failure to load. -->
          <!-- Desktop Discover: its map teleports in here and is the right half
               until a listing is opened over it. Hidden, not unmounted, so the
               map keeps its camera for the way back. -->
          <div v-if="discoverMapSlot" v-show="panes.mode === 'split' && !panes.detailOpen" id="desk-map-slot" class="pane-map" />
          <div
            v-if="panes.mode === 'split' && !panes.detailOpen"
            v-show="!discoverMapSlot"
            class="pane-empty"
          >
            <IconifyIcon icon="lucide:mouse-pointer-click" width="26" />
            <p>{{ panes.hint }}</p>
          </div>

          <template v-else>
          <!-- Discover's detail covers its map; this is the way back to it. -->
          <header v-if="discoverMapSlot" class="desk-panel-bar pane-back-bar">
            <button type="button" class="desk-panel-back" aria-label="Back" @click="backInPane">
              <IconifyIcon icon="lucide:arrow-left" width="20" />
            </button>
            <span class="desk-panel-title">{{ pageTitleOverride ?? matchSecondary(route.path, config)?.title }}</span>
          </header>
          <router-view v-slot="{ Component }">
            <transition name="page">
              <keep-alive :include="KEEP_ALIVE_PAGES" :max="20">
                <component :is="Component" :key="pageKey" />
              </keep-alive>
            </transition>
          </router-view>
          </template>
        </div>
      </div>
    </q-page-container>

    <!-- One navigation, two presentations. The rail is always up in tablet
         mode: a sub-page there fills the detail pane beside its list rather
         than replacing the screen, so there is nothing for it to hide behind
         the way a phone sub-page hides the footer. -->
    <DesktopRail
      v-if="isDesktop"
      :tabs="displayTabs"
      :active="activeBottomTab"
      :actions="displayQuickActions"
      :account-actions="railAccountActions"
      :path="route.path"
      :avatar-url="profileImageUrl"
      :initials="userInitials"
      @select="goToTab"
      @navigate="navigateMenuAction"
    />

    <SideRail
      v-else-if="isTablet"
      :tabs="displayTabs"
      :active="activeBottomTab"
      :avatar-url="profileImageUrl"
      :initials="userInitials"
      :menu-open="menuOpen"
      @select="goToTab"
    />

    <q-footer
      v-else-if="!isSubPage && !immersive"
      class="bottom-footer"
    >
      <BottomNav
        :tabs="displayTabs"
        :active="activeBottomTab"
        :avatar-url="profileImageUrl"
        :initials="userInitials"
        :menu-open="menuOpen"
        @select="goToTab"
      />
    </q-footer>

    <TermsGate />

    <QuickActions
      v-if="!immersive"
      v-model:open="menuOpen"
      :account-actions="accountActions"
      :actions="displayQuickActions"
      :avatar-url="profileImageUrl"
      :initials="userInitials"
      :menu-id="`${role}-menu`"
      @navigate="navigateMenuAction"
    />

    <!-- One confirmation card for the whole app. Renders nothing until something asks. -->
    <ConfirmGate />
    <!-- One PIN pad for the whole app, and the resume lock. Renders nothing until something asks. -->
    <PinGate @forgot="goToSecuritySettings" />
  </q-layout>
</template>

<script setup lang="ts">
import BottomNav from '@/components/layout/BottomNav.vue'
import BroadcastBanner from '@/components/shared/BroadcastBanner.vue'
import ConfirmGate from '@/components/shared/ConfirmGate.vue'
import DesktopRail from '@/components/layout/DesktopRail.vue'
import InAppNotice from '@/components/shared/InAppNotice.vue'
import PinGate from '@/components/shared/PinGate.vue'
import QuickActions from '@/components/layout/QuickActions.vue'
import SideRail from '@/components/layout/SideRail.vue'
import TermsGate from '@/components/shared/TermsGate.vue'
import { isDesktop, isTablet } from '@/utils/useTabletMode'
import { pageTitleOverride } from '@/utils/pageTitle'
import { useShell } from './shell/useShell'
import { usePinLock } from './shell/pinLock'

// The shell's state lives in ./shell/; this is its markup.
const {
  route,
  notifications,
  role,
  config,
  pageKey,
  displayTabs,
  displayQuickActions,
  accountActions,
  railAccountActions,
  userInitials,
  profileImageUrl,
  menuOpen,
  scrolled,
  activeBottomTab,
  matchSecondary,
  subPage,
  isSubPage,
  deskTitle,
  hasFloatingMap,
  panes,
  backInPane,
  discoverMapSlot,
  immersive,
  goToTab,
  goToNotifications,
  goBack,
  navigateMenuAction,
} = useShell()
const { goToSecuritySettings } = usePinLock(role)

// Bottom-nav tabs + the other singleton screens (no route param — one
// instance ever exists) kept alive across navigation instead of remounting
// (and re-running their loading skeleton) every time. Matched by Vue's
// auto-assigned `__name` (from each file's filename) — none of these declare
// an explicit name, and both Messages routes resolve to their per-role
// wrapper file, not the shared MessagesPage.vue they render.
//
// TenantProfile and StudentManagerPage are the two exceptions: both are
// per-id drill-downs (:leaseId / :id). They're still safe to include because
// the `:key="route.fullPath"` on the <component> above gives each distinct
// id its own cache entry — without that key, keep-alive would reuse the same
// cached instance across different tenants/managers and show stale data.
// Every other per-id screen (AccommodationDetail, StudentListingPage,
// StudentRoomPage) is deliberately left out: they're opened once and left,
// so there's no repeat visit to speed up, and it's not worth growing the
// cache for.
const KEEP_ALIVE_PAGES = [
  'ManagerDashboard', 'ManagerTenantsPage', 'ManagerMessagesPage', 'ManagerProfilePage',
  'StudentDashboard', 'StudentDiscoverPage', 'StudentMessagesPage', 'StudentProfilePage',
  'ManagerAccommodationsPage', 'ManagerConcernsPage', 'ManagerOsasPage', 'TenantProfile',
  'StudentPropertiesPage', 'StudentOsasPage', 'StudentConcernsPage', 'StudentStayPage', 'StudentManagerPage',
  // The two History screens are the heaviest reads in the app (payments +
  // reviews + boarding history) and are revisited often. Kept alive so
  // useLiveData's TTL can actually apply — without keep-alive they remount and
  // refetch everything on every visit, which is what they used to do.
  'StudentHistoryPage', 'ManagerHistoryPage',
]
</script>

<style scoped>
.app-header {
  /* Top offset lives in padding, not margin: Quasar reserves page-container
     space by measuring the header's offsetHeight, which counts padding but
     not margin. A margin-top here would visually push the header down while
     leaving the page's reserved space too short by that amount — the page
     starts under the header instead of below it. */
  margin: 0 12px 0;
  padding-top: calc(env(safe-area-inset-top, 0px) + 6px);
  /* Quasar's fixed-top header carries no z-index of its own, so it only
     outranks plain in-flow content. Any page element that is ALSO
     positioned (position: relative/absolute, z-index: auto — common for
     card overlays) ties with it in the same paint step and, being later in
     the DOM, wins — it scrolls up and paints over the header. bottom-footer
     already sets its own z-index below; the header needs the same. */
  z-index: 50;
  color: var(--m-ink);
  /* Always transparent, full height including the safe-area padding above.
     The visible "card" (background, border, blur, shadow) lives on
     .header-row below instead of here — otherwise it paints across the
     status-bar band too, since that band is this element's own padding-top
     and background fills the whole border box, padding included. */
  border: 0;
  background: transparent;
  box-shadow: none !important;
}
.app-header--subpage {
  height: calc(56px + env(safe-area-inset-top, 0px));
  margin: 0;
  /* No floating-pill gap here — this bar runs edge to edge, so only the
     status-bar inset belongs in its padding, not the base rule's extra 6px. */
  padding-top: env(safe-area-inset-top, 0px);
  box-sizing: border-box;
}
.app-header--subpage .header-row {
  height: 55px;
  min-height: 55px;
  align-items: center;
  border-radius: 0;
  border-width: 0 0 1px;
}
.header-row {
  display: flex;
  min-height: 56px;
  align-items: center;
  justify-content: space-between;
  border: 1px solid transparent;
  /* Quasar's dark-mode chrome puts a translucent white border-color on
     q-header by default — override it explicitly or it shows through as an
     outline even though this rule already sets the border transparent. */
  border-color: transparent !important;
  border-radius: var(--m-radius-lg);
  background: transparent;
  transition: background-color .25s ease, backdrop-filter .25s ease, -webkit-backdrop-filter .25s ease, border-color .25s ease, box-shadow .25s ease;
}
.app-header:not(.is-scrolled) :deep(.q-layout__shadow) {
  display: none;
}
.app-header.is-scrolled .header-row {
  border-color: var(--m-border) !important;
  background: color-mix(in srgb, var(--m-bg) 72%, transparent);
  box-shadow: 0 6px 18px rgba(15, 23, 42, .06) !important;
  -webkit-backdrop-filter: blur(14px) saturate(140%);
  backdrop-filter: blur(14px) saturate(140%);
}
.app-header--subpage .header-row {
  background: var(--m-surface);
}
.app-title {
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.04em;
  text-transform: lowercase;
  color: var(--m-ink);
}
.desk-page-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.02em;
  color: var(--m-ink);
}
.setup-page-title {
  flex: 1 1 auto;
  margin: 0;
  display: flex;
  height: 44px;
  align-items: center;
  font-size: 18px;
  line-height: 1;
  letter-spacing: -0.02em;
  color: var(--m-ink);
}
.header-balance { width: 44px; height: 44px; }
.setup-back-button {
  height: 44px;
  min-width: 44px;
  min-height: 44px;
  margin-left: -8px;
  color: var(--m-ink);
}
.header-notif-button {
  position: relative;
  min-width: 40px;
  min-height: 40px;
  color: var(--m-ink);
}
.header-notif-dot {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--m-danger, #b42318);
  border: 1.5px solid var(--m-surface);
}
.bottom-footer {
  min-height: 52px;
  height: calc(52px + env(safe-area-inset-bottom, 0px));
  padding-bottom: env(safe-area-inset-bottom, 0px);
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 50;
  /* BottomNav draws the bar itself, notch and hairline included. */
  background: transparent;
  color: var(--m-text);
}
.page-container {
  background: var(--m-bg);
}
.page-stage { position: relative; min-height: 100%; overflow-x: clip; }

/* Two panes, one scroll each, half the stage apiece. An even split says the list
   and what is open from it are two views of equal standing, rather than a phone
   list with a detail parked next to it. */
.page-stage--split {
  display: grid;
  height: 100%;
  grid-template-columns: 1fr 1fr;
}
.pane {
  position: relative;
  height: 100%;
  min-width: 0;
  overflow-y: auto;
}
.pane-back-bar {
  position: sticky;
  top: 0;
  z-index: 5;
  background: var(--m-surface);
}
.pane-map {
  position: relative;
  height: 100%;
}
.pane--list {
  border-right: 1px solid var(--m-border);
}
[data-nav=page-slide-left] .page-enter-active,
[data-nav=page-slide-right] .page-leave-active {
  position: absolute;
  z-index: 1;
  inset: 0;
  width: 100%;
  background: var(--m-bg);
  box-shadow: -10px 0 24px rgba(15, 23, 42, .14);
  transition: transform 260ms cubic-bezier(.22, .61, .36, 1), box-shadow 260ms ease-out;
}
[data-nav=page-slide-left] .page-enter-from { transform: translateX(100%); }
[data-nav=page-slide-left] .page-enter-to { transform: translateX(0); }
[data-nav=page-slide-left] .page-leave-active { transition: opacity 260ms linear; }
[data-nav=page-slide-left] .page-leave-to { opacity: .99; }
[data-nav=page-slide-right] .page-leave-to { transform: translateX(100%); }
[data-nav=page-fade] .page-enter-active,
[data-nav=page-fade] .page-leave-active { transition: opacity 120ms ease-out; }
/* Tab to tab: the leaving page is lifted out of the flow and laid over the
   arriving one. Left in flow, the arriving page was laid out under it, its top
   edge exactly at the bottom bar's, and showed through the bar's notch behind
   the centre button for the length of the fade. */
[data-nav=page-fade] .page-leave-active {
  position: absolute;
  top: 0;
  left: 0;
  z-index: 1;
  width: 100%;
}
/* The box a page lives in, so a page lifted out of the flow keeps that box's
   width (a centred column on a tablet) rather than the whole stage's. */
.page-stage > div {
  position: relative;
}
[data-nav=page-fade] .page-enter-from,
[data-nav=page-fade] .page-leave-to { opacity: 0; }
/* Tenants <-> a tenant on desktop. The leaving page is lifted out of the flow
   and laid over the arriving one — two pages in flow at once would stack, and
   the card would jump down by a whole page for the length of the fade. Its box
   is the page's own container, made positioned for this in app.scss. */
/* Only the leaving page fades: the arriving one is already solid underneath,
   so the card's frame — identical in both — never dims mid-swap. */
[data-nav=page-swap] .page-leave-active {
  position: absolute;
  inset: 0;
  z-index: 1;
  transition: opacity 160ms ease-out;
}
[data-nav=page-swap] .page-leave-to {
  opacity: 0;
}
@media (prefers-reduced-motion: reduce) {
  [data-nav] .page-enter-active,
  [data-nav] .page-leave-active { transition: none; }
}
</style>
