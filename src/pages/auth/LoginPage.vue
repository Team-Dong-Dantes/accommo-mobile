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
      <q-form @submit.prevent="handleLogin" ref="loginFormRef">
        <!-- One group, two rows. The decorative envelope/padlock icons are gone:
             each repeated what its own label already said, and in a grouped list
             they crowded the value. -->
        <AuthFieldGroup>
          <AuthInput v-model="email" label="Email address" :rules="[(val: string) => !!val || 'Email is required', (val: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val) || 'Enter a valid email address']" />

          <AuthInput v-model="password" :type="showPassword ? 'text' : 'password'" label="Password"
            :rules="[(val: string) => !!val || 'Password is required']">
            <template #append>
              <IconifyIcon :icon="showPassword ? 'lucide:eye-off' : 'lucide:eye'" class="cursor-pointer"
                @click="showPassword = !showPassword" />
            </template>
          </AuthInput>
        </AuthFieldGroup>

        <div class="text-right q-mt-sm">
          <q-btn flat dense no-caps label="Forgot password?" class="auth-link" @click="handleForgotPassword" />
        </div>

        <AuthButton type="submit" :loading="loading" class="q-mt-md">
          Sign in
          <IconifyIcon icon="lucide:arrow-right" width="18" class="q-ml-sm" />
        </AuthButton>
      </q-form>

      <!-- Google sits below the form: e-mail is the main path here, and leading
           with Google pushed the fields most people came for down the screen. -->
      <AuthDivider />
      <AuthGoogleBtn @click="handleGoogleAuth" />

      <div class="signup-section">
        <span>New to Accommo?</span>
        <!-- Back to the start screen, which is where the role fork lives now.
             /register/role renders the same fork and still exists only because
             the guard sends unregistered Google accounts there (guard.ts:70). -->
        <q-btn flat dense no-caps label="Create account" to="/"
          class="auth-link q-ml-sm" />
      </div>
      </template>
    </div>
  <PinSetupDialog
      v-model="pinOfferOpen"
      mode="set"
      :email="email"
      cancel-label="Skip for now"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import { Capacitor } from '@capacitor/core';
import { useRouter, useRoute } from 'vue-router';
import type { QForm } from 'quasar';
import { useAuthStore } from '@/stores/auth';
import { supabase, readOAuthError, isSignupDatabaseError } from '@/utils/supabase';
import { useNotify } from '@/utils/notify';

import AuthInput from '@/components/auth/AuthInput.vue';
import AuthButton from '@/components/auth/AuthButton.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';
import AuthFieldGroup from '@/components/auth/AuthFieldGroup.vue';
import EmailVerifyInline from '@/components/auth/EmailVerifyInline.vue';
import { ALLOWED_EMAIL_DOMAINS_TEXT } from '@/utils/config';

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
    notify.info('You already have an account — sign in to finish submitting your requirements.');
    void router.replace('/login');
  }
  if (route.query.suspended) {
    notify.error('This account has been suspended. Contact OSAS if you think this is a mistake.');
    void router.replace('/login');
  }
  if (route.query.awaitingApproval) {
    notify.info('Your application is still being reviewed by OSAS. You can sign in once it is approved.');
    void router.replace('/login');
  }
  if (route.query.applicationRejected) {
    notify.error('OSAS did not approve this application. Contact OSAS to reapply.');
    void router.replace('/login');
  }
  if (route.query.adminUsesWeb) {
    notify.info('Admin accounts sign in on the OSAS web app, not here.');
    void router.replace('/login');
  }
  // Bounced here by the router: signed in, but the address was never confirmed.
  if (route.query.verifyEmail) {
    void resumeEmailVerify();
    return;
  }
  void handleOAuthReturn();
});

/**
 * "Continue with Google" returns to this screen, and signInWithOAuth provisions
 * the account whether or not the person had ever registered. Nothing was reading
 * that outcome, so a brand-new Google user just landed back on a login form with
 * no message, and a landlord/landlady still awaiting OSAS got no explanation either.
 */
/**
 * Turns a raw Google failure into something worth showing.
 *
 * The browser's redirect flow reports these in the URL; the native picker
 * throws them instead. Same failures either way, so the wording lives here.
 */
function googleFailureMessage(failure: string): string {
  if (/banned|blocked/i.test(failure)) {
    return 'Your application is still being reviewed by OSAS. You can sign in once it is approved.';
  }
  if (isSignupDatabaseError(failure)) {
    // Almost always the domain rule on auth.users turning away a new Google
    // account, but Supabase gives the same wording to any signup-time database
    // failure — so name the rule without claiming to know that is what it was.
    return `We couldn't connect that Google account. Accommo only accepts ${ALLOWED_EMAIL_DOMAINS_TEXT} addresses — check which account you picked, then try again.`;
  }
  return failure;
}

