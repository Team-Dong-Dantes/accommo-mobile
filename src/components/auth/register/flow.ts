// Moving through the flow: picking up a draft, creating the account on leaving
// the password screen, the steps, and submitting the documents at the end.
import { type DocExpected } from '@/utils/docReading';
import { type Session } from '@supabase/supabase-js';
import { composeStudentId, normalizePhPhone } from '@/utils/format';
import { computed, nextTick, onMounted } from 'vue';
import { isSignupDatabaseError, readOAuthError, supabase } from '@/utils/supabase';
import type { createRegisterForm } from './form';
import type { createRegisterGoogle } from './google';

export function createRegisterFlow(ctx: ReturnType<typeof createRegisterForm> & ReturnType<typeof createRegisterGoogle>) {
  const { router, route, notify, authStore, isManager, registerPath, stepIndex, agreedToTerms, CONSENT_MARKER, registerFormRef, stepsEl, isGoogleMode, googleUserId, emailCreated, emailVerified, creatingAccount, loading, isResubmit, decisionReason, steps, current, isLastStep, form, clearDraft, draft, syncFullName, fillFromGoogleSession, GOOGLE_REJECTED, adoptGoogleSession, saveGooglePassword } = ctx;
  let createdUserId: string | null = null;

  /**
   * Returns to the screen the draft was on. The account is created on leaving the
   * password screen, so a live e-mail session means that already happened and is
   * picked up here — otherwise finishing would try to create it a second time,
   * with no password. Without one, nobody goes past the password screen.
   */
  function restoreDraftStep(session: Session | null) {
    if (!draft) return;
    const savedAt = steps.value.indexOf(draft.step);
    if (session?.user.app_metadata?.provider === 'email') {
      createdUserId = session.user.id;
      emailCreated.value = true;
      // Continue is disabled on the verify screen until the code checks out, so
      // a draft past it was verified.
      emailVerified.value = savedAt > steps.value.indexOf('verify');
    }
    const target = session ? savedAt : Math.min(savedAt, steps.value.indexOf('password'));
    if (target > 0) goToStep(target);
  }

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

    // Resubmission: an existing landlord/landlady OSAS has asked to change something. Their
    // account and documents already exist, so only the documents step applies.
    if (
      isManager.value &&
      session &&
      profile &&
      registered &&
      (status === 'rejected' || status === 'needs_resubmission' || status === 'reviewing')
    ) {
      isResubmit.value = true;
      fillFromGoogleSession(session.user);
      decisionReason.value = await authStore.fetchDecisionReason(session.user.id);
      return;
    }

    await adoptGoogleSession(session, !!profile, registered);
    // Re-read: adoptGoogleSession signs out a Google account on a refused domain.
    restoreDraftStep((await supabase.auth.getSession()).data.session);
  });

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
      const field = stepsEl.value?.querySelector('.q-field--error, .picker-field--error');
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
    // Google mode already has the account, so the password goes onto it instead.
    if (current.value === 'password') {
      const ok = isGoogleMode.value ? await saveGooglePassword() : await createAccountNow();
      if (ok) goToStep(stepIndex.value + 1);
      return;
    }

    if (!isLastStep.value) goToStep(stepIndex.value + 1);
  }

  /**
   * Required rather than optional: a document with no expiry is indistinguishable
   * from one that never lapses. DateTimeField joins the QForm, so Continue and
   * submit check it like any other field.
   */
  const expiryRules = [(val: string) => !!val || 'Add the expiry date printed on this document.'];

  /** Each step starts at its own top; the scroller does not keep the last one's offset. */
  function goToStep(index: number) {
    stepIndex.value = index;
    void nextTick(() => {
      stepsEl.value?.scrollTo({ top: 0 });
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
   * What a scanned school ID or assessment is checked against. Middle initial and
   * suffix are left out: the check skips them anyway.
   */
  const documentExpected = computed<DocExpected>(() => ({
    fullName: `${form.firstName} ${form.lastName}`,
    studentId: composeStudentId(form.studentIdYear, form.studentIdNumber),
    college: form.college,
  }));

  /** Leave this enrolment document out; the assessment is the student's last screen, so skipping it finishes. */
  function skipDocument() {
    if (current.value === 'schoolId') {
      form.schoolIdFile = null;
      form.schoolIdText = null;
      goToStep(stepIndex.value + 1);
      return;
    }
    form.assessmentFile = null;
    form.assessmentText = null;
    void handleRegister(true);
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
          notify.success('Application updated. OSAS will review it again.');
          void router.push('/manager/dashboard');
          return;
        }

        if (isGoogleMode.value) {
          await authStore.completeGoogleManagerProfile(googleUserId.value, form);
        } else if (createdUserId) {
          await authStore.finalizeManagerAccount(createdUserId, form);
        } else {
          await authStore.registerManager(form); // safety fallback (no early account)
        }

        // Every path ends signed in. The app is theirs straight away; adding
        // accommodations and rooms is what waits for OSAS (the dashboard banner
        // says so, and the database enforces it).
        clearDraft();
        notify.success('Account created. OSAS will verify your requirements — you can add accommodations once they do.');
        void router.push('/manager/dashboard');
        return;
      }

      if (await studentIdTaken()) {
        notify.error('This Student ID is already registered. Please double check or log in.');
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

      clearDraft();
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

  return {
    createdUserId,
    restoreDraftStep,
    createAccountNow,
    revealFirstError,
    nextStep,
    expiryRules,
    goToStep,
    prevStep,
    skipStudentId,
    documentExpected,
    skipDocument,
    studentIdTaken,
    handleRegister,
    onEmailVerified,
  };
}
