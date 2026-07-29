<template>
  <q-page class="register-page">
    <div class="register-container column">
      <h3 class="auth-title col-auto">
        {{ isGoogleMode ? 'Complete Profile' : 'Create Account' }}
      </h3>
      <p class="auth-subtitle col-auto">Join the Accommo student community</p>

      <q-form
        ref="registerFormRef"
        class="col column"
        @submit.prevent="() => handleRegister(false)"
      >
        <q-stepper
          v-model="step"
          ref="stepper"
          color="teal-9"
          active-color="teal-9"
          done-color="teal-9"
          animated
          flat
          alternative-labels
          class="bg-transparent auth-stepper col-auto"
        >
          <q-step :name="1" title="Personal" icon="person" :done="step > 1">
            <template v-if="!isGoogleMode">
              <AuthGoogleBtn @click="handleGoogleAuth">Sign up with Google</AuthGoogleBtn>
              <AuthDivider />
            </template>
            <template v-else>
              <ConnectedGoogleBox :email="form.email" @cancel="cancelGoogle" />
            </template>

            <AuthInput
              v-model="form.fullName"
              label="Full Name"
              :rules="[(val: string) => !!val || 'Full Name is required']"
            >
              <template #prepend><q-icon name="person_outline" /></template>
            </AuthInput>

            <AuthSelect
              v-model="form.sex"
              :options="sexOptions"
              label="Sex"
              class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your sex']"
            >
              <template #prepend><q-icon name="wc" /></template>
            </AuthSelect>

            <AuthInput
              v-model="form.phone"
              label="Phone Number (e.g. 09123456789)"
              class="q-mt-md"
              :rules="[
                (val: string) => !!val || 'Phone number is required',
                (val: string) => /^[0-9]{11}$/.test(val) || 'Must be a valid 11-digit phone number',
              ]"
            >
              <template #prepend><q-icon name="phone" /></template>
            </AuthInput>
          </q-step>

          <q-step v-if="!isGoogleMode" :name="2" title="Account" icon="settings" :done="step > 2">
            <AuthInput
              v-model="form.email"
              label="Email Address"
              :rules="[
                (val: string) => !!val || 'Email is required',
                (val: string) => /.+@.+\..+/.test(val) || 'Must be a valid email address',
              ]"
            >
              <template #prepend><q-icon name="mail_outline" /></template>
            </AuthInput>

            <AuthInput
              v-model="form.password"
              :type="showPassword ? 'text' : 'password'"
              label="Password"
              class="q-mt-md"
              :rules="[
                (val: string) => !!val || 'Password is required',
                (val: string) => val.length >= 6 || 'Password must be at least 6 characters',
              ]"
            >
              <template #prepend><q-icon name="lock_outline" /></template>
              <template #append>
                <q-icon
                  :name="showPassword ? 'visibility' : 'visibility_off'"
                  class="cursor-pointer"
                  @click="showPassword = !showPassword"
                />
              </template>
            </AuthInput>

            <AuthInput
              v-model="form.confirmPassword"
              :type="showConfirmPassword ? 'text' : 'password'"
              label="Confirm Password"
              class="q-mt-md"
              :rules="[
                (val: string) => !!val || 'Please confirm your password',
                (val: string) => val === form.password || 'Passwords do not match',
              ]"
            >
              <template #prepend><q-icon name="lock_reset" /></template>
              <template #append>
                <q-icon
                  :name="showConfirmPassword ? 'visibility' : 'visibility_off'"
                  class="cursor-pointer"
                  @click="showConfirmPassword = !showConfirmPassword"
                />
              </template>
            </AuthInput>
          </q-step>

          <q-step :name="3" title="Academic" icon="school" :done="step > 3">
            <AuthInput
              v-model="form.college"
              label="College (e.g. CCSICT, CEAT)"
              :rules="[(val: string) => !!val || 'College is required']"
            >
              <template #prepend><q-icon name="account_balance" /></template>
            </AuthInput>

            <AuthInput
              v-model="form.program"
              label="Program (e.g. BSIT)"
              class="q-mt-md"
              :rules="[(val: string) => !!val || 'Program is required']"
            >
              <template #prepend><q-icon name="school" /></template>
            </AuthInput>

            <AuthSelect
              v-model="form.yearLevel"
              :options="yearOptions"
              label="Year Level"
              class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your year level']"
            >
              <template #prepend><q-icon name="timeline" /></template>
            </AuthSelect>
          </q-step>

          <q-step :name="4" title="Verification" icon="verified_user">
            <AuthInput
              v-model="form.studentId"
              label="ISU Student ID Number"
              :rules="[(val: string) => !!val || 'Student ID is required']"
            >
              <template #prepend><q-icon name="badge" /></template>
            </AuthInput>

            <div class="q-mt-md text-subtitle2 text-grey-7 q-ml-sm">Verify your enrollment</div>

            <AuthFileDropZone
              v-model="form.schoolIdFile"
              label="Tap to upload School ID"
              accept=".jpg, image/*, .pdf"
              class="q-mt-sm"
            >
              <template #prepend><q-icon name="portrait" color="teal-9" size="md" /></template>
              <template #append><q-icon name="cloud_upload" color="grey-6" /></template>
            </AuthFileDropZone>

            <AuthFileDropZone
              v-model="form.assessmentFile"
              label="Tap to upload Assessment of Fees"
              accept=".jpg, image/*, .pdf"
              class="q-mt-md"
            >
              <template #prepend><q-icon name="receipt_long" color="teal-9" size="md" /></template>
              <template #append><q-icon name="cloud_upload" color="grey-6" /></template>
            </AuthFileDropZone>
          </q-step>
        </q-stepper>

        <div class="q-px-sm q-mt-md">
          <AuthButton v-if="step < 4" @click="nextStep">
            NEXT STEP
            <q-icon name="arrow_forward" class="q-ml-sm" />
          </AuthButton>

          <AuthButton v-if="step === 4" type="submit" :loading="loading">
            {{ isGoogleMode ? 'FINISH PROFILE' : 'REGISTER' }}
            <q-icon name="person_add" class="q-ml-sm" />
          </AuthButton>

          <div class="row justify-center items-center q-mt-md full-width" style="height: 32px">
            <template v-if="step === 1 && !isGoogleMode">
              <span class="text-grey-7">Already have an account?</span>
              <q-btn
                to="/login"
                flat
                dense
                no-caps
                label="Sign In"
                color="teal-9"
                class="text-weight-bold q-ml-sm"
              />
            </template>
            <template v-else-if="step === 2 || step === 3">
              <q-btn
                flat
                dense
                no-caps
                label="Go Back"
                color="grey-6"
                class="text-weight-bold"
                @click="prevStep"
              />
            </template>
            <template v-else-if="step === 4">
              <div class="row justify-between full-width q-px-sm">
                <q-btn
                  flat
                  dense
                  no-caps
                  label="Go Back"
                  color="grey-6"
                  class="text-weight-bold"
                  @click="prevStep"
                />
                <q-btn
                  flat
                  dense
                  no-caps
                  label="Skip for now"
                  color="teal-9"
                  class="text-weight-bold"
                  @click="handleRegister(true)"
                />
              </div>
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
import type { SupabaseClient } from '@supabase/supabase-js';

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
const yearOptions = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year'];

