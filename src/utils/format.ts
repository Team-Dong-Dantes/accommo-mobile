// Shared formatting + display-label helpers for the Accommo app.
// Centralizes currency/date formatting and friendlier enum/status labels so
// the UI never shows raw database enum values (e.g. "under_review") to users.

export function formatPeso(amount: number): string {
  return '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return (parts[0] ?? '').slice(0, 2).toUpperCase();
  return ((parts[0]?.[0] ?? '') + (parts[parts.length - 1]?.[0] ?? '')).toUpperCase();
}

// Normalize a Philippine mobile number to E.164 (+63xxxxxxxxx).
// Accepts "09123456789", "9123456789", "+639123456789", or "63 912...".
// A leading country code (63) or the local leading 0 is stripped, so the
// user never has to remember whether to include it next to the +63 prefix.
export function normalizePhPhone(raw: string | number | null | undefined): string {
  let digits = String(raw ?? '').replace(/\D/g, '')
  if (digits.startsWith('63') && digits.length >= 12) {
    digits = digits.slice(2)
  }
  if (digits.startsWith('0')) {
    digits = digits.slice(1)
  }
  return '+63' + digits
}

// Returns just the 10-digit national number (no +63, no leading 0).
export function phNationalDigits(raw: string | number | null | undefined): string {
  return normalizePhPhone(raw).replace(/^\+63/, '')
}

// Some tables (messages.sent_at, conversations.last_time, etc.) are
// Postgres `timestamp without time zone` columns. The DB actually stores
// UTC, but PostgREST serializes these with no timezone suffix, e.g.
// "2026-09-04T19:15:34.465329". `new Date(...)` on a string like that is
// parsed as LOCAL time per the ECMAScript Date spec, silently shifting
// every such timestamp by the viewer's UTC offset — 8 hours off in the
// Philippines, which is why a message sent seconds ago could read "8h".
// Append `Z` only to a naive date-*time* string (has a `T`/space time part
// but no timezone marker) — a bare `date` column like "2026-09-05" is left
// untouched, since it's already correctly parsed as UTC midnight and adding
// `Z` to a string with no time part isn't reliably valid across engines.
// Already-correct `timestamptz` columns (e.g. notifications.created_at)
// pass through unchanged either way.
// House-rule times are stored as free text, so the pickers write one
// canonical shape ("10:00 PM", "10:00 PM – 6:00 AM") and read older,
// hand-typed values back as best they can.

/** "22:00" (an <input type="time"> value) -> "10:00 PM". */
export function to12Hour(value: string): string {
  const [h, m] = (value || '').split(':');
  const hour = Number(h);
  if (!value || Number.isNaN(hour) || !m) return '';
  const suffix = hour < 12 ? 'AM' : 'PM';
  const hour12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${hour12}:${m} ${suffix}`;
}

/** "10:00 PM" / "10PM" / "22:00" -> "22:00" for an <input type="time">. */
export function to24Hour(value: string): string {
  const text = (value || '').trim();
  const match = /^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$/.exec(text);
  if (!match) return '';
  let hour = Number(match[1]);
  const minutes = match[2] ?? '00';
  const suffix = match[3]?.toUpperCase();
  if (hour > 23 || Number(minutes) > 59) return '';
  if (suffix === 'PM' && hour < 12) hour += 12;
  if (suffix === 'AM' && hour === 12) hour = 0;
  return `${String(hour).padStart(2, '0')}:${minutes}`;
}

/** Splits a stored range ("10:00 PM – 6:00 AM") into two picker values. */
export function splitTimeRange(value: string): [string, string] {
  const [from, to] = (value || '').split(/[–-]/);
  return [to24Hour(from ?? ''), to24Hour(to ?? '')];
}

export function parseServerTime(iso: string): Date {
  const hasTime = /[T ]/.test(iso);
  const hasTz = /[Zz]$|[+-]\d{2}:?\d{2}$/.test(iso);
  return new Date(hasTime && !hasTz ? `${iso}Z` : iso);
}

/** Separator label above a run of messages sent on the same day. */
export function dayLabel(iso: string): string {
  const date = parseServerTime(iso);
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  if (date.getTime() >= start.getTime()) return 'Today';
  if (date.getTime() >= start.getTime() - 86400000) return 'Yesterday';
  return date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' });
}

/** Clock time shown under a message bubble. */
export function clockTime(iso: string): string {
  return parseServerTime(iso).toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' });
}

export function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' });
}

export function formatMonth(dateStr: string | null | undefined): string {
  if (!dateStr) return 'Unspecified';
  return new Date(dateStr).toLocaleDateString('en-PH', { month: 'long', year: 'numeric' });
}

export interface StatusMeta {
  text: string;
  color: string;
}

// Friendly labels + colors for the database enums.
export const LEASE_STATUS: Record<string, StatusMeta> = {
  active: { text: 'Active', color: 'teal' },
  pending: { text: 'Pending', color: 'amber' },
  ended: { text: 'Ended', color: 'grey' },
  terminated: { text: 'Terminated', color: 'red' },
  leave_requested: { text: 'Leave Requested', color: 'orange' },
  rejected: { text: 'Declined', color: 'red' },
};


export const PAYMENT_STATUS: Record<string, StatusMeta> = {
  due: { text: 'Due', color: 'amber' },
  paid: { text: 'Paid', color: 'green' },
  overdue: { text: 'Overdue', color: 'red' },
  pending_verification: { text: 'Pending Verification', color: 'orange' },
  rejected: { text: 'Rejected', color: 'red' },
};

export const PAYMENT_METHOD_LABEL: Record<string, string> = {
  gcash: 'GCash',
  maya: 'Maya',
  bank: 'Bank transfer',
  cash: 'Cash',
  others: 'Other',
};

/** concerns.status: open | acknowledged | in_progress | resolved | rejected */
export const CONCERN_STATUS: Record<string, StatusMeta> = {
  open: { text: 'Open', color: 'amber' },
  acknowledged: { text: 'Acknowledged', color: 'orange' },
  in_progress: { text: 'In Progress', color: 'orange' },
  resolved: { text: 'Resolved', color: 'green' },
  rejected: { text: 'Rejected', color: 'red' },
};

/** tickets.status — OSAS support tickets. Legacy values are kept because the
 *  database check constraint still permits them on older rows. */
export const TICKET_STATUS: Record<string, StatusMeta> = {
  open: { text: 'Open', color: 'amber' },
  pending: { text: 'Pending', color: 'amber' },
  assigned: { text: 'Assigned', color: 'orange' },
  in_progress: { text: 'In Progress', color: 'orange' },
  under_review: { text: 'Under Review', color: 'orange' },
  resolved: { text: 'Resolved', color: 'green' },
  closed: { text: 'Closed', color: 'grey' },
};

export const CONCERN_CATEGORY_LABEL: Record<string, string> = {
  maintenance: 'Maintenance',
  safety: 'Safety',
  billing: 'Billing',
  other: 'Other',
};



export function statusText(
  map: Record<string, StatusMeta>,
  key: string | null | undefined,
  fallback = '—',
): string {
  if (!key) return fallback;
  return map[key]?.text ?? key;
}

export function statusColor(
  map: Record<string, StatusMeta>,
  key: string | null | undefined,
  fallback = 'grey',
): string {
  if (!key) return fallback;
  return map[key]?.color ?? fallback;
}
