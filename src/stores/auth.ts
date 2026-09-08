import { defineStore } from 'pinia';
import { Capacitor } from '@capacitor/core';
import { supabase } from '@/utils/supabase';
import { uploadSecureDocument } from '@/utils/upload';
import type { RegisterForm } from '@/types/forms';

// The database role enum uses 'accommodation_manager' where the app's UI and
// routing use 'manager' (the leader's terminology change). Map between them
// at the DB boundary so the rest of the app keeps using 'manager'.
const APP_ROLE_TO_DB: Record<string, string> = { manager: 'accommodation_manager' };
const DB_ROLE_TO_APP: Record<string, string> = { accommodation_manager: 'manager' };

function toDbRole(role: string): string {
  return APP_ROLE_TO_DB[role] ?? role;
}

function toAppRole(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const r = raw.toLowerCase();
  return DB_ROLE_TO_APP[r] ?? r;
}

function sanitizeError(error: unknown): Error {
  // Supabase auth/PostgREST errors are often plain objects (not Error
  // instances) that carry a real `.message`/`.code`/`.status`. Reading those
  // prevents `String(object)` → "[object Object]" from leaking to the UI.
  let raw: string;
  if (error instanceof Error) {
    raw = error.message;
  } else if (error && typeof error === 'object' && 'message' in error) {
    raw = String((error as { message: unknown }).message || 'Unknown error');
  } else {
    raw = String(error ?? 'Unknown error');
  }
  let friendly = 'An unexpected error occurred. Please try again.';
  const m = (error instanceof Error ? error.message : '') || raw;
  if (
    m.includes('23505') ||
    m.includes('duplicate key') ||
    m.includes('student_profiles_student_id_key')
  ) {
    friendly = 'This Student ID is already registered.';
  } else if (m.includes('already registered') || m.includes('email_exists') || m.includes('User already')) {
    friendly = 'This email is already registered. Try signing in instead.';
  } else if (m.includes('PGRST116') || m.includes('0 rows')) {
    friendly = 'Registration failed due to a database conflict. Please try again.';
  } else if (m.includes('Invalid login credentials')) {
    friendly = 'Invalid email or password.';
  } else if (m.includes('Email not confirmed')) {
    friendly = 'Please confirm your email address before signing in.';
  } else if (m.includes('rate limit')) {
    friendly = 'Too many attempts. Please try again later.';
  }
  // Surface the raw backend message so failures are diagnosable on-device
  // instead of being collapsed into a generic string.
  return new Error(`${friendly} (${raw})`);
}