async function handleOAuthReturn() {
  // Supabase reports OAuth failures (a banned account among them) in the URL.
  const failure = readOAuthError();
  if (failure) {
    notify.error(googleFailureMessage(failure));
    history.replaceState(null, '', window.location.pathname);
    return;
  }

  const { session, profile, registered, status } = await authStore.getSessionProfile();
  if (!session) return;

  if (!registered) {
    // signInWithOAuth provisions an account for whoever clicks the button, so an
    // unregistered session arriving HERE means there was nothing to sign in to.
    // Drop it and let them choose: pushing them into onboarding trapped them,
    // because the guard bounces every route but /login and /register back to the
    // role picker, and this handler bounced /login straight back again.
    // A half-finished e-mail signup is left alone — handleLogin() resumes those
    // when the person actually signs in.
    if (session.user.app_metadata?.provider === 'google') {
      await supabase.auth.signOut();
      authStore.clearCachedRole();
      notify.info('That Google account isn\'t registered yet. Tap Create account to sign up.');
    }
    return;
  }

  const role = profile?.role;
  if (role === 'manager') {
    if (status === 'pending') {
      await supabase.auth.signOut();
      authStore.clearCachedRole();
      notify.info('Your application is still being reviewed by OSAS. You can sign in once it is approved.');
      return;
    }
    if (status === 'rejected' || status === 'reviewing') {
      notify.warning('OSAS needs changes to your application — update it below.');
      void router.push('/register/manager?resubmit=true');
      return;
    }
    // A landlord/landlady holds no session during registration (they are signed out
    // until OSAS approves), so this is the first moment a PIN can be set.
    // Offered once per account, skippable, and settable later in Settings.
    if (!(await hasPinAlready()) && !alreadyOffered()) {
      markOffered();
      pinOfferOpen.value = true;
      return;
    }
    void router.push('/manager/dashboard');
    return;
  }
  if (role === 'student') {
    void router.push(status === 'rejected' || status === 'reviewing' ? '/student/support' : '/student/home');
  }
}

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
    const data = await authStore.loginWithGoogle('/login');
    // The native picker resolves in place — nothing navigates and nothing
    // re-mounts this screen, so the routing onMounted would have done has to be
    // run here instead. On the browser's redirect path this is unreachable:
    // signInWithOAuth has already sent the tab to Google.
    if (data && 'session' in data && data.session) await handleOAuthReturn();
  } catch (error: unknown) {
    // Failures used to arrive as URL params for handleOAuthReturn to shape; the
    // native path throws them instead, so the same wording is applied here.
    notify.error(googleFailureMessage(error instanceof Error ? error.message : 'An error occurred'));
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

    if (role === 'manager' && (status === 'rejected' || status === 'reviewing')) {
      notify.warning('OSAS needs changes to your application — update it below.');
      void router.push('/register/manager?resubmit=true');
      return;
    }

    if (status === 'rejected') {
      notify.warning('OSAS rejected your requirements — re-upload them to try again.');
    } else if (status === 'pending' || status === 'reviewing') {
      notify.info('Your account is still awaiting OSAS review.');
    } else {
      notify.success('Welcome back!');
    }

    // Students are sent straight to the screen where they can act on their
    // status. Landlords and landladies only ever reach this point when already verified —
    // login() refuses the sign-in otherwise.
    const studentNeedsOsas = status === 'rejected' || status === 'reviewing';
    if (role === 'student') void router.push(studentNeedsOsas ? '/student/support' : '/student/home');
    else if (role === 'manager') void router.push('/manager/dashboard');
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
        : window.location.origin + '/login';
      const { error } = await supabase.auth.resetPasswordForEmail(email.value, { redirectTo });
    if (error) throw error;
    notify.success('Password reset link sent to your email.');
  } catch {
    notify.error('Failed to send reset email. Please try again.');
  } finally {
    forgotPasswordLoading.value = false;
  }
}

const pinOfferOpen = ref(false);

async function hasPinAlready() {
  const { data } = await supabase.rpc('has_pin');
  return data === true;
}

/** Offered once per account, so declining is not re-asked at every sign-in. */
function offerKey() {
  return 'accommo:pin-offered';
}
function alreadyOffered() {
  try { return localStorage.getItem(offerKey()) === email.value; } catch { return true; }
}
function markOffered() {
  try { localStorage.setItem(offerKey(), email.value); } catch { /* private mode */ }
}

watch(pinOfferOpen, (open) => {
  if (!open) void router.push('/manager/dashboard');
});
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
  /* Quasar gives h3 a ~50px line-height, which left the title floating well
     above its own subtitle. */
  line-height: 1.12;
  letter-spacing: -0.02em;
}

.welcome-subtitle {
  color: var(--m-muted);
  margin-top: 8px;
  margin-bottom: 26px;
  font-size: 14.5px;
}

.verify-note {
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.5;
  margin-bottom: 16px;
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