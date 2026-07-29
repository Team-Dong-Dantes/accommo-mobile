<template>
  <q-layout view="hHh lpR fFf">
    <q-header elevated class="bg-primary text-white">
      <q-toolbar>
        <q-btn dense flat round icon="menu" @click="toggleLeftDrawer" />

        <q-toolbar-title> Accommo </q-toolbar-title>

        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </q-toolbar>
    </q-header>

    <q-drawer show-if-above v-model="leftDrawerOpen" side="left" bordered>
      <q-list>
        <q-item-label header>Menu</q-item-label>

        <!-- STUDENT MENU -->
        <template v-if="userRole === 'student'">
          <q-item clickable v-ripple to="/student/dashboard" exact>
            <q-item-section avatar>
              <q-icon name="dashboard" />
            </q-item-section>
            <q-item-section> Dashboard </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/student/stay" exact>
            <q-item-section avatar>
              <q-icon name="bed" />
            </q-item-section>
            <q-item-section> My Stay </q-item-section>
          </q-item>
        </template>

        <!-- LANDLORD MENU -->
        <template v-else-if="userRole === 'landlord'">
          <q-item clickable v-ripple to="/landlord/dashboard" exact>
            <q-item-section avatar>
              <q-icon name="dashboard" />
            </q-item-section>
            <q-item-section> Overview </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/landlord/properties" exact>
            <q-item-section avatar>
              <q-icon name="domain" />
            </q-item-section>
            <q-item-section> My Properties </q-item-section>
          </q-item>
        </template>

        <!-- COMMON MENU -->
        <q-item clickable v-ripple to="/profile" exact>
          <q-item-section avatar>
            <q-icon name="person" />
          </q-item-section>
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
import { supabase } from '../utils/supabase';

const router = useRouter();
const leftDrawerOpen = ref(false);
const userRole = ref('');

// Define the auth methods to bypass ESLint/TypeScript errors
interface SupabaseAuthOverride {
  getUser: () => Promise<{ data: { user: { id: string } | null }; error: Error | null }>;
  signOut: () => Promise<{ error: Error | null }>;
}

// Define the database query chain to bypass ESLint/TypeScript errors
interface SupabaseDatabaseOverride {
  from: (table: string) => {
    select: (columns: string) => {
      eq: (
        column: string,
        value: string,
      ) => {
        single: () => Promise<{ data: { role: string } | null; error: Error | null }>;
      };
    };
  };
}

const toggleLeftDrawer = () => {
  leftDrawerOpen.value = !leftDrawerOpen.value;
};

// When the layout loads, check who logged in and grab their role
onMounted(async () => {
  const auth = supabase.auth as unknown as SupabaseAuthOverride;
  const { data } = await auth.getUser();
  const user = data?.user;

  if (user) {
    const db = supabase as unknown as SupabaseDatabaseOverride;
    const { data: userData } = await db.from('users').select('role').eq('id', user.id).single();

    if (userData) {
      userRole.value = userData.role;
    }
  }
});

const handleLogout = async () => {
  const auth = supabase.auth as unknown as SupabaseAuthOverride;
  const { error } = await auth.signOut();

  if (error) {
    console.error('Error logging out:', error.message);
  } else {
    await router.push('/login');
  }
};
</script>
