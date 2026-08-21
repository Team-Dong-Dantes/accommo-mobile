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

    <q-footer bordered class="bg-white text-grey-8 bottom-footer">
      <q-tabs
        v-model="activeBottomTab"
        indicator-color="teal-9"
        active-color="teal-9"
        class="bottom-tabs"
        @update:model-value="goToTab"
      >
        <q-tab name="home" icon="home" label="Home" />
        <q-tab name="tenants" icon="groups" label="Tenants" />
        <q-tab name="payments" icon="payments" label="Payments" />
        <q-tab name="support" icon="help_outline" label="Support" />
        <q-tab name="notif" icon="notifications" label="Notifications" />
      </q-tabs>
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
  { name: 'tenants', route: '/landlord/tenants' },
  { name: 'payments', route: '/landlord/payments' },
  { name: 'support', route: '/landlord/support' },
  { name: 'notif', route: '/landlord/notifications' },
] as const

type BottomTabName = 'home' | 'tenants' | 'payments' | 'support' | 'notif'

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

watch(
  () => route.path,
  value => {
    if (value.startsWith('/landlord/dashboard')) activeBottomTab.value = 'home'
    else if (value.startsWith('/landlord/tenants')) activeBottomTab.value = 'tenants'
    else if (value.startsWith('/landlord/payments')) activeBottomTab.value = 'payments'
    else if (value.startsWith('/landlord/support')) activeBottomTab.value = 'support'
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
  height: 64px;
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 30;
  box-shadow: 0 -8px 20px rgba(15, 23, 42, 0.08);
}
.bottom-tabs {
  height: 64px;
}
.bottom-tabs :deep(.q-tab) {
  min-width: 0;
  padding: 0 4px;
  font-size: 11px;
  font-weight: 600;
}
.bottom-tabs :deep(.q-tab__icon) {
  font-size: 22px;
  margin-bottom: 2px;
}
</style>
