import { defineStore } from 'pinia';
import { Capacitor } from '@capacitor/core';
import { supabase } from '@/shared/utils/supabase';
import { uploadDocument } from '@/shared/utils/upload';
import type { RegisterForm } from '@/shared/types/forms';

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
      if (form.schoolIdFile) schoolIdUrl = await uploadDocument(form.schoolIdFile, userId, 'school_id');
      if (form.assessmentFile) assessmentUrl = await uploadDocument(form.assessmentFile, userId, 'assessment');

      const { error: profileError } = await supabase
        .from('student_profiles')
        .update({
          college: form.college,
          program: form.program,
          year_level: parseInt(form.yearLevel.charAt(0)) || 1,
          school_id_url: schoolIdUrl,
          assessment_of_fees_url: assessmentUrl,
        })
        .eq('user_id', userId);
      if (profileError) throw sanitizeError(profileError);
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

      if (form.schoolIdFile) schoolIdUrl = await uploadDocument(form.schoolIdFile, userId, 'school_id');
      if (form.assessmentFile) assessmentUrl = await uploadDocument(form.assessmentFile, userId, 'assessment');

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
          schoolIdUrl = await uploadDocument(form.schoolIdFile, userId, 'school_id');
        } catch {
          schoolIdUrl = null;
        }
      }
      if (form.assessmentFile) {
        try {
          assessmentUrl = await uploadDocument(form.assessmentFile, userId, 'assessment');
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
      await this.submitStudentVerificationDocuments(userId, [
        { docType: 'school_id', file: form.schoolIdFile ?? null, url: schoolIdUrl },
        { docType: 'assessment_of_fees', file: form.assessmentFile ?? null, url: assessmentUrl },
      ]);
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
      // After submit, the manager is signed out and “pending” until OSAS approves.
      await supabase.auth.signOut();
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

      await supabase.auth.signOut();

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

      await this.submitManagerVerificationDocuments(userId, form);
    },

    async submitManagerVerificationDocuments(userId: string, form: ManagerRegisterForm) {
      if (!form.governmentIdFile || !form.businessPermitFile) {
        throw new Error('Both verification documents are required.');
      }

      const [governmentIdUrl, businessPermitUrl] = await Promise.all([
        uploadDocument(form.governmentIdFile, userId, 'government_id'),
        uploadDocument(form.businessPermitFile, userId, 'business_permit'),
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

      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('role')
        .eq('id', authData.user.id)
        .single();

      if (userError) throw sanitizeError(userError);

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
      };
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
        .select('role')
        .eq('id', session.user.id)
        .maybeSingle();

      const role = toAppRole(profile?.role);
      this.cachedRole = role;

      return { session, profile: profile ? { ...profile, role } : null };
    },
  },
});
