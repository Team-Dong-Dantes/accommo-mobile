// The auth store's steps that read or write nothing of the store's own state:
// creating a landlord/landlady account, stamping registration, Google sign-in,
// and the phone and e-mail codes. The store keeps a one-line action for each.

import { Capacitor } from '@capacitor/core'
import { SocialLogin } from '@capgo/capacitor-social-login'
import { supabase } from '@/utils/supabase'
import { captcha } from '@/utils/captcha'
import { isPhMobile } from '@/utils/format'
import { ensureUserRow, formatProfileData, sanitizeError } from '@/stores/authRows'
import type { ManagerRegisterForm } from '@/stores/auth'

// --- MANAGER REGISTRATION (account-first) ---
export async function createManagerAccount(form: ManagerRegisterForm) {
  const profileData = formatProfileData(form, 'manager')
  const response = await supabase.auth.signUp({
    email: form.email,
    password: form.password ?? '',
    options: { data: profileData, ...(await captcha()) },
  })
  if (response.error) throw sanitizeError(response.error)
  const userId = response.data.user?.id
  if (!userId) throw new Error('Failed to retrieve user ID after registration.')
  await ensureUserRow(userId, form.email, profileData, 'pending')
  return userId
}

/**
 * Records that the signed-in user proved they read their e-mail. Only succeeds
 * when the current token came from an e-mail code (or an OAuth provider that
 * already vouched for the address) — the check runs server-side against the
 * token's own `amr` claim, so the client cannot simply assert it.
 */
/**
 * Marks onboarding finished. Until this is set the account exists but its
 * owner never completed registration — which is the normal state right after
 * an OAuth sign-in, since signInWithOAuth provisions the user whether they
 * came from the login screen or the register screen.
 */
export async function markRegistered() {
  // Both consents are stamped here rather than at each call site: this is
  // the one function every registration path (student/manager, email/Google)
  // ends with. The register screen gates every action that creates something
  // on the consent sheet — the Google button, account creation, and its own
  // final submit — so reaching this point means both were given. Both, and
  // separately, since RA 10173 makes consent to data processing its own
  // decision from agreeing to the terms.
  //
  // An RPC rather than three column writes, because those columns were
  // writable by the account holder: anyone could mark themselves registered
  // having done none of it, and — worse — write or rewrite their own consent
  // evidence. complete_registration() is SECURITY DEFINER, refuses to run
  // without a confirmed e-mail, and stamps with coalesce() so the timestamps
  // are append-only and cannot be back-dated afterwards.
  //
  // No userId argument: the function reads auth.uid(), so the client no
  // longer gets to name the row it is completing.
  const { error } = await supabase.rpc('complete_registration')
  if (error) throw sanitizeError(error)
}

/** The note OSAS left with their decision, for the resubmission screen. */
export async function fetchDecisionReason(userId: string): Promise<string> {
  const { data } = await supabase
    .from('verification_requests')
    .select('decision_notes, rejection_reasons')
    .eq('entity_type', 'user')
    .eq('entity_id', userId)
    .order('reviewed_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  return data?.decision_notes || (data?.rejection_reasons ?? []).join(', ') || ''
}

export async function confirmEmailOwnership() {
  const { error } = await supabase.rpc('confirm_email_ownership')
  if (error) throw sanitizeError(error)
}

// --- PHONE VERIFICATION (proof of ownership, not a login) ---
// The user must already be signed in (e.g. immediately after registering, or
// from their Profile). updateUser triggers an SMS with a code; verifying it
// with the `phone_change` type confirms the number WITHOUT creating a new
// session, so this is purely a verification step, not passwordless auth.
export async function sendPhoneVerification(phone: string) {
  // normalizePhPhone() only reshapes what it is given: it prefixes '+63' to
  // whatever digits are left over, so anything at all reaches this call as a
  // plausible-looking number. The register screen has a field rule and the
  // profile screens check before saving, but this is the one place a number
  // leaves for Supabase Auth, so the check belongs here too — every caller
  // is covered by the one guard, and an SMS is sent on the strength of it.
  if (!isPhMobile(phone)) {
    throw new Error('That is not a usable Philippine mobile number.')
  }
  const { error } = await supabase.auth.updateUser({ phone })
  if (error) throw sanitizeError(error)
}

export async function sendEmailOtp(email: string) {
  // shouldCreateUser:false — the account already exists; we only deliver a code.
  // Resend is a no-op guard against accidental double-creation.
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: false, emailRedirectTo: undefined as unknown as string, ...(await captcha()) },
  })
  if (error) throw sanitizeError(error)
}

