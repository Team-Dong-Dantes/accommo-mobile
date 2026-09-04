<template>
  <q-page class="register-page">
    <div class="register-container column">
      <h3 class="auth-title col-auto">
        {{ isGoogleMode ? 'Complete Profile' : 'Manager Application' }}
      </h3>
      <p class="auth-subtitle col-auto">Partner with Accommo to rent your property</p>

      <q-form ref="registerFormRef" class="col column" @submit.prevent="handleRegister">
        <q-stepper v-model="step" ref="stepper" color="teal-9" active-color="teal-9" done-color="teal-9" animated flat
          alternative-labels class="bg-transparent auth-stepper col-auto">

          <q-step :name="1" title="Personal" icon="person" :done="step > 1">
            <template v-if="!isGoogleMode">
              <AuthGoogleBtn @click="handleGoogleAuth">Continue with Google</AuthGoogleBtn>
              <AuthDivider />
            </template>
            <template v-else>
              <ConnectedGoogleBox :email="form.email" @cancel="cancelGoogle" />
            </template>

            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <AuthInput v-model="form.firstName" label="First Name"
                  :rules="[(val: string) => !!val || 'First name is required']">
                  <template #prepend><IconifyIcon icon="material-icons:person_outline" /></template>
                </AuthInput>
              </div>
              <div class="col-6">
                <AuthInput v-model="form.lastName" label="Last Name"
                  :rules="[(val: string) => !!val || 'Last name is required']">
                  <template #prepend><IconifyIcon icon="material-icons:badge" /></template>
                </AuthInput>
              </div>
            </div>

            <AuthSelect v-model="form.sex" :options="sexOptions" label="Sex" class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your sex']">
              <template #prepend><IconifyIcon icon="material-icons:wc" /></template>
            </AuthSelect>

            <AuthInput :model-value="form.phoneDigits"
              @update:model-value="form.phoneDigits = phNationalDigits($event).slice(0, 10)" label="Phone Number"
              class="q-mt-md" maxlength="10" inputmode="numeric" placeholder="9123456789"
              :rules="[(val: string) => !!val || 'Phone number is required', (val: string) => /^\d{10}$/.test(val) || 'Enter exactly 10 digits', (val: string) => /^9\d{9}$/.test(val) || 'Must start with 9 (e.g. 9123456789)']">
              <template #prepend>
                <div class="row items-center no-wrap">
                  <IconifyIcon icon="material-icons:phone" class="q-mr-xs" />
                  <span class="text-grey-7 text-weight-medium phone-prefix">+63</span>
                  <span class="q-ml-xs text-grey-4 phone-prefix">|</span>
                </div>
              </template>
            </AuthInput>
          </q-step>

          <q-step v-if="!isGoogleMode" :name="2" title="Account" icon="settings" :done="step > 2">
            <AuthInput
              v-model="form.emailUser"
              label="Email"
              :rules="[
                (val: string) => !!val || 'Email is required',
                (val: string) => /^[a-zA-Z0-9._%+-]+$/.test(val) || 'Invalid email username',
              ]"
            >
              <template #prepend><IconifyIcon icon="material-icons:mail_outline" /></template>
              <template #append>
                <div class="row items-center no-wrap">
                  <span class="text-grey-7 text-weight-medium q-mr-xs" style="font-size: 16px">@</span>
                  <q-select
                    v-model="form.emailDomain"
                    :options="emailDomains"
                    borderless
                    dense
                    hide-bottom-space
                    class="email-domain-select"
                    style="min-width: 105px"
                  />
                </div>
              </template>
            </AuthInput>

            <AuthInput v-model="form.password" :type="showPassword ? 'text' : 'password'" label="Password"
              class="q-mt-md"
              :rules="[
                (val: string) => !!val || 'Password is required',
                (val: string) => val.length >= 8 || 'At least 8 characters',
                (val: string) => /[a-z]/.test(val) || 'Must include a lowercase letter',
                (val: string) => /[A-Z]/.test(val) || 'Must include an uppercase letter',
                (val: string) => /\d/.test(val) || 'Must include a number',
                (val: string) => /[!@#$%^&*]/.test(val) || 'Must include a special character (!@#$%^&*)',
              ]">
              <template #prepend><IconifyIcon icon="material-icons:lock_outline" /></template>
              <template #append>
                <IconifyIcon :icon="'material-icons:' + (showPassword ? 'visibility' : 'visibility_off')" class="cursor-pointer"
                  @click="showPassword = !showPassword" />
              </template>
            </AuthInput>

            <ul class="password-checklist q-mt-sm">
              <li v-for="item in passwordChecks" :key="item.label" :class="{ ok: item.ok }">
                <IconifyIcon :icon="item.ok ? 'material-icons:check_circle' : 'material-icons:radio_button_unchecked'" />
                <span>{{ item.label }}</span>
              </li>
            </ul>

            <AuthInput v-model="form.confirmPassword" :type="showConfirmPassword ? 'text' : 'password'"
              label="Confirm Password" class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please confirm your password', (val: string) => val === form.password || 'Passwords do not match']">
              <template #prepend><IconifyIcon icon="material-icons:lock_reset" /></template>
              <template #append>
                <IconifyIcon :icon="'material-icons:' + (showConfirmPassword ? 'visibility' : 'visibility_off')" class="cursor-pointer"
                  @click="showConfirmPassword = !showConfirmPassword" />
              </template>
            </AuthInput>
          </q-step>

          <q-step v-if="!isGoogleMode" :name="3" title="Confirm e-mail" icon="mail" :done="step > 3">
            <template v-if="!emailCreated">
              <div class="q-pa-sm">
                <p class="otp-note text-grey-7">We’ll create your manager account, then send a code to your inbox to confirm your e-mail before you continue.</p>
                <AuthButton @click="createAccountNow" :loading="creatingAccount">Create account &amp; send code
                  <IconifyIcon icon="material-icons:arrow_forward" class="q-ml-sm" /></AuthButton>
              </div>
            </template>
            <template v-else>
              <EmailVerifyInline v-if="!emailVerified" :email="form.email" @verified="onEmailVerified" />
              <div v-else class="otp-verified">
                <IconifyIcon icon="material-icons:check_circle" color="teal-6" size="28" class="q-mr-sm" />
                <div><strong>E-mail confirmed</strong><span class="text-grey-7"> Continue to upload your documents.</span></div>
              </div>
            </template>
          </q-step>

          <q-step :name="4" title="Verification" icon="verified_user" :done="step > 4">
            <div class="q-mt-xs q-mb-md text-subtitle2 text-grey-8 font-weight-medium">
              Upload verification documents
            </div>

            <AuthFileDropZone v-model="form.governmentIdFile" label="Tap to upload Valid Government ID"
              accept=".jpg, image/*, .pdf" :rules="[(val: File | null) => !!val || 'Government ID is required']"
              hide-bottom-space>
              <template #prepend><IconifyIcon icon="material-icons:badge" color="teal-9" /></template>
              <template #append><IconifyIcon icon="material-icons:cloud_upload" color="grey-5" /></template>
            </AuthFileDropZone>

            <AuthFileDropZone v-model="form.businessPermitFile" label="Tap to upload Business / Mayor's Permit"
              accept=".jpg, image/*, .pdf" class="q-mt-md"
              :rules="[(val: File | null) => !!val || 'Business Permit is required']" hide-bottom-space>
              <template #prepend><IconifyIcon icon="material-icons:description" color="teal-9" /></template>
              <template #append><IconifyIcon icon="material-icons:cloud_upload" color="grey-5" /></template>
            </AuthFileDropZone>
          </q-step>
        </q-stepper>

        <div class="q-px-sm q-mt-md">
          <AuthButton v-if="step < 4" @click="nextStep">
            NEXT STEP
            <IconifyIcon icon="material-icons:arrow_forward" class="q-ml-sm" />
          </AuthButton>

          <AuthButton v-if="step === 4" type="submit" :loading="loading" :disable="creatingAccount">
            {{ isGoogleMode ? 'SUBMIT APPLICATION' : 'REGISTER' }}
            <IconifyIcon icon="material-icons:check_circle" class="q-ml-sm" />
          </AuthButton>

          <div class="row justify-center items-center q-mt-md full-width" style="height: 32px">
            <template v-if="step === 1 && !isGoogleMode">
              <span class="text-grey-7">Already a partner?</span>
              <q-btn to="/login" flat dense no-caps label="Sign In" color="teal-9"
                class="text-weight-bold q-ml-sm nav-link-btn" />
            </template>

            <template v-else-if="step === 2 || step === 3">
              <q-btn flat dense no-caps label="Go Back" color="grey-6" class="text-weight-bold nav-link-btn"
                @click="prevStep" />
            </template>
            <template v-else-if="step === 4">
              <q-btn flat dense no-caps label="Go Back" color="grey-6" class="text-weight-bold nav-link-btn"
                @click="prevStep" />
            </template>
          </div>
        </div>
      </q-form>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useQuasar, type QForm } from 'quasar';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/shared/utils/supabase';
