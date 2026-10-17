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
            {{ decisionReason || 'OSAS needs clearer copies of your requirements — re-upload them below.' }}
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
          <!-- Not on a resubmit's first screen: there is no role to go back to. -->
          <q-btn
            v-if="stepIndex > 0 || !isResubmit"
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
        @submit.prevent="() => (isLastStep ? handleRegister(false) : nextStep())"
      >
        <div ref="stepsEl" class="steps col">
          <!-- One question per screen, and the question is the screen's title.
               The 34px page heading is gone with it: repeating "Create Account"
               above "What's your name?" said nothing the second time. -->
          <header class="auth-question">
            <h1>{{ question.title }}</h1>
            <p v-if="question.note">{{ question.note }}</p>
          </header>

          <AccountSteps />
          <StudentSteps />
          <ManagerSteps />
        </div>

        <!-- The action bar. Fixed at the foot of the sheet, so it holds still
             while the fields above it scroll. The keyboard simply comes up over
             it — nothing moves to make room. Back is
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

          <!-- Two skips that carry on rather than end the flow: the ID nobody
               has to hand, and the documents OSAS can wait for. Both leave their
               fields empty and advance; neither submits. -->
          <q-btn
            v-if="current === 'studentId'"
            flat
            no-caps
            class="actions-secondary"
            label="I don't have it right now"
            @click="skipStudentId"
          />

          <q-btn
            v-else-if="current === 'schoolId' || current === 'assessment'"
            flat
            no-caps
            class="actions-secondary"
            label="Skip for now"
            @click="skipDocument"
          />

          <div v-else-if="stepIndex === 0 && !isGoogleMode && !isResubmit" class="actions-note">
            <span>{{ isManager ? 'Already a partner?' : 'Already have an account?' }}</span>
            <q-btn to="/login" flat dense no-caps label="Log in" class="auth-link q-ml-xs" />
          </div>
        </div>
      </q-form>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import AccountSteps from '@/components/auth/register/AccountSteps.vue'
import AuthButton from '@/components/auth/AuthButton.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import ManagerSteps from '@/components/auth/register/ManagerSteps.vue'
import StudentSteps from '@/components/auth/register/StudentSteps.vue'
import { provideRegister } from '@/components/auth/register/register'

// The page is the frame — progress, the question, the action bar. The screens
// themselves live in components/auth/register/, one group per role.
const {
  isManager,
  stepIndex,
  registerFormRef,
  stepsEl,
  isGoogleMode,
  emailVerified,
  creatingAccount,
  loading,
  isResubmit,
  decisionReason,
  steps,
  current,
  stepTitle,
  isLastStep,
  question,
  nextLabel,
  submitLabel,
  nextStep,
  prevStep,
  skipStudentId,
  skipDocument,
  handleRegister,
} = provideRegister()
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
   every other titled surface uses (BottomSheet, QRScanner, the landlord/landlady cards,
   EmailVerifyInline) and the two auth screens never did. Tight leading because
   these run to two lines on a phone and a question has to read as one line of
   speech, not two stacked sentences. */
/* The scroller. Negative side margins with matching padding so a focused field's
   tinted row still reaches the sheet's edge, and the bottom padding keeps the
   last field clear of the action bar's hairline. */
.steps {
  min-height: 0;
  margin: 0 -24px;
  padding: 0 24px 8px;
  overflow-y: auto;
  overscroll-behavior-y: contain;
}
/* Sits at the foot of the frame, and stays there when the keyboard opens: it is
   covered rather than moved, so this bar just needs its own padding. */
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
@media (prefers-reduced-motion: reduce) {
  .progress-seg,
    .actions { transition: none; }
}
</style>
