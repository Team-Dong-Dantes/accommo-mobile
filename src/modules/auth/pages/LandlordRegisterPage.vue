<template>
  <q-page class="register-page">
    <div class="register-container column">
      <h3 class="auth-title col-auto">
        {{ isGoogleMode ? 'Complete Profile' : 'Landlord Application' }}
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

            <AuthInput v-model="form.fullName" label="Full Name"
              :rules="[(val: string) => !!val || 'Full Name is required']">
              <template #prepend><IconifyIcon icon="material-icons:person_outline" /></template>
            </AuthInput>

            <AuthSelect v-model="form.sex" :options="sexOptions" label="Sex" class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your sex']">
              <template #prepend><IconifyIcon icon="material-icons:wc" /></template>
            </AuthSelect>

            <AuthInput :model-value="form.phoneDigits"
              @update:model-value="form.phoneDigits = phNationalDigits($event)" label="Phone Number" class="q-mt-md"
              maxlength="12" inputmode="numeric"
              :rules="[(val: string) => !!val || 'Phone number is required', (val: string) => phNationalDigits(val).length === 10 || 'Enter your 10-digit mobile number (leading 0 is optional, e.g. 9123456789)']">
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

          <q-step :name="3" title="Business" icon="storefront" :done="step > 3">
            <div class="q-mb-md text-subtitle2 text-grey-8">Tell us about your property</div>

            <AuthInput v-model="form.businessName" label="Boarding House / Business Name"
              :rules="[(val: string) => !!val || 'Business name is required']">
              <template #prepend><IconifyIcon icon="material-icons:apartment" /></template>
            </AuthInput>
          </q-step>

          <q-step :name="4" title="Documents" icon="verified_user">
            <div class="q-mt-xs q-mb-md text-subtitle2 text-grey-8 font-weight-medium">
              Upload documents for accreditation
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

          <AuthButton v-if="step === 4" type="submit" :loading="loading">
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
import { reactive, ref, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useQuasar, type QForm } from 'quasar';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/shared/utils/supabase';
import { normalizePhPhone, phNationalDigits } from '@/shared/utils/format';

import AuthInput from '@/modules/auth/components/AuthInput.vue';
import AuthSelect from '@/modules/auth/components/AuthSelect.vue';
import AuthFileDropZone from '@/modules/auth/components/AuthFileDropZone.vue';
import AuthButton from '@/modules/auth/components/AuthButton.vue';
import AuthGoogleBtn from '@/modules/auth/components/AuthGoogleBtn.vue';
import AuthDivider from '@/modules/auth/components/AuthDivider.vue';
import ConnectedGoogleBox from '@/modules/auth/components/ConnectedGoogleBox.vue';

const router = useRouter();
const route = useRoute();
const $q = useQuasar();
const authStore = useAuthStore();

const step = ref(1);
const registerFormRef = ref<QForm | null>(null);
const isGoogleMode = ref(false);
const googleUserId = ref('');

const sexOptions = ['Male', 'Female'];
const emailDomains = ['gmail.com', 'isu.edu.ph'];

const form = reactive({
  fullName: '',
  sex: '',
  phoneDigits: '',
  phone: '',
  emailUser: '',
  emailDomain: '',
  email: '',
  password: '',
  confirmPassword: '',
  businessName: '',
  governmentIdFile: null as File | null,
  businessPermitFile: null as File | null,
});

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
    void router.replace('/register/landlord');
  }

  const { session, profile } = await authStore.getSessionProfile();

  if (session && !profile) {
    isGoogleMode.value = true;
    googleUserId.value = session.user.id;
    form.email = session.user.email || '';
    form.fullName = session.user.user_metadata?.full_name || '';
  }
});

async function nextStep() {
  if (!registerFormRef.value) return;
  const success = await registerFormRef.value.validate();
  if (success) {
    if (step.value === 1 && isGoogleMode.value) step.value = 3;
    else if (step.value < 4) step.value++;
  }
}

function prevStep() {
  if (step.value === 3 && isGoogleMode.value) step.value = 1;
  else if (step.value > 1) step.value--;
}

async function handleGoogleAuth() {
  try {
    await authStore.loginWithGoogle('/register/landlord');
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
  form.fullName = '';

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
      await authStore.completeGoogleLandlordProfile(googleUserId.value, form);
      $q.notify({
        message: 'Application submitted successfully!',
        position: 'top',
        color: 'grey-9',
        textColor: 'white',
        icon: 'check_circle',
        iconColor: 'teal-4',
        classes: 'custom-notify',
      });
      void router.push('/landlord/dashboard');
    } else {
      await authStore.registerLandlord(form);
      $q.notify({
        message: 'Application submitted! OSAS will review your application. Check your email for updates.',
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
  min-height: 360px;
  overflow: hidden;
}

.auth-stepper :deep(.q-stepper__step-inner) {
  padding: 0;
  min-width: 0;
}

.auth-stepper :deep(.q-stepper__header) {
  padding: 0;
}

.auth-stepper :deep(.q-stepper__tab) {
  padding: 20px 4px;
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
