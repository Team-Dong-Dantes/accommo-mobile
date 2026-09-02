<template>
  <q-layout view="hHh lpR fFf">
    <q-header v-if="!chatFullscreen" class="bg-transparent text-grey-9 app-header" :class="{ 'is-scrolled': scrolled, 'app-header--subpage': isSecondaryPage }">
      <div class="header-row q-px-md">
        <template v-if="isSecondaryPage">
          <q-btn flat round dense class="setup-back-button" :aria-label="`Back to ${secondaryBackLabel}`" @click="goBack">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </q-btn>
          <h1 class="setup-page-title text-black text-weight-bold">{{ secondaryTitle }}</h1>
          <span class="header-balance" aria-hidden="true" />
        </template>
        <template v-else>
          <div class="app-title text-black text-weight-bold">accommo</div>
          <!-- Header Bell Icon -> Opens Notifications -->
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

    <q-footer v-if="!isSecondaryPage && !chatFullscreen" bordered class="bg-white text-grey-8 bottom-footer">
      <div class="bottom-nav">
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'home' }" aria-label="Home" @click="goToTab('home')">
          <IconifyIcon icon="lucide:house" width="22" />
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'discover' }" aria-label="Discover" @click="goToTab('discover')">
          <IconifyIcon icon="lucide:search" width="22" />
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'messages' }" aria-label="Messages" @click="goToTab('messages')">
          <IconifyIcon icon="lucide:message-circle" width="22" />
        </button>
        <!-- Bottom Tab: Profile (Icon-only) -->
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'profile' }" aria-label="Profile" @click="goToTab('profile')">
          <q-avatar size="26px" class="profile-avatar-mini" text-color="white">
            <q-img v-if="profileImageUrl" :src="profileImageUrl" alt="Profile" />
            <span v-else>{{ userInitials }}</span>
          </q-avatar>
        </button>
      </div>
    </q-footer>

    <div v-if="fabOpen" class="quick-action-layer">
      <div class="quick-action-backdrop" @click="fabOpen = false" />
      <div id="student-quick-actions" class="quick-action-menu" role="menu" aria-label="Quick actions">
        <button type="button" role="menuitem" @click="navigateTo('/student/support')">
          <span class="quick-action-icon"><IconifyIcon icon="lucide:shield-check" width="18" /></span>
          <span>OSAS</span>
        </button>
        <button type="button" role="menuitem" @click="navigateTo('/student/concerns')">
          <span class="quick-action-icon"><IconifyIcon icon="lucide:triangle-alert" width="18" /></span>
          <span>Concerns</span>
        </button>
        <button type="button" role="menuitem" @click="navigateTo('/student/payments')">
          <span class="quick-action-icon"><IconifyIcon icon="lucide:wallet-cards" width="18" /></span>
          <span>Payments</span>
        </button>
      </div>
    </div>
    <button
      v-if="showFab"
      type="button"
      class="bottom-fab"
      :class="{ 'bottom-fab--open': fabOpen }"
      :aria-expanded="fabOpen"
      aria-controls="student-quick-actions"
      aria-label="Open quick actions"
      @click="fabOpen = !fabOpen"
    >
      <IconifyIcon icon="lucide:plus" width="20" />
    </button>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'
import { initialsOf } from '@/shared/utils/format'
import { chatFullscreen } from '@/shared/utils/chatFullscreen'

const router = useRouter()
const route = useRoute()
const userInitials = ref('U')
const profileImageUrl = ref<string | null>(null)
const unreadNotifCount = ref(0)
const fabOpen = ref(false)
const scrolled = ref(false)
const activeBottomTab = ref<StudentBottomTab>('home')
const isProfilePage = computed(() => route.path === '/student/profile')
const isNotificationsPage = computed(() => route.path === '/student/notifications')
const isSecondaryPage = computed(() => isProfilePage.value || isNotificationsPage.value)
const showFab = computed(() => !isSecondaryPage.value)
const secondaryTitle = computed(() => isNotificationsPage.value ? 'Notifications' : 'Profile')
const secondaryBackLabel = computed(() => 'home')
const pageTransition = ref('page-fade')

type StudentBottomTab = 'home' | 'discover' | 'messages' | 'profile'

const bottomTabs = [
  { name: 'home', route: '/student/home' },
  { name: 'discover', route: '/student/discover' },
  { name: 'messages', route: '/student/messages' },
  { name: 'profile', route: '/student/profile' },
] as const

onMounted(async () => {
  window.addEventListener('scroll', onScroll, true)
  document.querySelector('.q-page-container')?.addEventListener('scroll', onScroll)
  onScroll()
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    const metadata = user.user_metadata as Record<string, unknown> | undefined
    const picture = typeof metadata?.avatar_url === 'string'
      ? metadata.avatar_url
      : (typeof metadata?.picture === 'string' ? metadata.picture : '')
    profileImageUrl.value = picture || null

    const { data } = await supabase
      .from('users')
      .select('initials, full_name')
      .eq('id', user.id)
      .maybeSingle()

    const row = data as { initials: string | null; full_name: string | null } | null
    userInitials.value = row?.initials || initialsOf(String(row?.full_name || user.email || 'User'))

    // Check unread notifications count
    const { count } = await (supabase as any)
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
  document.querySelector('.q-page-container')?.removeEventListener('scroll', onScroll)
})

