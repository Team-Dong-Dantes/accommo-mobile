<template>
  <!-- .shell-column in phone mode only: on a portrait tablet it keeps the app
       in the column its screens were drawn for, and pulls every fixed overlay in
       with it (see app.scss). In tablet mode the shell is the full screen,
       because the panes are what fills it. -->
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
            :aria-label="`Back to ${subPage.backLabel}`"
            @click="goBack"
          >
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </q-btn>
          <h1 class="setup-page-title text-weight-bold">{{ subPage.title }}</h1>
          <span class="header-balance" aria-hidden="true" />
        </template>

        <template v-else>
          <div class="app-title text-weight-bold">accommo</div>
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
          <div v-if="panes.mode === 'split' && !panes.detailOpen" class="pane-empty">
            <IconifyIcon icon="lucide:mouse-pointer-click" width="26" />
            <p>{{ panes.hint }}</p>
          </div>

          <router-view v-else v-slot="{ Component }">
            <transition :name="pageTransition">
              <keep-alive :include="KEEP_ALIVE_PAGES" :max="20">
                <component :is="Component" :key="pageKey" />
              </keep-alive>
            </transition>
          </router-view>
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
      bordered
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

    <!-- One PIN pad for the whole app. Renders nothing until something asks. -->
    <PinGate @forgot="goToSecuritySettings" />

    <!-- Same shape as the delete confirmations in AccommodationDetail: grip,
         warning header, then Cancel beside the destructive action. -->
    <q-dialog v-model="signOutConfirmOpen" position="bottom">
      <q-card class="confirm-sheet">
        <span class="confirm-grip" aria-hidden="true" />
        <div class="confirm-header">
          <span class="confirm-header-icon"><IconifyIcon icon="lucide:log-out" width="18" /></span>
          <h3 class="confirm-title">Sign out?</h3>
        </div>
        <p class="confirm-hint">
          You'll need your e-mail and password to get back in.
        </p>
        <div class="confirm-actions">
          <button type="button" class="confirm-ghost" :disabled="signingOut" @click="signOutConfirmOpen = false">
            Cancel
          </button>
          <button type="button" class="confirm-danger" :disabled="signingOut" @click="signOut">
            {{ signingOut ? 'Signing out…' : 'Sign out' }}
          </button>
        </div>
      </q-card>
    </q-dialog>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase, authUser } from '@/utils/supabase'
import { useNotificationsStore } from '@/stores/notifications'
import { useMessagesStore } from '@/stores/messages'
import { initialsOf } from '@/utils/format'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import { Capacitor } from '@capacitor/core'
import DesktopRail from '@/components/layout/DesktopRail.vue'
import { useShellPanes, PANE_LISTS } from '@/utils/useShellPanes'
import BottomNav from '@/components/layout/BottomNav.vue'
import SideRail from '@/components/layout/SideRail.vue'
import TermsGate from '@/components/shared/TermsGate.vue'
import BroadcastBanner from '@/components/shared/BroadcastBanner.vue'
import QuickActions from '@/components/layout/QuickActions.vue'
import PinGate from '@/components/shared/PinGate.vue'
import { usePinStore, RESUME_LOCK_MS } from '@/stores/pin'
import { lockApp, settlePin } from '@/utils/requirePin'
import { clearAllCache } from '@/utils/persistCache'
import type { QuickAction, SecondaryPage, ShellConfig } from '@/types/app-types'
import { countLeasesAwaitingManager } from '@/api/leases';

const router = useRouter()
const route = useRoute()
const notifications = useNotificationsStore()
const messagesStore = useMessagesStore()
const pin = usePinStore()

/**
 * Lock the app when it comes back after sitting in the background. This is the
 * half of the PIN feature that covers *reads* — private messages, tenant phone
 * numbers, a student's uploaded school ID — none of which any per-action gate
 * can protect, because none of them are actions.
 *
 * `visibilitychange` is the cross-platform signal and works in the browser
 * during development; the Capacitor App plugin adds the native foreground
 * event, which fires in cases the web event misses.
 */
function onHidden() {
  pin.backgroundedAt = Date.now()
}

