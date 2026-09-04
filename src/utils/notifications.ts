// Presentation and navigation rules for notification rows.
//
// The `link_url` column is written by whichever surface created the row, and
// most of the existing values address the admin web app (/verifications,
// /room-hub, /support-tickets). Following those blindly would dead-end the
// mobile user, so a link is only used when it names a route this app actually
// has, and anything else falls back to the best screen for the row's type.

export type Role = 'manager' | 'student';

export interface NotifLook {
  icon: string;
  tone: 'ok' | 'warn' | 'bad' | 'info' | 'idle';
}

const LOOK: Record<string, NotifLook> = {
  verification: { icon: 'lucide:shield-check', tone: 'info' },
  accommodation: { icon: 'lucide:building-2', tone: 'info' },
  application: { icon: 'lucide:file-check', tone: 'ok' },
  lease: { icon: 'lucide:file-text', tone: 'info' },
  leave: { icon: 'lucide:door-open', tone: 'warn' },
  payment: { icon: 'lucide:wallet-cards', tone: 'ok' },
  ticket: { icon: 'lucide:triangle-alert', tone: 'warn' },
};

export function notifLook(type: string | null | undefined): NotifLook {
  return LOOK[type || ''] ?? { icon: 'lucide:bell', tone: 'idle' };
}

/** Every path the mobile router can actually reach. Keep in step with src/router. */
const ROUTES = new Set([
  '/manager/dashboard',
  '/manager/tenants',
  '/manager/messages',
  '/manager/profile',
  '/manager/notifications',
  '/manager/osas-compliance',
  '/manager/support',
  '/manager/properties',
  '/student/home',
  '/student/discover',
  '/student/messages',
  '/student/profile',
  '/student/notifications',
  '/student/support',
  '/student/concerns',
  '/student/payments',
]);

/** Where each type belongs when its own link_url is unusable here. */
const BY_TYPE: Record<Role, Record<string, string>> = {
  manager: {
    verification: '/manager/osas-compliance',
    accommodation: '/manager/properties',
    application: '/manager/tenants',
    lease: '/manager/tenants',
    leave: '/manager/tenants',
    payment: '/manager/tenants',
    ticket: '/manager/support',
  },
  student: {
    verification: '/student/support',
    accommodation: '/student/discover',
    // The seeded rows point at /student/stay, which this app has no route for;
    // the dashboard is where a student's lease actually surfaces.
    application: '/student/home',
    lease: '/student/home',
    leave: '/student/home',
    payment: '/student/payments',
    ticket: '/student/concerns',
  },
};

/**
 * The path to open for a row, or null when there is nowhere sensible to go —
 * in which case tapping it only marks it read.
 */
export function resolveNotifLink(
  linkUrl: string | null | undefined,
  type: string | null | undefined,
  role: Role,
): string | null {
  if (linkUrl) {
    const base = linkUrl.split('?')[0] ?? '';
    // Own-role routes only: a student must never be sent into manager screens.
    if (ROUTES.has(base) && base.startsWith(`/${role}/`)) return linkUrl;
  }
  return BY_TYPE[role][type || ''] ?? null;
}

/** Day bucket used to group the list: 0 today, 1 yesterday, 2 earlier. */
export function dayBucket(iso: string): 0 | 1 | 2 {
  const then = new Date(iso);
  if (Number.isNaN(then.getTime())) return 2;
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  if (then.getTime() >= startOfToday.getTime()) return 0;
  if (then.getTime() >= startOfToday.getTime() - 86400000) return 1;
  return 2;
}

export const BUCKET_LABEL = ['Today', 'Yesterday', 'Earlier'] as const;

/** "just now", "3h", "2d", then a date once it stops being recent. */
export function since(iso: string | null | undefined): string {
  if (!iso) return '';
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return '';
  const minutes = Math.floor((Date.now() - then) / 60000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d`;
  return new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' });
}
