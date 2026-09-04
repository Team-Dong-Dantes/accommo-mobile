<template>
  <q-layout view="hHh Lpr fFf">
    <q-header
      v-if="!chatFullscreen"
      class="bg-transparent text-grey-9 app-header"
      :class="{ 'is-scrolled': scrolled, 'app-header--subpage': isSubPage }"
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
          <h1 class="setup-page-title text-black text-weight-bold">{{ subPage.title }}</h1>
          <span class="header-balance" aria-hidden="true" />
        </template>

        <template v-else>
          <div class="app-title text-black text-weight-bold">accommo</div>
          <q-btn
            flat
            round
            dense
            class="header-notif-button"
            aria-label="Notifications"
            @click="goToNotifications"
          >
            <IconifyIcon icon="lucide:bell" width="22" />
            <span v-if="unreadNotifCount > 0" class="header-notif-dot" />
          </q-btn>
        </template>
      </div>
    </q-header>

    <q-page-container class="bg-grey-1">
      <div class="page-stage">
        <router-view v-slot="{ Component }">
          <transition :name="pageTransition">
            <component :is="Component" />
          </transition>
        </router-view>
      </div>
    </q-page-container>

    <q-footer
      v-if="!isSubPage && !chatFullscreen"
      bordered
      class="bg-white text-grey-8 bottom-footer"
    >
      <BottomNav
        :tabs="config.tabs"
        :active="activeBottomTab"
        :avatar-url="profileImageUrl"
        :initials="userInitials"
        @select="goToTab"
      />
    </q-footer>

    <QuickActions
      v-if="showQuickActions"
      v-model:open="quickActionsOpen"
      :actions="config.quickActions"
      :menu-id="`${role}-quick-actions`"
      @navigate="navigateQuickAction"
    />
  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'
import { initialsOf } from '@/shared/utils/format'
import { resolveAsset } from '@/shared/utils/cloudinaryUrl'
import { chatFullscreen } from '@/shared/utils/chatFullscreen'
import BottomNav from '@/components/layout/BottomNav.vue'
import QuickActions from '@/components/layout/QuickActions.vue'
import type { SecondaryPage, ShellConfig } from '@/shared/types/app-types'

const router = useRouter()
const route = useRoute()