function onVisible() {
  const away = pin.backgroundedAt ? Date.now() - pin.backgroundedAt : 0
  pin.backgroundedAt = 0
  if (away > RESUME_LOCK_MS) void lockApp()
}

/**
 * The other half of the resume lock: the app being closed outright.
 *
 * `backgroundedAt` lives in memory, and `visibilitychange` does not fire on a
 * first paint, so a cold launch measured no time away and never locked —
 * swiping the app out of recents and reopening it walked straight into messages
 * and tenant records with the PIN never asked for. That is the easiest phone-in-
 * hand bypass there was, and it is the exact threat the PIN exists for.
 *
 * A launch is treated as "away long enough" unconditionally. The one case that
 * must not lock is having just signed in, which AuthLayout marks as it goes.
 */
function lockIfColdLaunch() {
  let authedHere = false
  try {
    authedHere = sessionStorage.getItem('accommo.authed.here') === '1'
  } catch {
    // Unreadable storage: fall through and ask for the PIN.
  }
  if (!authedHere) void lockApp()
}

function onVisibilityChange() {
  if (document.visibilityState === 'hidden') onHidden()
  else onVisible()
}

// One shell, two configurations. The role is read from the path so the chrome
// renders correctly on first paint, with no async role lookup flicker.
const SHELLS: Record<'manager' | 'student', ShellConfig> = {
  manager: {
    home: '/manager/dashboard',
    notifications: '/manager/notifications',
    tabs: [
      { name: 'home', route: '/manager/dashboard', icon: 'lucide:house', label: 'Home' },
      { name: 'tenants', route: '/manager/tenants', icon: 'lucide:users', label: 'Tenants', match: ['/manager/tenant/'] },
      { name: 'messages', route: '/manager/messages', icon: 'lucide:message-circle', label: 'Messages' },
      { name: 'menu', route: '/manager/profile', icon: 'lucide:menu', label: 'Menu' },
    ],
    quickActions: [
      { icon: 'lucide:shield-check', label: 'OSAS', route: '/manager/osas' },
      { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/manager/support' },
      { icon: 'lucide:building-2', label: 'My Properties', route: '/manager/properties' },
      { icon: 'lucide:megaphone', label: 'Announce', route: '/manager/announcements' },
    ],
    secondaryPages: [
      { path: '/manager/profile', title: 'Profile', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/settings', title: 'Settings', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/profile/qr-scanner', title: 'QR scanner', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/profile/history', title: 'History', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/settings/policies', title: 'Policies & Guidelines', back: '/manager/settings', backLabel: 'settings' },
      { path: '/manager/notifications', title: 'Notifications', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/announcements', title: 'Announce', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: /^\/manager\/announcement\/[^/]+$/, title: 'Announcement', back: '/manager/notifications', backLabel: 'notifications' },
      { path: /^\/manager\/person\/[^/]+$/, title: 'Profile', back: '/manager/messages', backLabel: 'messages' },
      { path: '/manager/osas', title: 'OSAS', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/support', title: 'Concerns', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: /^\/manager\/tenant\/[^/]+$/, title: 'Tenant', back: '/manager/tenants', backLabel: 'tenants' },
      { path: '/manager/properties', title: 'My Properties', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/properties/new', title: 'New Accommodation', back: '/manager/properties', backLabel: 'my properties' },
      { path: /^\/manager\/properties\/[^/]+$/, title: 'Accommodation Details', back: '/manager/properties', backLabel: 'my properties' },
    ],
  },
  student: {
    home: '/student/home',
    notifications: '/student/notifications',
    tabs: [
      { name: 'home', route: '/student/home', icon: 'lucide:house', label: 'Home' },
      { name: 'discover', route: '/student/discover', icon: 'lucide:search', label: 'Discover' },
      { name: 'messages', route: '/student/messages', icon: 'lucide:message-circle', label: 'Messages' },
      { name: 'menu', route: '/student/profile', icon: 'lucide:menu', label: 'Menu' },
    ],
    quickActions: [
      { icon: 'lucide:shield-check', label: 'OSAS', route: '/student/support' },
      { icon: 'lucide:home', label: 'My Stay', route: '/student/stay' },
      { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/student/concerns' },
    ],
    secondaryPages: [
      { path: '/student/profile', title: 'Profile', back: '/student/home', backLabel: 'home' },
      { path: '/student/settings', title: 'Settings', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/profile/qr', title: 'My QR', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/profile/history', title: 'History', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/settings/policies', title: 'Policies & Guidelines', back: '/student/settings', backLabel: 'settings' },
      { path: '/student/notifications', title: 'Notifications', back: '/student/home', backLabel: 'home' },
      { path: /^\/student\/announcement\/[^/]+$/, title: 'Announcement', back: '/student/notifications', backLabel: 'notifications' },
      { path: /^\/student\/person\/[^/]+$/, title: 'Profile', back: '/student/messages', backLabel: 'messages' },
      { path: '/student/support', title: 'OSAS', back: '/student/home', backLabel: 'home' },
      { path: '/student/concerns', title: 'Concerns', back: '/student/home', backLabel: 'home' },
      { path: '/student/stay', title: 'My Stay', back: '/student/home', backLabel: 'home' },
      { path: '/student/payments', title: 'Payments', back: '/student/home', backLabel: 'home' },
      { path: /^\/student\/listing\/[^/]+$/, title: 'Listing', back: '/student/discover', backLabel: 'discover' },
      { path: '/student/properties', title: 'Properties', back: '/student/discover', backLabel: 'discover' },
      { path: /^\/student\/room\/[^/]+$/, title: 'Room', back: '/student/discover', backLabel: 'discover' },
      { path: /^\/student\/manager\/[^/]+$/, title: 'Landlord/Landlady', back: '/student/discover', backLabel: 'discover' },
    ],
  },
}

const role = computed<'manager' | 'student'>(() =>
  route.path.startsWith('/manager') ? 'manager' : 'student',
)
const config = computed(() => SHELLS[role.value])

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

// Pages that show their list beside the open item on desktop and pick the item
// by query (?c= a thread, ?t= a ticket). Keyed by fullPath, every pick remounted
// the whole page, list and scroll position included; keyed by path, the page
// (which reads the query reactively) swaps just the item.
const SELF_SPLITTING = ['/manager/messages', '/student/messages', '/manager/osas', '/student/support']
const pageKey = computed(() =>
  isDesktop.value && SELF_SPLITTING.includes(route.path) ? route.path : route.fullPath,
)

/**
 * Which desktop card a path belongs to: a list shown in a pane (or Tenants,
 * which splits itself), for the list and for every detail whose `back` is it.
 * Moving within one card swaps its contents in place (no slide, no back bar).
 */
function cardOf(path: string | undefined): string | null {
  if (!path) return null
  const lists = [...PANE_LISTS, '/manager/tenants']
  if (lists.includes(path)) return path
  const back = matchSecondary(path, SHELLS[path.startsWith('/manager') ? 'manager' : 'student'])?.back
  return back && lists.includes(back) ? back : null
}

// Same tabs, with the live unread count from the messages store folded onto
// the 'messages' entry — kept separate from SHELLS so that config stays a
// plain static lookup.
const displayTabs = computed(() =>
  config.value.tabs.map((tab) => {
    if (tab.name === 'messages') return { ...tab, badge: messagesStore.totalUnread }
    if (tab.name === 'tenants') return { ...tab, dot: tenantsNeedCheck.value }
    if (tab.name === 'discover') return { ...tab, dot: discoverNeedCheck.value }
    if (tab.name === 'menu') return { ...tab, dot: profileNeedsCheck.value }
    return tab
  }),
)

// Same idea for the quick-action menu, so both roles' Concerns entry carries
// the same kind of self-clearing signal.
const CONCERNS_ROUTE: Record<'manager' | 'student', string> = {
  manager: '/manager/support',
  student: '/student/concerns',
}
const displayQuickActions = computed(() =>
  config.value.quickActions.map((action) =>
    action.route === CONCERNS_ROUTE[role.value] ? { ...action, dot: concernsNeedCheck.value } : action,
  ),
)

// The hamburger tab (bottom nav's old profile slot) opens this menu: Profile
// and Settings up top, then the role's quick actions below, all in one card.
// The third row is role-specific: a landlord/landlady scans student QR codes, a
// student shows their own.
const accountActions = computed(() => {
  const profileRoute = config.value.tabs.find((t) => t.name === 'menu')?.route ?? config.value.home
  const items: QuickAction[] = [
    { icon: 'lucide:user', label: 'Profile', route: profileRoute, avatar: true },
    // Settings is its own destination, not a child of Profile — hence the
    // role path rather than profileRoute. Scanner/QR below genuinely are
    // profile screens and keep hanging off it.
    { icon: 'lucide:settings', label: 'Settings', route: `/${role.value}/settings` },
  ]
  // The scanner is a phone held up to a phone; a browser has no business with it.
  if (role.value === 'manager') {
    if (Capacitor.isNativePlatform()) {
      items.push({ icon: 'lucide:scan', label: 'Scanner', route: `${profileRoute}/qr-scanner` })
    }
  } else {
    items.push({ icon: 'lucide:qr-code', label: 'My QR', route: `${profileRoute}/qr` })
  }
  // Last in the account group, directly under My QR / Scanner. Not a route —
  // navigateMenuAction intercepts this sentinel; see SIGN_OUT.
  items.push({ icon: 'lucide:log-out', label: 'Sign out', route: SIGN_OUT, danger: true })
  return items
})

// The desktop rail has no Menu tab to carry the needs-checking dot, so it moves
// onto the Profile row, which is where the thing being flagged lives.
const railAccountActions = computed(() =>
  accountActions.value.map((a) => (a.avatar ? { ...a, dot: profileNeedsCheck.value } : a)),
)

const userInitials = ref('U')
const profileImageUrl = ref<string | null>(null)
// Needs-checking dots: each is a plain existence check against a status that
// clears itself the moment the underlying row is acted on, so there's no
// separate "seen/unseen" state to maintain — except discover/concerns below,
// which use a rolling time window instead (see loadNeedsCheckDots).
const tenantsNeedCheck = ref(false)
const profileNeedsCheck = ref(false)
const concernsNeedCheck = ref(false)
const discoverNeedCheck = ref(false)
const menuOpen = ref(false)
const scrolled = ref(false)
const activeBottomTab = ref('home')
const pageTransition = ref('page-fade')
// Where the user actually was before landing on the current sub-page — a
// sub-page like Settings or Concerns is reachable from anywhere via the
// hamburger menu, so its back button must return there, not to a fixed
// parent. Falls back to the sub-page's configured `back` route when there's
// no prior in-session path (a fresh load or deep link straight into it).
const lastPath = ref<string | null>(null)

function matchSecondary(path: string, shell: ShellConfig): SecondaryPage | undefined {
  return shell.secondaryPages.find((entry) =>
    typeof entry.path === 'string' ? entry.path === path : entry.path.test(path),
  )
}

// On desktop a detail shown inside a card has its way back right there — its
// list in the pane beside it (a listing beside Discover, an announcement beside
// Notifications), or a back button on the card itself (TenantProfile,
// AccommodationDetail) — so the header stays the plain one, not a back bar.
const OWN_BACK = /^\/manager\/(tenant\/[^/]+|properties\/(?!new$)[^/]+)$/
const subPage = computed(() =>
  isDesktop.value && (panes.value.mode === 'split' || OWN_BACK.test(route.path))
    ? undefined
    : matchSecondary(route.path, config.value),
)
const isSubPage = computed(() => Boolean(subPage.value))

// Discover runs its map full-bleed behind this header instead of below it,
// so the header needs its scrolled-state card background always — a plain
// transparent header over a map (rather than over the page's own solid
// background) leaves its icons floating with no backing.
const hasFloatingMap = computed(() => route.path === '/student/discover')

// Which panes the stage shows. Single in phone mode, always — the composable
// short-circuits on isTablet before it looks at anything else.
const panes = useShellPanes(() => config.value, () => isTablet.value)

// An open thread or ticket covers the screen on a phone, so the chrome steps
// aside. In tablet mode it fills the detail pane instead, beside a list that is
// still on screen — there is nothing to step aside for, and hiding the rail
// would strand the one thing that navigates. Resolved here rather than in each
// page so every screen that raises chatFullscreen gets it.
const immersive = computed(() => chatFullscreen.value && !isTablet.value)

function goToTab(tabName: string) {
  if (tabName === 'menu') {
    menuOpen.value = !menuOpen.value
    return
  }
  menuOpen.value = false
  const tab = config.value.tabs.find((item) => item.name === tabName)
  if (tab) void router.push(tab.route)
}

function goToNotifications() {
  void router.push(config.value.notifications)
}

function goBack() {
  void router.push(lastPath.value ?? subPage.value?.back ?? config.value.home)
}

/**
 * Not a real path. The menu is route-driven, and Sign out is the one row that
 * acts instead of navigating, so it travels as a sentinel the handler below
 * intercepts — cheaper than giving QuickActions a second event for one row.
 */
const SIGN_OUT = '#sign-out'

const signOutConfirmOpen = ref(false)
const signingOut = ref(false)

async function signOut() {
  if (signingOut.value) return
  signingOut.value = true
  try {
    // Stop the realtime subscriptions before dropping the session: this layout
    // owns them (see onUnmounted), and leaving them open would carry one user's
    // channels into the next sign-in on the same device.
    notifications.stop()
    messagesStore.stop()
    // Drop the unlock and the has-PIN answer with the session, so the next
    // account on this device is never treated as already unlocked.
    pin.lock()
    pin.hasPin = false
    pin.ready = false
    // Same reasoning as the channels above: a cached dashboard/listing from
    // this account must not flash on screen for the next one who signs in.
    clearAllCache()
    await supabase.auth.signOut()
    signOutConfirmOpen.value = false
    void router.push('/login')
  } finally {
    signingOut.value = false
  }
}

function navigateMenuAction(path: string) {
  menuOpen.value = false
  if (path === SIGN_OUT) {
    signOutConfirmOpen.value = true
    return
  }
  void router.push(path)
}

watch(
  () => route.path,
  (path, previousPath) => {
    const shell = SHELLS[path.startsWith('/manager') ? 'manager' : 'student']

    // Slide when moving between the main shell and a sub-page; fade otherwise.
    const entering = Boolean(matchSecondary(path, shell))
    const leaving = Boolean(previousPath && matchSecondary(previousPath, shell))

    // Only refresh "where the user was" when arriving from a main-shell page.
    // A sub-page reached from another sub-page (Profile → Settings, Profile →
    // History) doesn't overwrite it, so back from Settings skips the Profile
    // stepping-stone and returns to the real page underneath both.
    if (previousPath && !leaving) lastPath.value = previousPath

    pageTransition.value =
      entering && !leaving ? 'page-slide-left' : leaving && !entering ? 'page-slide-right' : 'page-fade'

    // On desktop, moving within one card (a list and its details) changes that
    // card's contents in place; a slide would say "new page".
    const card = cardOf(path)
    if (isDesktop.value && card && card === cardOf(previousPath)) pageTransition.value = 'page-swap'

    if (entering) menuOpen.value = false

    const active = shell.tabs.find((tab) =>
      [tab.route, ...(tab.match ?? [])].some((prefix) => path.startsWith(prefix)),
    )
    activeBottomTab.value = active?.name ?? 'home'

    // Vue Router doesn't reset scroll on navigation, so a page you'd
    // scrolled down on leaves the next one visually mid-scroll too — and the
    // header keeps its scrolled border since the viewport genuinely is still
    // scrolled. Every tab/page should start at its own top.
    window.scrollTo(0, 0)
    document.querySelector('.q-page-container')?.scrollTo(0, 0)
    void nextTick(onScroll)
  },
  { immediate: true },
)

onMounted(async () => {
  window.addEventListener('scroll', onScroll, true)
  window.addEventListener('accommo:avatar-change', onAvatarChange)
  document.addEventListener('visibilitychange', onVisibilityChange)
  document.querySelector('.q-page-container')?.addEventListener('scroll', onScroll)
  onScroll()
  // Answers "does this account have a PIN at all" once. Gates no longer race
  // it: requirePin() and lockApp() both await pin.ensureReady(), which joins
  // this same call rather than issuing a second one.
  void pin.refresh()
  lockIfColdLaunch()
  try {
    const { data } = await authUser()
    const user = data?.user
    if (!user) return

    const metadata = user.user_metadata as Record<string, unknown> | undefined
    const picture =
      typeof metadata?.avatar_url === 'string'
        ? metadata.avatar_url
        : typeof metadata?.picture === 'string'
          ? metadata.picture
          : ''
    profileImageUrl.value = picture ? resolveAsset(picture, AVATAR) : null

    const { data: userData } = await supabase
      .from('users')
      .select('initials, full_name, avatar_url')
      .eq('id', user.id)
      .maybeSingle()

    const row = userData as { initials: string | null; full_name: string | null; avatar_url: string | null } | null
    userInitials.value =
      row?.initials || initialsOf(String(row?.full_name || metadata?.full_name || user.email || 'User'))

    // Fall back to the stored column when this session's metadata has no
    // picture — it can be stale or empty (avatar uploaded on another device,
    // or written straight to the database), which otherwise left the shell
    // showing initials despite a photo being on file.
    if (!picture && row?.avatar_url) profileImageUrl.value = resolveAsset(row.avatar_url, AVATAR)

    // Keeps users.avatar_url (the only copy anyone but this user can ever
    // read) in step with the auth session's own picture — a Google sign-in
    // never writes it directly, and a Cloudinary upload's write in
    // uploadAvatar() can't cover a photo change made on Google's side.
    if (picture && row?.avatar_url !== picture) {
      void supabase.from('users').update({ avatar_url: picture }).eq('id', user.id)
    }

    void loadNeedsCheckDots(user.id)

    // Subscribes once for the session; the notifications page reuses the same
    // store, so a row marked read there clears this dot immediately.
    await notifications.start(user.id)
    // Same idea for the Messages tab's unread badge — MessagesPage.vue reuses
    // this same store instance, so start() here is a no-op once that page
    // also calls it (see the userId/channel guard in stores/messages.ts).
    await messagesStore.start(user.id)


  } catch {
    userInitials.value = 'U'
  }
})

onUnmounted(() => {
  notifications.stop()
  messagesStore.stop()
  window.removeEventListener('scroll', onScroll, true)
  window.removeEventListener('accommo:avatar-change', onAvatarChange)
  document.removeEventListener('visibilitychange', onVisibilityChange)
  document.querySelector('.q-page-container')?.removeEventListener('scroll', onScroll)
})

/**
 * "Forgot PIN?" from an ACTION prompt: the user is already inside and unlocked,
 * so send them to Settings where the reset lives. The resume lock never reaches
 * here — it cannot navigate out of the cover it is showing, so PinGate runs the
 * reset in place instead.
 */
function goToSecuritySettings() {
  settlePin(false)
  void router.push(`/${role.value}/settings`)
}

// One existence-check query per dot, run once on shell mount. Deliberately
// not realtime: these are low-frequency "does something need a look" flags,
// not live counters — reopening the tab is enough to refresh them.
//
// The landlord/landlady's signals are exact-state checks (a lease sitting at 'pending', a
// concern sitting at 'open') that self-clear the instant someone acts on the
// row. Concerns has no per-student "seen this response" column, and
// accommodations has no per-student "seen this listing" column either — so
// the student side uses a rolling time window instead (a concern resolved
// in the last few days, a listing accredited in the last week): still
// self-clearing (it ages out on its own), just on a timer instead of a
// status flip.
const CONCERN_WINDOW_DAYS = 3
const LISTING_WINDOW_DAYS = 7

async function loadNeedsCheckDots(userId: string) {
  const isManager = role.value === 'manager'
  const [tenants, docs, concerns, listings] = await Promise.all([
    isManager
      ? countLeasesAwaitingManager(userId).then((count) => ({ count }))
      : Promise.resolve({ count: 0 }),
    supabase
      .from('verification_documents')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('status', 'rejected'),
    isManager
      ? supabase
          .from('concerns')
          .select('id, leases!inner(landlord_id)', { count: 'exact', head: true })
          .eq('status', 'open')
          .eq('leases.landlord_id', userId)
      : supabase
          .from('concerns')
          .select('id, leases!inner(student_id)', { count: 'exact', head: true })
          .in('status', ['resolved', 'rejected'])
          .gte('updated_at', new Date(Date.now() - CONCERN_WINDOW_DAYS * 86400000).toISOString())
          .eq('leases.student_id', userId),
    isManager
      ? Promise.resolve({ count: 0 })
      : supabase
          .from('accommodations')
          .select('id', { count: 'exact', head: true })
          .eq('status', 'accredited')
          .gte('accredited_at', new Date(Date.now() - LISTING_WINDOW_DAYS * 86400000).toISOString()),
  ])
  tenantsNeedCheck.value = Boolean(tenants.count)
  profileNeedsCheck.value = Boolean(docs.count)
  concernsNeedCheck.value = Boolean(concerns.count)
  discoverNeedCheck.value = Boolean(listings.count)
}

function onAvatarChange(event: Event) {
  const url = (event as CustomEvent<{ url: string }>).detail?.url
  if (url) profileImageUrl.value = resolveAsset(url)
}

function onScroll() {
  const container = document.querySelector('.q-page-container') as HTMLElement | null
  scrolled.value = Math.max(window.scrollY || 0, container?.scrollTop || 0) > 8
}
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
  background: var(--m-surface);
  color: var(--m-text);
  box-shadow: 0 -8px 20px rgba(15, 23, 42, 0.08);
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
.pane--list {
  border-right: 1px solid var(--m-border);
}
.page-slide-left-enter-active,
.page-slide-right-leave-active {
  position: absolute;
  z-index: 1;
  inset: 0;
  width: 100%;
  background: var(--m-bg);
  box-shadow: -10px 0 24px rgba(15, 23, 42, .14);
  transition: transform 260ms cubic-bezier(.22, .61, .36, 1), box-shadow 260ms ease-out;
}
.page-slide-left-enter-from { transform: translateX(100%); }
.page-slide-left-enter-to { transform: translateX(0); }
.page-slide-left-leave-active { transition: opacity 260ms linear; }
.page-slide-left-leave-to { opacity: .99; }
.page-slide-right-leave-to { transform: translateX(100%); }
.page-fade-enter-active,
.page-fade-leave-active { transition: opacity 120ms ease-out; }
.page-fade-enter-from,
.page-fade-leave-to { opacity: 0; }
/* Tenants <-> a tenant on desktop. The leaving page is lifted out of the flow
   and laid over the arriving one — two pages in flow at once would stack, and
   the card would jump down by a whole page for the length of the fade. Its box
   is the page's own container, made positioned for this in app.scss. */
/* Only the leaving page fades: the arriving one is already solid underneath,
   so the card's frame — identical in both — never dims mid-swap. */
.page-swap-leave-active {
  position: absolute;
  inset: 0;
  z-index: 1;
  transition: opacity 160ms ease-out;
}
.page-swap-leave-to {
  opacity: 0;
}
@media (prefers-reduced-motion: reduce) {
  .page-swap-leave-active,
  .page-slide-left-enter-active,
  .page-slide-left-leave-active,
  .page-slide-right-leave-active,
  .page-fade-enter-active,
  .page-fade-leave-active { transition: none; }
}
/* Sign-out confirmation. Mirrors the delete sheets in AccommodationDetail so
   a destructive confirm looks the same everywhere in the app. */
.confirm-sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 10px;
  padding: 8px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom, 0px));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.confirm-grip {
  width: 38px;
  height: 4px;
  align-self: center;
  margin-bottom: 4px;
  border-radius: 999px;
  background: var(--m-border);
}
.confirm-header {
  display: flex;
  align-items: center;
  gap: 10px;
}
.confirm-header-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.confirm-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
.confirm-hint {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.confirm-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 4px;
}
.confirm-ghost,
.confirm-danger {
  min-height: 46px;
  flex: 0 0 auto;
  padding: 0 20px;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.confirm-ghost {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.confirm-danger {
  border: 0;
  background: var(--m-danger);
  color: #fff;
}
.confirm-ghost:disabled,
.confirm-danger:disabled {
  opacity: 0.6;
}
</style>
