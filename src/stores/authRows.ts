// The registration writes the auth store makes on its way to an account: the
// users row, its profile fields, and the documents OSAS reviews. None of them
// touch the store's state, so they live here and the store calls them.
import { supabase } from '@/utils/supabase'
import { uploadSecureDocument } from '@/utils/upload'
import { initialsOf } from '@/utils/format'
import type { RegisterForm, StudentRegisterForm } from '@/types/forms'
import type { DocReadings } from '@/utils/docReading'
import type { Database, Json } from '@/types/database.gen'
import type { ManagerRegisterForm } from '@/stores/auth'

// The database role enum says 'landlord'; this app's routes and folders say
// 'manager' (`/manager/*`, `pages/manager/`). That split is deliberate and
// documented in the workspace CLAUDE.md — the role was renamed to Landlord/Landlady, but the
// internal paths were left alone rather than churn 150+ references for
// something no user reads. Map between the two at the DB boundary so routing
// keeps working off 'manager' while everything stored stays 'landlord'.

const APP_ROLE_TO_DB: Record<string, string> = { manager: 'landlord' }
const DB_ROLE_TO_APP: Record<string, string> = { landlord: 'manager' }

type DbRole = Database['public']['Enums']['user_role'];

/** Unknown names pass through unchanged; the enum column rejects them. */
export function toDbRole(role: string): DbRole {
  return (APP_ROLE_TO_DB[role] ?? role) as DbRole
}

export function toAppRole(raw: string | null | undefined): string | null {
  if (!raw) return null
  const r = raw.toLowerCase()
  return DB_ROLE_TO_APP[r] ?? r
}

/**
 * The text the phone read off each proof-of-enrolment document, for
 * student_profiles.document_text. Only for a file that is being sent, and capped
 * well under the column's size check.
 */
export function documentText(form: StudentRegisterForm): Json | null {
  const readAt = new Date().toISOString()
  const readings: DocReadings = {}
  if (form.schoolIdFile && form.schoolIdText) readings.school_id = { text: form.schoolIdText.slice(0, 20000), read_at: readAt }
  if (form.assessmentFile && form.assessmentText) readings.assessment_of_fees = { text: form.assessmentText.slice(0, 20000), read_at: readAt }
  return Object.keys(readings).length ? (readings as Json) : null
}

export function sanitizeError(error: unknown): Error {
  // Supabase auth/PostgREST errors are often plain objects (not Error
  // instances) that carry a real `.message`/`.code`/`.status`. Reading those
  // prevents `String(object)` → "[object Object]" from leaking to the UI.
  let raw: string
  if (error instanceof Error) {
    raw = error.message
  } else if (error && typeof error === 'object' && 'message' in error) {
    raw = String((error as { message: unknown }).message || 'Unknown error')
  } else {
    raw = String(error ?? 'Unknown error')
  }
  let friendly = 'An unexpected error occurred. Please try again.'
  const m = (error instanceof Error ? error.message : '') || raw
  if (
    m.includes('23505') ||
    m.includes('duplicate key') ||
    m.includes('student_profiles_student_id_key')
  ) {
    friendly = 'This Student ID is already registered.'
  } else if (m.includes('already registered') || m.includes('email_exists') || m.includes('User already')) {
    friendly = 'This email is already registered. Try logging in instead.'
  } else if (m.includes('PGRST116') || m.includes('0 rows')) {
    friendly = 'Registration failed due to a database conflict. Please try again.'
  } else if (m.includes('Invalid login credentials')) {
    friendly = 'Invalid email or password.'
  } else if (m.includes('Email not confirmed')) {
    friendly = 'Please confirm your email address before logging in.'
  } else if (m.includes('rate limit')) {
    friendly = 'Too many attempts. Please try again later.'
  }
  // Surface the raw backend message so failures are diagnosable on-device
  // instead of being collapsed into a generic string.
  return new Error(`${friendly} (${raw})`)
}

