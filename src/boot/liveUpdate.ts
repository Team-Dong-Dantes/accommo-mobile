import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { CapacitorUpdater } from '@capgo/capacitor-updater'

// Runs first among the boot files, before any network call: it tells the OTA
// updater this web bundle started. A bundle that doesn't confirm within 10
// seconds is treated as broken and rolled back. Updating itself is UpdateGate's
// job — on its own screen, when the user taps it (src/utils/liveUpdate.ts).
export default defineBoot(() => {
  if (!Capacitor.isNativePlatform()) return
  void CapacitorUpdater.notifyAppReady().catch(() => undefined)
})
