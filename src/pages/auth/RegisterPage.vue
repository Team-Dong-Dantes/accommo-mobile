<template>
  <!-- One flow, both roles. `/register` and `/register/manager` resolve to this
       same component; the path picks the role. Student and manager share the
       first three steps exactly (Personal, Account, Confirm e-mail) and differ
       only in the tail, which is why these were one screen written twice. -->
  <q-page class="register-page">
    <!-- A frame, not a long page: the sheet is a fixed-height column whose
         middle section is the only thing that scrolls. The primary action then
         sits in the same place on every step instead of travelling with the
         length of the step's field list. -->
    <div class="auth-sheet column">
      <div v-if="isResubmit" class="reject-banner col-auto">
        <IconifyIcon icon="lucide:triangle-alert" width="16" />
        <div>
          <p class="reject-title">What OSAS asked for</p>
          <p class="reject-text">
            {{ decisionReason || 'OSAS needs clearer copies of your documents — re-upload them below.' }}
          </p>
        </div>
      </div>

      <!-- Progress: one segment per step, rather than q-stepper's header (four
           or five tabs at 9px across a phone) or a continuous fill that needs a
           written "Step 2 of 4" beside it to say how far there is to go. The
           segments carry the count themselves, so the header is one row, and
           Back lives in it — one permanent home, above the content it leaves,
           rather than three different spots under the primary button. -->
      <div v-if="steps.length > 1" class="progress col-auto">
        <div class="progress-row">
          <!-- Shown on the first screen too, where it leaves the flow rather
               than stepping back through it: picking the wrong role was
               otherwise a dead end, with the only way out being to kill the app. -->
          <q-btn
            flat
            dense
            round
            class="progress-back"
            :aria-label="stepIndex > 0 ? 'Go back a step' : 'Choose a different role'"
            @click="prevStep"
          >
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </q-btn>
          <span class="progress-step">{{ stepTitle }}</span>
        </div>
        <div
          class="progress-track"
          role="progressbar"
          :aria-valuenow="stepIndex + 1"
          :aria-valuemin="1"
          :aria-valuemax="steps.length"
          :aria-label="`Step ${stepIndex + 1} of ${steps.length}: ${stepTitle}`"
        >
          <span
            v-for="(key, i) in steps"
            :key="key"
            class="progress-seg"
            :class="{ done: i < stepIndex, current: i === stepIndex }"
          />
        </div>
      </div>

      <q-form
        ref="registerFormRef"
        class="col column no-wrap"
        @submit.prevent="() => isLastStep && handleRegister(false)"
      >
        <div ref="stepsEl" class="steps col">
          <!-- One question per screen, and the question is the screen's title.
               The 34px page heading is gone with it: repeating "Create Account"
               above "What's your name?" said nothing the second time. -->
          <header class="auth-question">
            <h1>{{ question.title }}</h1>
            <p v-if="question.note">{{ question.note }}</p>
          </header>

          <!-- Name. Google sits on this screen rather than a chooser of its own:
               connecting Google fills in exactly the name and e-mail this screen
               and the next one ask for, so it belongs beside the fields it
               saves you typing. The consent closes the screen, below the fields:
               an ordinary part of the form, required to leave the screen, and
               deliberately not a gate on the Google button above it. -->
          <template v-if="current === 'name'">
            <template v-if="!isGoogleMode">
              <!-- "Connect", because that is what it does. This button signs
                   nobody up: it links a Google account, fills in the two name
                   fields and the e-mail, and leaves every remaining screen —
                   phone, studies, student ID, proof — to be answered as normal.
                   The app already said so on the other side of it, where success
                   renders ConnectedGoogleBox reading "Google Connected" with an
                   unlink button. Login is a different action and keeps its own
                   wording, since signing in with Google really is signing in.

                   Pressable with nothing else on the screen filled in — no
                   fields, no consent. See handleGoogleAuth for what that costs
                   and what still holds. -->

              <AuthGoogleBtn @click="handleGoogleAuth">Connect with Google</AuthGoogleBtn>
              <AuthDivider />
            </template>
            <template v-else>
              <ConnectedGoogleBox :email="form.email" @cancel="cancelGoogle" />
            </template>

            <!-- Given name, middle initial, surname, extension — the order a
                 Philippine record is written in, so the surname lands after the
                 initial and the extension sits with the surname it belongs to. -->
            <AuthFieldGroup>
              <div class="row name-row">
                <div class="col-8">
                  <AuthInput
                    v-model="form.firstName"
                    label="First Name"
                    autofocus
                    :rules="nameRules('First name')"
                    @blur="tidyName('firstName')"
                  />
                </div>
                <div class="col-4 name-split">
                  <AuthInput
                    v-model="form.middleInitial"
                    label="M.I."
                    maxlength="1"
                    :rules="middleInitialRules"
                    @blur="tidyName('middleInitial')"
                  />
                </div>
              </div>

              <div class="row name-row">
                <div class="col-8">
                  <AuthInput
                    v-model="form.lastName"
                    label="Last Name"
                    :rules="nameRules('Last name')"
                    @blur="tidyName('lastName')"
                  />
                </div>
                <div class="col-4 name-split">
                  <AuthSelect
                    v-model="form.nameExtension"
                    :options="nameExtensions"
                    label="Ext."
                  />
                </div>
              </div>

              <AuthSelect
                v-model="form.sex"
                :options="sexOptions"
                label="Sex"
                :rules="[(val: string) => !!val || 'Please select your sex']"
              />

              <!-- Native date input: on Android this is the platform picker, and
                   OSAS checks what is typed here against the birth date printed
                   on the school or government ID that gets uploaded later. -->
              <AuthInput
                v-model="form.dateOfBirth"
                label="Date of Birth"
                type="date"
                :max="today"
                :rules="dateOfBirthRules"
              />
            </AuthFieldGroup>

            <AuthConsent v-model="agreedToTerms" />
          </template>

          <!-- Phone -->
          <template v-else-if="current === 'phone'">
            <AuthFieldGroup>
              <!-- The +63 prefix stays: unlike the icons this replaced, it is
                   part of the value rather than decoration. -->
              <AuthInput
                :model-value="form.phoneDigits"
                label="Phone Number"
                maxlength="10"
                inputmode="numeric"
                placeholder="9123456789"
                autofocus
                :rules="[
                  (val: string) => !!val || 'Phone number is required',
                  (val: string) => /^\d{10}$/.test(val) || 'Enter exactly 10 digits',
                  (val: string) => /^9\d{9}$/.test(val) || 'Must start with 9 (e.g. 9123456789)',
                  // The shared rule, so this screen and the profile editors
                  // cannot drift apart on what counts as a number again.
                  (val: string) => isPhMobile(val) || 'That is not a usable mobile number',
                ]"
                @update:model-value="form.phoneDigits = phNationalDigits($event).slice(0, 10)"
              >
                <template #prepend>
                  <span class="phone-prefix">+63</span>
                </template>
              </AuthInput>
            </AuthFieldGroup>
          </template>

          <!-- E-mail address -->
          <template v-else-if="current === 'email'">
            <AuthFieldGroup>
              <AuthInput
                v-model="form.emailUser"
                label="Email"
                autofocus
                :rules="[
                  (val: string) => !!val || 'Email is required',
                  (val: string) => /^[a-zA-Z0-9._%+-]+$/.test(val) || 'Invalid email username',
                ]"
              >
                <template #append>
                  <div class="row items-center no-wrap">
                    <span class="text-grey-7 text-weight-medium q-mr-xs" style="font-size: 16px">@</span>
                    <!-- A raw q-select rather than AuthSelect, because it sits
                         inside another field. It still borrows the same popup
                         styling so the two dropdowns on this flow match. -->
                    <q-select
                      v-model="form.emailDomain"
                      :options="emailDomains"
                      borderless
                      dense
                      hide-bottom-space
                      popup-content-class="auth-select-menu"
                      class="email-domain-select"
                      style="min-width: 105px"
                    />
                  </div>
                </template>
              </AuthInput>
            </AuthFieldGroup>
          </template>

          <!-- Password -->
          <template v-else-if="current === 'password'">
            <AuthFieldGroup>
            <AuthInput
              v-model="form.password"
              :type="showPassword ? 'text' : 'password'"
              label="Password"
              autofocus
              :rules="[
                (val: string) => !!val || 'Password is required',
                (val: string) => val.length >= 8 || 'At least 8 characters',
                (val: string) => /[a-z]/.test(val) || 'Must include a lowercase letter',
                (val: string) => /[A-Z]/.test(val) || 'Must include an uppercase letter',
                (val: string) => /\d/.test(val) || 'Must include a number',
                (val: string) => /[!@#$%^&*]/.test(val) || 'Must include a special character (!@#$%^&*)',
              ]"
            >
              <template #append>
                <IconifyIcon
                  :icon="showPassword ? 'lucide:eye-off' : 'lucide:eye'"
                  class="cursor-pointer"
                  @click="showPassword = !showPassword"
                />
              </template>
            </AuthInput>

            <!-- A row of chips inside the group, not a five-line bullet list
                 below it: the same five rules in a fifth of the height, and
                 they sit attached to the field they describe. -->
            <div class="pw-checks">
              <span v-for="item in passwordChecks" :key="item.label" class="pw-chip" :class="{ ok: item.ok }">
                <IconifyIcon :icon="item.ok ? 'lucide:check' : 'lucide:minus'" width="12" />
                {{ item.short }}
              </span>
            </div>

            <AuthInput
              v-model="form.confirmPassword"
              :type="showConfirmPassword ? 'text' : 'password'"
              label="Confirm Password"
              :rules="[
                (val: string) => !!val || 'Please confirm your password',
                (val: string) => val === form.password || 'Passwords do not match',
              ]"
            >
              <template #append>
                <IconifyIcon
                  :icon="showConfirmPassword ? 'lucide:eye-off' : 'lucide:eye'"
                  class="cursor-pointer"
                  @click="showConfirmPassword = !showConfirmPassword"
                />
              </template>
            </AuthInput>
            </AuthFieldGroup>
          </template>

          <!-- Confirm e-mail -->
          <!-- The account already exists by the time this screen renders —
               nextStep() creates it on leaving Password — and EmailVerifyInline
               sends the code itself on mount. So there is nothing to press
               before the code field: the screen opens ready to type into.
               The confirmed panel below is the back-navigation state; verifying
               advances the flow on its own, so nobody arrives at it forwards. -->
          <template v-else-if="current === 'verify'">
            <EmailVerifyInline v-if="!emailVerified" :email="form.email" @verified="onEmailVerified" />
            <div v-else class="otp-verified">
              <IconifyIcon icon="lucide:circle-check" width="26" class="q-mr-sm" />
              <div>
                <strong>E-mail confirmed</strong>
                <span class="text-grey-7">
                  {{ isManager ? ' Continue to upload your documents.' : ' You’re verified. Continue to your academic details.' }}
                </span>
              </div>
            </div>
          </template>

          <!-- Studies (student only) -->
          <template v-else-if="current === 'studies'">
            <AuthFieldGroup>
              <AuthSelect
                v-model="form.college"
                :options="collegeOptions"
                label="College"
                :rules="[(val: string) => !!val || 'Please select your college']"
                @update:model-value="onCollegeChange"
              />

              <AuthSelect
                v-model="form.program"
                :options="filteredPrograms"
                label="Program"
                :rules="[(val: string) => !!val || 'Please select your program']"
                :disable="!form.college"
              />

              <AuthSelect
                v-model="form.yearLevel"
                :options="yearOptions"
                label="Year Level"
                :rules="[(val: string) => !!val || 'Please select your year level']"
              />
            </AuthFieldGroup>
          </template>

          <!-- Student ID -->
          <!-- Two halves, because that is what a student ID is: an entry year
               and a student number. One free-text box let "Lol" and
               "TEST-LICHTZY-0" into the table. -->
          <template v-else-if="current === 'studentId'">
            <AuthFieldGroup>
              <div class="row name-row">
                <div class="col-4">
                  <AuthInput
                    v-model="form.studentIdYear"
                    label="Year"
                    maxlength="2"
                    inputmode="numeric"
                    placeholder="YY"
                    autofocus
                    :rules="[
                      (val: string) => !!val || 'Required',
                      (val: string) => /^\d{2}$/.test(val) || '2 digits',
                    ]"
                    @update:model-value="form.studentIdYear = digitsOnly($event, 2)"
                  />
                </div>
                <div class="col-8 name-split">
                  <AuthInput
                    v-model="form.studentIdNumber"
                    label="Student Number"
                    maxlength="6"
                    inputmode="numeric"
                    placeholder="NNNN"
                    :rules="[
                      (val: string) => !!val || 'Student number is required',
                      (val: string) => /^\d{4,6}$/.test(val) || 'Between 4 and 6 digits',
                    ]"
                    @update:model-value="form.studentIdNumber = digitsOnly($event, 6)"
                  />
                </div>
              </div>
            </AuthFieldGroup>
          </template>

          <!-- Proof of enrolment (student, optional) -->
          <!-- The section head that used to sit here said "Two documents /
               Optional", which the question above and the count beside it
               already say between them. -->
          <template v-else-if="current === 'proof'">
            <div class="doc-count">{{ proofAdded }} of 2 added</div>

            <AuthDocumentCard
              v-model="form.schoolIdFile"
              title="School ID"
              hint="The front, with all four corners in the frame."
              icon="lucide:id-card"
            />

            <AuthDocumentCard
              v-model="form.assessmentFile"
              title="Assessment of Fees"
              hint="This term's copy, showing your name."
              icon="lucide:receipt-text"
              class="q-mt-sm"
            />
          </template>

          <!-- App PIN (student, optional, last).
               Plain fields rather than PinSetupDialog's keypad: that component
               is right for an interruption — Settings, the forgot-PIN path, the
               offer after signing in — but this is a question in a form, and it
               should look like the eight before it. -->
          <!-- Two separate blocks, not two rows of one group: a PIN and its
               confirmation are the same secret typed twice, and fusing them
               behind a hairline made the second read as another field to fill
               rather than a check on the first. Six cells apiece, because the
               PIN is exactly six digits and the boxes say so without a rule
               having to. -->
          <template v-else-if="current === 'pin'">
            <q-field
              ref="pinFieldRef"
              :model-value="form.pin + form.pinConfirm"
              :rules="[pinPairRule]"
              lazy-rules="ondemand"
              borderless
              hide-bottom-space
              class="pin-field"
            >
              <template #control>
                <div class="pin-blocks">
                  <div class="pin-block">
                    <span class="pin-label">Choose a PIN</span>
                    <PinCells ref="pinCellsRef" v-model="form.pin" aria-label="PIN" />
                  </div>

                  <div class="pin-block">
                    <span class="pin-label">Type it again</span>
                    <PinCells
                      v-model="form.pinConfirm"
                      aria-label="Confirm PIN"
                      :invalid="pinMismatch"
                    />
                  </div>
                </div>
              </template>
            </q-field>
          </template>

          <!-- Documents (manager) -->
          <template v-else-if="current === 'documents'">
            <div class="doc-count">{{ documentsAdded }} of 2 added · both required</div>

            <AuthDocumentCard
              v-model="form.governmentIdFile"
              title="Valid Government ID"
              hint="Any government-issued ID showing your photo and name."
              icon="lucide:id-card"
              :rules="[(val: File | null) => !!val || 'Government ID is required']"
            />

            <AuthDocumentCard
              v-model="form.businessPermitFile"
              title="Business / Mayor's Permit"
              hint="The current permit for the property you are listing."
              icon="lucide:file-text"
              class="q-mt-sm"
              :rules="[(val: File | null) => !!val || 'Business Permit is required']"
            />
          </template>
        </div>

        <!-- The action bar. Fixed at the foot of the sheet, so it holds still
             while the fields above it scroll. The sheet shrinks by --m-kb when
             the Android keyboard is up, so this bar stays above it. Back is
             not here — it is in the step header. -->
        <div class="actions col-auto">
          <AuthButton
            v-if="!isLastStep"
            :loading="creatingAccount"
            :disable="current === 'verify' && !emailVerified"
            @click="nextStep"
          >
            {{ nextLabel }}
            <IconifyIcon icon="lucide:arrow-right" width="18" class="q-ml-sm" />
          </AuthButton>

          <AuthButton v-else type="submit" :loading="loading" :disable="creatingAccount">
            {{ submitLabel }}
            <IconifyIcon :icon="isManager ? 'lucide:check' : 'lucide:user-plus'" width="18" class="q-ml-sm" />
          </AuthButton>

          <!-- The PIN screen is the student's last, and finishing without one is
               a real choice: forcing a secret chosen in a hurry at the end of a
               nine-screen form is how people end up locked out of a brand-new
               account. It can be set any time from Settings. -->
          <q-btn
            v-if="current === 'pin'"
            flat
            no-caps
            class="actions-secondary"
            label="Set one up later"
            :disable="loading"
            @click="finishWithoutPin"
          />

          <!-- Two skips that carry on rather than end the flow: the ID nobody
               has to hand, and the documents OSAS can wait for. Both leave their
               fields empty and advance; neither submits. -->
          <q-btn
            v-else-if="current === 'studentId'"
            flat
            no-caps
            class="actions-secondary"
            label="I don't have it right now"
            @click="skipStudentId"
          />

          <q-btn
            v-else-if="current === 'proof' && !isManager"
            flat
            no-caps
            class="actions-secondary"
            label="Skip for now"
            @click="skipProof"
          />

          <div v-else-if="stepIndex === 0 && !isGoogleMode && !isResubmit" class="actions-note">
            <span>{{ isManager ? 'Already a partner?' : 'Already have an account?' }}</span>
            <q-btn to="/login" flat dense no-caps label="Sign in" class="auth-link q-ml-xs" />
          </div>
        </div>
      </q-form>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref, computed, nextTick, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import type { QField, QForm } from 'quasar';
