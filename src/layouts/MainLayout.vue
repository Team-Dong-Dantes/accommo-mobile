<template>
  <q-layout view="hHh Lpr fFf">
    <q-header class="bg-transparent text-grey-9 app-header" :class="{ 'is-scrolled': scrolled, 'app-header--subpage': isSecondaryPage }">
      <div class="header-row q-px-md">
        <template v-if="isAccommodationSetup || isAccommodationDetail"><q-btn flat round dense class="setup-back-button" aria-label="Back to accommodations" @click="goToAccommodations"><IconifyIcon icon="lucide:arrow-left" width="20" /></q-btn><div class="setup-page-title text-black text-weight-bold">{{ isAccommodationDetail ? 'Accommodation Details' : 'New Accommodation' }}</div></template>
        <template v-else-if="isSecondaryPage"><q-btn flat round dense class="setup-back-button" :aria-label="`Back to ${secondaryBackLabel}`" @click="goBack"><IconifyIcon icon="lucide:arrow-left" width="20" /></q-btn><h1 class="setup-page-title text-black text-weight-bold">{{ secondaryTitle }}</h1><span class="header-balance" aria-hidden="true" /></template>
        <template v-else><div class="app-title text-black text-weight-bold">accommo</div>
        <q-btn
          flat
          round
          dense
          class="avatar-button"
          @click="goToProfile"
        >
          <q-avatar size="36px" class="profile-avatar-shell text-weight-bold" text-color="white">
            <q-img v-if="profileImageUrl" :src="profileImageUrl" alt="Profile photo" />
            <span v-else>{{ userInitials }}</span>
          </q-avatar>
        </q-btn></template>
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

    <q-footer v-if="!isSecondaryPage" bordered class="bg-white text-grey-8 bottom-footer" :class="{ 'bottom-footer--setup': isAccommodationSetup }">
      <div class="bottom-nav">
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'home' }" @click="goToTab('home')">
          <IconifyIcon icon="lucide:house" width="22" />
          <span class="bottom-nav-label">Home</span>
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'tenants' }" @click="goToTab('tenants')">
          <IconifyIcon icon="lucide:users" width="22" />
          <span class="bottom-nav-label">Tenants</span>
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'messages' }" @click="goToTab('messages')">
          <IconifyIcon icon="lucide:message-circle" width="22" />
          <span class="bottom-nav-label">Messages</span>
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'notif' }" @click="goToTab('notif')">
          <IconifyIcon icon="lucide:bell" width="22" />
          <span class="bottom-nav-label">Alerts</span>
        </button>
      </div>

      <div v-if="quickActionsOpen" class="quick-action-layer">
        <div class="quick-action-backdrop" @click="quickActionsOpen = false" />
        <div id="landlord-quick-actions" class="quick-action-menu" role="menu" aria-label="Quick actions">
          <button type="button" role="menuitem" @click="navigateQuickAction('/landlord/osas-compliance')">
            <span class="quick-action-icon"><IconifyIcon icon="lucide:shield-check" width="18" /></span>
            <span>OSAS</span>
          </button>
          <button type="button" role="menuitem" @click="navigateQuickAction('/landlord/support')">
            <span class="quick-action-icon"><IconifyIcon icon="lucide:triangle-alert" width="18" /></span>
            <span>Concerns</span>
          </button>
          <button type="button" role="menuitem" @click="navigateQuickAction('/landlord/properties')">
            <span class="quick-action-icon"><IconifyIcon icon="lucide:building-2" width="18" /></span>
            <span>Accommodations</span>
          </button>
        </div>
      </div>
      <button
        v-if="showQuickActions"
        type="button"
        class="bottom-fab"
        :class="{ 'bottom-fab--open': quickActionsOpen }"
        :aria-expanded="quickActionsOpen"
        aria-controls="landlord-quick-actions"
        aria-label="Open quick actions"
        @click="quickActionsOpen = !quickActionsOpen"
      >
        <IconifyIcon icon="lucide:plus" width="20" />
      </button>
    </q-footer>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../shared/utils/supabase'
import { initialsOf } from '@/shared/utils/format'

