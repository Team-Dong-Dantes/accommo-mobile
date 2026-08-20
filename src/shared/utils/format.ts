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
};

export const ROOM_STATUS: Record<string, StatusMeta> = {
  available: { text: 'Available', color: 'green' },
  occupied: { text: 'Occupied', color: 'orange' },
  maintenance: { text: 'Maintenance', color: 'red' },
};

export const PAYMENT_STATUS: Record<string, StatusMeta> = {
  due: { text: 'Due', color: 'amber' },
  paid: { text: 'Paid', color: 'green' },
  overdue: { text: 'Overdue', color: 'red' },
  pending_verification: { text: 'Pending Verification', color: 'orange' },
};

export const CONCERN_STATUS: Record<string, StatusMeta> = {
  open: { text: 'Open', color: 'amber' },
  in_progress: { text: 'In Progress', color: 'teal' },
  resolved: { text: 'Resolved', color: 'green' },
  rejected: { text: 'Rejected', color: 'red' },
};

export const COMPLAINT_STATUS: Record<string, StatusMeta> = {
  pending: { text: 'Pending', color: 'amber' },
  assigned: { text: 'Assigned', color: 'blue' },
  under_review: { text: 'Under Review', color: 'teal' },
  resolved: { text: 'Resolved', color: 'green' },
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
