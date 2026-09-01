<template>
  <q-layout view="hHh lpR fFf">
    <q-header v-if="!isProfilePage" class="bg-white text-grey-9 app-header">
      <div class="header-row q-px-md">
        <div class="app-title text-black text-weight-bold">accommo</div>
        <q-btn flat round dense class="avatar-button" @click="goToProfile">
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
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'discover' }" @click="goToTab('discover')">
          <IconifyIcon icon="lucide:search" width="22" />
          <span class="bottom-nav-label">Discover</span>
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'messages' }" @click="goToTab('messages')">
          <IconifyIcon icon="lucide:message-circle" width="22" />
          <span class="bottom-nav-label">Messages</span>
        </button>
        <button type="button" class="bottom-nav-item" :class="{ active: activeBottomTab === 'alerts' }" @click="goToTab('alerts')">
          <IconifyIcon icon="lucide:bell" width="22" />
          <span class="bottom-nav-label">Alerts</span>
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
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';
import { initialsOf } from '@/shared/utils/format';

const router = useRouter();
const route = useRoute();
const userInitials = ref('U');
const profileImageUrl = ref<string | null>(null);
const fabOpen = ref(false);
const activeBottomTab = ref<StudentBottomTab>('home');
const isProfilePage = computed(() => route.path === '/student/profile');
const showFab = computed(() => !isProfilePage.value && !route.path.startsWith('/student/notifications'));

type StudentBottomTab = 'home' | 'discover' | 'messages' | 'alerts';

const bottomTabs = [
  { name: 'home', route: '/student/home' },
  { name: 'discover', route: '/student/discover' },
  { name: 'messages', route: '/student/messages' },
  { name: 'alerts', route: '/student/notifications' },
] as const;

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;
  const metadata = user.user_metadata as Record<string, unknown> | undefined;
  const picture = typeof metadata?.avatar_url === 'string'
    ? metadata.avatar_url
    : (typeof metadata?.picture === 'string' ? metadata.picture : '');
  profileImageUrl.value = picture || null;

  const { data } = await supabase
    .from('users')
    .select('initials, full_name')
    .eq('id', user.id)
    .maybeSingle();

  const row = data as { initials: string | null; full_name: string | null } | null;
  userInitials.value = row?.initials || initialsOf(String(row?.full_name || user.email || 'User'));
});

function navigateTo(path: string) {
  fabOpen.value = false;
  void router.push(path);
}

function goToTab(tabName: StudentBottomTab) {
  const selectedTab = bottomTabs.find((item) => item.name === tabName);
  if (selectedTab) void router.push(selectedTab.route);
}

watch(
  () => route.path,
  (path) => {
    if (path === '/student/profile' || path === '/student/home') fabOpen.value = false;
    if (path.startsWith('/student/discover')) activeBottomTab.value = 'discover';
    else if (path.startsWith('/student/messages')) activeBottomTab.value = 'messages';
    else if (path.startsWith('/student/notifications')) activeBottomTab.value = 'alerts';
    else activeBottomTab.value = 'home';
  },
  { immediate: true },
);

function goToProfile() {
  void router.push('/student/profile');
}
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
  font-weight: 700;
  letter-spacing: -0.04em;
  text-transform: lowercase;
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
  background: #e6f5f3;
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
@keyframes quick-actions-in { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
@media (prefers-reduced-motion: reduce) { .bottom-fab, .bottom-fab svg { transition: none; } .quick-action-menu { animation: none; } }
</style>
