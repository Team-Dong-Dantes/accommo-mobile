<template>
  <q-page class="register-page">
    <!-- The same sheet and the same question treatment as the register flow it
         leads into, from app.scss. This screen had kept its own copy of both,
         frozen at the 34px body-font heading and the taller sheet register no
         longer uses, so the two halves of one flow stopped matching. -->
    <div class="auth-sheet column">
      <header class="auth-question col-auto">
        <h1>Are you a student or a manager?</h1>
        <p>This sets what Accommo shows you, and OSAS verifies each differently.</p>
      </header>

      <div class="col">
        <RoleFork @pick="pick" />
      </div>

      <div class="role-signin col-auto">
        <span>Already have an account?</span>
        <q-btn flat dense no-caps label="Sign in" class="auth-link q-ml-xs" to="/login" />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/utils/supabase';
import RoleFork from '@/components/auth/RoleFork.vue';

const router = useRouter();
const authStore = useAuthStore();

// Where the guard sends an account whose onboarding never finished — in
// practice a Google sign-in, which is provisioned as 'student' because Google
// sends no role. The pick has to be written back before onboarding continues;
// the database refuses it once registration is complete.
async function applyRole(role: 'student' | 'manager') {
  const { data } = await supabase.auth.getSession();
  if (!data.session) return;
  try {
    await authStore.chooseRole(role);
  } catch {
    // Already-registered accounts keep their role; onboarding just continues.
  }
}

async function pick(role: 'student' | 'manager') {
  await applyRole(role);
  void router.push(role === 'student' ? '/register' : '/register/manager');
}
</script>

<style scoped>
/* The sheet and the question come from app.scss now; only this screen's own
   footer lives here. */
.role-signin {
  display: flex;
  height: 52px;
  align-items: center;
  justify-content: center;
  color: var(--m-muted);
  font-size: 13px;
}
</style>
