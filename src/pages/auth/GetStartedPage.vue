<template>
  <!-- AuthLayout's splash hero carries the photograph and the wordmark in the
       top corner. Everything here sits on the dark end of its scrim, so the
       pitch and the fork read against the image rather than over flat colour. -->
  <q-page class="getstarted-page">
    <h1 class="pitch-line">{{ PITCH_LINE }}</h1>

    <!-- Landscape puts the pitch on the photograph (app.scss hides the line
         above), which would leave the panel opening with two unexplained rows.
         The fork's own question introduces them, in the same words
         /register/role uses. -->
    <header v-if="isTablet" class="auth-question">
      <h1>{{ ROLE_QUESTION }}</h1>
      <p>{{ ROLE_QUESTION_NOTE }}</p>
    </header>

    <RoleFork :variant="isTablet ? 'solid' : 'glass'" @pick="pick" />

    <p class="signin">
      Already have an account?
      <button type="button" class="signin-link" @click="router.push('/login')">Sign in</button>
    </p>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { PITCH_LINE, ROLE_QUESTION, ROLE_QUESTION_NOTE } from '@/utils/config';
import { isTablet } from '@/utils/useTabletMode';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/utils/supabase';
import RoleFork from '@/components/auth/RoleFork.vue';

const router = useRouter();
const authStore = useAuthStore();

// A Google sign-in is provisioned as 'student' because Google sends no role, so
// the pick made here has to be written back before onboarding continues. Only
// possible while registration is unfinished; the database refuses it afterwards.
// Signed-out visitors — almost everyone who reaches this screen — have no
// session and fall straight through.
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
.getstarted-page {
  display: flex;
  min-height: 100vh;
  min-height: 100dvh;
  flex-direction: column;
  justify-content: flex-end;
  gap: 14px;
  padding: clamp(16px, 4vw, 28px);
  padding-top: calc(env(safe-area-inset-top) + 72px);
  padding-bottom: calc(clamp(16px, 4vw, 28px) + env(safe-area-inset-bottom));
}

.pitch-line {
  margin: 0 0 18px;
  color: #fff;
  font-family: var(--m-font-display);
  font-size: clamp(27px, 8vw, 34px);
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.14;
  text-wrap: balance;
}

.signin {
  margin: 4px 0 0;
  color: rgba(255, 255, 255, 0.88);
  font-size: 14px;
  text-align: center;
}
.signin-link {
  padding: 8px 4px;
  border: 0;
  background: none;
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-weight: 700;
  text-decoration: underline;
  text-underline-offset: 3px;
  -webkit-tap-highlight-color: transparent;
}

/* Short screens: the headline is the first thing to give up space. */
@media (max-height: 640px) {
  .getstarted-page { padding-top: calc(env(safe-area-inset-top) + 56px); }
  .pitch-line { font-size: 24px; }
}
</style>
