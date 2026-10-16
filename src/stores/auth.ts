import { defineStore } from 'pinia';
import { supabase } from '@/utils/supabase';
import { captcha } from '@/utils/captcha';
import { uploadSecureDocument } from '@/utils/upload';
import type { StudentRegisterForm } from '@/types/forms';
import * as flows from '@/stores/authFlows';
import { documentText, ensureUserRow, formatProfileData, sanitizeError, submitManagerVerificationDocuments, submitStudentVerificationDocuments, toAppRole, toDbRole } from '@/stores/authRows';

export interface ManagerRegisterForm {
  email: string;
  password?: string;
  fullName: string;
  sex: string;
  /** ISO yyyy-mm-dd. OSAS checks it against the birth date on the submitted ID. */
  dateOfBirth: string;
  phone: string;
  governmentIdFile: File | null;
  /** ISO yyyy-mm-dd, read off the document by the person uploading it. */
  governmentIdExpiresAt?: string;
  businessPermitFile: File | null;
  businessPermitExpiresAt?: string;
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    cachedRole: null as string | null,
    /**
     * `users.status` of the signed-in account, as last read — by login() and
     * by the router on every navigation, so an OSAS decision shows up on the
     * next screen change. Screens read `isVerifiedLandlord` rather than this.
     */
    accountStatus: null as string | null,
  }),
  getters: {
    /**
     * A landlord/landlady may use the app before OSAS verifies them, but may
     * not add accommodations, rooms or facilities until then — the database
     * refuses those inserts (20260924120000), and the UI says so up front
     * instead of letting the form fail at the end.
     */
    isVerifiedLandlord: (state) => state.accountStatus === 'verified',
  },
  actions: {

 

    // --- STUDENT REGISTRATION (re-architected, account-first) ---
    // Phase 1: create the auth account + users row + empty student_profiles ONLY
    // (no academic/docs yet). Called when the student leaves the Account step so
    // an e-mail OTP can be sent, then Academy/Docs attach later on the SAME user.
    async createStudentAccount(
      form: StudentRegisterForm,
    ) {
      const profileData = formatProfileData(form, 'student');
      const response = await supabase.auth.signUp({
        email: form.email,
        password: form.password ?? '',
        options: { data: profileData, ...(await captcha()) },
      });
      if (response.error) throw sanitizeError(response.error);
      const userId = response.data.user?.id;
      if (!userId) throw new Error('Failed to retrieve user ID after registration.');

      await ensureUserRow(userId, form.email, profileData, 'pending');

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
      form: StudentRegisterForm,
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
          document_text: documentText(form),
        })
        .eq('user_id', userId);
      if (profileError) throw sanitizeError(profileError);
      // The other two paths (register, completeGoogleProfile) file these too;
      // this one, the usual one, left OSAS's document review empty.
      await submitStudentVerificationDocuments(userId, [
        { docType: 'school_id', file: form.schoolIdFile ?? null, url: schoolIdUrl },
        { docType: 'assessment_of_fees', file: form.assessmentFile ?? null, url: assessmentUrl },
      ]);
      await this.markRegistered();
      this.cachedRole = 'student';
    },

    async register(
      form: StudentRegisterForm,
    ) {
      const profileData = formatProfileData(form, 'student');

      const response = await supabase.auth.signUp({
        email: form.email,
        password: form.password ?? '',
        options: { data: profileData, ...(await captcha()) },
      });

      if (response.error) throw sanitizeError(response.error);

      const userId = response.data.user?.id;

      if (!userId) throw new Error('Failed to retrieve user ID after registration.');

      await ensureUserRow(userId, form.email, profileData, 'pending');

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
          document_text: documentText(form),
        });

      if (profileError) throw sanitizeError(profileError);

      // Keep the session active (email autoconfirm is on) so the caller can proceed
      // to the phone-verification step without having to sign in again.
      await submitStudentVerificationDocuments(userId, [
        { docType: 'school_id', file: form.schoolIdFile ?? null, url: schoolIdUrl },
        { docType: 'assessment_of_fees', file: form.assessmentFile ?? null, url: assessmentUrl },
      ]);
      await this.markRegistered();
      this.cachedRole = 'student';

      return response.data;
    },

    async completeGoogleProfile(
      userId: string,
      form: StudentRegisterForm,
    ) {
      const profileData = formatProfileData(form, 'student');

      await ensureUserRow(userId, form.email, profileData, 'pending');

      const { error: userError } = await supabase
        .from('users')
        .update({ ...profileData })
        .eq('id', userId);

      if (userError) throw sanitizeError(userError);

      // A failed upload stops here, as on the password path. Swallowing it let a
      // Google sign-up finish registering with no documents for OSAS to check.
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
          document_text: documentText(form),
        });

      if (profileError) throw sanitizeError(profileError);

      // Google already vouched for this address, so there is no code to type.
      try { await this.confirmEmailOwnership(); } catch { /* non-fatal */ }

      await submitStudentVerificationDocuments(userId, [
        { docType: 'school_id', file: form.schoolIdFile ?? null, url: schoolIdUrl },
        { docType: 'assessment_of_fees', file: form.assessmentFile ?? null, url: assessmentUrl },
      ]);
      await this.markRegistered();
      this.cachedRole = 'student';
    },

    createManagerAccount(form: ManagerRegisterForm) {
      return flows.createManagerAccount(form);
    },

    async finalizeManagerAccount(userId: string, form: ManagerRegisterForm) {
      await submitManagerVerificationDocuments(userId, form);
      await this.markRegistered();
      // Stays signed in: an unverified landlord/landlady uses the app straight
      // away, and only adding inventory waits for OSAS.
      this.accountStatus = 'pending';
    },

    // --- MANAGER REGISTRATION (legacy one-shot) ---

    async registerManager(form: ManagerRegisterForm) {
      const profileData = formatProfileData(form, 'manager');

      const response = await supabase.auth.signUp({
        email: form.email,
        password: form.password ?? '',
        options: { data: profileData, ...(await captcha()) },
      });

      if (response.error) throw sanitizeError(response.error);

      const userId = response.data.user?.id;

      if (!userId) throw new Error('Failed to retrieve user ID after registration.');

      // Upload both documents in parallel (they're independent) while we ensure
      // the user row — this significantly cuts registration latency vs doing the
      // uploads one-after-another on a mobile connection.
      await ensureUserRow(userId, form.email, profileData, 'pending');
      await submitManagerVerificationDocuments(userId, form);
      await this.markRegistered();
      this.accountStatus = 'pending';

      return response.data;
    },

    async completeGoogleManagerProfile(userId: string, form: ManagerRegisterForm) {
      const profileData = formatProfileData(form, 'manager');

      await ensureUserRow(userId, form.email, profileData, 'pending');

      const { error: userError } = await supabase
        .from('users')
        .update({ ...profileData })
        .eq('id', userId);

      if (userError) throw sanitizeError(userError);

      // Google already vouched for this address, so there is no code to type.
      try { await this.confirmEmailOwnership(); } catch { /* non-fatal */ }

      await submitManagerVerificationDocuments(userId, form);
      await this.markRegistered();
      this.accountStatus = 'pending';
    },


    // --- SHARED LOGIN ---
    async login(email: string, password: string, captchaHost?: HTMLElement | null) {
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
        options: await captcha(captchaHost),
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

      // A landlord/landlady no longer waits outside while OSAS reviews them: they
      // sign in, upload requirements, raise tickets and message, and only adding
      // accommodations and rooms waits for verification (enforced by the
      // database; see isVerifiedLandlord).
      this.accountStatus = typeof userData.status === 'string' ? userData.status : null;

      let role = toAppRole(userData?.role);

      // Some accounts were created by the auth trigger without a role. Fall back
      // to the role captured in user_metadata at signup and backfill the users
      // row so future logins resolve it directly.
      if (!role) {
        const metaRole = (authData.user?.user_metadata as Record<string, unknown> | undefined)?.role;
        if (typeof metaRole === 'string' && metaRole) {
          role = toAppRole(metaRole);
          if (role) {
            await supabase.from('users').update({ role: toDbRole(role) }).eq('id', authData.user.id);
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

    markRegistered() {
      return flows.markRegistered();
    },

    /**
     * Sets the role chosen on the role picker. An OAuth signup is defaulted to
     * 'student' by the auth trigger because Google sends no role, so a landlord/landlady
     * has to be able to correct it — the database allows this only while
     * registered_at is null.
     */
    async chooseRole(role: 'student' | 'manager') {
      const { data } = await supabase.auth.getUser();
      const userId = data?.user?.id;
      if (!userId) return;
      const { error } = await supabase
        .from('users')
        .update({ role: toDbRole(role) })
        .eq('id', userId);
      if (error) throw sanitizeError(error);
      this.cachedRole = role;
    },

    /**
     * Re-submits a landlord/landlady application OSAS sent back. The account already exists
     * and is registered, so this only replaces the requirements and returns the
     * account to 'pending' until OSAS decides again. They stay signed in.
     */
    async resubmitManagerApplication(userId: string, form: ManagerRegisterForm) {
      await submitManagerVerificationDocuments(userId, form);
      const { error } = await supabase.rpc('resubmit_verification');
      if (error) throw sanitizeError(error);
      this.accountStatus = 'pending';
    },

    fetchDecisionReason(userId: string): Promise<string> {
      return flows.fetchDecisionReason(userId);
    },

    confirmEmailOwnership() {
      return flows.confirmEmailOwnership();
    },

    sendPhoneVerification(phone: string) {
      return flows.sendPhoneVerification(phone);
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

    sendEmailOtp(email: string) {
      return flows.sendEmailOtp(email);
    },

    verifyEmailOtp(email: string, token: string) {
      return flows.verifyEmailOtp(email, token);
    },

    clearCachedRole() {
      this.cachedRole = null;
    },

    loginWithGoogle(redirectPath: string) {
      return flows.loginWithGoogle(redirectPath);
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
      if (typeof profile?.status === 'string') this.accountStatus = profile.status;

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
