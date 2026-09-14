import { App } from '@capacitor/app';
import { Capacitor } from '@capacitor/core';

export const EXTERNAL_URLS = {
  GOOGLE_ICON: 'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
  ISU_BACKGROUND: 'https://isu.edu.ph/wp-content/uploads/2024/11/ISU-Aerial.jpg',
} as const;

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
