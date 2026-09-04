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
        @submit.prevent="() => step === 5 && handleRegister(false)"
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

            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <AuthInput
                  v-model="form.firstName"
                  label="First Name"
                  :rules="[(val: string) => !!val || 'First name is required']"
                >
                  <template #prepend><IconifyIcon icon="material-icons:person_outline" /></template>
                </AuthInput>
              </div>

              <div class="col-6">
                <AuthInput
                  v-model="form.lastName"
                  label="Last Name"
                  :rules="[(val: string) => !!val || 'Last name is required']"
                >
                  <template #prepend><IconifyIcon icon="material-icons:badge" /></template>
                </AuthInput>
              </div>
            </div>

            <AuthSelect
              v-model="form.sex"
              :options="sexOptions"
              label="Sex"
              class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your sex']"
            >
              <template #prepend><IconifyIcon icon="material-icons:wc" /></template>
            </AuthSelect>

            <AuthInput
              :model-value="form.phoneDigits"
              @update:model-value="form.phoneDigits = phNationalDigits($event).slice(0, 10)"
              label="Phone Number"
              class="q-mt-md"
              maxlength="10"
              inputmode="numeric"
              placeholder="9123456789"
              :rules="[
                (val: string) => !!val || 'Phone number is required',
                (val: string) => /^\d{10}$/.test(val) || 'Enter exactly 10 digits',
                (val: string) => /^9\d{9}$/.test(val) || 'Must start with 9 (e.g. 9123456789)',
              ]"
            >
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

            <AuthInput
              v-model="form.password"
              :type="showPassword ? 'text' : 'password'"
              label="Password"
              class="q-mt-md"
              :rules="[
                (val: string) => !!val || 'Password is required',
                (val: string) => val.length >= 8 || 'At least 8 characters',
                (val: string) => /[a-z]/.test(val) || 'Must include a lowercase letter',
                (val: string) => /[A-Z]/.test(val) || 'Must include an uppercase letter',
                (val: string) => /\d/.test(val) || 'Must include a number',
                (val: string) => /[!@#$%^&*]/.test(val) || 'Must include a special character (!@#$%^&*)',
              ]"
            >
              <template #prepend><IconifyIcon icon="material-icons:lock_outline" /></template>
              <template #append>
                <IconifyIcon :icon="'material-icons:' + (showPassword ? 'visibility' : 'visibility_off')"
                  class="cursor-pointer"
                  @click="showPassword = !showPassword"
                />
              </template>
            </AuthInput>

            <ul class="password-checklist q-mt-sm">
              <li v-for="item in passwordChecks" :key="item.label" :class="{ ok: item.ok }">
                <IconifyIcon :icon="item.ok ? 'material-icons:check_circle' : 'material-icons:radio_button_unchecked'" />
                <span>{{ item.label }}</span>
              </li>
            </ul>

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
              <template #prepend><IconifyIcon icon="material-icons:lock_reset" /></template>
              <template #append>
                <IconifyIcon :icon="'material-icons:' + (showConfirmPassword ? 'visibility' : 'visibility_off')"
                  class="cursor-pointer"
                  @click="showConfirmPassword = !showConfirmPassword"
                />
              </template>
            </AuthInput>
          </q-step>

          <q-step v-if="!isGoogleMode" :name="3" title="Confirm e-mail" icon="mail" :done="step > 3">
            <template v-if="!emailCreated">
              <div class="q-pa-sm">
                <p class="otp-note">We’ll create your account, then a code goes to your inbox to confirm your e-mail before you continue.</p>
                <AuthButton @click="createAccountNow" :loading="creatingAccount">
                  Create account &amp; send code
                  <IconifyIcon icon="material-icons:arrow_forward" class="q-ml-sm" />
                </AuthButton>
              </div>
            </template>
            <template v-else>
              <EmailVerifyInline :email="form.email"
                 v-if="!emailVerified"
                 @verified="onEmailVerified" />
              <div v-else class="otp-verified">
                <IconifyIcon icon="material-icons:check_circle" color="teal-6" size="28" class="q-mr-sm" />
                <div><strong>E-mail confirmed</strong><span class="text-grey-7"> You’re verified. Continue to your academic details.</span></div>
              </div>
            </template>
          </q-step>

          <q-step :name="4" title="Academic" icon="school" :done="step > 4">
            <AuthSelect
              v-model="form.college"
              :options="collegeOptions"
              label="College"
              :rules="[(val: string) => !!val || 'Please select your college']"
              @update:model-value="onCollegeChange"
            >
              <template #prepend><IconifyIcon icon="material-icons:account_balance" /></template>
            </AuthSelect>

            <AuthSelect
              v-model="form.program"
              :options="filteredPrograms"
              label="Program"
              class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your program']"
              :disable="!form.college"
            >
              <template #prepend><IconifyIcon icon="material-icons:school" /></template>
            </AuthSelect>

            <AuthSelect
              v-model="form.yearLevel"
              :options="yearOptions"
              label="Year Level"
              class="q-mt-md"
              :rules="[(val: string) => !!val || 'Please select your year level']"
            >
              <template #prepend><IconifyIcon icon="material-icons:timeline" /></template>
            </AuthSelect>
          </q-step>

          <q-step :name="5" title="Verification" icon="verified_user" :done="step > 5">
            <AuthInput
              v-model="form.studentId"
              label="ISU Student ID Number"
              :rules="[(val: string) => !!val || 'Student ID is required']"
            >
              <template #prepend><IconifyIcon icon="material-icons:badge" /></template>
            </AuthInput>

            <div class="q-mt-md text-subtitle2 text-grey-7 q-ml-sm">Verify your enrollment</div>

            <AuthFileDropZone
              v-model="form.schoolIdFile"
              label="Tap to upload School ID"
              accept=".jpg, image/*, .pdf"
              class="q-mt-sm"
            >
              <template #prepend><IconifyIcon icon="material-icons:portrait" color="teal-9" /></template>
              <template #append><IconifyIcon icon="material-icons:cloud_upload" color="grey-6" /></template>
            </AuthFileDropZone>

            <AuthFileDropZone
              v-model="form.assessmentFile"
              label="Tap to upload Assessment of Fees"
              accept=".jpg, image/*, .pdf"
              class="q-mt-md"
            >
              <template #prepend><IconifyIcon icon="material-icons:receipt_long" color="teal-9" /></template>
              <template #append><IconifyIcon icon="material-icons:cloud_upload" color="grey-6" /></template>
            </AuthFileDropZone>
          </q-step>

        </q-stepper>

        <div class="q-px-sm q-mt-md">
          <AuthButton v-if="step < 5" @click="nextStep">
            NEXT STEP
            <IconifyIcon icon="material-icons:arrow_forward" class="q-ml-sm" />
          </AuthButton>

          <AuthButton v-if="step === 5" type="submit" :loading="loading" :disable="creatingAccount">
            {{ isGoogleMode ? 'FINISH PROFILE' : 'REGISTER' }}
            <IconifyIcon icon="material-icons:person_add" class="q-ml-sm" />
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
            <template v-else-if="step >= 2 && step <= 4">
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
            <template v-else-if="step === 5">
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
import { reactive, ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useQuasar, type QForm } from 'quasar';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/shared/utils/supabase';

