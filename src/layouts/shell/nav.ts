// Where the user is and how they move: the active tab, the back bar or desktop
// title, which card a page belongs to, and the page transition.
import { CONCERNS_ROUTE, OWN_BACK, SHELLS } from './shells'
import { PANE_LISTS, useShellPanes } from '@/utils/useShellPanes'
import { type QuickAction, type SecondaryPage, type ShellConfig } from '@/types/app-types'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { computed, nextTick, onUnmounted, ref, watch } from 'vue'
import { isDesktop, isTablet } from '@/utils/useTabletMode'
import { pageTitleOverride } from '@/utils/pageTitle'
import { useAuthStore } from '@/stores/auth'
import { useMessagesStore } from '@/stores/messages'
import { useNotificationsStore } from '@/stores/notifications'
import { useRoute, useRouter } from 'vue-router'

export function createShellNav() {
  const router = useRouter()
  const route = useRoute()
  const notifications = useNotificationsStore()
  const messagesStore = useMessagesStore()

  const role = computed<'manager' | 'student'>(() =>
    route.path.startsWith('/manager') ? 'manager' : 'student',
  )
  const config = computed(() => SHELLS[role.value])

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

  const displayQuickActions = computed(() =>
    config.value.quickActions.map((action) =>
      action.route === CONCERNS_ROUTE[role.value] ? { ...action, dot: concernsNeedCheck.value } : action,
    ),
  )

  // The hamburger tab (bottom nav's old profile slot) opens this menu: Profile
  // and Settings up top, then the role's quick actions below, all in one card.
  // The third row is role-specific: a landlord/landlady scans student QR codes, a
  // student shows their own.
  const auth = useAuthStore()
  const accountActions = computed(() => {
    const profileRoute = config.value.tabs.find((t) => t.name === 'menu')?.route ?? config.value.home
    const items: QuickAction[] = [
      { icon: 'lucide:user', label: 'Profile', route: profileRoute, avatar: true },
      // Settings is its own destination, not a child of Profile — hence the
      // role path rather than profileRoute. Scanner/QR below genuinely are
      // profile screens and keep hanging off it.
      { icon: 'lucide:settings', label: 'Settings', route: `/${role.value}/settings` },
    ]
    // Offered on web too; there the scanner is manual code entry only (see
    // QRScanner). Verified landlords/landladies only — the database refuses the rest.
    if (role.value !== 'manager') items.push({ icon: 'lucide:qr-code', label: 'My QR', route: `${profileRoute}/qr` })
    else if (auth.isVerifiedLandlord) items.push({ icon: 'lucide:scan', label: 'Scanner', route: `${profileRoute}/qr-scanner` })
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

  function matchSecondary(path: string, shell: ShellConfig): SecondaryPage | undefined {
    return shell.secondaryPages.find((entry) =>
      typeof entry.path === 'string' ? entry.path === path : entry.path.test(path),
    )
  }

  // Everything the desktop rail links to straight (OSAS, Concerns, Announcements,
  // Profile, Settings, My QR — and the tabs) is a destination there, not a
  // step down from somewhere, so it gets no back button either.
  const railRoutes = computed(() => [
    ...config.value.quickActions.map((a) => a.route),
    ...accountActions.value.map((a) => a.route),
  ])
  const subPage = computed(() =>
    isDesktop.value &&
    (panes.value.mode === 'split' || OWN_BACK.test(route.path) || railRoutes.value.includes(route.path))
      ? undefined
      : matchSecondary(route.path, config.value),
  )
  const isSubPage = computed(() => Boolean(subPage.value))

  // Desktop names the screen in the header, since the rail's icons don't. In a
  // split it is the card's name (Discover, Notifications), not the item open in
  // it — the detail pane carries its own title where it needs one.
  const deskTitle = computed(() => {
    const split = panes.value.mode === 'split'
    const path = split ? panes.value.listPath : route.path
    return (split ? null : pageTitleOverride.value)
      ?? matchSecondary(path, config.value)?.title
      ?? config.value.tabs.find((t) => t.name === activeBottomTab.value)?.label
  })

  // Discover runs its map full-bleed behind this header instead of below it,
  // so the header needs its scrolled-state card background always — a plain
  // transparent header over a map (rather than over the page's own solid
  // background) leaves its icons floating with no backing. Not on desktop, where
  // the map is the card's right half, below the header — there the header stays
  // the plain, unoutlined one.
  const hasFloatingMap = computed(() => route.path === '/student/discover' && !isDesktop.value)

  // Which panes the stage shows. Single in phone mode, always — the composable
  // short-circuits on isTablet before it looks at anything else.
  const panes = useShellPanes(() => config.value, () => isTablet.value)
  /** A listing opened from a room goes back to the room, else to the map. */
  function backInPane() {
    if (window.history.state?.back) router.back()
    else void router.push('/student/discover')
  }
  const discoverMapSlot = computed(
    () => isDesktop.value && panes.value.mode === 'split' && panes.value.listPath === '/student/discover',
  )

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

  // Back steps one page up the way the user came (Listing → Landlord → back is
  // the Listing, not Discover), the same as the phone's own back button. Only a
  // fresh load or deep link, with nothing behind it, uses the configured `back`.
  function goBack() {
    if (window.history.state?.back) router.back()
    else void router.push(subPage.value?.back ?? config.value.home)
  }

  function navigateMenuAction(path: string) {
    menuOpen.value = false
    void router.push(path)
  }

  // Which way a page change animates, as <html data-nav>, which the page
  // transition's CSS keys off. Not the <transition>'s name: a page coming back
  // out of keep-alive keeps the hooks of the name it last left with, so a
  // changing name gave the arriving and leaving pages different animations.
  // Set in beforeEach, before the route (and so the page) changes.
  function transitionFor(path: string, previousPath: string): string {
    const shell = SHELLS[path.startsWith('/manager') ? 'manager' : 'student']
    // Slide when moving between the main shell and a sub-page; fade otherwise.
    const entering = Boolean(matchSecondary(path, shell))
    const leaving = Boolean(matchSecondary(previousPath, shell))
    // On desktop, moving within one card (a list and its details) changes that
    // card's contents in place; a slide would say "new page".
    const card = cardOf(path)
    if (isDesktop.value && card && card === cardOf(previousPath)) return 'page-swap'
    return entering && !leaving ? 'page-slide-left' : leaving && !entering ? 'page-slide-right' : 'page-fade'
  }
  const html = document.documentElement
  html.dataset.nav = 'page-fade'
  const stopNavDirection = router.beforeEach((to, from) => {
    if (to.path !== from.path) html.dataset.nav = transitionFor(to.path, from.path)
  })
  onUnmounted(() => {
    stopNavDirection()
    delete html.dataset.nav
  })

  watch(
    () => route.path,
    (path) => {
      const shell = SHELLS[path.startsWith('/manager') ? 'manager' : 'student']

      // Opening a sub-page closes the menu it may have been picked from.
      const entering = Boolean(matchSecondary(path, shell))
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

  function onScroll() {
    const container = document.querySelector('.q-page-container') as HTMLElement | null
    scrolled.value = Math.max(window.scrollY || 0, container?.scrollTop || 0) > 8
  }

  return {
    router,
    route,
    notifications,
    messagesStore,
    role,
    config,
    SELF_SPLITTING,
    pageKey,
    cardOf,
    displayTabs,
    displayQuickActions,
    auth,
    accountActions,
    railAccountActions,
    userInitials,
    profileImageUrl,
    tenantsNeedCheck,
    profileNeedsCheck,
    concernsNeedCheck,
    discoverNeedCheck,
    menuOpen,
    scrolled,
    activeBottomTab,
    matchSecondary,
    railRoutes,
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
    transitionFor,
    html,
    stopNavDirection,
    onScroll,
  }
}