import { Icon as IconifyIcon } from '@iconify/vue';
import { useAuthStore } from '@/stores/auth';
import { supabase, readOAuthError, isSignupDatabaseError } from '@/utils/supabase';
import { useNotify } from '@/utils/notify';

import AuthInput from '@/components/auth/AuthInput.vue';
import AuthSelect from '@/components/auth/AuthSelect.vue';
import AuthDocumentCard from '@/components/auth/AuthDocumentCard.vue';
import AuthButton from '@/components/auth/AuthButton.vue';
import AuthConsent from '@/components/auth/AuthConsent.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';
import EmailVerifyInline from '@/components/auth/EmailVerifyInline.vue';
import ConnectedGoogleBox from '@/components/auth/ConnectedGoogleBox.vue';
import AuthFieldGroup from '@/components/auth/AuthFieldGroup.vue';
import PinCells from '@/components/shared/PinCells.vue';
import { usePinStore } from '@/stores/pin';
import { capitalizeName, composeStudentId, isPhMobile, normalizePhPhone, phNationalDigits } from '@/utils/format';
import { ALLOWED_EMAIL_DOMAINS, ALLOWED_EMAIL_DOMAINS_TEXT, isAllowedEmailDomain } from '@/utils/config';
import { yearOptions, collegePrograms } from '@/constants/academics';

