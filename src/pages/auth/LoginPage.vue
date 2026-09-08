<template>
  <q-page class="login-page">
    <div class="login-container">
      <h3 class="welcome-title">Welcome back</h3>
      <p class="welcome-subtitle">Sign in to your account</p>

      <template v-if="needsEmailVerify">
        <p class="verify-note">
          Confirm your e-mail address to finish setting up this account. We've sent a
          code to <strong>{{ email }}</strong>.
        </p>
        <EmailVerifyInline :email="email" @verified="onEmailVerified" />
        <q-btn flat dense no-caps label="Use a different account" class="q-mt-md"
          @click="cancelEmailVerify" />
      </template>

      <template v-else>
      <AuthGoogleBtn @click="handleGoogleAuth" />
      <AuthDivider />

      <q-form @submit.prevent="handleLogin" ref="loginFormRef">
        <AuthInput v-model="email" label="Email address" :rules="[(val: string) => !!val || 'Email is required', (val: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val) || 'Enter a valid email address']">
          <template #prepend><IconifyIcon icon="material-icons:mail_outline" /></template>
        </AuthInput>

        <AuthInput v-model="password" :type="showPassword ? 'text' : 'password'" label="Password" class="q-mt-md"
          :rules="[(val: string) => !!val || 'Password is required']">
          <template #prepend><IconifyIcon icon="material-icons:lock_outline" /></template>
          <template #append>
            <IconifyIcon :icon="'material-icons:' + (showPassword ? 'visibility' : 'visibility_off')" class="cursor-pointer"
              @click="showPassword = !showPassword" />
          </template>
        </AuthInput>

        <div class="text-right q-mt-sm">
          <q-btn flat dense no-caps label="Forgot password?" class="forgot-link" @click="handleForgotPassword" />
        </div>

        <AuthButton type="submit" :loading="loading" class="q-mt-md">
          Sign In
          <IconifyIcon icon="material-icons:arrow_forward" class="q-ml-sm" />
        </AuthButton>
      </q-form>

      <div class="signup-section">
        <span>New to Accommo?</span>
        <q-btn flat dense no-caps color="teal-9" label="Create Account" to="/register/role"
          class="text-weight-bold q-ml-sm" />
      </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Capacitor } from '@capacitor/core';
import { useRouter, useRoute } from 'vue-router';
import type { QForm } from 'quasar';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/utils/supabase';
import { useNotify } from '@/utils/notify';

import AuthInput from '@/components/auth/AuthInput.vue';
import AuthButton from '@/components/auth/AuthButton.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';
import EmailVerifyInline from '@/components/auth/EmailVerifyInline.vue';

const router = useRouter();
const route = useRoute();
const notify = useNotify();
const authStore = useAuthStore();

const email = ref('');
const password = ref('');
const showPassword = ref(false);
const loading = ref(false);
const forgotPasswordLoading = ref(false);
const loginFormRef = ref<QForm | null>(null);
const needsEmailVerify = ref(false);
const verifiedRole = ref<string | null>(null);

onMounted(() => {
  if (route.query.accountExists) {
    notify.info('You already have an account — sign in to finish submitting your documents.');
    void router.replace('/login');
  }
  if (route.query.suspended) {
    notify.error('This account has been suspended. Contact OSAS if you think this is a mistake.');
    void router.replace('/login');
  }
  if (route.query.adminUsesWeb) {
    notify.info('Admin accounts sign in on the OSAS web app, not here.');
    void router.replace('/login');
  }
  // Bounced here by the router: signed in, but the address was never confirmed.
  if (route.query.verifyEmail) {
    void resumeEmailVerify();
  }
});

// The router keeps the session when it bounces an unconfirmed address, so the
// e-mail is read back from it rather than asking the user to retype it.
async function resumeEmailVerify() {
  const { data } = await supabase.auth.getUser();
  if (!data?.user?.email) {
    void router.replace('/login');
    return;
  }
  email.value = data.user.email;
  verifiedRole.value = authStore.cachedRole;
  needsEmailVerify.value = true;
  void router.replace('/login');
}