const form = reactive({
  fullName: '',
  sex: '',
  phone: '',
  email: '',
  password: '',
  confirmPassword: '',
  college: '',
  program: '',
  yearLevel: '',
  studentId: '',
  schoolIdFile: null,
  assessmentFile: null,
});

const showPassword = ref(false);
const showConfirmPassword = ref(false);
const loading = ref(false);

onMounted(async () => {
  if (route.query.newUser) {
    $q.notify({
      message: 'Account not found. Please complete registration.',
      position: 'top',
      color: 'grey-9',
      textColor: 'white',
      icon: 'info',
      iconColor: 'amber-4',
      classes: 'custom-notify',
    });
    void router.replace('/register');
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
    await authStore.loginWithGoogle('/register');
  } catch (error: unknown) {
    let errorMsg = 'An error occurred';
    if (error instanceof Error) {
      errorMsg = error.message;
    }
    $q.notify({
      message: errorMsg,
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

async function handleRegister(skipVerification: boolean = false) {
  if (!skipVerification && registerFormRef.value) {
    const success = await registerFormRef.value.validate();
    if (!success) {
      $q.notify({
        message: 'Please provide your Student ID to complete registration.',
        position: 'top',
        color: 'grey-9',
        textColor: 'white',
        icon: 'warning',
        iconColor: 'amber-4',
        classes: 'custom-notify',
      });
      return;
    }

    loading.value = true;
    try {
      // Validate unique Student ID before attempting to register by casting to the exact client type
      const client = supabase as SupabaseClient;
      const { data } = await client
        .from('student_profiles')
        .select('student_id')
        .eq('student_id', form.studentId)
        .maybeSingle();

      if (data) {
        $q.notify({
          message: 'This Student ID is already registered. Please double check or sign in.',
          position: 'top',
          color: 'grey-9',
          textColor: 'white',
          icon: 'error_outline',
          iconColor: 'red-4',
          classes: 'custom-notify',
        });
        loading.value = false;
        return;
      }
    } catch (err) {
      console.error('ID Validation check failed:', err);
    }
    loading.value = false;
  }

  try {
    loading.value = true;
    if (isGoogleMode.value) {
      await authStore.completeGoogleProfile(googleUserId.value, form);
      $q.notify({
        message: 'Profile completed successfully!',
        position: 'top',
        color: 'grey-9',
        textColor: 'white',
        icon: 'check_circle',
        iconColor: 'teal-4',
        classes: 'custom-notify',
      });
      void router.push('/student/dashboard');
    } else {
      await authStore.register(form);
      $q.notify({
        message: 'Account created! Please sign in.',
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
    let errorMsg = 'An unexpected error occurred';

    if (error instanceof Error) {
      errorMsg = error.message;
    } else if (error && typeof error === 'object' && 'message' in error) {
      errorMsg = String(error.message);
    } else if (typeof error === 'string') {
      errorMsg = error;
    }

    // Catch and translate unhandled database constraints
    if (errorMsg.includes('student_profiles_student_id_key') || errorMsg.includes('23505')) {
      errorMsg = 'This Student ID is already registered.';
    } else if (errorMsg.includes('PGRST116') || errorMsg.includes('0 rows')) {
      errorMsg = 'Registration failed due to a database conflict. Please try again.';
    }

    $q.notify({
      message: errorMsg,
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
