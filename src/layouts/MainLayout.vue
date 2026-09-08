<template>
  <q-layout view="hHh Lpr fFf">
    <q-header
      v-if="!chatFullscreen"
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
    </q-header>

    <q-page-container class="page-container">
      <div class="page-stage">
        <router-view v-slot="{ Component }">
          <transition :name="pageTransition">
            <keep-alive :include="KEEP_ALIVE_PAGES" :max="20">
              <component :is="Component" :key="route.fullPath" />
            </keep-alive>
          </transition>
        </router-view>
      </div>
    </q-page-container>

    <q-footer
      v-if="!isSubPage && !chatFullscreen"
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

    <QuickActions
      v-if="!chatFullscreen"
      v-model:open="menuOpen"
      :account-actions="accountActions"
      :actions="displayQuickActions"
      :avatar-url="profileImageUrl"
      :initials="userInitials"
      :menu-id="`${role}-menu`"
      @navigate="navigateMenuAction"
    />
  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/utils/supabase'
import { useNotificationsStore } from '@/stores/notifications'
import { useMessagesStore } from '@/stores/messages'
import { initialsOf } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { chatFullscreen } from '@/utils/chatFullscreen'
import BottomNav from '@/components/layout/BottomNav.vue'
import QuickActions from '@/components/layout/QuickActions.vue'
import type { SecondaryPage, ShellConfig } from '@/types/app-types'

const router = useRouter()
const route = useRoute()
const notifications = useNotificationsStore()
const messagesStore = useMessagesStore()