const router = useRouter();
const route = useRoute();
const notify = useNotify();
const authStore = useAuthStore();
const pinStore = usePinStore();

/** The path is the role. Routes are unchanged, so every existing redirect still lands correctly. */
const isManager = computed(() => route.path.startsWith('/register/manager'));
const registerPath = computed(() => (isManager.value ? '/register/manager' : '/register'));

type StepKey =
  | 'name'
  | 'phone'
  | 'email'
  | 'password'
  | 'verify'
  | 'studies'
  | 'studentId'
  | 'proof'
  | 'pin'
  | 'documents';

/** The short name in the step header — what this screen is, for the progress row. */
const STEP_TITLE: Record<StepKey, string> = {
  name: 'Your name',
  phone: 'Mobile',
  email: 'E-mail',
  password: 'Password',
  verify: 'Confirm e-mail',
  studies: 'Studies',
  studentId: 'Student ID',
  proof: 'Enrolment',
  pin: 'App PIN',
  documents: 'Documents',
};

/**
 * The question each screen asks, which is also its title. One thing per screen
 * is the whole point of this flow, so the question carries the screen rather
 * than sitting under a page heading that repeats on every one of them.
 */
const STEP_QUESTION: Record<StepKey, { title: string; note?: string }> = {
  name: { title: "What's your name?", note: 'As it appears on your school records.' },
  phone: { title: "What's your mobile number?", note: 'Managers reach you here about your application.' },
  email: { title: 'What e-mail should we use?', note: 'We send a code here to confirm it is yours.' },
  password: { title: 'Choose a password' },
  verify: { title: 'Confirm your e-mail' },
  studies: { title: 'What are you studying?' },
  studentId: {
    title: "What's your student ID?",
    note: 'The number printed on your ISU school ID. You can add it later from Profile if you do not have it to hand.',
  },
  // Not "Can you prove your enrolment?", which read as a challenge — the app
  // asking a student to justify themselves before it will let them in. This is
  // the same task the manager screen calls "Verify your property", and the two
  // should sound like the same app doing the same thing.
  proof: {
    title: 'Verify your enrolment',
    note: 'Optional — only OSAS sees these. You can browse Accommo while they check, or add them later from Profile.',
  },
  documents: {
    title: 'Verify your property',
    note: 'Only OSAS sees these. They cannot accredit a property without both.',
  },
  // Last, because it is the only screen about what happens *after* registration
  // rather than part of it. It used to be a dialog thrown over the finished
  // form once the progress bar had already run out.
  pin: {
    title: 'Protect your account with a PIN',
    note: 'Optional — six digits, asked whenever you reopen Accommo. You can set one later from Settings.',
  },
};

