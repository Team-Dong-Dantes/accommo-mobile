// Registering with Google: connecting the account, deciding what a fresh
// Google session means here, and giving it a password.
import { ALLOWED_EMAIL_DOMAINS, ALLOWED_EMAIL_DOMAINS_TEXT, isAllowedEmailDomain } from '@/utils/config';
import { NAME_EXT_NONE } from './model';
import { isSignupDatabaseError, supabase } from '@/utils/supabase';
import type { createRegisterForm } from './form';

export function createRegisterGoogle(ctx: ReturnType<typeof createRegisterForm>) {
  const { router, notify, authStore, isManager, registerPath, stepIndex, agreedToTerms, CONSENT_MARKER, isGoogleMode, googleUserId, creatingAccount, isResubmit, decisionReason, form, splitFullName, syncFullName } = ctx;
  function fillFromGoogleSession(user: { id: string; email?: string | undefined; user_metadata?: Record<string, unknown> }) {
    googleUserId.value = user.id;
    form.email = user.email || '';
    // Only into empty fields: a name already typed, or brought back by the draft
    // after a reload, is the person's own correction and outranks Google's.
    if (!form.firstName && !form.lastName) {
      const split = splitFullName(String(user.user_metadata?.full_name || ''));
      form.firstName = split.firstName;
      form.lastName = split.lastName;
    }
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
    // Same exemption as resolveDestination(): a landlord/landlady OSAS sent back is
    // registered but still has to reach this screen to correct the application.
    const resubmitting = role === 'manager' && (status === 'rejected' || status === 'needs_resubmission' || status === 'reviewing');

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

  /**
   * Gives a Google-connected account a password too, so the login screen's e-mail
   * and password form works for it. Re-saving the same password — going back and
   * forward, or resuming an unfinished registration — is not an error here.
   */
  async function saveGooglePassword(): Promise<boolean> {
    creatingAccount.value = true;
    try {
      // On a re-save the account already has this password, and Supabase requires
      // the current one before changing it; sending it lets that land on same_password.
      const { error } = await supabase.auth.updateUser({ password: form.password, current_password: form.password });
      const code: string | undefined = error?.code;
      // A different password typed on resuming: the one saved the first time stays.
      if (code === 'current_password_mismatch') {
        notify.info('You already set a password earlier, and it is kept. Use "Forgot password" on the login screen if you need a new one.');
        return true;
      }
      if (error && code !== 'same_password') throw error;
      return true;
    } catch (error: unknown) {
      notify.error(error instanceof Error ? error.message : 'Could not save your password.');
      return false;
    } finally {
      creatingAccount.value = false;
    }
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

  return {
    fillFromGoogleSession,
    GOOGLE_REJECTED,
    routeAfterGoogle,
    adoptGoogleSession,
    saveGooglePassword,
    handleGoogleAuth,
    cancelGoogle,
  };
}
