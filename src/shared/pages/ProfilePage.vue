<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <div>
          <h4 class="q-my-none text-weight-bold">My Profile</h4>
          <p class="text-subtitle1 text-white-7 q-mb-none">Your account details</p>
        </div>
      </div>
    </div>

    <div class="content-section q-pa-md">
      <q-card flat bordered class="custom-card">
        <q-card-section>
          <div class="row items-center q-col-gutter-md">
            <div class="col-auto">
              <q-avatar size="64px" color="teal-9" text-color="white" font-size="32px">
                {{ initials }}
              </q-avatar>
            </div>
            <div class="col">
              <div class="text-h6 text-weight-bold">{{ displayName }}</div>
              <div class="text-subtitle2 text-grey-7">{{ email }}</div>
            </div>
            <div class="col-auto" v-if="role">
              <q-badge color="teal" :label="role" />
            </div>
          </div>
        </q-card-section>
        <q-separator />
        <q-card-actions align="right" class="q-pa-md">
          <q-btn
            unelevated
            color="teal-9"
            class="action-btn"
            label="Sign Out"
            @click="handleLogout"
          />
        </q-card-actions>
      </q-card>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';

const router = useRouter();

const email = ref('');
const role = ref('');
const error = ref<string | null>(null);

const displayName = computed(() => {
  const local = email.value.split('@')[0] ?? '';
  const pretty = local.replace(/[._-]+/g, ' ').trim();
  if (!pretty) return 'Demo User';
  return pretty.replace(/\b\w/g, (letter) => letter.toUpperCase());
});

const initials = computed(() => {
  const parts = displayName.value.split(' ').filter(Boolean);
  return ((parts[0]?.[0] ?? 'U') + (parts[1]?.[0] ?? '')).toUpperCase();
});

async function loadProfile() {
  error.value = null;
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      void router.push('/login');
      return;
    }

    email.value = user.email ?? 'demo@accommo.local';

    const { data: userData } = await supabase
      .from('users')
      .select('role')
      .eq('id', user.id)
      .single();

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const roleValue = (userData as { role?: string } | null)?.role;
    if (roleValue) role.value = roleValue;
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load profile';
  }
}

async function handleLogout() {
  await supabase.auth.signOut();
  void router.push('/login');
}

onMounted(loadProfile);
</script>

<style scoped>
.header-section {
  background: #004d40;
  border-radius: 0 0 28px 28px;
  margin-bottom: -40px;
}
.text-white-7 {
  color: rgba(255, 255, 255, 0.7);
}
.content-section {
  position: relative;
  z-index: 1;
}
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}
.action-btn {
  border-radius: 12px;
  font-weight: 600;
  padding: 8px 24px;
}
</style>