import AuthInput from '@/components/auth/AuthInput.vue';
import AuthSelect from '@/components/auth/AuthSelect.vue';
import AuthFileDropZone from '@/components/auth/AuthFileDropZone.vue';
import AuthButton from '@/components/auth/AuthButton.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';
import EmailVerifyInline from '@/components/auth/EmailVerifyInline.vue';
import ConnectedGoogleBox from '@/components/auth/ConnectedGoogleBox.vue';
import { normalizePhPhone, phNationalDigits } from '@/shared/utils/format';

const router = useRouter();
const route = useRoute();
const $q = useQuasar();
const authStore = useAuthStore();

const step = ref(1);
const registerFormRef = ref<QForm | null>(null);
const isGoogleMode = ref(false);
const googleUserId = ref('');
const needEmailOtp = ref(false);
const emailCreated = ref(false);
const emailVerified = ref(false);
const creatingAccount = ref(false);
let createdUserId: string | null = null;

const sexOptions = ['Male', 'Female'];
const yearOptions = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', '6th Year'];
const emailDomains = ['gmail.com', 'isu.edu.ph'];

const collegePrograms: Record<string, string[]> = {
  'College of Agriculture (CA)': [
    'BS in Agriculture major in Agronomy',
    'BS in Agriculture major in Horticulture',
    'BS in Agriculture major in Animal Science',
    'BS in Agribusiness',
    'BS in Animal Husbandry',
    'Diploma in Agricultural Technology (DAT)',
  ],
  'College of Arts and Sciences (CAS)': [
    'BS in Biology',
    'BS in Mathematics',
    'BS in Psychology',
    'BA in Communication',
    'BA in English Language Studies',
    'BS in Environmental Science',
  ],
  'College of Business, Accountancy and Public Administration (CBAPA)': [
    'BS in Accountancy',
    'BS in Management Accounting',
    'BS in Business Administration',
    'BS in Entrepreneurship',
    'BA in Public Administration',
    'BS in Hospitality Management',
    'BS in Tourism Management',
  ],
  'College of Computing Studies, Information and Communication Technology (CCSICT)': [
    'BS in Computer Science',
    'BS in Information Technology',
    'BS in Information Systems',
    'BS in Library and Information Science',
    'BS in Data Science and Analytics',
  ],
  'College of Criminal Justice Education (CCJE)': [
    'BS in Criminology',
    'BS in Law Enforcement Administration',
  ],
  'College of Education (COEd)': [
    'Bachelor of Elementary Education (BEEd)',
    'Bachelor of Secondary Education (BSEd)',
    'Bachelor of Physical Education (BPEd)',
    'Bachelor of Technology and Livelihood Education (BTLEd)',
  ],
  'College of Engineering (COE)': [
    'BS in Agricultural and Biosystems Engineering',
    'BS in Civil Engineering',
  ],
  'College of Nursing (CON)': [
    'BS in Nursing (BSN)',
  ],
  'Institute of Fisheries (IOF)': [
    'BS in Fisheries and Aquatic Sciences',
  ],
  'School of Veterinary Medicine (SVM)': [
    'Doctor of Veterinary Medicine (DVM)',
  ],
};

