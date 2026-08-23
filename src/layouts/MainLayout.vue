<template>
  <q-layout view="hHh Lpr fFf">
    <q-header elevated class="bg-white text-grey-9 app-header">
      <q-toolbar class="q-px-md">
        <q-btn dense flat round @click="toggleLeftDrawer" class="menu-button">
          <IconifyIcon width="22" icon="material-icons:menu" />
        </q-btn>

        <q-toolbar-title class="app-title text-black text-weight-bold">
          accommo
        </q-toolbar-title>

        <q-btn
          flat
          round
          dense
          class="avatar-button"
          @click="goToProfile"
        >
          <div class="profile-icon-shell">
            <IconifyIcon class="profile-action-icon" width="22" icon="material-icons:person" />
          </div>
        </q-btn>
      </q-toolbar>
    </q-header>

    <q-drawer show-if-above v-model="leftDrawerOpen" side="left" bordered>
      <q-list>
        <q-item-label header>Menu</q-item-label>

        <template v-if="userRole === 'student'">
          <q-item clickable v-ripple to="/student/dashboard" exact>
            <q-item-section avatar>
              <IconifyIcon width="24" icon="material-icons:dashboard" />
            </q-item-section>
            <q-item-section> Dashboard </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/student/stay" exact>
            <q-item-section avatar>
              <IconifyIcon width="24" icon="material-icons:bed" />
            </q-item-section>
            <q-item-section> My Stay </q-item-section>
          </q-item>
        </template>

        <template v-else-if="userRole === 'landlord'">
          <q-item clickable v-ripple to="/landlord/dashboard" exact>
            <q-item-section avatar>
              <IconifyIcon width="24" icon="material-icons:dashboard" />
            </q-item-section>
            <q-item-section> Overview </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/landlord/properties" exact>
            <q-item-section avatar>
              <IconifyIcon width="24" icon="material-icons:domain" />
            </q-item-section>
            <q-item-section> My Boarding Houses </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/landlord/tenants" exact>
            <q-item-section avatar>
              <IconifyIcon width="24" icon="material-icons:people" />
            </q-item-section>
            <q-item-section> Tenants </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/landlord/payments" exact>
            <q-item-section avatar>
              <IconifyIcon width="24" icon="material-icons:payments" />
            </q-item-section>
            <q-item-section> Payments </q-item-section>
          </q-item>
        </template>

        <q-item clickable v-ripple :to="profileRoute" exact>
          <q-item-section avatar>
            <IconifyIcon width="24" icon="material-icons:person" />
          </q-item-section>
          <q-item-section> Profile </q-item-section>
        </q-item>
      </q-list>
    </q-drawer>

    <q-page-container class="bg-grey-1">
      <router-view />
    </q-page-container>

    <div v-if="fabMenuOpen" class="fab-backdrop" @click="fabMenuOpen = false" />

    <q-footer bordered class="bg-white text-grey-8 bottom-footer">
      <div class="bottom-nav">
        <button
          type="button"
          class="bottom-nav-item"
          :class="{ active: activeBottomTab === 'home' }"
          @click="goToTab('home')"
        >
          <svg class="bottom-nav-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" />
          </svg>
          <span class="bottom-nav-label">Home</span>
        </button>
        <button
          type="button"
          class="bottom-nav-item"
          :class="{ active: activeBottomTab === 'tenants' }"
          @click="goToTab('tenants')"
        >
          <svg class="bottom-nav-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" />
          </svg>
          <span class="bottom-nav-label">Tenants</span>
        </button>
        <button
          type="button"
          class="bottom-nav-item"
          :class="{ active: activeBottomTab === 'messages' }"
          @click="goToTab('messages')"
        >
          <svg class="bottom-nav-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z" />
          </svg>
          <span class="bottom-nav-label">Messages</span>
        </button>
        <button
          type="button"
          class="bottom-nav-item"
          :class="{ active: activeBottomTab === 'notif' }"
          @click="goToTab('notif')"
        >
          <svg class="bottom-nav-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z" />
          </svg>
          <span class="bottom-nav-label">Notification</span>
        </button>
      </div>

      <div class="fab-menu-wrap" v-if="fabMenuOpen">
        <q-btn
          flat
          class="fab-menu-item fab-item-osas"
          @click="openScreen('/landlord/osas-compliance')"
        >
          <q-icon name="shield" color="purple-7" size="18px" class="q-mr-sm" />
          OSAS
        </q-btn>
        <q-btn
          flat
          class="fab-menu-item fab-item-support"
          @click="openScreen('/landlord/support')"
        >
          <q-icon name="help_outline" color="teal-8" size="18px" class="q-mr-sm" />
          Support
        </q-btn>
        <q-btn
          flat
          class="fab-menu-item fab-item-properties"
          @click="openScreen('/landlord/properties')"
        >
          <q-icon name="business" color="teal-8" size="18px" class="q-mr-sm" />
          Properties
        </q-btn>

        <q-btn round color="black" icon="close" class="fab-close-button" @click="fabMenuOpen = false" />
      </div>

      <q-btn round color="teal-9" icon="add" class="fab-button" @click="toggleFabMenu" />
    </q-footer>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '../shared/utils/supabase'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const leftDrawerOpen = ref(false)