// One shell, two configurations. The role is read from the path so the chrome
// renders correctly on first paint, with no async role lookup flicker.
const SHELLS: Record<'manager' | 'student', ShellConfig> = {
  manager: {
    home: '/manager/dashboard',
    notifications: '/manager/notifications',
    tabs: [
      { name: 'home', route: '/manager/dashboard', icon: 'lucide:house', label: 'Home' },
      { name: 'tenants', route: '/manager/tenants', icon: 'lucide:users', label: 'Tenants' },
      { name: 'messages', route: '/manager/messages', icon: 'lucide:message-circle', label: 'Messages' },
      { name: 'menu', route: '/manager/profile', icon: 'lucide:menu', label: 'Menu' },
    ],
    quickActions: [
      { icon: 'lucide:shield-check', label: 'OSAS', route: '/manager/osas-compliance' },
      { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/manager/support' },
      { icon: 'lucide:building-2', label: 'My Properties', route: '/manager/properties' },
    ],
    secondaryPages: [
      { path: '/manager/profile', title: 'Profile', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/profile/settings', title: 'Settings', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/profile/qr-scanner', title: 'QR scanner', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/profile/history', title: 'History', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/notifications', title: 'Notifications', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/osas-compliance', title: 'OSAS Compliance', back: '/manager/dashboard', backLabel: 'dashboard' },
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
      { path: '/student/profile/settings', title: 'Settings', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/profile/qr', title: 'My QR', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/profile/history', title: 'History', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/notifications', title: 'Notifications', back: '/student/home', backLabel: 'home' },
      { path: '/student/support', title: 'OSAS', back: '/student/home', backLabel: 'home' },
      { path: '/student/concerns', title: 'Concerns', back: '/student/home', backLabel: 'home' },
      { path: '/student/stay', title: 'My Stay', back: '/student/home', backLabel: 'home' },
      { path: '/student/payments', title: 'Payments', back: '/student/home', backLabel: 'home' },
      { path: /^\/student\/listing\/[^/]+$/, title: 'Listing', back: '/student/discover', backLabel: 'discover' },
      { path: '/student/properties', title: 'Properties', back: '/student/discover', backLabel: 'discover' },
      { path: /^\/student\/room\/[^/]+$/, title: 'Room', back: '/student/discover', backLabel: 'discover' },
      { path: /^\/student\/manager\/[^/]+$/, title: 'Manager', back: '/student/discover', backLabel: 'discover' },
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
  'ManagerAccommodationsPage', 'ManagerConcernsPage', 'ManagerOsasCompliancePage', 'TenantProfile',
  'StudentPropertiesPage', 'StudentOsasPage', 'StudentConcernsPage', 'StudentStayPage', 'StudentManagerPage',
]

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
// The third row is role-specific: a manager scans student QR codes, a
// student shows their own.
const accountActions = computed(() => {
  const profileRoute = config.value.tabs.find((t) => t.name === 'menu')?.route ?? config.value.home
  const items = [
    { icon: 'lucide:user', label: 'Profile', route: profileRoute, avatar: true },
    { icon: 'lucide:settings', label: 'Settings', route: `${profileRoute}/settings` },
  ]
  items.push(
    role.value === 'manager'
      ? { icon: 'lucide:scan', label: 'Scanner', route: `${profileRoute}/qr-scanner` }
      : { icon: 'lucide:qr-code', label: 'My QR', route: `${profileRoute}/qr` },
  )
  return items
})

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

const subPage = computed(() => matchSecondary(route.path, config.value))
const isSubPage = computed(() => Boolean(subPage.value))

// Discover runs its map full-bleed behind this header instead of below it,
// so the header needs its scrolled-state card background always — a plain
// transparent header over a map (rather than over the page's own solid
// background) leaves its icons floating with no backing.
const hasFloatingMap = computed(() => route.path === '/student/discover')

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

function navigateMenuAction(path: string) {
  menuOpen.value = false
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
  document.querySelector('.q-page-container')?.addEventListener('scroll', onScroll)
  onScroll()
  try {
    const { data } = await supabase.auth.getUser()
    const user = data?.user
    if (!user) return

    const metadata = user.user_metadata as Record<string, unknown> | undefined
    const picture =
      typeof metadata?.avatar_url === 'string'
        ? metadata.avatar_url
        : typeof metadata?.picture === 'string'
          ? metadata.picture
          : ''
    profileImageUrl.value = picture ? resolveAsset(picture) : null

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
    if (!picture && row?.avatar_url) profileImageUrl.value = resolveAsset(row.avatar_url)

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
  document.querySelector('.q-page-container')?.removeEventListener('scroll', onScroll)
})

// One existence-check query per dot, run once on shell mount. Deliberately
// not realtime: these are low-frequency "does something need a look" flags,
// not live counters — reopening the tab is enough to refresh them.
//
// Manager's signals are exact-state checks (a lease sitting at 'pending', a
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
      ? supabase
          .from('leases')
          .select('id', { count: 'exact', head: true })
          .eq('accommodation_manager_id', userId)
          .in('status', ['pending', 'leave_requested'])
      : Promise.resolve({ count: 0 }),
    supabase
      .from('verification_documents')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('status', 'rejected'),
    isManager
      ? supabase
          .from('concerns')
          .select('id, leases!inner(accommodation_manager_id)', { count: 'exact', head: true })
          .eq('status', 'open')
          .eq('leases.accommodation_manager_id', userId)
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
  margin: 6px 12px 0;
  border: 1px solid transparent;
  /* Quasar's dark-mode chrome puts a translucent white border-color on
     q-header by default — override it explicitly or it shows through as an
     outline even though this rule already sets the border transparent. */
  border-color: transparent !important;
  border-radius: var(--m-radius-lg);
  background: transparent;
  color: var(--m-ink);
  box-shadow: none !important;
  transition: background-color .25s ease, backdrop-filter .25s ease, -webkit-backdrop-filter .25s ease, border-color .25s ease, box-shadow .25s ease;
}
.app-header:not(.is-scrolled) :deep(.q-layout__shadow) {
  display: none;
}
.app-header.is-scrolled {
  border-color: var(--m-border) !important;
  background: color-mix(in srgb, var(--m-bg) 72%, transparent);
  box-shadow: 0 6px 18px rgba(15, 23, 42, .06) !important;
  -webkit-backdrop-filter: blur(14px) saturate(140%);
  backdrop-filter: blur(14px) saturate(140%);
}
.app-header--subpage {
  height: 56px;
  margin: 0;
  border-width: 0 0 1px;
  border-radius: 0;
  background: var(--m-surface);
  box-sizing: border-box;
}
.app-header--subpage .header-row {
  height: 55px;
  min-height: 55px;
  align-items: center;
}
.header-row {
  display: flex;
  min-height: 56px;
  align-items: center;
  justify-content: space-between;
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
@media (prefers-reduced-motion: reduce) {
  .page-slide-left-enter-active,
  .page-slide-left-leave-active,
  .page-slide-right-leave-active,
  .page-fade-enter-active,
  .page-fade-leave-active { transition: none; }
}
</style>