function onScroll() {
  const container = document.querySelector('.q-page-container') as HTMLElement | null
  scrolled.value = Math.max(window.scrollY || 0, container?.scrollTop || 0) > 8
}

function navigateTo(path: string) {
  fabOpen.value = false
  void router.push(path)
}

function goToTab(tabName: StudentBottomTab) {
  const selectedTab = bottomTabs.find((item) => item.name === tabName)
  if (selectedTab) void router.push(selectedTab.route)
}

watch(
  () => route.path,
  (path, previousPath) => {
    const enteringSecondaryPage = path === '/student/profile' || path === '/student/notifications'
    const leavingSecondaryPage = previousPath === '/student/profile' || previousPath === '/student/notifications'
    pageTransition.value = enteringSecondaryPage && !leavingSecondaryPage ? 'page-slide-left' : leavingSecondaryPage && !enteringSecondaryPage ? 'page-slide-right' : 'page-fade'
    if (path === '/student/profile' || path === '/student/home') fabOpen.value = false
    if (path.startsWith('/student/discover')) activeBottomTab.value = 'discover'
    else if (path.startsWith('/student/messages')) activeBottomTab.value = 'messages'
    else if (path.startsWith('/student/profile')) activeBottomTab.value = 'profile'
    else activeBottomTab.value = 'home'
  },
  { immediate: true },
)

function goToNotifications() {
  void router.push('/student/notifications')
}

function goBack() {
  void router.push('/student/home')
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

.profile-avatar-mini {
  width: 24px;
  height: 24px;
  background: #00897b;
  font-size: 10.5px;
  font-weight: 800;
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

.bottom-nav {
  display: flex;
  height: 100%;
  align-items: stretch;
}

.bottom-nav-item {
  position: relative;
  display: flex;
  min-width: 0;
  flex: 1 1 0;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 2px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #9ca3af;
  cursor: pointer;
  font-family: inherit;
  -webkit-tap-highlight-color: transparent;
  transition: color 0.12s ease, transform 0.12s ease;
}

.bottom-nav-item:active {
  transform: scale(0.9);
}

.bottom-nav-item.active {
  color: #00897b;
}

.bottom-nav-label {
  display: block;
  font-size: 11px;
  font-weight: 600;
  line-height: 1;
}

.bottom-fab {
  position: fixed;
  right: 16px;
  bottom: 68px;
  z-index: 60;
  display: grid;
  width: 44px;
  height: 44px;
  padding: 0;
  place-items: center;
  border: 1px solid var(--m-primary-dark);
  border-radius: 50%;
  background: var(--m-primary-dark);
  box-shadow: 0 4px 12px rgba(0, 105, 92, 0.22);
  color: #fff;
  cursor: pointer;
  transition: background-color 180ms ease-out, box-shadow 180ms ease-out;
}
.bottom-fab svg { transition: transform 260ms cubic-bezier(0.34, 1.56, 0.64, 1); }
.bottom-fab--open { border-color: var(--m-danger); background: var(--m-danger); box-shadow: 0 4px 12px rgba(180, 35, 24, 0.24); }
.bottom-fab--open svg { transform: rotate(45deg); }
.bottom-fab:focus-visible,
.quick-action-menu button:focus-visible { outline: 2px solid var(--m-primary); outline-offset: 3px; }
.quick-action-layer { position: fixed; z-index: 55; top: 0; right: 0; bottom: calc(64px + env(safe-area-inset-bottom, 0px)); left: 0; }
.quick-action-backdrop { position: absolute; inset: 0; background: rgba(23, 32, 42, 0.28); backdrop-filter: blur(5px); -webkit-backdrop-filter: blur(5px); }
.quick-action-menu { position: absolute; right: 12px; bottom: 72px; display: flex; flex-direction: column; align-items: flex-end; gap: var(--m-space-2); animation: quick-actions-in 200ms ease-out both; }
.quick-action-menu button { display: flex; min-height: 44px; align-items: center; gap: var(--m-space-2); padding: var(--m-space-1) var(--m-space-2) var(--m-space-1) var(--m-space-1); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08); color: var(--m-ink); cursor: pointer; font: inherit; font-size: 13px; font-weight: 700; text-align: left; }
.quick-action-menu button:hover { background: var(--m-primary-soft); }
.quick-action-icon { display: grid; width: 36px; height: 36px; place-items: center; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); color: var(--m-primary-dark); }

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
@keyframes quick-actions-in { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
@media (prefers-reduced-motion: reduce) { .bottom-fab, .bottom-fab svg, .page-slide-left-enter-active, .page-slide-left-leave-active, .page-slide-right-leave-active, .page-fade-enter-active, .page-fade-leave-active { transition: none; } .quick-action-menu { animation: none; } }
</style>