import { normalizePhPhone, phNationalDigits } from '@/shared/utils/format';

import AuthInput from '@/components/auth/AuthInput.vue';
import AuthSelect from '@/components/auth/AuthSelect.vue';
import AuthFileDropZone from '@/components/auth/AuthFileDropZone.vue';
import AuthButton from '@/components/auth/AuthButton.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';
import ConnectedGoogleBox from '@/components/auth/ConnectedGoogleBox.vue';
import EmailVerifyInline from '@/components/auth/EmailVerifyInline.vue';

const router = useRouter();
const route = useRoute();
const $q = useQuasar();
const authStore = useAuthStore();

const step = ref(1);
const registerFormRef = ref<QForm | null>(null);
const isGoogleMode = ref(false);
const needEmailOtp = ref(false);
const emailCreated = ref(false);
const emailVerified = ref(false);
const creatingAccount = ref(false);
let createdUserId: string | null = null;
const googleUserId = ref('');

const sexOptions = ['Male', 'Female'];
const emailDomains = ['gmail.com', 'isu.edu.ph'];

const form = reactive({
  firstName: '',
  lastName: '',
  fullName: '',
  sex: '',
  phoneDigits: '',
  phone: '',
  emailUser: '',
  emailDomain: 'gmail.com',
  email: '',
  password: '',
  confirmPassword: '',
  governmentIdFile: null as File | null,
  businessPermitFile: null as File | null,
});

