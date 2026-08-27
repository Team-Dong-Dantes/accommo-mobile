<template>
  <q-page class="login-page">
    <div class="login-container">
      <h3 class="welcome-title">Welcome back</h3>
      <p class="welcome-subtitle">Sign in to your account</p>

      <AuthGoogleBtn @click="handleGoogleAuth" />
      <AuthDivider />

      <q-form v-if="mode === 'email'" @submit.prevent="handleLogin" ref="loginFormRef">
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

      <q-form v-else @submit.prevent="handlePhoneLogin" ref="phoneFormRef">
        <AuthInput :model-value="phoneDigits" @update:model-value="phoneDigits = phNationalDigits($event)" label="Phone Number" class="q-mt-md" maxlength="12" inputmode="numeric"
          :rules="[(val: string) => !!val || 'Phone number is required', (val: string) => phNationalDigits(val).length === 10 || 'Enter your 10-digit mobile number (e.g. 9123456789)']">
          <template #prepend>
            <div class="row items-center no-wrap">
              <IconifyIcon icon="material-icons:phone" class="q-mr-xs" />
              <span class="text-grey-7 text-weight-medium phone-prefix">+63</span>
              <span class="q-ml-xs text-grey-4 phone-prefix">|</span>
            </div>
          </template>
        </AuthInput>

        <AuthInput v-if="otpSent" v-model="otpCode" label="Verification code" class="q-mt-md" maxlength="6" inputmode="numeric"
          :rules="[(val: string) => /^\d{6}$/.test(val) || 'Enter the 6-digit code']">
          <template #prepend><IconifyIcon icon="material-icons:pin" /></template>
        </AuthInput>

        <AuthButton type="submit" :loading="phoneLoading" class="q-mt-md">
          {{ otpSent ? 'Verify code' : 'Send code' }}
          <IconifyIcon icon="material-icons:arrow_forward" class="q-ml-sm" />
        </AuthButton>
      </q-form>

      <div class="text-center q-mt-sm">
        <q-btn flat dense no-caps :label="mode === 'email' ? 'Use phone number instead' : 'Use email instead'" class="switch-link" @click="switchMode" />
      </div>

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
import { useQuasar, type QForm } from 'quasar';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/shared/utils/supabase';
import { normalizePhPhone, phNationalDigits } from '@/shared/utils/format';

import AuthInput from '@/modules/auth/components/AuthInput.vue';
import AuthButton from '@/modules/auth/components/AuthButton.vue';
import AuthGoogleBtn from '@/modules/auth/components/AuthGoogleBtn.vue';
import AuthDivider from '@/modules/auth/components/AuthDivider.vue';

const router = useRouter();
const route = useRoute();
const $q = useQuasar();
const authStore = useAuthStore();

const email = ref('');
const password = ref('');
const showPassword = ref(false);
const loading = ref(false);
const forgotPasswordLoading = ref(false);
const loginFormRef = ref<QForm | null>(null);

const mode = ref<'email' | 'phone'>('email');
const phoneDigits = ref('');
const otpSent = ref(false);
const otpCode = ref('');
const phoneLoading = ref(false);
const phoneFormRef = ref<QForm | null>(null);

onMounted(() => {
  if (route.query.accountExists) {
    $q.notify({
      message: 'Account already exists. Please log in.',
      position: 'top', color: 'grey-9', textColor: 'white', icon: 'info', iconColor: 'amber-4', classes: 'custom-notify'
    });
    void router.replace('/login');
  }
});

async function handleGoogleAuth() {
  try {
    await authStore.loginWithGoogle('/login');
  } catch (error: unknown) {
    $q.notify({ message: error instanceof Error ? error.message : 'An error occurred', position: 'top', color: 'grey-9', textColor: 'white', icon: 'error_outline', iconColor: 'red-4', classes: 'custom-notify' });
  }
}