const router = useRouter()
const route = useRoute()
const activeBottomTab = ref<BottomTabName>('home')
const userInitials = ref('U')
const profileImageUrl = ref<string | null>(null)
const isProfilePage = computed(() => route.path === '/landlord/profile')
const isNotificationsPage = computed(() => route.path === '/landlord/notifications')
const isSecondaryPage = computed(() => isProfilePage.value || isNotificationsPage.value)
const isAccommodationSetup = computed(() => route.path === '/landlord/properties/new')
const isAccommodationDetail = computed(() => /^\/landlord\/properties\/[^/]+$/.test(route.path))
const quickActionsOpen = ref(false)
const scrolled = ref(false)
const showQuickActions = computed(() => !isSecondaryPage.value && !isAccommodationSetup.value && !isAccommodationDetail.value)
const secondaryTitle = computed(() => isNotificationsPage.value ? 'Notifications' : 'Profile')
const secondaryBackLabel = computed(() => isNotificationsPage.value ? 'dashboard' : 'dashboard')
const pageTransition = ref('page-fade')

const bottomTabs = [
  { name: 'home', route: '/landlord/dashboard' },
  { name: 'tenants', route: '/landlord/tenants' },
  { name: 'messages', route: '/landlord/messages' },
  { name: 'notif', route: '/landlord/notifications' },
] as const

type BottomTabName = 'home' | 'tenants' | 'messages' | 'notif'

const goToTab = (tabName: string | number) => {
  const selectedTab = bottomTabs.find(item => item.name === tabName)
  if (selectedTab) {
    void router.push(selectedTab.route)
  }
}

const goToProfile = () => {
  void router.push('/landlord/profile')
}

const goBack = () => {
  void router.push('/landlord/dashboard')
}

const goToAccommodations = () => {
  void router.push('/landlord/properties')
}

function navigateQuickAction(path: string) {
  quickActionsOpen.value = false
  void router.push(path)
}

watch(
  () => route.path,
  (value, previousValue) => {
    const enteringSecondaryPage = value === '/landlord/profile' || value === '/landlord/notifications'
    const leavingSecondaryPage = previousValue === '/landlord/profile' || previousValue === '/landlord/notifications'
    pageTransition.value = enteringSecondaryPage && !leavingSecondaryPage ? 'page-slide-left' : leavingSecondaryPage && !enteringSecondaryPage ? 'page-slide-right' : 'page-fade'
    if (value.startsWith('/landlord/notifications') || value === '/landlord/profile' || value === '/landlord/properties/new' || /^\/landlord\/properties\/[^/]+$/.test(value)) quickActionsOpen.value = false
    if (value.startsWith('/landlord/dashboard')) activeBottomTab.value = 'home'
    else if (value.startsWith('/landlord/tenants')) activeBottomTab.value = 'tenants'
    else if (value.startsWith('/landlord/messages')) activeBottomTab.value = 'messages'
    else if (value.startsWith('/landlord/chat')) activeBottomTab.value = 'messages'
    else if (value.startsWith('/landlord/notifications')) activeBottomTab.value = 'notif'
  },
  { immediate: true },
)