export function formatProfileData(form: RegisterForm | ManagerRegisterForm, role: 'student' | 'manager') {
  // Was a second hand-rolled copy of initialsOf(), which drifted from it:
  // this one took the literal last word, so "Juan D. Dela Cruz Jr." became
  // JJ — the J of Jr. — while the profile screen's edit of the same name
  // produced JC. One helper, one answer, whichever path wrote the row.
  const initials = initialsOf(form.fullName)

  const formattedSex = form.sex === 'Male' ? 'M' : form.sex === 'Female' ? 'F' : 'U'

  return {
    email: form.email,
    full_name: form.fullName,
    initials,
    sex: formattedSex,
    // Read by handle_auth_user_sync into public.users.date_of_birth; an empty
    // string would fail the cast, so it is normalised away here.
    date_of_birth: form.dateOfBirth || null,
    role: toDbRole(role),
    phone: form.phone,
  }
}

   // Ensures the public.users row exists for the given auth user.
// The auth.users -> public.users sync trigger normally handles this, but
// this upsert is a safety net (idempotent via onConflict). status is left
// out so the trigger's email-verification logic isn't clobbered.
// Required NOT NULL columns: id, email, phone, role, full_name, initials.
export async function ensureUserRow(
  userId: string,
  email: string,
  profileData: {
    /** App ('manager') or DB ('landlord') name: toDbRole maps either. */
    role: string;
    full_name: string;
    initials: string;
    phone?: string;
    date_of_birth?: string | null;
  },
  status?: 'pending',
) {
  const fields = {
    phone: (profileData.phone as string) ?? '+639000000000',
    role: toDbRole(profileData.role),
    full_name: profileData.full_name,
    initials: profileData.initials,
    ...(profileData.date_of_birth ? { date_of_birth: profileData.date_of_birth } : {}),
  }
  // Insert-if-missing, then update — not one upsert. An upsert's DO UPDATE
  // reads the incoming e-mail and phone, and those columns are not readable
  // by clients (20261005010000), so it was refused outright. The e-mail is
  // left to the auth sync either way.
  const { error: insertError } = await supabase
    .from('users')
    .upsert({ id: userId, email, ...fields, ...(status ? { status } : {}) }, { onConflict: 'id', ignoreDuplicates: true })
  if (insertError) throw sanitizeError(insertError)

  const { error } = await supabase.from('users').update(fields).eq('id', userId)
  if (error) throw sanitizeError(error)
}

export async function submitStudentVerificationDocuments(
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
    }))

  if (!rows.length) return

  // Upsert for the same reason as registerManager: (user_id, doc_type) is
  // unique, and a resubmitted proof replaces its own row rather than
  // stacking a second copy beside it.
  const { error } = await supabase
    .from('verification_documents')
    .upsert(rows, { onConflict: 'user_id,doc_type' })
  if (error) throw sanitizeError(error)

  const { error: userError } = await supabase
    .from('users')
    .update({ status: 'pending' })
    .eq('id', userId)
  if (userError) throw sanitizeError(userError)
}

export async function submitManagerVerificationDocuments(userId: string, form: ManagerRegisterForm) {
  if (!form.governmentIdFile || !form.businessPermitFile) {
    throw new Error('Both requirements must be uploaded.')
  }

  // Every student gets a student_profiles row at registration; landlords/landladies were
  // getting no profile row at all, so a landlord/landlady had no record to hang
  // responsiveness stats or admin review data on. Created here because all
  // three landlord/landlady registration paths (password, resumed, Google) submit
  // documents through this method. Upsert: resubmitting must not fail.
  const { error: profileError } = await supabase
    .from('landlord_profiles')
    .upsert({ user_id: userId }, { onConflict: 'user_id' })
  if (profileError) throw sanitizeError(profileError)

  const [governmentIdUrl, businessPermitUrl] = await Promise.all([
    uploadSecureDocument(form.governmentIdFile),
    uploadSecureDocument(form.businessPermitFile),
  ])

  // Upsert, not insert: a retried registration used to write a second copy
  // of both documents, leaving the landlord/landlady's record listing each one twice.
  // (user_id, doc_type) is unique, so a retry now overwrites its own row.
  const { error } = await supabase.from('verification_documents').upsert(
    [
      {
        user_id: userId,
        doc_type: 'government_id',
        file_url: governmentIdUrl,
        filename: form.governmentIdFile.name,
        status: 'pending' as const,
        expires_at: form.governmentIdExpiresAt || null,
      },
      {
        user_id: userId,
        doc_type: 'business_permit',
        file_url: businessPermitUrl,
        filename: form.businessPermitFile.name,
        status: 'pending' as const,
        expires_at: form.businessPermitExpiresAt || null,
      },
    ],
    { onConflict: 'user_id,doc_type' },
  )

  if (error) throw sanitizeError(error)
}