const collegeOptions = Object.keys(collegePrograms);

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
  college: '',
  program: '',
  yearLevel: '',
  studentId: '',
  schoolIdFile: null as File | null,
  assessmentFile: null as File | null,
});

const filteredPrograms = computed(() => {
  if (!form.college) return [];
  return collegePrograms[form.college] || [];
});

function onCollegeChange(val: string | number | null | undefined) {
  form.program = '';
}

const showPassword = ref(false);
const showConfirmPassword = ref(false);
const loading = ref(false);

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

async function createAccountNow(): Promise<boolean> {
  if (emailCreated.value || creatingAccount.value) return emailCreated.value;
  creatingAccount.value = true;
  try {
    syncFullName();
    if (form.phoneDigits) form.phone = normalizePhPhone(form.phoneDigits);
    if (!isGoogleMode.value) form.email = `${form.emailUser}@${form.emailDomain}`;
    createdUserId = await authStore.createStudentAccount(form as any);
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
    const split = splitFullName(String(session.user.user_metadata?.full_name || ''));
    form.firstName = split.firstName;
    form.lastName = split.lastName;
    syncFullName();
  }
});

async function nextStep() {
  if (!registerFormRef.value) return;
  const success = await registerFormRef.value.validate();
  if (!success) return;

  if (isGoogleMode.value) {
    // Google path skips Account (2)/Confirm (3) → straight to Academic(4)
    if (step.value === 1) { step.value = 4; return; }
    if (step.value < 5) step.value++;
    return;
  }

  if (step.value === 2) {
    // Leaving Account: create the account so Confirm-e-mail can send a code.
    const ok = await createAccountNow();
    if (ok) step.value = 3;
    return;
  }

  if (step.value === 3 && !emailVerified.value) {
    $q.notify({
      message: 'Confirm your e-mail before continuing.',
      position: 'top',
      color: 'grey-9',
      textColor: 'white',
      icon: 'info',
      iconColor: 'amber-4',
      classes: 'custom-notify',
    });
    return;
  }
  if (step.value < 5) step.value++;
}

function prevStep() {
  if (step.value === 4 && isGoogleMode.value) step.value = 1;
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
  form.emailUser = '';
  form.emailDomain = 'gmail.com';
  form.firstName = '';
  form.lastName = '';
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
  syncFullName();
  form.phone = normalizePhPhone(form.phoneDigits);
  if (!isGoogleMode.value) {
    form.email = `${form.emailUser}@${form.emailDomain}`;
  }

  if (!skipVerification && registerFormRef.value) {
    const success = await registerFormRef.value.validate();
    if (!success) return;
  }

  loading.value = true;

  if (form.studentId) {
    try {
      const { data } = await (supabase.rpc as any)('check_student_id_exists', {
        p_student_id: form.studentId,
      });

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
    } catch {
      // Check will be re-validated on server side
    }
  }

   try {
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
     } else {
        if (createdUserId) {
        await authStore.finalizeStudentAccount(createdUserId, form as any);
      } else {
        await authStore.register(form); // safety fallback (no early account)
      }
        $q.notify({
          message: 'Account created successfully!',
          position: 'top',
          color: 'grey-9',
          textColor: 'white',
         icon: 'check_circle',
         iconColor: 'teal-4',
        classes: 'custom-notify',
       });
     }
      finishRegistration();
    } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'An unexpected error occurred';
    $q.notify({
      message,
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

function finishRegistration() {
  void router.push('/student/home');
}

// Called by the Confirm-e-mail step when the code verifies.
function onEmailVerified() {
  emailVerified.value = true;
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

/* More readable step-title line for the narrower 5-step header */
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