onMounted(async () => {
  window.addEventListener('scroll', onScroll, true)
  document.querySelector('.q-page-container')?.addEventListener('scroll', onScroll)
  onScroll()
  try {
    const { data } = await supabase.auth.getUser()
    const user = data?.user

    if (user) {
      const metadata = user.user_metadata as Record<string, unknown> | undefined
      const picture = typeof metadata?.avatar_url === 'string'
        ? metadata.avatar_url
        : (typeof metadata?.picture === 'string' ? metadata.picture : '')
      profileImageUrl.value = picture || null

        const { data: userData } = await supabase
          .from('users')
          .select('initials, full_name')
        .eq('id', user.id)
        .maybeSingle()

      if (userData) {
        userInitials.value =
          userData.initials || initialsOf(String(userData.full_name || user.email || 'User'))
      } else {
        userInitials.value = initialsOf(String(metadata?.full_name || user.email || 'User'))
      }
    }
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
  letter-spacing: -0.04em;
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
.avatar-button {
  min-width: 36px;
  min-height: 36px;
  padding: 0;
  color: #111827;
}

.profile-avatar-shell {
  width: 36px;
  height: 36px;
  background: #E6F5F3;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.profile-avatar-shell span {
  color: #0f766e;
}
.bottom-footer {
  min-height: 64px;
  height: calc(64px + env(safe-area-inset-bottom, 0px));
  padding-bottom: env(safe-area-inset-bottom, 0px);
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 50;
  box-shadow: 0 -8px 20px rgba(15, 23, 42, 0.08);
}
.bottom-footer--setup {
  box-shadow: none;
}
.bottom-nav {
  height: 100%;
  display: flex;
  align-items: stretch;
}
.bottom-nav-item {
  flex: 1 1 0;
  min-width: 0;
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  padding: 0;
  border: none;
  background: transparent;
  appearance: none;
  -webkit-appearance: none;
  outline: none;
  cursor: pointer;
  color: #9CA3AF;
  font-family: inherit;
  -webkit-tap-highlight-color: transparent;
  user-select: none;
  transition: transform 0.12s ease, color 0.12s ease;
}
.bottom-nav-item:active {
  transform: scale(0.9);
}
.bottom-nav-item.active {
  color: #00897B;
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
  bottom: 80px;
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
.bottom-fab svg {
  transition: transform 260ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
.bottom-fab--open svg {
  transform: rotate(45deg);
}
.bottom-fab--open {
  border-color: var(--m-danger);
  background: var(--m-danger);
  box-shadow: 0 4px 12px rgba(180, 35, 24, 0.24);
}
.bottom-fab:focus-visible,
.quick-action-menu button:focus-visible {
  outline: 2px solid var(--m-primary);
  outline-offset: 3px;
}
.quick-action-layer {
  position: fixed;
  z-index: 55;
  top: 0;
  right: 0;
  bottom: calc(64px + env(safe-area-inset-bottom, 0px));
  left: 0;
}
.quick-action-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(23, 32, 42, 0.28);
  backdrop-filter: blur(5px);
  -webkit-backdrop-filter: blur(5px);
}
.quick-action-menu {
  position: absolute;
  right: 12px;
  bottom: 72px;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: var(--m-space-2);
  animation: quick-actions-in 200ms ease-out both;
}
.quick-action-menu button {
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: var(--m-space-2);
  padding: var(--m-space-1) var(--m-space-2) var(--m-space-1) var(--m-space-1);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  text-align: left;
}
.quick-action-menu button:hover { background: var(--m-primary-soft); }
.quick-action-icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.page-stage { position: relative; min-height: 100%; overflow-x: clip; }

/* Horizontal cover transition for notifs/profile:
   - OPEN (page-slide-left): the incoming page slides in from the RIGHT and
     moves left (right → left); the base page nudges slightly left.
   - CLOSE (page-slide-right): the page slides back out to the RIGHT while the
     base page re-enters from the LEFT (left → right). */
.page-slide-left-enter-active,
.page-slide-left-leave-active,
.page-slide-right-enter-active,
.page-slide-right-leave-active {
  position: absolute;
  inset: 0;
  width: 100%;
  background: var(--m-bg);
  transition: transform 300ms cubic-bezier(.25, 1, .3, 1);
}
.page-slide-left-enter-active {
  z-index: 1;
  box-shadow: -10px 0 24px rgba(15, 23, 42, .14);
}
.page-slide-left-enter-from { transform: translateX(100%); }
.page-slide-left-enter-to { transform: translateX(0); }
.page-slide-left-leave-to { transform: translateX(-30%); }
.page-slide-right-leave-to { transform: translateX(100%); }
.page-slide-right-enter-from { transform: translateX(-100%); }
.page-slide-right-enter-to { transform: translateX(0); }
.page-fade-enter-active,
.page-fade-leave-active { transition: opacity 120ms ease-out; }
.page-fade-enter-from,
.page-fade-leave-to { opacity: 0; }
@keyframes quick-actions-in {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
@media (prefers-reduced-motion: reduce) {
  .bottom-fab,
  .bottom-fab svg,
  .page-slide-left-enter-active,
  .page-slide-left-leave-active,
  .page-slide-right-leave-active,
  .page-fade-enter-active,
  .page-fade-leave-active { transition: none; }
  .quick-action-menu { animation: none; }
}
</style>
