<template>
  <q-page class="register-page">
    <div class="register-container column">
      <h3 class="auth-title col-auto">Create Account</h3>
      <p class="auth-subtitle col-auto">Are you a student or a manager?</p>

      <div class="col column q-gutter-y-md q-mt-sm">
        <!-- Student — icon left, forward arrow right -->
        <button type="button" class="role-card full-width" @click="goStudent">
          <span class="role-icon role-icon--student">
            <IconifyIcon icon="material-icons:school" width="24" height="24" />
          </span>
          <span class="col text-left q-ml-md">
            <span class="role-title">Student</span>
            <span class="role-desc">Find and rent a verified boarding house</span>
          </span>
          <span class="role-arrow">
            <IconifyIcon icon="material-icons:arrow_forward" width="20" height="20" />
          </span>
        </button>

        <!-- Manager — back arrow left, icon right -->
        <button type="button" class="role-card role-card--manager full-width" @click="goManager">
          <span class="role-arrow">
            <IconifyIcon icon="material-icons:arrow_back" width="20" height="20" />
          </span>
          <span class="col text-left q-ml-md">
            <span class="role-title">Manager</span>
            <span class="role-desc">List your property and find tenants</span>
          </span>
          <span class="role-icon role-icon--manager">
            <IconifyIcon icon="material-icons:apartment" width="24" height="24" />
          </span>
        </button>
      </div>

      <div class="row justify-center items-center q-mt-lg">
        <span class="text-grey-7" style="font-size: 13px;">Already have an account?</span>
        <q-btn
          flat
          dense
          no-caps
          label="Sign In"
          color="teal-8"
          class="text-weight-bold q-ml-sm"
          to="/login"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { transitionDir } from '@/utils/transition';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/utils/supabase';

const router = useRouter();
const authStore = useAuthStore();

// A Google sign-in is provisioned as 'student' because Google sends no role, so
// the pick made here has to be written back before onboarding continues. Only
// possible while registration is unfinished; the database refuses it afterwards.
async function applyRole(role: 'student' | 'manager') {
  const { data } = await supabase.auth.getSession();
  if (!data.session) return;
  try {
    await authStore.chooseRole(role);
  } catch {
    // Already-registered accounts keep their role; onboarding just continues.
  }
}

async function goStudent() {
  transitionDir.value = 'left';
  await applyRole('student');
  void router.push('/register');
}

async function goManager() {
  transitionDir.value = 'right';
  await applyRole('manager');
  void router.push('/register/manager');
}
</script>

<style scoped>
.register-container {
  background: var(--m-surface);
  border-radius: 0 0 28px 28px;
  padding: 32px 24px 24px;
  min-height: calc(100vh - 160px);
  opacity: 0;
  animation: slideDown 0.6s cubic-bezier(0.25, 1, 0.3, 1) forwards;
}

.auth-title {
  margin: 0 0 0 12px;
  color: var(--m-ink);
  font-size: 34px;
  font-weight: 700;
}

.auth-subtitle {
  color: var(--m-muted);
  margin: 6px 0 8px 12px;
}

.role-card {
  display: flex;
  align-items: center;
  width: 100%;
  border: 1.5px solid var(--m-border);
  border-radius: 18px;
  padding: 18px 20px;
  background: var(--m-bg);
  color: var(--m-ink);
  text-align: left;
  font-family: inherit;
  cursor: pointer;
  transition: border-color 0.2s ease, background 0.2s ease, transform 0.2s ease;
}

.role-card:hover {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
}

.role-card:active {
  transform: scale(0.985);
}

.role-icon {
  flex: 0 0 auto;
  width: 52px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
}

.role-icon--student {
  background: var(--m-primary-soft);
  color: var(--m-primary);
}

.role-icon--manager {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}

.role-title {
  display: block;
  color: var(--m-ink);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.2;
}

.role-desc {
  display: block;
  font-size: 13px;
  color: var(--m-muted);
  margin-top: 3px;
}

.role-arrow {
  flex: 0 0 auto;
  color: var(--m-muted);
  display: inline-flex;
}

@keyframes slideDown {
  0% {
    opacity: 0;
    transform: translateY(-80px);
  }

  100% {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
