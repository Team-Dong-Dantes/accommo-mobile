<template>
  <q-layout view="hHh lpR fFf">
    <q-header elevated class="bg-primary text-white">
      <q-toolbar>
        <q-btn dense flat round @click="toggleLeftDrawer">
          <IconifyIcon width="24" icon="material-icons:menu" />
        </q-btn>
        <q-toolbar-title> Accommo </q-toolbar-title>
        <q-btn flat round dense @click="goToProfile">
          <q-avatar size="32px" color="white" text-color="primary" class="text-weight-bold">
            {{ userInitials }}
          </q-avatar>
        </q-btn>
      </q-toolbar>
    </q-header>

    <q-drawer show-if-above v-model="leftDrawerOpen" side="left" bordered>
      <q-list>
        <q-item-label header>Menu</q-item-label>
        <template v-if="userRole === 'student'">
          <q-item clickable v-ripple to="/student/home" exact>
            <q-item-section avatar><IconifyIcon width="24" icon="material-icons:dashboard" /></q-item-section>
            <q-item-section> Dashboard </q-item-section>
          </q-item>
          <q-item clickable v-ripple to="/student/stay" exact>
            <q-item-section avatar><IconifyIcon width="24" icon="material-icons:bed" /></q-item-section>
            <q-item-section> My Stay </q-item-section>
          </q-item>
        </template>
        <template v-else-if="userRole === 'landlord'">
          <q-item clickable v-ripple to="/landlord/dashboard" exact>
            <q-item-section avatar><IconifyIcon width="24" icon="material-icons:dashboard" /></q-item-section>
            <q-item-section> Overview </q-item-section>
          </q-item>
          <q-item clickable v-ripple to="/landlord/properties" exact>
            <q-item-section avatar><IconifyIcon width="24" icon="material-icons:domain" /></q-item-section>
            <q-item-section> My Properties </q-item-section>
          </q-item>
        </template>
        <q-item clickable v-ripple to="/profile" exact>
          <q-item-section avatar><IconifyIcon width="24" icon="material-icons:person" /></q-item-section>
          <q-item-section> Profile </q-item-section>
        </q-item>
      </q-list>
    </q-drawer>

    <q-page-container class="bg-grey-1">
      <router-view />
    </q-page-container>

    <!-- Student Bottom Navigation (shared across all student pages) -->
    <q-footer v-if="isStudentRoute" class="bg-white text-dark" style="border-top: 1px solid #eee;">
      <q-tabs class="text-grey-7" active-color="teal-8" indicator-color="teal-8" align="justify">
        <q-route-tab name="home" icon="cottage" label="Home" to="/student/home" />
        <q-route-tab name="discover" icon="travel_explore" label="Discover" to="/student/discover" />
        <q-route-tab name="messages" icon="forum" label="Messages" to="/student/messages" />
        <q-route-tab name="notif" icon="notifications" label="Notif" to="/student/notifications" />
      </q-tabs>
    </q-footer>

    <!-- FAB Menu (student only) -->
    <template v-if="userRole === 'student'">
      <div v-if="fabOpen" class="fixed-full bg-black" style="opacity:0.35;z-index:1100" @click="fabOpen = false" />

      <div class="fab-container" style="position:fixed;bottom:86px;right:18px;z-index:1200;display:flex;flex-direction:column;align-items:flex-end;gap:12px">
        <transition-group name="fab-slide">
          <q-btn
            v-if="fabOpen" key="support"
            unelevated color="blue-8" label="Support" icon="support_agent" no-caps
            class="fab-pill text-weight-bold" @click="navigateTo('/student/support')"
          />
          <q-btn
            v-if="fabOpen" key="concerns"
            unelevated color="amber-8" label="Concerns" icon="report_problem" no-caps
            class="fab-pill text-weight-bold" @click="navigateTo('/student/concerns')"
          />
          <q-btn
            v-if="fabOpen" key="pay"
            unelevated color="teal-8" label="Pay" icon="payments" no-caps
            class="fab-pill text-weight-bold" @click="navigateTo('/student/payments')"
          />
        </transition-group>
        <q-btn
          fab :icon="fabOpen ? 'close' : 'add'"
          :color="fabOpen ? 'grey-9' : 'teal-8'"
          class="shadow-4" @click="fabOpen = !fabOpen"
        />
      </div>
    </template>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { supabase } from '../shared/utils/supabase';

const router = useRouter();
const route = useRoute();
const leftDrawerOpen = ref(false);
const userRole = ref('');
const userInitials = ref('U');
const fabOpen = ref(false);

interface SupabaseAuthOverride {
  getUser: () => Promise<{ data: { user: { id: string } | null }; error: Error | null }>;
}

interface SupabaseDatabaseOverride {
  from: (table: string) => {
    select: (columns: string) => {
      eq: (column: string, value: string) => {
        single: () => Promise<{ data: { role: string; initials?: string | null } | null; error: Error | null }>;
      };
    };
  };
}

// Show the bottom nav only on student pages
const isStudentRoute = computed(() => route.path.startsWith('/student'));

const toggleLeftDrawer = () => { leftDrawerOpen.value = !leftDrawerOpen.value; };

onMounted(async () => {
  const auth = supabase.auth as unknown as SupabaseAuthOverride;
  const { data } = await auth.getUser();
  const user = data?.user;
  if (user) {
    const db = supabase as unknown as SupabaseDatabaseOverride;
    const { data: userData } = await db.from('users').select('role, initials').eq('id', user.id).single();
    if (userData) {
      userRole.value = userData.role;
      userInitials.value = userData.initials ?? 'U';
    }
  }
});

function navigateTo(path: string) {
  fabOpen.value = false;
  void router.push(path);
}

function goToProfile() {
  if (userRole.value === 'student') {
    void router.push('/student/profile');
  } else if (userRole.value === 'landlord') {
    void router.push('/profile');
  }
}
</script>

<style scoped>
.fab-pill {
  border-radius: 24px;
  padding: 0 20px;
  min-height: 40px;
  font-size: 14px;
}
.fab-slide-enter-active,
.fab-slide-leave-active {
  transition: all 0.2s ease;
}
.fab-slide-enter-from,
.fab-slide-leave-to {
  opacity: 0;
  transform: translateY(10px);
}
</style>