async function handleLogin() {
  if (!loginFormRef.value) return;
  const success = await loginFormRef.value.validate();
  if (!success) {
    $q.notify({ message: 'Please enter your email and password.', position: 'top', color: 'grey-9', textColor: 'white', icon: 'warning', iconColor: 'amber-4', classes: 'custom-notify' });
    return;
  }

  try {
    loading.value = true;
    const { role } = await authStore.login(email.value, password.value);
    $q.notify({ message: 'Welcome back!', position: 'top', color: 'grey-9', textColor: 'white', icon: 'check_circle', iconColor: 'teal-4', classes: 'custom-notify' });

    if (role === 'student') void router.push('/student/home');
    else if (role === 'landlord') void router.push('/landlord/dashboard');
    else if (role === 'admin') void router.push('/admin/dashboard');
    else void router.push('/');
  } catch (error: unknown) {
    $q.notify({ message: error instanceof Error ? error.message : 'An unexpected error occurred', position: 'top', color: 'grey-9', textColor: 'white', icon: 'error_outline', iconColor: 'red-4', classes: 'custom-notify' });
    } finally {
      loading.value = false;
    }
  }

  async function sendPhoneCode() {
    const digits = phNationalDigits(phoneDigits.value);
    if (digits.length !== 10) {
      $q.notify({ message: 'Enter your 10-digit mobile number (e.g. 9123456789).', position: 'top', color: 'grey-9', textColor: 'white', icon: 'warning', iconColor: 'amber-4', classes: 'custom-notify' });
      return;
    }
    try {
      phoneLoading.value = true;
      await authStore.sendPhoneOtp(normalizePhPhone(phoneDigits.value));
      otpSent.value = true;
      $q.notify({ message: 'Verification code sent to +63' + digits, position: 'top', color: 'grey-9', textColor: 'white', icon: 'check_circle', iconColor: 'teal-4', classes: 'custom-notify' });
    } catch (error: unknown) {
      $q.notify({ message: error instanceof Error ? error.message : 'Could not send code.', position: 'top', color: 'grey-9', textColor: 'white', icon: 'error_outline', iconColor: 'red-4', classes: 'custom-notify' });
    } finally {
      phoneLoading.value = false;
    }
  }

  async function handlePhoneLogin() {
    if (!phoneFormRef.value) return;
    const valid = await phoneFormRef.value.validate();
    if (!valid) return;

    const phone = normalizePhPhone(phoneDigits.value);
    try {
      phoneLoading.value = true;
      if (!otpSent.value) {
        await sendPhoneCode();
        return;
      }
      const { role } = await authStore.verifyPhoneOtp(phone, otpCode.value);
      $q.notify({ message: 'Welcome back!', position: 'top', color: 'grey-9', textColor: 'white', icon: 'check_circle', iconColor: 'teal-4', classes: 'custom-notify' });

      if (role === 'student') void router.push('/student/home');
      else if (role === 'landlord') void router.push('/landlord/dashboard');
      else if (role === 'admin') void router.push('/admin/dashboard');
      else {
        await supabase.auth.signOut();
        void router.push('/register?newUser=true');
      }
    } catch (error: unknown) {
      $q.notify({ message: error instanceof Error ? error.message : 'Verification failed.', position: 'top', color: 'grey-9', textColor: 'white', icon: 'error_outline', iconColor: 'red-4', classes: 'custom-notify' });
    } finally {
      phoneLoading.value = false;
    }
  }

  function switchMode() {
    mode.value = mode.value === 'email' ? 'phone' : 'email';
    otpSent.value = false;
    otpCode.value = '';
  }

  async function handleForgotPassword() {
  if (!email.value) {
    $q.notify({ message: 'Please enter your email address first.', position: 'top', color: 'grey-9', textColor: 'white', icon: 'info', iconColor: 'amber-4', classes: 'custom-notify' });
    return;
  }

  forgotPasswordLoading.value = true;
  try {
    const { error } = await supabase.auth.resetPasswordForEmail(email.value, {
      redirectTo: window.location.origin + '/login',
    });
    if (error) throw error;
    $q.notify({ message: 'Password reset link sent to your email.', position: 'top', color: 'grey-9', textColor: 'white', icon: 'check_circle', iconColor: 'teal-4', classes: 'custom-notify' });
  } catch {
    $q.notify({ message: 'Failed to send reset email. Please try again.', position: 'top', color: 'grey-9', textColor: 'white', icon: 'error_outline', iconColor: 'red-4', classes: 'custom-notify' });
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

.phone-prefix {
  font-size: 16px;
}

.switch-link {
  color: #009688;
  font-weight: 600;
}
</style>
<style>
.custom-notify {
  border-radius: 20px !important;
  padding: 10px 20px !important;
  font-weight: 500;
}
</style>
