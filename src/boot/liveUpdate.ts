import { defineBoot } from '#q-app';
import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';
import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { AWAY_MS, applyPendingBundle } from '@/utils/liveUpdate';

// Runs first among the boot files, before any network call, for two reasons
// (see src/utils/liveUpdate.ts):
//  1. It tells the OTA updater this web bundle started. A bundle that doesn't
//     confirm within 10 seconds is treated as broken and rolled back.
//  2. It applies a queued update at the two moments nobody is mid-task: a cold
//     start, and a return after AWAY_MS in the background. A short trip away —
//     the camera, a share sheet — never reloads the app.
export default defineBoot(() => {
  if (!Capacitor.isNativePlatform()) return;
  void CapacitorUpdater.notifyAppReady().then(() => applyPendingBundle()).catch(() => undefined);

  let pausedAt = 0;
  void App.addListener('pause', () => {
    pausedAt = Date.now();
  });
  void App.addListener('resume', () => {
    if (pausedAt && Date.now() - pausedAt >= AWAY_MS) void applyPendingBundle().catch(() => undefined);
  });
});
