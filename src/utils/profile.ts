// Presentation helpers shared by the two profile pages, so a landlord/landlady and a
// student never see the same underlying status described two different ways.

import { formatDate, parseServerTime } from '@/utils/format';
import { supabase } from '@/utils/supabase';
import { since } from '@/utils/notifications';
import { secureDocUrl } from '@/utils/upload';
import type { RequirementItem } from '@/components/shared/RequirementCards.vue';

/** Friendly names for the doc_type strings written during registration. */
export const DOC_LABEL: Record<string, string> = {
  government_id: 'Government ID',
  business_permit: 'Business permit',
  school_id: 'School ID',
  assessment_of_fees: 'Assessment of fees',
};

// Tone names match what the hand-written page designs use, so a pasted
// `class="tag-${status.tone}"` resolves without a translation step.
export interface Presentation {
  label: string;
  tone: 'good' | 'warn' | 'danger' | 'idle';
  icon: string;
}

/** doc_status: pending | approved | rejected — plus `resubmit`, a document OSAS asked for again. */
export function docPresentation(status: string | null | undefined): Presentation {
  if (status === 'approved') return { label: 'Approved', tone: 'good', icon: 'lucide:check' };
  if (status === 'rejected') return { label: 'Rejected', tone: 'danger', icon: 'lucide:x' };
  if (status === 'resubmit') return { label: 'Upload again', tone: 'warn', icon: 'lucide:file-warning' };
  return { label: 'In review', tone: 'warn', icon: 'lucide:hourglass' };
}

/** A verification_documents row as the OSAS pages read it. */
export interface AccountDocRow {
  id: string;
  doc_type: string;
  file_url: string;
  status: string;
  uploaded_at: string;
  verified_at: string | null;
}

/** An account document's requirement card, read against the account's own status. */
export function accountDocItem(type: string, row: AccountDocRow | undefined, accountStatus: string): RequirementItem {
  const label = DOC_LABEL[type] ?? type;
  if (!row) return { type, label, statusLabel: 'Not submitted', tone: 'idle', when: '', fileUrl: '', verified: false };
  // Once the account is verified that overrides an old row stuck at 'pending'.
  // Otherwise the row speaks for itself: OSAS marks only the documents it
  // wants again, so a sent-back account can still have an approved one.
  const effectiveStatus = accountStatus === 'verified' ? 'approved' : row.status === 'rejected' && accountStatus === 'needs_resubmission' ? 'resubmit' : row.status;
  const presentation = docPresentation(effectiveStatus);
  const when = row.verified_at ? `Reviewed ${since(row.verified_at)}` : `Sent ${since(row.uploaded_at)}`;
  return { type, label, statusLabel: presentation.label, tone: presentation.tone, when, fileUrl: row.file_url, verified: effectiveStatus === 'approved' };
}

/**
 * The newest row per doc_type (rows arrive newest first), each with a link
 * signed for this viewer: documents use Cloudinary authenticated delivery, so
 * file_url holds a ref rather than a readable URL.
 */
export async function latestSignedDocs<R extends { id: string; doc_type: string | null }>(rows: R[] | null): Promise<R[]> {
  const seen = new Set<string>();
  const latest = (rows ?? []).filter((d) => {
    if (!d.doc_type || seen.has(d.doc_type)) return false;
    seen.add(d.doc_type);
    return true;
  });
  return Promise.all(latest.map(async (d) => ({ ...d, file_url: await secureDocUrl('verification_documents', d.id) })));
}

/** user_status: unverified | pending | reviewing | verified | needs_resubmission | rejected | suspended */
export function statusPresentation(status: string | null | undefined): Presentation {
  switch (status) {
    case 'verified':
      return { label: 'Verified', tone: 'good', icon: 'lucide:badge-check' };
    case 'needs_resubmission':
      return { label: 'Needs resubmission', tone: 'warn', icon: 'lucide:file-warning' };
    case 'rejected':
      return { label: 'Rejected', tone: 'danger', icon: 'lucide:file-x' };
    case 'suspended':
      return { label: 'Suspended', tone: 'danger', icon: 'lucide:ban' };
    case 'pending':
    case 'reviewing':
      return { label: 'In review', tone: 'warn', icon: 'lucide:hourglass' };
    default:
      return { label: 'Unverified', tone: 'idle', icon: 'lucide:circle-dashed' };
  }
}

