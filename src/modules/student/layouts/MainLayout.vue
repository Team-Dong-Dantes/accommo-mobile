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
        <q-item clickable v-ripple to="/student/home" exact>
          <q-item-section avatar><IconifyIcon width="24" icon="material-icons:dashboard" /></q-item-section>
          <q-item-section> Dashboard </q-item-section>
        </q-item>
        <q-item clickable v-ripple to="/student/stay" exact>
          <q-item-section avatar><IconifyIcon width="24" icon="material-icons:bed" /></q-item-section>
          <q-item-section> My Stay </q-item-section>
        </q-item>
        <q-item clickable v-ripple @click="goToProfile">
          <q-item-section avatar><IconifyIcon width="24" icon="material-icons:person" /></q-item-section>
          <q-item-section> Profile </q-item-section>
        </q-item>
      </q-list>
    </q-drawer>

    <q-page-container class="bg-grey-1">
      <router-view />
    </q-page-container>

    <!-- Student Bottom Navigation -->
    <q-footer class="bg-white text-dark" style="border-top: 1px solid #eee;">
      <q-tabs class="text-grey-7" active-color="teal-8" indicator-color="teal-8" align="justify">
        <q-route-tab name="home" icon="cottage" label="Home" to="/student/home" />
        <q-route-tab name="discover" icon="travel_explore" label="Discover" to="/student/discover" />
        <q-route-tab name="messages" icon="forum" label="Messages" to="/student/messages" />
        <q-route-tab name="notif" icon="notifications" label="Notif" to="/student/notifications" />
      </q-tabs>
    </q-footer>

    <!-- FAB Menu (student features) -->
    <div v-if="fabOpen" class="fixed-full bg-black" style="opacity:0.35;z-index:1100" @click="fabOpen = false" />
    <div class="fab-container" style="position:fixed;bottom:86px;right:18px;z-index:1200;display:flex;flex-direction:column;align-items:flex-end;gap:12px">
      <transition-group name="fab-slide">
        <q-btn v-if="fabOpen" key="support" unelevated color="blue-8" label="Support" icon="support_agent" no-caps class="fab-pill text-weight-bold" @click="navigateTo('/student/support')" />
        <q-btn v-if="fabOpen" key="concerns" unelevated color="amber-8" label="Concerns" icon="report_problem" no-caps class="fab-pill text-weight-bold" @click="navigateTo('/student/concerns')" />
        <q-btn v-if="fabOpen" key="pay" unelevated color="teal-8" label="Pay" icon="payments" no-caps class="fab-pill text-weight-bold" @click="navigateTo('/student/payments')" />
      </transition-group>
      <q-btn fab :icon="fabOpen ? 'close' : 'add'" :color="fabOpen ? 'grey-9' : 'teal-8'" class="shadow-4" @click="fabOpen = !fabOpen" />
    </div>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';

const router = useRouter();
const leftDrawerOpen = ref(false);
const userInitials = ref('U');
const fabOpen = ref(false);

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'U';
  if (parts.length === 1) return (parts[0] ?? '').slice(0, 2).toUpperCase();
  return ((parts[0]?.[0] ?? '') + (parts[parts.length - 1]?.[0] ?? '')).toUpperCase();
}

const toggleLeftDrawer = () => { leftDrawerOpen.value = !leftDrawerOpen.value; };

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;
  const { data } = await supabase.from('users').select('full_name').eq('id', user.id).maybeSingle();
  const name = (data as unknown as { full_name: string | null } | null)?.full_name;
  if (name) userInitials.value = initialsOf(name);
});

function navigateTo(path: string) {
  fabOpen.value = false;
  void router.push(path);
}

function goToProfile() {
  void router.push('/student/profile');
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
