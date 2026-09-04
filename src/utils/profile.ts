// Presentation helpers shared by the two profile pages, so a manager and a
// student never see the same underlying status described two different ways.

/** Friendly names for the doc_type strings written during registration. */
export const DOC_LABEL: Record<string, string> = {
  government_id: 'Government ID',
  business_permit: 'Business permit',
  school_id: 'School ID',
  assessment_of_fees: 'Assessment of fees',
};

export interface Presentation {
  label: string;
  tone: 'ok' | 'warn' | 'bad' | 'idle';
  icon: string;
}

/** doc_status: pending | approved | rejected */
export function docPresentation(status: string | null | undefined): Presentation {
  if (status === 'approved') return { label: 'Approved', tone: 'ok', icon: 'lucide:check' };
  if (status === 'rejected') return { label: 'Rejected', tone: 'bad', icon: 'lucide:x' };
  return { label: 'In review', tone: 'warn', icon: 'lucide:hourglass' };
}

/** user_status: unverified | pending | reviewing | verified | rejected | suspended */
export function statusPresentation(status: string | null | undefined): Presentation {
  switch (status) {
    case 'verified':
      return { label: 'Verified', tone: 'ok', icon: 'lucide:badge-check' };
    case 'rejected':
      return { label: 'Rejected', tone: 'bad', icon: 'lucide:file-x' };
    case 'suspended':
      return { label: 'Suspended', tone: 'bad', icon: 'lucide:ban' };
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
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString('en-PH', { month: 'long', year: 'numeric' });
}

/** Compact relative age: "today", "3d", "2mo". */
export function ago(iso: string | null | undefined): string {
  if (!iso) return '';
  const then = new Date(iso).getTime();
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
