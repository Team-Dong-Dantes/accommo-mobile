import { Capacitor, registerPlugin } from '@capacitor/core'
import { Directory, Filesystem } from '@capacitor/filesystem'
import { CapacitorUpdater, type BundleInfo } from '@capgo/capacitor-updater'

// Required, in-app updates. CI publishes every release to GitHub Releases and
// records it in the one `app_release` row; UpdateGate compares that against
// this install and, when it is behind, puts up a screen with no way past it.
//
// Two ways to update, both inside the app:
//  - 'bundle': a release that changed only web code. Its zipped web build
//    (~3 MB) is downloaded with the OTA plugin and switched to at once; the app
//    reloads into the new version. It used to download quietly and wait for a
//    cold start, which Android rarely gives an app — so updates seemed never to
//    arrive, and every failure was swallowed.
//  - 'apk': a release that changed native code (CI raises
//    `min_supported_version_code`), or a bundle that failed. The APK (~32 MB)
//    is downloaded into the cache and handed to Android's installer
//    (ApkInstallerPlugin.java) — no browser.
//
// Rollback is the plugin's: boot/liveUpdate.ts confirms each bundle at startup,
// and one that never gets that far is reverted and marked `error`.

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
  const v = bundle.id === 'builtin' ? versionCode : Number(bundle.version)
  return Number.isFinite(v) ? v : 0
}

/**
 * Where CI publishes releases. The checksum sits in the same `app_release` row
 * as the link, so it proves the download arrived intact, not who made it —
 * whoever could edit that row could otherwise send every phone code (or an
 * APK) from a server of their own. Pinned here, they also need the GitHub repo.
 */
const RELEASES = 'https://github.com/Team-Dong-Dantes/accommo-mobile/releases/'

/** How this install has to update to `release`, if at all. */
export function updateAction(release: Release, versionCode: number, running: number): 'apk' | 'bundle' | 'none' {
  // With no APK to point at, the wall would strand the user — fail open.
  if (versionCode < release.min_supported_version_code) {
    return hasApk(release) ? 'apk' : 'none'
  }
  // The plugin refuses a download without a sha256 checksum, so no checksum means no bundle.
  if (!release.bundle_url?.startsWith(`${RELEASES}download/`) || !release.bundle_checksum || !release.bundle_version) return 'none'
  return release.bundle_version > running ? 'bundle' : 'none'
}

/** Whether `release` points at an APK this app may install. */
export function hasApk(release: Release): boolean {
  return release.apk_url?.trim().startsWith(RELEASES) ?? false
}

/**
 * What to do about the bundle for `version`, given what is on the device:
 * switch to it, download it, or give up on it — it was tried and rolled back,
 * and the same files would fail the same way.
 */
export function bundleStep(bundles: BundleInfo[], version: string): { step: 'set'; id: string } | { step: 'download' | 'broken' } {
  const b = bundles.find((x) => x.version === version)
  if (b?.status === 'error') return { step: 'broken' }
  if (b && (b.status === 'success' || b.status === 'pending')) return { step: 'set', id: b.id }
  return { step: 'download' }
}

/** Thrown when a bundle rolled back before; the page offers the APK instead. */
export class BrokenBundleError extends Error {}

/**
 * Downloads `release`'s web bundle (reporting 0–100 to `onPercent`) and
 * switches to it. On success the app reloads into it, so this never returns.
 */
export async function installBundle(release: Release, onPercent: (percent: number) => void): Promise<void> {
  const version = String(release.bundle_version)
  const { bundles } = await CapacitorUpdater.list()
  const next = bundleStep(bundles, version)
  if (next.step === 'broken') throw new BrokenBundleError('This update did not start on your phone last time.')
  let id = next.step === 'set' ? next.id : ''
  if (next.step === 'download') {
    // A download cut off earlier leaves a half bundle under the same version.
    const stale = bundles.find((b) => b.version === version)
    if (stale) await CapacitorUpdater.delete({ id: stale.id }).catch(() => undefined)
    const sub = await CapacitorUpdater.addListener('download', (e) => onPercent(e.percent))
    try {
      id = (await CapacitorUpdater.download({ url: release.bundle_url ?? '', version, checksum: release.bundle_checksum ?? '' })).id
    } finally {
      void sub.remove()
    }
  }
  await CapacitorUpdater.set({ id })
}

interface ApkInstallerPlugin {
  install(opts: { path: string }): Promise<{ opened: 'settings' | 'installer' }>
}
const ApkInstaller = registerPlugin<ApkInstallerPlugin>('ApkInstaller')

/** Inside the cache's Accommo/cache/ — the only cache folder the file provider shares. */
const APK_PATH = 'Accommo/cache/accommo-update.apk'

/** An APK from before ApkInstallerPlugin can only update through the browser. */
export function canInstallInApp(): boolean {
  return Capacitor.isPluginAvailable('ApkInstaller')
}

/** Downloads `release`'s APK into the cache, reporting 0–100 to `onPercent`. */
export async function downloadApk(release: Release, onPercent: (percent: number) => void): Promise<void> {
  const sub = await Filesystem.addListener('progress', (p) => {
    if (p.contentLength > 0) onPercent(Math.round((p.bytes / p.contentLength) * 100))
  })
  try {
    await Filesystem.downloadFile({ url: release.apk_url.trim(), path: APK_PATH, directory: Directory.Cache, progress: true, recursive: true })
  } finally {
    void sub.remove()
  }
}

/**
 * Opens Android's installer on the downloaded APK — or, the first time, the
 * "Install unknown apps" switch for accommo, after which the user taps Install again.
 */
export async function installApk(): Promise<'settings' | 'installer'> {
  return (await ApkInstaller.install({ path: APK_PATH })).opened
}

/** Frees the ~32 MB an installed update leaves behind in the cache. */
export function removeDownloadedApk(): Promise<void> {
  return Filesystem.deleteFile({ path: APK_PATH, directory: Directory.Cache }).catch(() => undefined)
}
