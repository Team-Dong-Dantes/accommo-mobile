<template>
  <q-page class="login-page">
    <div class="login-container">
      <h3 class="welcome-title">Welcome back</h3>
      <p class="welcome-subtitle">Sign in to your account</p>

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
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import type { QForm } from 'quasar';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/utils/supabase';
import { useNotify } from '@/utils/notify';

import AuthInput from '@/components/auth/AuthInput.vue';
import AuthButton from '@/components/auth/AuthButton.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';

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

onMounted(() => {
  if (route.query.accountExists) {
    notify.info('Account already exists. Please log in.');
    void router.replace('/login');
  }
});

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
    const { role } = await authStore.login(email.value, password.value);
    notify.success('Welcome back!');

    if (role === 'student') void router.push('/student/home');
    else if (role === 'manager') void router.push('/manager/dashboard');
    else if (role === 'admin') void router.push('/admin/dashboard');
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
      const { error } = await supabase.auth.resetPasswordForEmail(email.value, {
        redirectTo: window.location.origin + '/#/login',
      });
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
  background: white;
  border-radius: 28px 28px 0 0;
  padding: 24px;
  min-height: calc(100vh - 150px);
}

.welcome-title {
  margin: 0;
  font-size: 34px;
  font-weight: 700;
}

.welcome-subtitle {
  color: #8b8b8b;
  margin-top: 6px;
  margin-bottom: 24px;
}

.forgot-link {
  color: #009688;
  font-weight: 600;
}

.signup-section {
  text-align: center;
  margin: 24px 0;
  color: #999;
}
</style>
<style>
.custom-notify {
  border-radius: 20px !important;
  padding: 10px 20px !important;
  font-weight: 500;
}
</style>