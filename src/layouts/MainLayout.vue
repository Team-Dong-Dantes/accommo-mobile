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
              <q-icon name="people" size="24px" />
            </q-item-section>
            <q-item-section> Tenants </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/landlord/payments" exact>
            <q-item-section avatar>
              <q-icon name="payments" size="24px" />
            </q-item-section>
            <q-item-section> Payments </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/landlord/support" exact>
            <q-item-section avatar>
              <q-icon name="help_outline" size="24px" />
            </q-item-section>
            <q-item-section> Support </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/landlord/osas-compliance" exact>
            <q-item-section avatar>
              <q-icon name="policy" size="24px" />
            </q-item-section>
            <q-item-section> OSAS Compliance </q-item-section>
          </q-item>
        </template>

        <template v-else-if="userRole === 'admin'">
          <q-item clickable v-ripple to="/osas/complaints" exact>
            <q-item-section avatar>
              <IconifyIcon width="24" icon="material-icons:inbox" />
            </q-item-section>
            <q-item-section> OSAS Inbox </q-item-section>
          </q-item>
          <q-item clickable v-ripple to="/landlord/osas-compliance" exact>
            <q-item-section avatar>
              <q-icon name="policy" size="24px" />
            </q-item-section>
            <q-item-section> OSAS Compliance </q-item-section>
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

    <q-footer bordered class="bg-white text-grey-8 bottom-footer">
      <div class="bottom-nav">
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'home' }" @click="goToTab('home')">
          <q-icon name="home" size="22px" />
          <span class="bottom-nav-label">Home</span>
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'messages' }" @click="goToTab('messages')">
          <q-icon name="chat" size="22px" />
          <span class="bottom-nav-label">Msgs</span>
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'notif' }" @click="goToTab('notif')">
          <q-icon name="notifications" size="22px" />
          <span class="bottom-nav-label">Notif</span>
        </button>
      </div>

      <q-btn fab icon="add" color="teal-9" class="bottom-fab" @click="goAddProperty" />
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

const profileRoute = computed(() => {
  if (userRole.value === 'student') return '/profile'
  return '/landlord/profile'
})

const bottomTabs = [
  { name: 'home', route: '/landlord/dashboard' },
  { name: 'messages', route: '/landlord/messages' },
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

const goAddProperty = () => {
  void router.push('/landlord/properties/new')
}

watch(
  () => route.path,
  value => {
    if (value.startsWith('/landlord/dashboard')) activeBottomTab.value = 'home'
    else if (value.startsWith('/landlord/messages')) activeBottomTab.value = 'messages'
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
  box-shadow: 0 10px 22px rgba(0, 137, 123, 0.32);
}
</style>