async function onEmailVerified() {
  needsEmailVerify.value = false;
  notify.success('E-mail confirmed.');
  const role = verifiedRole.value ?? (await authStore.getSessionProfile()).profile?.role ?? null;
  if (role === 'student') void router.push('/student/home');
  else if (role === 'manager') void router.push('/manager/dashboard');
  else void router.push('/');
}

async function cancelEmailVerify() {
  await supabase.auth.signOut();
  authStore.clearCachedRole();
  needsEmailVerify.value = false;
  password.value = '';
}

async function handleGoogleAuth() {
  try {
    await authStore.loginWithGoogle('/login');
  } catch (error: unknown) {
    notify.error(error instanceof Error ? error.message : 'An error occurred');
  }
}

async function handleLogin() {
  if (!loginFormRef.value) return;
  const success = await loginFormRef.value.validate();
  if (!success) {
    notify.warning('Please enter your email and password.');
    return;
  }

  try {
    loading.value = true;
    const { role, status, emailVerified } = await authStore.login(email.value, password.value);

    // Admin/OSAS lives in the web client; this app has no admin surface, and
    // pushing to /admin/dashboard used to land them on a 404.
    if (role === 'admin') {
      await supabase.auth.signOut();
      notify.info('Admin accounts sign in on the OSAS web app, not here.');
      return;
    }

    // Session is kept on purpose: the code they need is sent to this account, and
    // signing them out here would leave no way to ever confirm the address.
    if (!emailVerified) {
      verifiedRole.value = role;
      needsEmailVerify.value = true;
      notify.info('Confirm your e-mail address to continue.');
      return;
    }

    if (status === 'rejected') {
      notify.warning('OSAS rejected your documents — re-upload them to try again.');
    } else if (status === 'pending' || status === 'reviewing') {
      notify.info('Your account is still awaiting OSAS review.');
    } else {
      notify.success('Welcome back!');
    }

    // A rejected or pending user is sent straight to the screen where they can
    // actually act on it, instead of a home page that never mentions it.
    const needsOsas = status === 'rejected' || status === 'reviewing';
    if (role === 'student') void router.push(needsOsas ? '/student/support' : '/student/home');
    else if (role === 'manager') void router.push(needsOsas ? '/manager/osas-compliance' : '/manager/dashboard');
    else {
      notify.info('Your account role is not set. Please complete registration.');
      await supabase.auth.signOut();
      void router.push('/register?newUser=true');
    }
  } catch (error: unknown) {
    notify.error(error instanceof Error ? error.message : 'An unexpected error occurred');
  } finally {
    loading.value = false;
  }
}

async function handleForgotPassword() {
  if (!email.value) {
    notify.info('Please enter your email address first.');
    return;
  }

  forgotPasswordLoading.value = true;
  try {
      // On a Capacitor build window.location.origin is not a reachable web
      // origin, so the reset link had nowhere to come back to. Same custom
      // scheme the Google flow already registers.
      const redirectTo = Capacitor.isNativePlatform()
        ? 'com.accommo.app://auth/callback'
        : window.location.origin + '/#/login';
      const { error } = await supabase.auth.resetPasswordForEmail(email.value, { redirectTo });
    if (error) throw error;
    notify.success('Password reset link sent to your email.');
  } catch {
    notify.error('Failed to send reset email. Please try again.');
  } finally {
    forgotPasswordLoading.value = false;
  }
}
</script>

<style scoped>
.login-page {
  padding-top: 150px;
}

.login-container {
  background: var(--m-surface);
  border-radius: 28px 28px 0 0;
  padding: 24px;
  min-height: calc(100vh - 150px);
}

.welcome-title {
  margin: 0;
  color: var(--m-ink);
  font-size: 34px;
  font-weight: 700;
}

.welcome-subtitle {
  color: var(--m-muted);
  margin-top: 6px;
  margin-bottom: 24px;
}

.verify-note {
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.5;
  margin-bottom: 16px;
}

.forgot-link {
  color: var(--m-primary);
  font-weight: 600;
}

.signup-section {
  text-align: center;
  margin: 24px 0;
  color: var(--m-muted);
}
</style>
<style>
.custom-notify {
  border-radius: 20px !important;
  padding: 10px 20px !important;
  font-weight: 500;
}
</style>