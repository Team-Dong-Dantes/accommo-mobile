import { defineStore } from 'pinia';
import { supabase } from '@/shared/utils/supabase';
import { uploadDocument } from '@/shared/utils/upload';
import type { RegisterForm } from '@/shared/types/database';

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
        role: role,
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

      await supabase.auth.signOut();

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

      const { error: profileError } = await supabase
        .from('landlord_profiles')
        .insert({
          user_id: userId,
          government_id_url: govIdUrl,
        });

      if (profileError) throw sanitizeError(profileError);

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

      const { error: profileError } = await supabase
        .from('landlord_profiles')
        .insert({
          user_id: userId,
          government_id_url: govIdUrl,
        });

      if (profileError) throw sanitizeError(profileError);

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

      this.cachedRole = userData?.role ?? null;

      return {
        session: authData.session,
        role: userData?.role,
      };
    },

    // --- PHONE OTP LOGIN (passwordless) ---
    // Sends a 6-digit SMS code to an existing phone number. shouldCreateUser is
    // false so this only logs in users who already registered with this phone;
    // brand-new numbers get a clear error instead of creating an orphan auth user.
    async sendPhoneOtp(phone: string) {
      const { error } = await supabase.auth.signInWithOtp({
        phone,
        options: { shouldCreateUser: false },
      });
      if (error) throw sanitizeError(error);
    },

    async verifyPhoneOtp(phone: string, token: string) {
      const { data, error } = await supabase.auth.verifyOtp({
        phone,
        token,
        type: 'sms',
      });
      if (error) throw sanitizeError(error);

      const {
        data: { session },
      } = await supabase.auth.getSession();

      const userId = session?.user?.id;
      if (!userId) {
        throw new Error('Phone verification succeeded but no session was returned.');
      }

      const { data: profile, error: profileError } = await supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

      if (profileError) throw sanitizeError(profileError);

      this.cachedRole = profile?.role ?? null;

      return { session, role: profile?.role ?? null };
    },

    clearCachedRole() {
      this.cachedRole = null;
    },

    async loginWithGoogle(redirectPath: string) {
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo: window.location.origin + redirectPath },
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

      this.cachedRole = profile?.role ?? null;

      return { session, profile };
    },
  },
});
