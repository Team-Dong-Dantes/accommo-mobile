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
        <q-item clickable v-ripple to="/landlord/dashboard" exact>
          <q-item-section avatar><IconifyIcon width="24" icon="material-icons:dashboard" /></q-item-section>
          <q-item-section> Overview </q-item-section>
        </q-item>
        <q-item clickable v-ripple to="/landlord/properties" exact>
          <q-item-section avatar><IconifyIcon width="24" icon="material-icons:domain" /></q-item-section>
          <q-item-section> My Properties </q-item-section>
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
  </q-layout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';

const router = useRouter();
const leftDrawerOpen = ref(false);
const userInitials = ref('U');

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

function goToProfile() {
  void router.push('/profile');
}
</script>