const passwordChecks = computed(() => {
  const pwd = form.password;
  return [
    { label: 'At least 8 characters', ok: pwd.length >= 8 },
    { label: 'One lowercase letter', ok: /[a-z]/.test(pwd) },
    { label: 'One uppercase letter', ok: /[A-Z]/.test(pwd) },
    { label: 'One number', ok: /\d/.test(pwd) },
    { label: 'One special character (!@#$%^&*)', ok: /[!@#$%^&*]/.test(pwd) },
  ];
});

function splitFullName(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return {
    firstName: parts[0] ?? '',
    lastName: parts.slice(1).join(' '),
  };
}

function syncFullName() {
  form.fullName = `${form.firstName} ${form.lastName}`.trim().replace(/\s+/g, ' ');
}

const showPassword = ref(false);
const showConfirmPassword = ref(false);
const loading = ref(false);

onMounted(async () => {
  if (route.query.newUser) {
    $q.notify({
      message: 'Account not found. Please complete your application.',
      position: 'top',
      color: 'grey-9',
      textColor: 'white',
      icon: 'info',
      iconColor: 'amber-4',
      classes: 'custom-notify',
    });
    void router.replace('/register/manager');
  }

  const { session, profile } = await authStore.getSessionProfile();

  if (session && !profile) {
    isGoogleMode.value = true;
    googleUserId.value = session.user.id;
    form.email = session.user.email || '';
    const split = splitFullName(String(session.user.user_metadata?.full_name || ''));
    form.firstName = split.firstName;
    form.lastName = split.lastName;
    syncFullName();
  }
});

async function createAccountNow(): Promise<boolean> {
  if (emailCreated.value || creatingAccount.value) return emailCreated.value;
  creatingAccount.value = true;
  try {
    syncFullName();
    if (form.phoneDigits) form.phone = normalizePhPhone(form.phoneDigits);
    if (!isGoogleMode.value) form.email = `${form.emailUser}@${form.emailDomain}`;
    createdUserId = await authStore.createManagerAccount(form);
    emailCreated.value = true;
    return true;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Could not create your account.';
    $q.notify({ message, position: 'top', color: 'grey-9', textColor: 'white', icon: 'error_outline', iconColor: 'red-4', classes: 'custom-notify' });
    return false;
  } finally {
    creatingAccount.value = false;
  }
}

async function nextStep() {
  if (!registerFormRef.value) return;
  const success = await registerFormRef.value.validate();
  if (!success) return;
  if (isGoogleMode.value) {
    if (step.value === 1) step.value = 4;   // skip Account(2)/Confirm(3) -> Verification(4)
    else if (step.value < 4) step.value++;
    return;
  }
  if (step.value === 2) {
    const ok = await createAccountNow();
    if (ok) step.value = 3;
    return;
  }
  if (step.value === 3 && !emailVerified.value) {
    $q.notify({ message: 'Confirm your e-mail before continuing.', position: 'top', color: 'grey-9', textColor: 'white', icon: 'info', iconColor: 'amber-4', classes: 'custom-notify' });
    return;
  }
  if (step.value < 4) step.value++;
}

function prevStep() {
  if (step.value === 4 && isGoogleMode.value) step.value = 1;
  else if (step.value > 1) step.value--;
}

async function handleGoogleAuth() {
  try {
    await authStore.loginWithGoogle('/register/manager');
  } catch (error: unknown) {
    $q.notify({
      message: error instanceof Error ? error.message : 'An error occurred',
      position: 'top',
      color: 'grey-9',
      textColor: 'white',
      icon: 'error_outline',
      iconColor: 'red-4',
      classes: 'custom-notify',
    });
  }
}

async function cancelGoogle() {
  await supabase.auth.signOut();
  isGoogleMode.value = false;
  googleUserId.value = '';
  form.email = '';
  form.firstName = '';
  form.lastName = '';
  form.fullName = '';
  form.emailDomain = 'gmail.com';

  $q.notify({
    message: 'Google account unlinked.',
    color: 'grey-9',
    textColor: 'white',
    icon: 'info',
    position: 'top',
    classes: 'custom-notify',
  });
}

async function handleRegister() {
  syncFullName();
  form.phone = normalizePhPhone(form.phoneDigits);
  if (!isGoogleMode.value) {
    form.email = `${form.emailUser}@${form.emailDomain}`;
  }

  if (!registerFormRef.value) return;

  const success = await registerFormRef.value.validate();
  if (!success) {
    return;
  }

  try {
    loading.value = true;

    if (isGoogleMode.value) {
      await authStore.completeGoogleManagerProfile(googleUserId.value, form);
      $q.notify({
        message: 'Application submitted successfully!',
        position: 'top',
        color: 'grey-9',
        textColor: 'white',
        icon: 'check_circle',
        iconColor: 'teal-4',
        classes: 'custom-notify',
      });
      void router.push('/manager/dashboard');
    } else {
      if (createdUserId) {
        await authStore.finalizeManagerAccount(createdUserId, form);
      } else {
        await authStore.registerManager(form); // safety fallback (no early account)
      }
      $q.notify({
        message: 'Application submitted! OSAS will review your documents. Check your e-mail for updates.',
        position: 'top',
        color: 'grey-9',
        textColor: 'white',
        icon: 'check_circle',
        iconColor: 'teal-4',
        classes: 'custom-notify',
      });
      void router.push('/login');
    }
  } catch (error: unknown) {
    $q.notify({
      message: error instanceof Error ? error.message : 'An unexpected error occurred',
      position: 'top',
      color: 'grey-9',
      textColor: 'white',
      icon: 'error_outline',
      iconColor: 'red-4',
      classes: 'custom-notify',
    });
  } finally {
    loading.value = false;
  }
}

function onEmailVerified() {
  emailVerified.value = true; // Confirm-e-mail step passed; docs submit is next
}

</script>

<style scoped>
.register-container {
  background: white;
  border-radius: 0 0 28px 28px;
  padding: 24px 24px 24px;
  min-height: calc(100vh - 160px);
  opacity: 0;
  animation: slideDown 0.6s cubic-bezier(0.25, 1, 0.3, 1) forwards;
}

.auth-stepper :deep(.q-stepper__content) {
  min-height: 40vh;
  overflow-y: auto;
}

.auth-stepper :deep(.q-stepper__step-inner) {
  padding: 0;
  overflow: visible;
  min-width: 0;
}

.auth-stepper :deep(.q-stepper__header) {
  padding: 0;
  min-height: 0;
}

.auth-stepper :deep(.q-stepper__tab) {
  padding: 8px 2px;
}

.auth-stepper :deep(.q-stepper__tab .q-stepper__title) {
  font-size: 9px;
  line-height: 1.1;
  white-space: normal;
}

.auth-title {
  margin: 0 0 0 12px;
  font-size: 34px;
  font-weight: 700;
}

.auth-subtitle {
  color: #8b8b8b;
  margin: 6px 0 16px 12px;
}

.phone-prefix {
  font-size: 16px;
}

.password-checklist {
  margin: 0;
  padding: 0 0 0 4px;
  list-style: none;
}

.password-checklist li {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 4px 0;
  color: #6b7280;
  font-size: 12px;
}

.password-checklist li.ok {
  color: #15803d;
}

.email-domain-select :deep(.q-field__control) {
  min-height: unset;
  height: auto;
  background: transparent;
  padding: 0;
}

.email-domain-select :deep(.q-field__native) {
  padding: 0;
  min-height: unset;
}

.email-domain-select :deep(.q-field__append) {
  padding-left: 2px;
}

.email-domain-select :deep(.q-field__before),
.email-domain-select :deep(.q-field__prepend) {
  display: none;
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