const stepIndex = ref(0);
const agreedToTerms = ref(false);
/** Carries "they already consented" across the Google redirect, which wipes local state. */
const CONSENT_MARKER = 'accommo.register.consent';
const registerFormRef = ref<QForm | null>(null);
const stepsEl = ref<HTMLElement | null>(null);
const isGoogleMode = ref(false);
const googleUserId = ref('');
const emailCreated = ref(false);
const emailVerified = ref(false);
const creatingAccount = ref(false);
const showPassword = ref(false);
const showConfirmPassword = ref(false);
const pinCellsRef = ref<InstanceType<typeof PinCells> | null>(null);
const pinFieldRef = ref<QField | null>(null);
const loading = ref(false);
// OSAS sent a manager's application back: sign-in is allowed again so it can be
// corrected, and only the documents step is relevant.
const isResubmit = ref(false);
const decisionReason = ref('');
let createdUserId: string | null = null;

const sexOptions = ['Male', 'Female'];

/** Today, as yyyy-mm-dd, for the date input's own upper bound. */
const today = new Date().toISOString().slice(0, 10);

// The database carries the same bounds (users_date_of_birth_plausible); these
// exist so the person is told before the request is made, not after it fails.
const dateOfBirthRules = [
  (val: string) => !!val || 'Please enter your date of birth',
  (val: string) => val <= today || 'Date of birth cannot be in the future',
  (val: string) => val > '1900-01-01' || 'Please enter a valid date of birth',
];
/** N/A leads and is the default: most people have no extension. */
const NAME_EXT_NONE = 'N/A';
const nameExtensions = [NAME_EXT_NONE, 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];

/**
 * Unicode classes rather than A-Z, so Ñoño and Áurea are names rather than
 * errors, and the body allows what Philippine surnames actually contain —
 * "Dela Cruz", "D'Souza", "St. Clair". The messages name the rule, because
 * "Invalid" leaves someone staring at a field with no idea what it wants.
 *
 * Capitalisation is not a rule here: `capitalizeName()` fixes it on blur, so
 * there is nothing to refuse someone over.
 */