export interface ManagerRegisterForm {
  email: string;
  password?: string;
  fullName: string;
  sex: string;
  phone: string;
  governmentIdFile: File | null;
  businessPermitFile: File | null;
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    cachedRole: null as string | null,
  }),
  actions: {
    formatProfileData(form: RegisterForm | ManagerRegisterForm, role: 'student' | 'manager') {
      const nameParts = form.fullName.trim().split(' ').filter(Boolean);
      let initials = 'UN';

      if (nameParts.length > 1) {
        const firstLetter = nameParts[0]?.[0] || '';
        const lastLetter = nameParts[nameParts.length - 1]?.[0] || '';
        initials = (firstLetter + lastLetter).toUpperCase();
      } else if (nameParts.length === 1) {
        const onlyName = nameParts[0] || '';
        initials = onlyName.substring(0, 2).toUpperCase();
      }

      const formattedSex = form.sex === 'Male' ? 'M' : form.sex === 'Female' ? 'F' : 'U';

      return {
        email: form.email,
        full_name: form.fullName,
        initials,
        sex: formattedSex,
        role: toDbRole(role) as any,
        phone: form.phone,
      };
    },

    // Ensures the public.users row exists for the given auth user.
    // The auth.users -> public.users sync trigger normally handles this, but
    // this upsert is a safety net (idempotent via onConflict). status is left
    // out so the trigger's email-verification logic isn't clobbered.
    // Required NOT NULL columns: id, email, phone, role, full_name, initials.
    async ensureUserRow(
      userId: string,
      email: string,
      profileData: { role: 'student' | 'manager'; full_name: string; initials: string; phone?: string },
      status?: 'pending',
    ) {
      const { error } = await supabase
        .from('users')
        .upsert(
          {
            id: userId,
            email,
            phone: (profileData.phone as string) ?? '+639000000000',
            role: toDbRole(profileData.role) as any,
            full_name: profileData.full_name,
            initials: profileData.initials,
            ...(status ? { status } : {}),
          },
          { onConflict: 'id' },
        );

      if (error) throw sanitizeError(error);
    },

    async submitStudentVerificationDocuments(
      userId: string,
      documents: Array<{ docType: string; file: File | null; url: string | null }>,
    ) {
      const rows = documents
        .filter((document) => document.file && document.url)
        .map((document) => ({
          user_id: userId,
          doc_type: document.docType,
          file_url: document.url!,
          filename: document.file!.name,
          status: 'pending' as const,
        }));

      if (!rows.length) return;

      const { error } = await supabase.from('verification_documents').insert(rows);
      if (error) throw sanitizeError(error);

      const { error: userError } = await supabase
        .from('users')
        .update({ status: 'pending' })
        .eq('id', userId);
      if (userError) throw sanitizeError(userError);
    },

    // --- STUDENT REGISTRATION (re-architected, account-first) ---
    // Phase 1: create the auth account + users row + empty student_profiles ONLY
    // (no academic/docs yet). Called when the student leaves the Account step so
    // an e-mail OTP can be sent, then Academy/Docs attach later on the SAME user.
    async createStudentAccount(
      form: RegisterForm & { schoolIdFile?: File | null; assessmentFile?: File | null },
    ) {
      const profileData = this.formatProfileData(form, 'student');
      const response = await supabase.auth.signUp({
        email: form.email,
        password: form.password ?? '',
        options: { data: profileData },
      });
      if (response.error) throw sanitizeError(response.error);
      const userId = response.data.user?.id;
      if (!userId) throw new Error('Failed to retrieve user ID after registration.');

      await this.ensureUserRow(userId, form.email, profileData, 'pending');

      const { error: profileError } = await supabase.from('student_profiles').upsert(
        {
          user_id: userId,
          student_id: form.studentId || null,
          college: form.college,
          program: form.program,
          year_level: parseInt(form.yearLevel.charAt(0)) || 1,
        },
        { onConflict: 'user_id' },
      );
      if (profileError) throw sanitizeError(profileError);

      this.cachedRole = 'student';
      return userId;
    },

    // Phase 2: given an already-created student user, upload school docs and update
    // the academic fields onto that existing profile (never re-signUp).
    async finalizeStudentAccount(
      userId: string,
      form: RegisterForm & { schoolIdFile?: File | null; assessmentFile?: File | null },
    ) {
      let schoolIdUrl: string | null = null;
      let assessmentUrl: string | null = null;
      if (form.schoolIdFile) schoolIdUrl = await uploadSecureDocument(form.schoolIdFile);
      if (form.assessmentFile) assessmentUrl = await uploadSecureDocument(form.assessmentFile);

      const { error: profileError } = await supabase
        .from('student_profiles')
        .update({
          // createStudentAccount runs at the Account step, before the student
          // number is even asked for, so it inserted null. Without this line the
          // number typed on the Verification step was thrown away and the student
          // ended up with no QR identity at all.
          student_id: form.studentId || null,
          college: form.college,
          program: form.program,
          year_level: parseInt(form.yearLevel.charAt(0)) || 1,
          school_id_url: schoolIdUrl,
          assessment_of_fees_url: assessmentUrl,
        })
        .eq('user_id', userId);
      if (profileError) throw sanitizeError(profileError);
      await this.markRegistered(userId);
      this.cachedRole = 'student';
    },

    async register(
      form: RegisterForm & { schoolIdFile?: File | null; assessmentFile?: File | null },
    ) {
      const profileData = this.formatProfileData(form, 'student');

      const response = await supabase.auth.signUp({
        email: form.email,
        password: form.password ?? '',
        options: { data: profileData },
      });

      if (response.error) throw sanitizeError(response.error);

      const userId = response.data.user?.id;

      if (!userId) throw new Error('Failed to retrieve user ID after registration.');

      await this.ensureUserRow(userId, form.email, profileData, 'pending');

      let schoolIdUrl: string | null = null;
      let assessmentUrl: string | null = null;

      if (form.schoolIdFile) schoolIdUrl = await uploadSecureDocument(form.schoolIdFile);
      if (form.assessmentFile) assessmentUrl = await uploadSecureDocument(form.assessmentFile);

      const { error: profileError } = await supabase
        .from('student_profiles')
        .insert({
          user_id: userId,
          student_id: form.studentId || null,
          college: form.college,
          program: form.program,
          year_level: parseInt(form.yearLevel.charAt(0)) || 1,
          school_id_url: schoolIdUrl,
          assessment_of_fees_url: assessmentUrl,
        });

      if (profileError) throw sanitizeError(profileError);

      // Keep the session active (email autoconfirm is on) so the caller can proceed
      // to the phone-verification step without having to sign in again.
      await this.submitStudentVerificationDocuments(userId, [
        { docType: 'school_id', file: form.schoolIdFile ?? null, url: schoolIdUrl },
        { docType: 'assessment_of_fees', file: form.assessmentFile ?? null, url: assessmentUrl },
      ]);
      await this.markRegistered(userId);
      this.cachedRole = 'student';

      return response.data;
    },

    async completeGoogleProfile(
      userId: string,
      form: RegisterForm & { schoolIdFile?: File | null; assessmentFile?: File | null },
    ) {
      const profileData = this.formatProfileData(form, 'student');

      await this.ensureUserRow(userId, form.email, profileData, 'pending');

      const { error: userError } = await supabase
        .from('users')
        .update({ ...profileData })
        .eq('id', userId);

      if (userError) throw sanitizeError(userError);

      let schoolIdUrl: string | null = null;
      let assessmentUrl: string | null = null;

      if (form.schoolIdFile) {
        try {
          schoolIdUrl = await uploadSecureDocument(form.schoolIdFile);
        } catch {
          schoolIdUrl = null;
        }
      }
      if (form.assessmentFile) {
        try {
          assessmentUrl = await uploadSecureDocument(form.assessmentFile);
        } catch {
          assessmentUrl = null;
        }
      }

      const { error: profileError } = await supabase
        .from('student_profiles')
        .insert({
          user_id: userId,
          student_id: form.studentId || null,
          college: form.college,
          program: form.program,
          year_level: parseInt(form.yearLevel.charAt(0)) || 1,
          school_id_url: schoolIdUrl,
          assessment_of_fees_url: assessmentUrl,
        });

      if (profileError) throw sanitizeError(profileError);

      // Google already vouched for this address, so there is no code to type.
      try { await this.confirmEmailOwnership(); } catch { /* non-fatal */ }

      await this.submitStudentVerificationDocuments(userId, [
        { docType: 'school_id', file: form.schoolIdFile ?? null, url: schoolIdUrl },
        { docType: 'assessment_of_fees', file: form.assessmentFile ?? null, url: assessmentUrl },
      ]);
      await this.markRegistered(userId);
      this.cachedRole = 'student';
    },

    // --- MANAGER REGISTRATION (account-first) ---
    async createManagerAccount(form: ManagerRegisterForm) {
      const profileData = this.formatProfileData(form, 'manager');
      const response = await supabase.auth.signUp({
        email: form.email,
        password: form.password ?? '',
        options: { data: profileData },
      });
      if (response.error) throw sanitizeError(response.error);
      const userId = response.data.user?.id;
      if (!userId) throw new Error('Failed to retrieve user ID after registration.');
      await this.ensureUserRow(userId, form.email, profileData, 'pending');
      return userId;
    },

    async finalizeManagerAccount(userId: string, form: ManagerRegisterForm) {
      await this.submitManagerVerificationDocuments(userId, form);
      await this.markRegistered(userId);
      // A manager holds no session until OSAS approves. This sign-out used to be
      // theatre because login ignored status; login now enforces it, so the door
      // is really shut.
      await supabase.auth.signOut();
      this.cachedRole = null;
    },

    // --- MANAGER REGISTRATION (legacy one-shot) ---

    async registerManager(form: ManagerRegisterForm) {
      const profileData = this.formatProfileData(form, 'manager');

      const response = await supabase.auth.signUp({
        email: form.email,
        password: form.password ?? '',
        options: { data: profileData },
      });

      if (response.error) throw sanitizeError(response.error);

      const userId = response.data.user?.id;

      if (!userId) throw new Error('Failed to retrieve user ID after registration.');

      // Upload both documents in parallel (they're independent) while we ensure
      // the user row — this significantly cuts registration latency vs doing the
      // uploads one-after-another on a mobile connection.
      await this.ensureUserRow(userId, form.email, profileData, 'pending');
      await this.submitManagerVerificationDocuments(userId, form);
      await this.markRegistered(userId);

      await supabase.auth.signOut();
      this.cachedRole = null;

      return response.data;
    },

    async completeGoogleManagerProfile(userId: string, form: ManagerRegisterForm) {
      const profileData = this.formatProfileData(form, 'manager');

      await this.ensureUserRow(userId, form.email, profileData, 'pending');

      const { error: userError } = await supabase
        .from('users')
        .update({ ...profileData })
        .eq('id', userId);

      if (userError) throw sanitizeError(userError);

      // Google already vouched for this address, so there is no code to type.
      try { await this.confirmEmailOwnership(); } catch { /* non-fatal */ }

      await this.submitManagerVerificationDocuments(userId, form);
      await this.markRegistered(userId);
      await supabase.auth.signOut();
      this.cachedRole = null;
    },

    async submitManagerVerificationDocuments(userId: string, form: ManagerRegisterForm) {
      if (!form.governmentIdFile || !form.businessPermitFile) {
        throw new Error('Both verification documents are required.');
      }

      // Every student gets a student_profiles row at registration; managers were
      // getting no profile row at all, so a manager had no record to hang
      // responsiveness stats or admin review data on. Created here because all
      // three manager registration paths (password, resumed, Google) submit
      // documents through this method. Upsert: resubmitting must not fail.
      const { error: profileError } = await supabase
        .from('accommodation_manager_profiles')
        .upsert({ user_id: userId }, { onConflict: 'user_id' });
      if (profileError) throw sanitizeError(profileError);

      const [governmentIdUrl, businessPermitUrl] = await Promise.all([
        uploadSecureDocument(form.governmentIdFile),
        uploadSecureDocument(form.businessPermitFile),
      ]);

      const { error } = await supabase.from('verification_documents').insert([
        {
          user_id: userId,
          doc_type: 'government_id',
          file_url: governmentIdUrl,
          filename: form.governmentIdFile.name,
          status: 'pending',
        },
        {
          user_id: userId,
          doc_type: 'business_permit',
          file_url: businessPermitUrl,
          filename: form.businessPermitFile.name,
          status: 'pending',
        },
      ]);

      if (error) throw sanitizeError(error);
    },

    // --- SHARED LOGIN ---
    async login(email: string, password: string) {
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (authError) throw sanitizeError(authError);
      if (!authData?.user) throw new Error('Login failed: No user returned.');

      // maybeSingle, not single: a missing users row is its own situation, and
      // single() surfaced it as PGRST116 -> "Registration failed due to a
      // database conflict", which is nonsense on a sign-in screen.
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('role, status, email_verified_at')
        .eq('id', authData.user.id)
        .maybeSingle();

      if (userError) throw sanitizeError(userError);
      if (!userData) {
        await supabase.auth.signOut();
        throw new Error('This account is not set up yet. Please finish registration.');
      }

      // A suspended account must not hold a session. Nothing downstream checked
      // status, so suspending someone previously did nothing at all: they signed
      // straight back in and kept working.
      if (userData.status === 'suspended') {
        await supabase.auth.signOut();
        throw new Error('This account has been suspended. Contact OSAS if you think this is a mistake.');
      }

      // A manager waits outside only while OSAS still owes them a decision. Once
      // OSAS has replied and wants changes ('rejected'/'reviewing'), they must be
      // able to sign in and fix the application — otherwise a rejection is a dead
      // end and the documents can never be corrected.
      if (toAppRole(userData.role) === 'manager' && userData.status === 'pending') {
        await supabase.auth.signOut();
        throw new Error('Your application is still being reviewed by OSAS. You can sign in once it is approved.');
      }

      let role = toAppRole(userData?.role);

      // Some accounts were created by the auth trigger without a role. Fall back
      // to the role captured in user_metadata at signup and backfill the users
      // row so future logins resolve it directly.
      if (!role) {
        const metaRole = (authData.user?.user_metadata as Record<string, unknown> | undefined)?.role;
        if (typeof metaRole === 'string' && metaRole) {
          role = toAppRole(metaRole);
          if (role) {
            await supabase.from('users').update({ role: toDbRole(role) } as any).eq('id', authData.user.id);
          }
        }
      }

      this.cachedRole = role;

      return {
        session: authData.session,
        role,
        status: userData.status as string,
        // Auto-confirm means Supabase marks every address confirmed at signup, so
        // this is the only evidence the applicant actually reads it: stamped by
        // confirm_email_ownership() once they enter a mailed code. The session is
        // deliberately kept so they can finish verifying from the login screen.
        emailVerified: userData.email_verified_at !== null,
      };
    },

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
    async markRegistered(userId: string) {
      const { error } = await supabase
        .from('users')
        .update({ registered_at: new Date().toISOString() })
        .eq('id', userId);
      if (error) throw sanitizeError(error);
    },

    /**
     * Sets the role chosen on the role picker. An OAuth signup is defaulted to
     * 'student' by the auth trigger because Google sends no role, so a manager
     * has to be able to correct it — the database allows this only while
     * registered_at is null.
     */
    async chooseRole(role: 'student' | 'manager') {
      const { data } = await supabase.auth.getUser();
      const userId = data?.user?.id;
      if (!userId) return;
      const { error } = await supabase
        .from('users')
        .update({ role: toDbRole(role) as any })
        .eq('id', userId);
      if (error) throw sanitizeError(error);
      this.cachedRole = role;
    },

    /**
     * Re-submits a manager application OSAS sent back. The account already exists
     * and is registered, so this only replaces the documents and returns the
     * account to 'pending' — which re-closes the door until OSAS decides again.
     */
    async resubmitManagerApplication(userId: string, form: ManagerRegisterForm) {
      await this.submitManagerVerificationDocuments(userId, form);
      const { error } = await supabase.rpc('resubmit_verification');
      if (error) throw sanitizeError(error);
      await supabase.auth.signOut();
      this.cachedRole = null;
    },

    /** The note OSAS left with their decision, for the resubmission screen. */
    async fetchDecisionReason(userId: string): Promise<string> {
      const { data } = await supabase
        .from('verification_requests')
        .select('decision_notes, rejection_reasons')
        .eq('entity_type', 'user')
        .eq('entity_id', userId)
        .order('reviewed_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      return data?.decision_notes || (data?.rejection_reasons ?? []).join(', ') || '';
    },

    async confirmEmailOwnership() {
      const { error } = await supabase.rpc('confirm_email_ownership');
      if (error) throw sanitizeError(error);
    },

    // --- PHONE VERIFICATION (proof of ownership, not a login) ---
    // The user must already be signed in (e.g. immediately after registering, or
    // from their Profile). updateUser triggers an SMS with a code; verifying it
    // with the `phone_change` type confirms the number WITHOUT creating a new
    // session, so this is purely a verification step, not passwordless auth.
    async sendPhoneVerification(phone: string) {
      const { error } = await supabase.auth.updateUser({ phone });
      if (error) throw sanitizeError(error);
    },

    async verifyPhoneVerification(phone: string, token: string) {
      const { data, error } = await supabase.auth.verifyOtp({
        phone,
        token,
        type: 'phone_change',
      });
      if (error) throw sanitizeError(error);
      this.cachedRole = data.user?.role ?? this.cachedRole;
      return data;
    },

    // --- EMAIL OTP (secondary e-mail verification for NON-OAuth sign-ups) ---
    // Users who registered with e-mail + password (instead of Google) confirm
    // they own the e-mail inbox via a one-time code delivered by Supabase Auth
    // through Brevo/SMTP. OAuth users skip this (their e-mail is already
    // verified by the provider).

    async sendEmailOtp(email: string) {
      // shouldCreateUser:false — the account already exists; we only deliver a code.
      // Resend is a no-op guard against accidental double-creation.
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: { shouldCreateUser: false, emailRedirectTo: undefined as unknown as string },
      });
      if (error) throw sanitizeError(error);
    },

    async verifyEmailOtp(email: string, token: string) {
      const { data, error } = await supabase.auth.verifyOtp({ email, token, type: 'email' });
      if (error) throw sanitizeError(error);
      return data;
    },

    clearCachedRole() {
      this.cachedRole = null;
    },

    async loginWithGoogle(redirectPath: string) {
      // Only installed Capacitor apps can receive the custom scheme. Browser
      // development sessions, including localhost, must return to their HTTP(S)
      // origin because Chrome has no handler for com.accommo.app://.
      let redirectTo: string
      if (Capacitor.isNativePlatform()) {
        redirectTo = 'com.accommo.app://auth/callback'
      } else {
        const base = window.location.origin
        const path = redirectPath.replace(/^\/+/, '')
        redirectTo = `${base}/${path}`
      }
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo,
          queryParams: {
            prompt: 'select_account',
          },
        },
      });
      if (error) throw sanitizeError(error);
      return data;
    },

    async getSessionProfile() {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!session) return { session: null, profile: null };

      const { data: profile } = await supabase
        .from('users')
        .select('role, status, registered_at')
        .eq('id', session.user.id)
        .maybeSingle();

      const role = toAppRole(profile?.role);
      this.cachedRole = role;

      return {
        session,
        profile: profile ? { ...profile, role } : null,
        // Null means the row exists but onboarding was never finished.
        registered: profile ? profile.registered_at !== null : false,
        status: (profile?.status as string | undefined) ?? null,
      };
    },
  },
});
