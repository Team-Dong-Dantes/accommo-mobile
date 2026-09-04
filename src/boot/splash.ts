import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { SplashScreen } from '@capacitor/splash-screen'

// Controlled splash dismissal. Native splash shows the app icon over the app
// surface while the WebView boots; hiding on first paint (instead of letting it
// flicker away on a blank/white frame) makes the launch feel native.
// Safe no-op on web.
export default defineBoot(() => {
  if (!Capacitor.isNativePlatform()) return

  const hide = () => {
    void SplashScreen.hide({ fadeOutDuration: 200 }).catch(() => {
      /* best-effort */
    })
  }

  if (document.readyState === 'complete') {
    // Already painted — next frame so the router has rendered content.
    requestAnimationFrame(hide)
  } else {
    // Wait for the app to finish its first paint rather than hiding on a blank frame.
    window.addEventListener('load', () => requestAnimationFrame(hide), { once: true })
    // Absolute fallback so a slow load never leaves the splash up forever.
    setTimeout(hide, 4000)
  }
})