function nameRules(label: string) {
  return [
    (val: string) => !!val?.trim() || `${label} is required`,
    (val: string) =>
      /^[\p{L}\p{M}][\p{L}\p{M}'\-. ]*$/u.test((val ?? '').trim()) ||
      'Letters, spaces, hyphens and apostrophes only',
  ];
}

// Required. Philippine records carry the mother's maiden surname as a middle
// name almost without exception, and OSAS matches registrations against school
// records where it is present — so a blank one is far more often a skipped field
// than a person without one. Case is corrected rather than policed, as with the
// other name fields.
const middleInitialRules = [
  (val: string) => !!val || 'Required',
  (val: string) => /^\p{L}$/u.test(val) || 'One letter only',
];

/**
 * The PIN is optional, so an empty pair passes — but a half-entered one must
 * not. One rule over both cells rather than one each: the only thing worth
 * saying is about the pair, and a message under the first block would be
 * pointing at the wrong one.
 */
function pinPairRule(): boolean | string {
  if (!form.pin && !form.pinConfirm) return true;
  if (form.pin.length !== 6) return 'A PIN is six digits';
  if (form.pin !== form.pinConfirm) return 'The two PINs do not match';
  return true;
}

/** Shakes the second row once both are full and they disagree. */
const pinMismatch = computed(
  () => form.pinConfirm.length === 6 && form.pin.length === 6 && form.pin !== form.pinConfirm,
);

/** Keeps a numeric field numeric while it is being typed into. */
function digitsOnly(value: string | number | null | undefined, max: number): string {
  return String(value ?? '').replace(/\D/g, '').slice(0, max);
}

/** Tidies the case when the field is left, rather than fighting the typing. */
function tidyName(field: 'firstName' | 'lastName' | 'middleInitial') {
  form[field] = capitalizeName(form[field].trim());
}
const emailDomains = [...ALLOWED_EMAIL_DOMAINS];
const collegeOptions = Object.keys(collegePrograms);

/**
 * The visible screens, which is all the branching the flow needs. Google already
 * owns the address and the password, so its path simply has a shorter list —
 * this replaces the old `if (step === 1) step = 4` jumps, and makes the progress
 * count correct for every path without a second rule.
 */
const steps = computed<StepKey[]>(() => {
  if (isResubmit.value) return ['documents'];
  const head: StepKey[] = isGoogleMode.value
    ? ['name', 'phone']
    : ['name', 'phone', 'email', 'password', 'verify'];
  return isManager.value
    ? [...head, 'documents']
    : [...head, 'studies', 'studentId', 'proof', 'pin'];
});

const current = computed<StepKey>(() => steps.value[stepIndex.value] ?? 'name');
const stepTitle = computed(() => STEP_TITLE[current.value]);
const isLastStep = computed(() => stepIndex.value === steps.value.length - 1);

/** The resubmit screen keeps its own wording: it is a correction, not a sign-up. */
const question = computed(() => {
  if (isResubmit.value) {
    return { title: 'Update your application', note: 'Replace the documents OSAS asked about.' };
  }
  return STEP_QUESTION[current.value];
});

/** "1 of 2 added" — visible progress on a screen whose two cards look alike. */
const proofAdded = computed(() => Number(!!form.schoolIdFile) + Number(!!form.assessmentFile));
const documentsAdded = computed(
  () => Number(!!form.governmentIdFile) + Number(!!form.businessPermitFile),
);

const nextLabel = computed(() => {
  // The auth account is created on leaving this screen, so the button says so.
  if (current.value === 'password') return 'Create account';
  return 'Continue';
});

const submitLabel = computed(() => {
  // "Register" overstated it — the auth account already exists by this point
  // (it is created on leaving the Account step); this last press finishes the
  // profile attached to it.
  if (!isGoogleMode.value) return isManager.value ? 'Submit application' : 'Finish signing up';
  return isManager.value ? 'Submit application' : 'Finish profile';
});

const form = reactive({
  firstName: '',
  middleInitial: '',
  lastName: '',
  nameExtension: NAME_EXT_NONE,
  fullName: '',
  sex: '',
  dateOfBirth: '',
  phoneDigits: '',
  phone: '',
  emailUser: '',
  emailDomain: ALLOWED_EMAIL_DOMAINS[0] as string,
  email: '',
  password: '',
  confirmPassword: '',
  college: '',
  program: '',
  yearLevel: '',
  studentIdYear: '',
  studentIdNumber: '',
  studentId: '',
  pin: '',
  pinConfirm: '',
  schoolIdFile: null as File | null,
  assessmentFile: null as File | null,
  governmentIdFile: null as File | null,
  businessPermitFile: null as File | null,
});

const filteredPrograms = computed(() => {
  if (!form.college) return [];
  return collegePrograms[form.college] || [];
});

function onCollegeChange(_val: string | number | null | undefined) {
  form.program = '';
}

// `short` is what the chips show; `label` stays for the rule messages, which
// still need to read as sentences when validation fails.
const passwordChecks = computed(() => {
  const pwd = form.password;
  return [
    { label: 'At least 8 characters', short: '8+ characters', ok: pwd.length >= 8 },
    { label: 'One lowercase letter', short: 'a–z', ok: /[a-z]/.test(pwd) },
    { label: 'One uppercase letter', short: 'A–Z', ok: /[A-Z]/.test(pwd) },
    { label: 'One number', short: '0–9', ok: /\d/.test(pwd) },
    { label: 'One special character (!@#$%^&*)', short: '!@#$%^&*', ok: /[!@#$%^&*]/.test(pwd) },
  ];
});

function splitFullName(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return {
    firstName: parts[0] ?? '',
    lastName: parts.slice(1).join(' '),
  };
}

/**
 * The four inputs become the one `full_name` the database actually stores —
 * "Juan D. Dela Cruz Jr." There are no first/middle/last columns anywhere, and
 * the profile screen edits this same string as free text later, so composing
 * here keeps one canonical spelling of a person's name.
 */
function syncFullName() {
  // Capitalised here as well as on blur: blur is what the person sees happen,
  // but it does not always fire before a submit on a touch screen, and the
  // stored name should not depend on which.
  const first = capitalizeName(form.firstName.trim());
  const last = capitalizeName(form.lastName.trim());
  const middle = form.middleInitial ? `${capitalizeName(form.middleInitial)}.` : '';
  const extension = form.nameExtension === NAME_EXT_NONE ? '' : form.nameExtension;
  form.fullName = [first, middle, last, extension].join(' ').trim().replace(/\s+/g, ' ');
}

function fillFromGoogleSession(user: { id: string; email?: string | undefined; user_metadata?: Record<string, unknown> }) {
  googleUserId.value = user.id;
  form.email = user.email || '';
  const split = splitFullName(String(user.user_metadata?.full_name || ''));
  form.firstName = split.firstName;
  form.lastName = split.lastName;
  syncFullName();
}

/**
 * Said by both auth screens, because neither can tell the two causes apart. A
 * trigger rejection reaches the client as Supabase's generic "Database error
 * saving new user", so the domain rule has to be explained here rather than
 * read off the error — and the wording also has to fit a genuine transient
 * failure, which arrives looking identical.
 */
const GOOGLE_REJECTED = `We couldn't connect that Google account. Accommo only accepts ${ALLOWED_EMAIL_DOMAINS_TEXT} addresses — check which account you picked, then try again.`;

onMounted(async () => {
  // A failed OAuth round trip comes back here with an error in the URL rather
  // than a session — the trigger on auth.users turning away a domain Accommo
  // does not accept looks exactly like this.
  const oauthFailure = readOAuthError();
  if (oauthFailure) {
    notify.error(isSignupDatabaseError(oauthFailure) ? GOOGLE_REJECTED : oauthFailure);
    history.replaceState(null, '', window.location.pathname);
    return;
  }

  if (route.query.newUser) {
    notify.info(
      isManager.value
        ? 'Account not found. Please complete your application.'
        : 'Account not found. Please complete registration.',
    );
    void router.replace(registerPath.value);
  }

  const { session, profile, registered, status } = await authStore.getSessionProfile();

  // Resubmission: an existing manager OSAS has asked to change something. Their
  // account and documents already exist, so only the documents step applies.
  if (
    isManager.value &&
    session &&
    profile &&
    registered &&
    (status === 'rejected' || status === 'reviewing')
  ) {
    isResubmit.value = true;
    fillFromGoogleSession(session.user);
    decisionReason.value = await authStore.fetchDecisionReason(session.user.id);
    return;
  }

  await adoptGoogleSession(session, !!profile, registered);
});

/**
 * Decides what a just-signed-in Google account means on the register screen.
 *
 * The router guard already rules on all of this, but only when a navigation
 * happens: the redirect flow earned that for free, because boot/deeplink.ts
 * reloaded the app once the tokens were set. The native picker resolves in
 * place and navigates nowhere, so the same three outcomes are decided here
 * rather than leaving a live session nobody has ruled on — which is what let a
 * finished account silently stay on this screen, and then walk straight into
 * the app the next time it touched a public route.
 */
async function routeAfterGoogle() {
  const { session, profile, registered, status } = await authStore.getSessionProfile();
  if (!session) return;

  const role = profile?.role;
  // Same exemption as resolveDestination(): a manager OSAS sent back is
  // registered but still has to reach this screen to correct the application.
  const resubmitting = role === 'manager' && (status === 'rejected' || status === 'reviewing');

  // A finished account cannot register again. Signing out first is what makes
  // the next screen honest — left signed in, /login would bounce them into the
  // app instead of showing the message.
  if (registered && !resubmitting) {
    await supabase.auth.signOut();
    authStore.clearCachedRole();
    void router.push('/login?accountExists=true');
    return;
  }

  if (resubmitting && isManager.value) {
    isResubmit.value = true;
    fillFromGoogleSession(session.user);
    decisionReason.value = await authStore.fetchDecisionReason(session.user.id);
    return;
  }

  await adoptGoogleSession(session, !!profile, registered);
}

/**
 * Turns a Google session into this screen's "Google connected" mode.
 *
 * Two routes arrive here. A browser session comes back through the redirect and
 * finds the session on mount; on a device the native picker resolves in place
 * and handleGoogleAuth calls this directly, with nothing having navigated.
 */
async function adoptGoogleSession(
  session: { user: { id: string; email?: string | undefined; app_metadata?: Record<string, unknown>; user_metadata?: Record<string, unknown> } } | null,
  hasProfile: boolean,
  // Undefined when there is no session at all, which the guard below rejects.
  registered: boolean | undefined,
) {
  // Was "session && !profile" — a condition the auth trigger makes impossible,
  // since it always writes the users row. The real signal is an OAuth session
  // whose onboarding never completed.
  const viaOAuth = session?.user?.app_metadata?.provider !== 'email';
  if (!(session && hasProfile && !registered && viaOAuth)) return;

  // Accounts predating the domain rule can still sign in — the trigger guards
  // INSERT only, so nobody already in the app is locked out of it — but they
  // must not be able to finish a fresh registration on a domain Accommo no
  // longer accepts.
  if (!isAllowedEmailDomain(session.user.email)) {
    await supabase.auth.signOut();
    notify.error(GOOGLE_REJECTED);
    return;
  }
  isGoogleMode.value = true;
  fillFromGoogleSession(session.user);
  // They consented on the way out — handleGoogleAuth cannot reach Google
  // otherwise. Asking again here would be asking twice for the same thing. If
  // the marker is gone, the guard in handleRegister still catches it.
  if (localStorage.getItem(CONSENT_MARKER) === '1') agreedToTerms.value = true;
}

async function createAccountNow(): Promise<boolean> {
  if (emailCreated.value || creatingAccount.value) return emailCreated.value;
  creatingAccount.value = true;
  try {
    syncFullName();
    if (form.phoneDigits) form.phone = normalizePhPhone(form.phoneDigits);
    if (!isGoogleMode.value) form.email = `${form.emailUser}@${form.emailDomain}`;

    // Resuming an unfinished registration: the auth account already exists (it
    // is created when leaving the Account step, and half-finished accounts are
    // routed back here), so signing up again would only fail with "already
    // registered" and trap the user in a loop. Reuse the live session instead.
    const existing = await supabase.auth.getUser();
    const existingUser = existing.data?.user;
    if (existingUser) {
      createdUserId = existingUser.id;
      emailCreated.value = true;
      return true;
    }

    createdUserId = isManager.value
      ? await authStore.createManagerAccount(form)
      : await authStore.createStudentAccount(form);
    emailCreated.value = true;
    return true;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Could not create your account.';
    notify.error(message);
    return false;
  } finally {
    creatingAccount.value = false;
  }
}

/**
 * Bring the first failing field into view. Validation paints the field red, but
 * on a step taller than the scroller that happens off-screen — pressing Continue
 * then looked like it had done nothing at all.
 */
function revealFirstError() {
  void nextTick(() => {
    const field = stepsEl.value?.querySelector('.q-field--error');
    field?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  });
}

async function nextStep() {
  if (!registerFormRef.value) return;
  const success = await registerFormRef.value.validate();
  if (!success) {
    revealFirstError();
    return;
  }

  // Leaving Password: the address and the password are both in hand, so create
  // the account here and the next screen can send its code straight away.
  if (current.value === 'password') {
    const ok = await createAccountNow();
    if (ok) goToStep(stepIndex.value + 1);
    return;
  }

  if (!isLastStep.value) goToStep(stepIndex.value + 1);
}

/** Each step starts at its own top; the scroller does not keep the last one's offset. */
function goToStep(index: number) {
  stepIndex.value = index;
  void nextTick(() => {
    stepsEl.value?.scrollTo({ top: 0 });
    // The PIN cells are a label over a hidden input, so `autofocus` has nothing
    // obvious to attach to — the screen focuses them itself, as the text
    // screens do with their first field.
    if (current.value === 'pin') pinCellsRef.value?.focus();
  });
}

/**
 * Back a screen — or, from the first one, back out to the role fork.
 *
 * `/register/role` rather than `/`, because it is the one target that resolves
 * for everybody. The guard's checks for a half-finished account all sit behind
 * `if (!isRegister)`, so a `/register/*` path skips them and is simply allowed;
 * the route is in PUBLIC_ROUTES as well, so a signed-out visitor reaches it too.
 *
 * `/` would have worked for most people and trapped one group: a student who
 * created their account on the password screen but has not yet typed the code
 * has `emailVerified === false`, and the guard turns that into
 * `/login?verifyEmail=true` — a worse dead end than the one this is fixing.
 */
function prevStep() {
  if (stepIndex.value > 0) {
    goToStep(stepIndex.value - 1);
    return;
  }
  void router.push('/register/role');
}

/**
 * Leave the student ID blank and carry on. Both halves are cleared so the
 * composed value is empty and the column takes NULL — a half-filled year left
 * behind would compose to nothing anyway, but it would also reappear if they
 * came back, looking like something they had entered.
 */
function skipStudentId() {
  form.studentIdYear = '';
  form.studentIdNumber = '';
  form.studentId = '';
  goToStep(stepIndex.value + 1);
}

/**
 * Carry on without the enrolment documents. This used to end registration on
 * the spot, because `proof` was the last screen; now the PIN follows it, so
 * skipping means skipping these two files and nothing else.
 */
function skipProof() {
  form.schoolIdFile = null;
  form.assessmentFile = null;
  goToStep(stepIndex.value + 1);
}

/** Finish with no PIN set. Clears the fields so a half-typed one is not used. */
function finishWithoutPin() {
  form.pin = '';
  form.pinConfirm = '';
  void handleRegister(true);
}

/**
 * Connecting Google is deliberately NOT gated on the consent boxes.
 *
 * It is a product decision, made knowingly: `signInWithOAuth` writes the name
 * and e-mail into `public.users` the moment it runs, so an abandoned connection
 * can leave a row behind that nobody consented to. The button is meant to be the
 * first thing someone can reach on the screen, without reading anything first,
 * and that is worth the intermediate row.
 *
 * What consent still gates is finishing: the boxes are a required field of this
 * screen's form, so Continue cannot leave without them, and handleRegister()
 * refuses to reach markRegistered() — which stamps terms_accepted_at and
 * privacy_accepted_at — without them either. Nobody completes registration
 * unconsented; only the auth row moves earlier than the consent.
 */
async function handleGoogleAuth() {
  try {
    // Only meaningful when the boxes happened to be ticked first: local state
    // does not survive a redirect, so this saves re-ticking on the way back.
    // The native picker never navigates, so there it is simply harmless.
    if (agreedToTerms.value) localStorage.setItem(CONSENT_MARKER, '1');
    const data = await authStore.loginWithGoogle(registerPath.value);
    // A session in hand means the native picker resolved in place rather than
    // handing off to a redirect, so nothing is going to re-mount this screen.
    if (data && 'session' in data && data.session) await routeAfterGoogle();
  } catch (error: unknown) {
    localStorage.removeItem(CONSENT_MARKER);
    const message = error instanceof Error ? error.message : 'An error occurred';
    // The domain rule on auth.users rejects the account at sign-in now that the
    // native path gets the failure thrown rather than returned in a URL.
    notify.error(isSignupDatabaseError(message) ? GOOGLE_REJECTED : message);
  }
}

async function cancelGoogle() {
  await supabase.auth.signOut();
  isGoogleMode.value = false;
  googleUserId.value = '';
  // Unlinking abandons the sign-up the consent was given for, so it does not
  // carry over to whatever they do next.
  agreedToTerms.value = false;
  localStorage.removeItem(CONSENT_MARKER);
  stepIndex.value = 0;
  form.email = '';
  form.emailUser = '';
  form.emailDomain = ALLOWED_EMAIL_DOMAINS[0];
  form.firstName = '';
  form.middleInitial = '';
  form.lastName = '';
  form.nameExtension = NAME_EXT_NONE;
  form.fullName = '';
  notify.info('Google account unlinked.');
}

/** The student ID is unique across accounts; catching it here saves a round trip into a failed submit. */
async function studentIdTaken(): Promise<boolean> {
  if (!form.studentId) return false;
  try {
    const { data } = await supabase.rpc('check_student_id_exists', { p_student_id: form.studentId });
    return data === true;
  } catch {
    // Re-validated server side on submit.
    return false;
  }
}

async function handleRegister(skipVerification = false) {
  syncFullName();
  form.phone = normalizePhPhone(form.phoneDigits);
  // Empty when either half is missing — including when the screen was skipped —
  // and the store writes `studentId || null`, so a skip reaches the column as
  // NULL rather than as a second empty string colliding on its unique index.
  form.studentId = composeStudentId(form.studentIdYear, form.studentIdNumber);
  if (!isGoogleMode.value) {
    form.email = `${form.emailUser}@${form.emailDomain}`;
  }

  if (!skipVerification && registerFormRef.value) {
    const success = await registerFormRef.value.validate();
    if (!success) {
      revealFirstError();
      return;
    }
  }

  // The backstop. Screen one's form already requires both consents, so this is
  // not reachable in normal use — but this function is what eventually calls
  // markRegistered() to stamp terms_accepted_at and privacy_accepted_at, and
  // those columns must never be written on an unticked box. Send them back to
  // the screen that asks rather than failing quietly.
  if (!agreedToTerms.value) {
    notify.info('Please accept the Terms of Service and the Privacy Notice first.');
    goToStep(0);
    return;
  }

  loading.value = true;
  try {
    if (isManager.value) {
      if (isResubmit.value) {
        await authStore.resubmitManagerApplication(googleUserId.value, form);
        notify.success('Application updated. OSAS will review it again — you can sign in once it is approved.');
        void router.push('/login');
        return;
      }

      if (isGoogleMode.value) {
        await authStore.completeGoogleManagerProfile(googleUserId.value, form);
      } else if (createdUserId) {
        await authStore.finalizeManagerAccount(createdUserId, form);
      } else {
        await authStore.registerManager(form); // safety fallback (no early account)
      }

      // Both paths end the same way: signed out, waiting on OSAS. A manager
      // holds no session until the application is approved, and login()
      // enforces that, so there is nowhere in the app to send them yet.
      notify.success('Application submitted. OSAS will review your documents — you can sign in once it is approved.');
      void router.push('/login');
      return;
    }

    if (await studentIdTaken()) {
      notify.error('This Student ID is already registered. Please double check or sign in.');
      return;
    }

    if (isGoogleMode.value) {
      await authStore.completeGoogleProfile(googleUserId.value, form);
      notify.success('Profile completed successfully!');
    } else {
      if (createdUserId) {
        await authStore.finalizeStudentAccount(createdUserId, form);
      } else {
        await authStore.register(form); // safety fallback (no early account)
      }
      notify.success('Account created successfully!');
    }

    // The PIN is the last screen's answer, so it is set here rather than by a
    // dialog thrown over the finished form. Set before navigating, so the app
    // is already protected the first time it is backgrounded.
    if (form.pin) {
      const { error: pinError } = await supabase.rpc('set_pin', { p_pin: form.pin });
      if (pinError) {
        // The account is made and registered by this point; only the PIN failed.
        // Say so rather than implying the whole registration did, and let them
        // set one from Settings.
        notify.warning('Your account is ready, but the PIN could not be set. You can add one from Settings.');
      } else {
        // Through the store, not a direct assignment: setHasPin also writes the
        // per-account cache the lock screen falls back on when it is offline.
        await pinStore.setHasPin(true);
      }
    }

    void router.push('/student/home');
  } catch (error: unknown) {
    notify.error(error instanceof Error ? error.message : 'An unexpected error occurred');
  } finally {
    loading.value = false;
    // Done with the redirect marker either way: consent is recorded on the row
    // by now, and a retry after an error still has it in memory.
    localStorage.removeItem(CONSENT_MARKER);
  }
}

// Called by the Confirm-e-mail step when the code verifies. Verifying *is* the
// step's action, so it carries the flow forward itself rather than confirming
// and then waiting for a second press on Continue.
function onEmailVerified() {
  emailVerified.value = true;
  if (!isLastStep.value) goToStep(stepIndex.value + 1);
}
</script>

<style scoped>
/* No entrance animation of its own: the route transition already drops this
   sheet in from the top, and running a second slideDown inside it meant the
   content was moving relative to a page that was itself moving. */
/* A fixed-height frame rather than a sheet that grows with its contents. The
   header and the action bar are `col-auto`; `.steps` between them is the only
   scroller. That is what stops the primary button moving hundreds of pixels
   between Personal (five fields) and Confirm e-mail (a code box). */
/* The name screen is the tallest in the flow — question, Google, divider, four
   name fields, two consent rows — and it has to fit without scrolling, because
   the consent gating the Google button is the last thing on it. Everything here
   is scoped to the sheet so Login's roomier two-field form is left alone. */
.auth-sheet :deep(.auth-field .q-field__control) {
  min-height: 56px;
}
.auth-sheet :deep(.divider) {
  margin: 14px 0;
}

.reject-banner {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  margin: 4px 0 16px;
  padding: 12px 14px;
  border: 1px solid color-mix(in srgb, var(--m-danger) 35%, transparent);
  border-radius: 12px;
  background: color-mix(in srgb, var(--m-danger) 8%, transparent);
  color: var(--m-danger);
}
.reject-title { margin: 0 0 2px; font-size: 13px; font-weight: 700; }
.reject-text { margin: 0; font-size: 13px; line-height: 1.5; color: var(--m-ink); }

.progress {
  margin: 0 12px 18px;
}
.progress-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 7px;
}
/* Pulled left by its own padding so the arrow's optical edge lines up with the
   title below it, while the tap target stays a full 44px. */
.progress-back {
  width: 44px;
  height: 44px;
  margin: -10px 0 -10px -12px;
  color: var(--m-ink);
}
.progress-step {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}

/* One segment per step. How many there are is the shape of the row; where you
   are is which segments are filled — neither needs reading, which is what let
   the written "Step 2 of 4" go. The current segment is wider so it reads as
   "here" rather than merely as the last one completed. */
.progress-track {
  display: flex;
  gap: 4px;
}
.progress-seg {
  height: 4px;
  flex: 1;
  border-radius: 999px;
  background: var(--m-border);
  transition: flex-grow 0.3s ease, background-color 0.3s ease;
}
.progress-seg.done {
  background: color-mix(in srgb, var(--m-primary) 55%, transparent);
}
.progress-seg.current {
  flex-grow: 1.6;
  background: var(--m-primary);
}

/* The question is the screen's title, so it gets the app's title face — the one
   every other titled surface uses (BottomSheet, QRScanner, the manager cards,
   EmailVerifyInline) and the two auth screens never did. Tight leading because
   these run to two lines on a phone and a question has to read as one line of
   speech, not two stacked sentences. */
/* The scroller. Negative side margins with matching padding so a focused field's
   tinted row still reaches the sheet's edge, and the bottom padding keeps the
   last field clear of the action bar's hairline. */
.steps {
  min-height: 0;
  margin: 0 -24px;
  /* Padded by the keyboard height so the last fields can still be scrolled
     clear of it. The sheet itself does not shrink any more, so without this the
     foot of this scroller would sit behind the keyboard with no way to reach
     it. */
  padding: 0 24px calc(8px + var(--m-kb, 0px));
  overflow-y: auto;
  overscroll-behavior-y: contain;
}

/* Sits at the foot of the frame. Clearing the keyboard is .auth-sheet's job —
   it shrinks by --m-kb — so this bar just needs its own padding. */
.actions {
  margin: 0 -24px;
  padding: 12px 24px 16px;
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.actions-secondary {
  width: 100%;
  height: 44px;
  margin-top: 6px;
  border-radius: 12px;
  color: var(--m-primary);
  font-size: 15px;
  font-weight: 700;
}
.actions-note {
  display: flex;
  height: 44px;
  align-items: center;
  justify-content: center;
  color: var(--m-muted);
  font-size: 14px;
}

/* Says what the step expects of you before the upload boxes do. */
/* The PIN pair. Two blocks with air between them rather than two rows sharing a
   hairline: the second is a check on the first, not another thing to fill in. */
.pin-field :deep(.q-field__control) {
  min-height: 0;
  padding: 0;
}
.pin-field :deep(.q-field__native) {
  padding: 0;
}
.pin-blocks {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 18px;
}
.pin-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pin-label {
  margin-left: 2px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

/* Visible progress on a screen whose two cards are meant to look alike. */
.doc-count {
  margin: 0 12px 10px;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.otp-verified {
  display: flex;
  align-items: center;
  padding: 8px;
  font-size: 13px;
  line-height: 1.4;
}

/* Part of the value, so it matches the input rather than sitting back like the
   icons it replaced. */
.phone-prefix {
  color: var(--m-ink);
  font-size: 16px;
  font-weight: 500;
}

/* Each name row is a wide field and a narrow one — First + M.I., then Last +
   Ext. — so the hairline runs between them vertically rather than the group's
   usual horizontal one. The group supplies the horizontal rule between rows. */
.name-row > div {
  min-width: 0;
}
.name-split {
  border-left: 1px solid var(--m-border);
}

.pw-checks {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  padding: 10px 16px 12px;
}
.pw-chip {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.pw-chip.ok {
  background: var(--m-success-soft);
  color: var(--m-success);
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

@media (prefers-reduced-motion: reduce) {
  .progress-seg,
  .actions { transition: none; }
}
</style>
