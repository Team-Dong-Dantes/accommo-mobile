import { App } from '@capacitor/app';
import { CapacitorUpdater, type BundleInfo } from '@capgo/capacitor-updater';

// Over-the-air web updates. CI zips each release's web build, attaches it to
// the GitHub release and records it in the `app_release` row; UpdateGate has
// this download it in the background. Only web code travels this way; a
// release that changes native code raises `min_supported_version_code`, and
// older installs get UpdateGate's wall instead, because a bundle built against
// newer plugins can't run on them.
//
// When it applies is ours, not the plugin's. A downloaded bundle is never
// queued with `next()`, because the plugin swaps a queued bundle on every trip
// to the background — including a trip to the camera to photograph a document,
// which would reload the app under a half-filled form — and on some phones (the
// Infinix it was tested on) that hook fires only some of the time. Instead
// boot/liveUpdate.ts switches with `set()` at cold start, or on a return after
// AWAY_MS in the background: the two moments nobody is mid-task.
//
// Rollback is the plugin's: boot/liveUpdate.ts confirms each bundle at startup,
// and one that never gets that far is reverted and marked `error`.

/** How long the app must sit in the background before a resume may reload it. */
export const AWAY_MS = 10 * 60 * 1000;

export type Release = {
  latest_version_code: number;
  latest_version_name: string;
  min_supported_version_code: number;
  apk_url: string;
  release_notes: string | null;
  bundle_version: number | null;
  bundle_url: string | null;
  bundle_checksum: string | null;
};

/**
 * The release number of the web code this install is running. The code shipped
 * inside the APK (`builtin`) comes from the same CI run as the APK, so it
 * carries the APK's versionCode; a downloaded bundle carries its own.
 */
export function runningVersion(versionCode: number, bundle: Pick<BundleInfo, 'id' | 'version'>): number {
  const v = bundle.id === 'builtin' ? versionCode : Number(bundle.version);
  return Number.isFinite(v) ? v : 0;
}

/** What this install should do about `release`. */
export function updateAction(release: Release, versionCode: number, running: number): 'wall' | 'stage' | 'none' {
  // With no APK to point at, the wall would strand the user — fail open.
  if (versionCode < release.min_supported_version_code) return release.apk_url?.trim() ? 'wall' : 'none';
  // The plugin refuses a download without a sha256 checksum, so no checksum means no bundle.
  if (!release.bundle_url || !release.bundle_checksum || !release.bundle_version) return 'none';
  return release.bundle_version > running ? 'stage' : 'none';
}

/** The newest downloaded bundle that is newer than what's running, if any. */
export function pickBundle(bundles: BundleInfo[], running: number): BundleInfo | undefined {
  return bundles
    .filter((b) => (b.status === 'success' || b.status === 'pending') && Number(b.version) > running)
    .sort((a, b) => Number(b.version) - Number(a.version))[0];
}

let staging: Promise<void> | null = null;

/** Downloads `release`'s bundle unless it is already on the device. */
export function stageBundle(release: Release): Promise<void> {
  // Launch and resume can both fire a check; one download is enough.
  staging ??= (async () => {
    const version = String(release.bundle_version);
    const { bundles } = await CapacitorUpdater.list();
    // Present already — downloaded earlier, or tried and rolled back, in which
    // case wait for the next release rather than re-download a broken bundle.
    if (bundles.some((b) => b.version === version && b.status !== 'downloading')) return;
    await CapacitorUpdater.download({ url: release.bundle_url ?? '', version, checksum: release.bundle_checksum ?? '' });
  })().finally(() => {
    staging = null;
  });
  return staging;
}

/** Switches to the newest downloaded bundle, if one is waiting. Reloads the app when it does. */
export async function applyPendingBundle(): Promise<void> {
  const [{ build }, { bundle }, { bundles }] = await Promise.all([
    App.getInfo(),
    CapacitorUpdater.current(),
    CapacitorUpdater.list(),
  ]);
  const next = pickBundle(bundles, runningVersion(Number(build), bundle));
  if (next) await CapacitorUpdater.set({ id: next.id });
}
