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
              <template #prepend><q-icon name="person_outline" /></template>
            </AuthInput>

            <AuthSelect v-model="form.sex" :options="sexOptions" label="Sex" class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your sex']">
              <template #prepend><q-icon name="wc" /></template>
            </AuthSelect>

            <AuthInput v-model="form.phone" label="Phone Number (e.g. 09123456789)" class="q-mt-md"
              :rules="[(val: string) => !!val || 'Phone number is required', (val: string) => /^[0-9]{11}$/.test(val) || 'Must be a valid 11-digit phone number']">
              <template #prepend><q-icon name="phone" /></template>
            </AuthInput>
          </q-step>

          <q-step v-if="!isGoogleMode" :name="2" title="Account" icon="settings" :done="step > 2">
            <AuthInput v-model="form.email" label="Email Address"
              :rules="[(val: string) => !!val || 'Email is required', (val: string) => /.+@.+\..+/.test(val) || 'Must be a valid email address']">
              <template #prepend><q-icon name="mail_outline" /></template>
            </AuthInput>

            <AuthInput v-model="form.password" :type="showPassword ? 'text' : 'password'" label="Password"
              class="q-mt-md"
              :rules="[(val: string) => !!val || 'Password is required', (val: string) => val.length >= 6 || 'Password must be at least 6 characters']">
              <template #prepend><q-icon name="lock_outline" /></template>
              <template #append>
                <q-icon :name="showPassword ? 'visibility' : 'visibility_off'" class="cursor-pointer"
                  @click="showPassword = !showPassword" />
              </template>
            </AuthInput>

            <AuthInput v-model="form.confirmPassword" :type="showConfirmPassword ? 'text' : 'password'"
              label="Confirm Password" class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please confirm your password', (val: string) => val === form.password || 'Passwords do not match']">
              <template #prepend><q-icon name="lock_reset" /></template>
              <template #append>
                <q-icon :name="showConfirmPassword ? 'visibility' : 'visibility_off'" class="cursor-pointer"
                  @click="showConfirmPassword = !showConfirmPassword" />
              </template>
            </AuthInput>
          </q-step>

          <q-step :name="3" title="Business" icon="storefront" :done="step > 3">
            <div class="q-mb-md text-subtitle2 text-grey-8">Tell us about your property</div>

            <AuthInput v-model="form.businessName" label="Boarding House / Business Name"
              :rules="[(val: string) => !!val || 'Business name is required']">
              <template #prepend><q-icon name="apartment" /></template>
            </AuthInput>
          </q-step>

          <q-step :name="4" title="Documents" icon="verified_user">
            <div class="q-mt-xs q-mb-md text-subtitle2 text-grey-8 font-weight-medium">
              Upload documents for accreditation
            </div>

            <AuthFileDropZone v-model="form.governmentIdFile" label="Tap to upload Valid Government ID"
              accept=".jpg, image/*, .pdf" :rules="[(val: File | null) => !!val || 'Government ID is required']"
              hide-bottom-space>
              <template #prepend><q-icon name="badge" color="teal-9" size="md" /></template>
              <template #append><q-icon name="cloud_upload" color="grey-5" /></template>
            </AuthFileDropZone>

            <AuthFileDropZone v-model="form.businessPermitFile" label="Tap to upload Business / Mayor's Permit"
              accept=".jpg, image/*, .pdf" class="q-mt-md"
              :rules="[(val: File | null) => !!val || 'Business Permit is required']" hide-bottom-space>
              <template #prepend><q-icon name="description" color="teal-9" size="md" /></template>
              <template #append><q-icon name="cloud_upload" color="grey-5" /></template>
            </AuthFileDropZone>
          </q-step>
        </q-stepper>

        <div class="q-px-sm q-mt-md">
          <AuthButton v-if="step < 4" @click="nextStep">
            NEXT STEP
            <q-icon name="arrow_forward" class="q-ml-sm" />
          </AuthButton>

          <AuthButton v-if="step === 4" type="submit" :loading="loading">
            {{ isGoogleMode ? 'SUBMIT APPLICATION' : 'APPLY NOW' }}
            <q-icon name="check_circle" class="q-ml-sm" />
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
import { supabase } from '@/utils/supabase';

import AuthInput from '@/components/auth/AuthInput.vue';
import AuthSelect from '@/components/auth/AuthSelect.vue';
import AuthFileDropZone from '@/components/auth/AuthFileDropZone.vue';
import AuthButton from '@/components/auth/AuthButton.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';
import ConnectedGoogleBox from '@/components/auth/ConnectedGoogleBox.vue';

const router = useRouter();
const route = useRoute();
const $q = useQuasar();
const authStore = useAuthStore();

const step = ref(1);
const registerFormRef = ref<QForm | null>(null);
const isGoogleMode = ref(false);
const googleUserId = ref('');

const sexOptions = ['Male', 'Female', 'Prefer not to say'];

const form = reactive({
  fullName: '',
  sex: '',
  phone: '',
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
        message: 'Application received! Please sign in.',
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
}

.auth-stepper :deep(.q-stepper__step-inner) {
  padding: 0;
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