export async function verifyEmailOtp(email: string, token: string) {
  // GoTrue files the code in a different column depending on the account,
  // and /verify only looks in the one matching `type`:
  //   - e-mail NOT yet confirmed -> a signup code in `confirmation_token`,
  //     which is type 'email'  (registration)
  //   - e-mail already confirmed -> /otp sends a MAGIC LINK instead, landing
  //     in `recovery_token`, which is type 'magiclink'  (any re-confirmation of
  //     an established account)
  // Asking for the wrong one answers 'token has expired or is invalid' on a
  // code sent seconds earlier, so try the second shape before giving up.
  const attempt = (type: 'email' | 'magiclink') =>
    supabase.auth.verifyOtp({ email, token, type })

  let { data, error } = await attempt('email')
  if (error) ({ data, error } = await attempt('magiclink'))
  if (error) throw sanitizeError(error)
  return data
}

export async function loginWithGoogle(redirectPath: string) {
  // On a device this never leaves the app. Android's Credential Manager
  // draws the account chooser natively and hands back an ID token, which
  // signInWithIdToken trades for a session in place — no browser tab, no
  // custom-scheme round trip, no reload. It replaced a Custom Tab flow that
  // was correct but still dumped the user into Chrome to finish signing in.
  //
  // Because nothing navigates, the caller is still mounted when this
  // resolves: RegisterPage keeps the consent it already collected, and
  // LoginPage can route off the returned session directly.
  if (Capacitor.isNativePlatform()) {
    const webClientId = import.meta.env.VITE_GOOGLE_WEB_CLIENT_ID
    if (!webClientId) {
      // Deliberately loud rather than quietly falling back to a browser
      // flow: a silent fallback looks exactly like "the fix did not work",
      // and costs a debugging round to tell the two apart.
      throw new Error(
        'Google sign-in is not configured for this build (VITE_GOOGLE_WEB_CLIENT_ID).',
      )
    }
    // initialize() only stores config, so there is nothing to gain from
    // doing it at boot for the many sessions that never touch Google.
    await SocialLogin.initialize({ google: { webClientId } })

    let result
    try {
      // No `scopes`: the plugin already requests openid + userinfo.email +
      // userinfo.profile, which is everything the ID token needs to carry.
      // Passing the array anyway makes it demand a patched MainActivity
      // ("You CANNOT use scopes without modifying the main activity") for
      // access-token authorization Accommo never asks for.
      ({ result } = await SocialLogin.login({ provider: 'google', options: {} }))
    } catch (e: unknown) {
      // Dismissing the account sheet rejects, and Credential Manager words
      // it several ways. Backing out is not a failure, so say nothing and
      // let the caller see "no session".
      const message = e instanceof Error ? e.message : String(e)
      if (/cancel/i.test(message)) return null
      throw e
    }

    const idToken = 'idToken' in result ? result.idToken : null
    if (!idToken) throw new Error('Google did not return an identity token.')

    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token: idToken,
    })
    if (error) throw sanitizeError(error)
    return data
  }

  // Browser development sessions have no native picker, so they keep the
  // redirect flow and return to their own HTTP(S) origin.
  const path = redirectPath.replace(/^\/+/, '')
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/${path}`,
      queryParams: {
        prompt: 'select_account',
      },
    },
  })
  if (error) throw sanitizeError(error)
  return data
}