/** "August 2026" — the month is precise enough for a profile. */
export function memberSince(iso: string | null | undefined): string {
  if (!iso) return '—';
  const date = parseServerTime(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString('en-PH', { month: 'long', year: 'numeric' });
}

/** Compact relative age: "today", "3d", "2mo". */
export function ago(iso: string | null | undefined): string {
  if (!iso) return '';
  const then = parseServerTime(iso).getTime();
  if (Number.isNaN(then)) return '';
  const days = Math.floor((Date.now() - then) / 86400000);
  if (days <= 0) return 'today';
  if (days === 1) return '1d';
  if (days < 30) return `${days}d`;
  const months = Math.floor(days / 30);
  return months === 1 ? '1mo' : `${months}mo`;
}

/** A lease/stay period as "Mar 2026 — Nov 2026". */
export function period(start: string | null | undefined, end: string | null | undefined): string {
  const fmt = (iso: string | null | undefined) => {
    if (!iso) return '—';
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return '—';
    return date.toLocaleDateString('en-PH', { month: 'short', year: 'numeric' });
  };
  return `${fmt(start)} — ${fmt(end)}`;
}

// ── Complete your profile ───────────────────────────────────────────────────
// The one definition of "what is still blank", shared by both dashboards, the
// Menu dot, the profile strip and the step flow, so they never disagree.

export type ProfileGapKey = 'photo' | 'sex' | 'dob' | 'studentId' | 'emergency';

export interface ProfileGap {
  key: ProfileGapKey;
  /** Lower-case noun for "Add your …" sentences. */
  label: string;
  /** A missing photo is a step in the flow but never raises the dot or task: initials stand in fine. */
  needed: boolean;
}

export interface ProfileGapSource {
  avatar_url?: string | null;
  sex?: string | null;
  date_of_birth?: string | null;
  student_id?: string | null;
  emergency_contact_json?: unknown;
}

/** Missing items in the order the flow asks for them. Students also owe a student ID and an emergency contact. */
export function profileGaps(row: ProfileGapSource, isStudent: boolean): ProfileGap[] {
  const gaps: ProfileGap[] = [];
  if (!row.avatar_url) gaps.push({ key: 'photo', label: 'profile photo', needed: false });
  if (!row.sex) gaps.push({ key: 'sex', label: 'sex', needed: true });
  if (!row.date_of_birth) gaps.push({ key: 'dob', label: 'date of birth', needed: true });
  if (isStudent) {
    if (!row.student_id) gaps.push({ key: 'studentId', label: 'student ID', needed: true });
    const contact = row.emergency_contact_json as { name?: string; phone?: string } | null | undefined;
    if (!contact?.name || !contact?.phone) gaps.push({ key: 'emergency', label: 'emergency contact', needed: true });
  }
  return gaps;
}

/** "student ID, emergency contact and date of birth" */
export function listGaps(gaps: ProfileGap[]): string {
  const names = gaps.map((g) => g.label);
  return names.length < 2 ? names.join('') : `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`;
}

export async function loadProfileGaps(userId: string, isStudent: boolean): Promise<ProfileGap[]> {
  const [{ data: user }, { data: student }] = await Promise.all([
    supabase.from('users_full').select('avatar_url, sex, date_of_birth').eq('id', userId).maybeSingle(),
    isStudent
      ? supabase.from('student_profiles').select('student_id, emergency_contact_json').eq('user_id', userId).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);
  // A failed read says nothing is missing rather than nagging about everything.
  if (!user) return [];
  return profileGaps({ ...user, ...(student ?? {}) }, isStudent);
}

/** users.sex holds only M/F when set; '' lets ProfileField show "Not set". */
export function sexLabel(sex: string | null | undefined): string {
  return sex === 'M' ? 'Male' : sex === 'F' ? 'Female' : '';
}

/** "Mar 4, 2001", or '' when blank. */
export function birthDateLabel(iso: string | null | undefined): string {
  return iso ? formatDate(iso) : '';
}
