<template>
  <q-layout view="hHh Lpr fFf">
    <q-header v-if="!isProfilePage" class="bg-white text-grey-9 app-header">
      <div class="header-row q-px-md">
        <div class="app-title text-black text-weight-bold">accommo</div>
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
        </q-btn>
      </div>
    </q-header>

    <q-page-container class="bg-grey-1">
      <router-view />
    </q-page-container>

    <q-footer v-if="!isProfilePage" bordered class="bg-white text-grey-8 bottom-footer">
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
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../shared/utils/supabase'
import { initialsOf } from '@/shared/utils/format'

const router = useRouter()
const route = useRoute()
const activeBottomTab = ref<BottomTabName>('home')
const userInitials = ref('U')
const profileImageUrl = ref<string | null>(null)
const isProfilePage = computed(() => route.path === '/landlord/profile')
const quickActionsOpen = ref(false)
const showQuickActions = computed(() => !isProfilePage.value && !route.path.startsWith('/landlord/notifications'))

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

function navigateQuickAction(path: string) {
  quickActionsOpen.value = false
  void router.push(path)
}

watch(
  () => route.path,
  value => {
    if (value.startsWith('/landlord/notifications') || value === '/landlord/profile') quickActionsOpen.value = false
    if (value.startsWith('/landlord/dashboard')) activeBottomTab.value = 'home'
    else if (value.startsWith('/landlord/tenants')) activeBottomTab.value = 'tenants'
    else if (value.startsWith('/landlord/messages')) activeBottomTab.value = 'messages'
    else if (value.startsWith('/landlord/chat')) activeBottomTab.value = 'messages'
    else if (value.startsWith('/landlord/notifications')) activeBottomTab.value = 'notif'
  },
  { immediate: true },
)

onMounted(async () => {
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
</script>

<style scoped>
.app-header {
  background: #ffffff;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  box-shadow: none !important;
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
@keyframes quick-actions-in {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
@media (prefers-reduced-motion: reduce) {
  .bottom-fab,
  .bottom-fab svg { transition: none; }
  .quick-action-menu { animation: none; }
}
</style>