// One shell, two configurations. The role is read from the path so the chrome
// renders correctly on first paint, with no async role lookup flicker.
const SHELLS: Record<'manager' | 'student', ShellConfig> = {
  manager: {
    home: '/manager/dashboard',
    notifications: '/manager/notifications',
    tabs: [
      { name: 'home', route: '/manager/dashboard', icon: 'lucide:house', label: 'Home' },
      { name: 'tenants', route: '/manager/tenants', icon: 'lucide:users', label: 'Tenants' },
      { name: 'messages', route: '/manager/messages', icon: 'lucide:message-circle', label: 'Messages', match: ['/manager/chat'] },
      { name: 'profile', route: '/manager/profile', icon: '', label: 'Profile', avatar: true },
    ],
    quickActions: [
      { icon: 'lucide:shield-check', label: 'OSAS', route: '/manager/osas-compliance' },
      { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/manager/support' },
      { icon: 'lucide:building-2', label: 'Accommodations', route: '/manager/properties' },
    ],
    secondaryPages: [
      { path: '/manager/profile', title: 'Profile', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/profile/qr-scanner', title: 'QR scanner', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/notifications', title: 'Notifications', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: /^\/manager\/tenant\/[^/]+$/, title: 'Tenant', back: '/manager/tenants', backLabel: 'tenants' },
      { path: '/manager/properties/new', title: 'New Accommodation', back: '/manager/properties', backLabel: 'accommodations', stacked: true },
      { path: /^\/manager\/properties\/[^/]+$/, title: 'Accommodation Details', back: '/manager/properties', backLabel: 'accommodations', stacked: true },
    ],
  },
  student: {
    home: '/student/home',
    notifications: '/student/notifications',
    tabs: [
      { name: 'home', route: '/student/home', icon: 'lucide:house', label: 'Home' },
      { name: 'discover', route: '/student/discover', icon: 'lucide:search', label: 'Discover' },
      { name: 'messages', route: '/student/messages', icon: 'lucide:message-circle', label: 'Messages' },
      { name: 'profile', route: '/student/profile', icon: '', label: 'Profile', avatar: true },
    ],
    quickActions: [
      { icon: 'lucide:shield-check', label: 'OSAS', route: '/student/support' },
      { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/student/concerns' },
      { icon: 'lucide:wallet-cards', label: 'Payments', route: '/student/payments' },
    ],
    secondaryPages: [
      { path: '/student/profile', title: 'Profile', back: '/student/home', backLabel: 'home' },
      { path: '/student/notifications', title: 'Notifications', back: '/student/home', backLabel: 'home' },
    ],
  },
}

const role = computed<'manager' | 'student'>(() =>
  route.path.startsWith('/manager') ? 'manager' : 'student',
)
const config = computed(() => SHELLS[role.value])

const userInitials = ref('U')
const profileImageUrl = ref<string | null>(null)
const unreadNotifCount = ref(0)
const quickActionsOpen = ref(false)
const scrolled = ref(false)
const activeBottomTab = ref('home')
const pageTransition = ref('page-fade')

function matchSecondary(path: string, shell: ShellConfig): SecondaryPage | undefined {
  return shell.secondaryPages.find((entry) =>
    typeof entry.path === 'string' ? entry.path === path : entry.path.test(path),
  )
}

const subPage = computed(() => matchSecondary(route.path, config.value))
const isSubPage = computed(() => Boolean(subPage.value))

// Student chat opens a full-width conversation; the FAB would sit on top of it.
const isInConversation = computed(
  () => route.path.startsWith(`/${role.value}/messages`) && Boolean(route.query.manager),
)
const showQuickActions = computed(
  () => !isSubPage.value && !isInConversation.value && !chatFullscreen.value,
)

function goToTab(tabName: string) {
  const tab = config.value.tabs.find((item) => item.name === tabName)
  if (tab) void router.push(tab.route)
}

function goToNotifications() {
  void router.push(config.value.notifications)
}

function goBack() {
  void router.push(subPage.value?.back ?? config.value.home)
}

function navigateQuickAction(path: string) {
  quickActionsOpen.value = false
  void router.push(path)
}

watch(
  () => route.path,
  (path, previousPath) => {
    const shell = SHELLS[path.startsWith('/manager') ? 'manager' : 'student']

    // Slide when moving between the main shell and a sub-page; fade otherwise.
    const entering = Boolean(matchSecondary(path, shell))
    const leaving = Boolean(previousPath && matchSecondary(previousPath, shell))
    pageTransition.value =
      entering && !leaving ? 'page-slide-left' : leaving && !entering ? 'page-slide-right' : 'page-fade'

    if (entering) quickActionsOpen.value = false

    const active = shell.tabs.find((tab) =>
      [tab.route, ...(tab.match ?? [])].some((prefix) => path.startsWith(prefix)),
    )
    activeBottomTab.value = active?.name ?? 'home'
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
      .select('initials, full_name')
      .eq('id', user.id)
      .maybeSingle()

    const row = userData as { initials: string | null; full_name: string | null } | null
    userInitials.value =
      row?.initials || initialsOf(String(row?.full_name || metadata?.full_name || user.email || 'User'))

    const { count } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .is('read_at', null)
    unreadNotifCount.value = count || 0
  } catch {
    userInitials.value = 'U'
  }
})

onUnmounted(() => {
  window.removeEventListener('scroll', onScroll, true)
  window.removeEventListener('accommo:avatar-change', onAvatarChange)
  document.querySelector('.q-page-container')?.removeEventListener('scroll', onScroll)
})

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
  border-radius: var(--m-radius-lg);
  background: transparent;
  box-shadow: none !important;
  transition: background-color .25s ease, backdrop-filter .25s ease, -webkit-backdrop-filter .25s ease, border-color .25s ease, box-shadow .25s ease;
}
.app-header:not(.is-scrolled) :deep(.q-layout__shadow) {
  display: none;
}
.app-header.is-scrolled {
  border-color: var(--m-border);
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
}
.header-balance { width: 44px; height: 44px; }
.setup-back-button {
  height: 44px;
  min-width: 44px;
  min-height: 44px;
  margin-left: -8px;
  color: #111827;
}
.header-notif-button {
  position: relative;
  min-width: 40px;
  min-height: 40px;
  color: #111827;
}
.header-notif-dot {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--m-danger, #b42318);
  border: 1.5px solid #ffffff;
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
  box-shadow: 0 -8px 20px rgba(15, 23, 42, 0.08);
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
