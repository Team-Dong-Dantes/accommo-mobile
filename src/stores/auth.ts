import { defineStore } from 'pinia';
import { supabase } from '@/shared/utils/supabase';
import { uploadDocument } from '@/shared/utils/upload';
import type { RegisterForm } from '@/shared/types/database';

// The database role enum uses 'accommodation_manager' where the app's UI and
// routing use 'landlord' (the leader's terminology change). Map between them
// at the DB boundary so the rest of the app keeps using 'landlord'.
const APP_ROLE_TO_DB: Record<string, string> = { landlord: 'accommodation_manager' };
const DB_ROLE_TO_APP: Record<string, string> = { accommodation_manager: 'landlord' };

function toDbRole(role: string): string {
  return APP_ROLE_TO_DB[role] ?? role;
}

function toAppRole(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const r = raw.toLowerCase();
  return DB_ROLE_TO_APP[r] ?? r;
}

function sanitizeError(error: unknown): Error {
  const raw = error instanceof Error ? error.message : String(error);
  let friendly = 'An unexpected error occurred. Please try again.';
  if (error instanceof Error) {
    const m = error.message;
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
  }
  // Surface the raw backend message so failures are diagnosable on-device
  // instead of being collapsed into a generic string.
  return new Error(`${friendly} (${raw})`);
}

export interface LandlordRegisterForm {
  email: string;
  password?: string;
  fullName: string;
  sex: string;
  phone: string;
  businessName: string;
  governmentIdFile: File | null;
  businessPermitFile: File | null;
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    cachedRole: null as string | null,
  }),
  actions: {
    formatProfileData(form: RegisterForm | LandlordRegisterForm, role: 'student' | 'landlord') {
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
      profileData: { role: 'student' | 'landlord'; full_name: string; initials: string; phone?: string },
    ) {
      const { error } = await supabase
        .from('users')
        .upsert(
          {
            id: userId,
            email,
            phone: (profileData.phone as string) ?? '+639000000000',
            role: profileData.role,
            full_name: profileData.full_name,
            initials: profileData.initials,
          },
          { onConflict: 'id' },
        );

      if (error) throw sanitizeError(error);
    },

    // --- STUDENT REGISTRATION ---
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

      await this.ensureUserRow(userId, form.email, profileData);

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

      // Keep the session active (email autoconfirm is on) so the caller can proceed
      // to the phone-verification step without having to sign in again.
      this.cachedRole = 'student';

      return response.data;
    },

    async completeGoogleProfile(
      userId: string,
      form: RegisterForm & { schoolIdFile?: File | null; assessmentFile?: File | null },
    ) {
      const profileData = this.formatProfileData(form, 'student');

      await this.ensureUserRow(userId, form.email, profileData);

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
      this.cachedRole = 'student';
    },

    // --- LANDLORD REGISTRATION ---
    async registerLandlord(form: LandlordRegisterForm) {
      const profileData = this.formatProfileData(form, 'landlord');

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
      const [govIdUrl, permitUrl] = await Promise.all([
        form.governmentIdFile
          ? uploadDocument(form.governmentIdFile, userId, 'government_id').catch(() => null)
          : Promise.resolve(null),
        form.businessPermitFile
          ? uploadDocument(form.businessPermitFile, userId, 'business_permit').catch(() => null)
          : Promise.resolve(null),
      ]);

      await this.ensureUserRow(userId, form.email, profileData);

      // The live schema has no landlord_profiles table (only admin_profiles);
      // store the government ID as a verification document, like the permit.
      if (govIdUrl) {
        const { error: govIdError } = await supabase.from('verification_documents').insert({
          user_id: userId,
          doc_type: 'government_id',
          file_url: govIdUrl,
          filename: form.governmentIdFile?.name ?? null,
          status: 'pending',
        });
        if (govIdError) throw sanitizeError(govIdError);
      }

      if (permitUrl) {
        await supabase.from('verification_documents').insert({
          user_id: userId,
          doc_type: 'business_permit',
          file_url: permitUrl,
          filename: form.businessPermitFile?.name ?? null,
          status: 'pending',
        });
      }

      await supabase.auth.signOut();

      return response.data;
    },

    async completeGoogleLandlordProfile(userId: string, form: LandlordRegisterForm) {
      const profileData = this.formatProfileData(form, 'landlord');

      await this.ensureUserRow(userId, form.email, profileData);

      const { error: userError } = await supabase
        .from('users')
        .update({ ...profileData })
        .eq('id', userId);

      if (userError) throw sanitizeError(userError);

      // Upload both documents in parallel (independent of each other).
      const [govIdUrl, permitUrl] = await Promise.all([
        form.governmentIdFile
          ? uploadDocument(form.governmentIdFile, userId, 'government_id').catch(() => null)
          : Promise.resolve(null),
        form.businessPermitFile
          ? uploadDocument(form.businessPermitFile, userId, 'business_permit').catch(() => null)
          : Promise.resolve(null),
      ]);

      // The live schema has no landlord_profiles table (only admin_profiles);
      // store the government ID as a verification document, like the permit.
      if (govIdUrl) {
        const { error: govIdError } = await supabase.from('verification_documents').insert({
          user_id: userId,
          doc_type: 'government_id',
          file_url: govIdUrl,
          filename: form.governmentIdFile?.name ?? null,
          status: 'pending',
        });
        if (govIdError) throw sanitizeError(govIdError);
      }

      if (permitUrl) {
        await supabase.from('verification_documents').insert({
          user_id: userId,
          doc_type: 'business_permit',
          file_url: permitUrl,
          filename: form.businessPermitFile?.name ?? null,
          status: 'pending',
        });
      }
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

    clearCachedRole() {
      this.cachedRole = null;
    },

    async loginWithGoogle(redirectPath: string) {
      // The app uses hash-based routing (/#/login), so the OAuth callback must
      // include the hash; otherwise the redirect lands on the wrong route and
      // the returned session is never picked up.
      const redirectTo = window.location.origin + '/#/' + redirectPath.replace(/^\/+/, '');
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo },
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
