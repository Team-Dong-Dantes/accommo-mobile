import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { defineCustomElements } from '@ionic/pwa-elements/loader'

// The Capacitor Camera plugin's web fallback (used when running in a plain
// browser — `npm run dev`, or any non-native session) renders its capture UI
// as a <pwa-camera-modal> custom element. Without registering it here,
// Camera.getPhoto() throws "Unable to load PWA Element 'pwa-camera-modal'"
// instead of showing a camera. Native platforms use the real native camera
// and never hit this path, so skip it there.
export default defineBoot(() => {
  if (Capacitor.isNativePlatform()) return
  void defineCustomElements(window)
})
