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

        <q-avatar color="teal-8" text-color="white" size="36px" class="avatar-badge">
          JD
        </q-avatar>
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
            <q-item-section> My Properties </q-item-section>
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
        <q-tab name="msgs" icon="chat_bubble_outline" label="Msgs" />
        <q-tab name="notif" icon="notifications_none" label="Notif" />
      </q-tabs>

      <q-btn round color="teal-9" icon="add" class="fab-button" @click="goToAddProperty" />
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

type BottomTabName = 'home' | 'tenants' | 'msgs' | 'notif'

const activeBottomTab = ref<BottomTabName>('home')

const profileRoute = computed(() => {
  if (userRole.value === 'student') return '/profile'
  return '/landlord/profile'
})

const bottomTabs = [
  { name: 'home', route: '/landlord/dashboard' },
  { name: 'tenants', route: '/landlord/tenants' },
  { name: 'msgs', route: '/landlord/chat' },
  { name: 'notif', route: '/landlord/notifications' },
] as const

interface SupabaseAuthOverride {
  getUser: () => Promise<{ data: { user: { id: string } | null }; error: Error | null }>
  signOut: () => Promise<{ error: Error | null }>
}

interface SupabaseDatabaseOverride {
  from: (table: string) => {
    select: (columns: string) => {
      eq: (column: string, value: string) => {
        single: () => Promise<{ data: { role: string } | null; error: Error | null }>
      }
    }
  }
}

const toggleLeftDrawer = () => {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

const goToTab = (tabName: string | number) => {
  const selectedTab = bottomTabs.find(item => item.name === tabName)

  if (selectedTab) {
    void router.push(selectedTab.route)
  }
}

const goToAddProperty = () => {
  void router.push('/landlord/properties/new')
}

watch(
  () => route.path,
  value => {
    if (value.startsWith('/landlord/dashboard')) activeBottomTab.value = 'home'
    else if (value.startsWith('/landlord/tenants')) activeBottomTab.value = 'tenants'
    else if (value.startsWith('/landlord/chat')) activeBottomTab.value = 'msgs'
    else if (value.startsWith('/landlord/notifications')) activeBottomTab.value = 'notif'
  },
  { immediate: true },
)

onMounted(async () => {
  try {
    const { profile } = await authStore.getSessionProfile()
    userRole.value = profile?.role ?? ''

    if (!profile?.role) {
      const auth = supabase.auth as unknown as SupabaseAuthOverride
      const { data } = await auth.getUser()
      const user = data?.user

      if (user) {
        const db = supabase as unknown as SupabaseDatabaseOverride
        const { data: userData } = await db.from('users').select('role').eq('id', user.id).single()

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
  border-bottom: 1px solid rgba(15, 23, 42, 0.06)
}

.app-title {
  font-size: 28px
  letter-spacing: -0.04em
}

.menu-button {
  color: #111827
}

.avatar-badge {
  font-size: 12px
  font-weight: 700
}

.bottom-footer {
  height: 78px
  position: fixed
  bottom: 0
  left: 0
  right: 0
  z-index: 30
  box-shadow: 0 -8px 20px rgba(15, 23, 42, 0.08)
}

.bottom-tabs {
  height: 78px
}

.bottom-tabs :deep(.q-tab) {
  min-width: 0
  padding: 0 8px
  font-size: 11px
  font-weight: 600
}

.bottom-tabs :deep(.q-tab__icon) {
  font-size: 22px
  margin-bottom: 4px
}

.fab-button {
  position: absolute
  right: 22px
  bottom: 52px
  box-shadow: 0 10px 22px rgba(0, 137, 123, 0.32)
}
</style>