const userRole = ref('')
const activeBottomTab = ref<BottomTabName>('home')
const fabMenuOpen = ref(false)

const profileRoute = computed(() => {
  if (userRole.value === 'student') return '/profile'
  return '/landlord/profile'
})

const bottomTabs = [
  { name: 'home', route: '/landlord/dashboard' },
  { name: 'tenants', route: '/landlord/tenants' },
  { name: 'messages', route: '/landlord/chat' },
  { name: 'notif', route: '/landlord/notifications' },
] as const

type BottomTabName = 'home' | 'tenants' | 'messages' | 'notif'

const toggleLeftDrawer = () => {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

const goToTab = (tabName: string | number) => {
  const selectedTab = bottomTabs.find(item => item.name === tabName)
  if (selectedTab) {
    void router.push(selectedTab.route)
  }
}

const goToProfile = () => {
  void router.push(profileRoute.value)
}

const toggleFabMenu = () => {
  fabMenuOpen.value = !fabMenuOpen.value
}

const openScreen = (path: string) => {
  fabMenuOpen.value = false
  void router.push(path)
}

watch(
  () => route.path,
  value => {
    if (value.startsWith('/landlord/dashboard')) activeBottomTab.value = 'home'
    else if (value.startsWith('/landlord/tenants')) activeBottomTab.value = 'tenants'
    else if (value.startsWith('/landlord/chat')) activeBottomTab.value = 'messages'
    else if (value.startsWith('/landlord/notifications')) activeBottomTab.value = 'notif'
  },
  { immediate: true },
)

onMounted(async () => {
  try {
    const { profile } = await authStore.getSessionProfile()
    userRole.value = profile?.role ?? ''

    if (!profile?.role) {
      const { data } = await supabase.auth.getUser()
      const user = data?.user

      if (user) {
        const { data: userData } = await supabase.from('users').select('role').eq('id', user.id).single()

        if (userData) {
          userRole.value = userData.role
        }
      }
    }
  } catch {
    userRole.value = 'landlord'
  }
})
</script>

<style scoped>
.app-header {
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}
.app-title {
  font-size: 28px;
  letter-spacing: -0.04em;
}
.menu-button {
  color: #111827;
}
.avatar-button {
  min-width: 36px;
  min-height: 36px;
  padding: 0;
  color: #111827;
}
.profile-icon-shell {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #E6F5F3;
  border: 1px solid rgba(15, 23, 42, 0.06);
}
.profile-action-icon {
  color: #0F766E;
}
.bottom-footer {
  min-height: 84px;
  height: calc(84px + env(safe-area-inset-bottom, 0px));
  padding-bottom: env(safe-area-inset-bottom, 0px);
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 30;
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
  gap: 5px;
  padding: 0;
  border: none;
  background: transparent;
  appearance: none;
  -webkit-appearance: none;
  outline: none;
  cursor: pointer;
  color: #6b7280;
  font-family: inherit;
}
.bottom-nav-item.active {
  color: #0f766e;
}
.bottom-nav-item.active::before {
  content: '';
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 28px;
  height: 3px;
  border-radius: 0 0 3px 3px;
  background: #0f766e;
}
.bottom-nav-icon {
  display: block;
  width: 26px;
  height: 26px;
}
.bottom-nav-label {
  display: block;
  font-size: 12px;
  font-weight: 600;
  line-height: 1;
}
.fab-backdrop {
  position: fixed;
  inset: 0;
  z-index: 25;
  background: rgba(17, 24, 39, 0.22);
  backdrop-filter: blur(6px);
}
.fab-menu-wrap {
  position: absolute;
  right: 22px;
  bottom: 150px;
  z-index: 31;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 10px;
}
.fab-menu-item {
  min-height: 42px;
  padding: 0 18px;
  border-radius: 999px;
  background: white;
  color: #111827;
  box-shadow: 0 12px 26px rgba(15, 23, 42, 0.12);
  border: 1px solid rgba(15, 23, 42, 0.06);
  font-weight: 700;
  font-size: 14px;
}
.fab-close-button {
  width: 44px;
  height: 44px;
  box-shadow: 0 12px 26px rgba(15, 23, 42, 0.2);
}
.fab-button {
  position: absolute;
  right: 22px;
  bottom: 96px;
  box-shadow: 0 10px 22px rgba(0, 137, 123, 0.32);
  z-index: 32;
}
</style>
