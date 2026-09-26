import { App } from '@capacitor/app';
import { Capacitor } from '@capacitor/core';

export const EXTERNAL_URLS = {
  GOOGLE_ICON: 'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
  // Bundled in public/, not hotlinked from isu.edu.ph: the campus site goes
  // down (ERR_CONNECTION_REFUSED), and it backs the splash, the PIN lock and
  // the update wall — three screens with no way past them. accommo-web already
  // ships the same file at the same path.
  ISU_BACKGROUND: '/isu-aerial.jpg',
} as const;

/**
 * The only e-mail domains Accommo accepts, for every way an account can be made.
 *
 * This list is the UI's copy: it fills the register screen's domain dropdown and
 * explains a rejected Google account. The enforcing copy lives in
 * `handle_auth_user_sync()` on `auth.users`
 * (supabase/migrations/20260915000000_restrict_email_domains.sql), because a
 * client-side list is a suggestion — a Google Workspace address on any domain
 * could otherwise connect. Change both together.
 */
export const ALLOWED_EMAIL_DOMAINS = ['gmail.com', 'isu.edu.ph'] as const;

/**
 * The product's one-line pitch. Shown on the splash (GetStartedPage) and, on a
 * landscape tablet or desktop, on the photo half of sign-in and register — the
 * same sentence in both places rather than two copies that drift.
 */
export const PITCH_LINE = 'Verified boarding houses near ISU Echague.';

/**
 * The student/manager fork, asked in the same words wherever it is offered —
 * the splash's panel and `/register/role`. Two screens ask one question; they
 * had their own copies of it until the splash grew a heading in landscape.
 */
export const ROLE_QUESTION = 'Are you a student or a manager?';
export const ROLE_QUESTION_NOTE =
  'This sets what Accommo shows you, and OSAS verifies each differently.';

/** Reads as a sentence: "@gmail.com or @isu.edu.ph". */
export const ALLOWED_EMAIL_DOMAINS_TEXT = ALLOWED_EMAIL_DOMAINS.map((d) => `@${d}`).join(' or ');

export function isAllowedEmailDomain(email: string | null | undefined): boolean {
  const domain = (email ?? '').split('@')[1]?.toLowerCase();
  return !!domain && (ALLOWED_EMAIL_DOMAINS as readonly string[]).includes(domain);
}

// Browser fallback only. On a device the installed versionName is the truth —
// CI stamps it with the release's run number (see .github/workflows/build.yml),
// which a constant baked into the bundle cannot know. Kept as a constant rather
// than a JSON import since resolveJsonModule isn't guaranteed in the generated
// Quasar tsconfig; bump it alongside package.json's version.
export const APP_VERSION = '1.0.0';

/**
 * The version actually running. Reads the installed Android versionName on a
 * device, so the Settings row can never drift from what the user has; falls
 * back to the constant in the browser and on any failure.
 */
export async function getAppVersion(): Promise<string> {
  if (!Capacitor.isNativePlatform()) return APP_VERSION;
  try {
    return (await App.getInfo()).version || APP_VERSION;
  } catch {
    return APP_VERSION;
  }
}
