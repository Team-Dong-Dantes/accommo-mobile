import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { Keyboard } from '@capacitor/keyboard'

// On a real Android/iOS device (Capacitor), the onscreen keyboard overlays the
// WebView instead of resizing or panning it, so the layout keeps its height and
// nothing jumps when an input is focused. That is set by
// android:windowSoftInputMode="adjustNothing" in the AndroidManifest.
// Keyboard.setResizeMode() is NOT the lever: it is call.unimplemented() in the
// Android plugin and silently rejects, so it was never doing anything here.
//
// The cost of overlaying is that nothing pinned to the bottom of the screen
// knows the keyboard is there — the register sheet's action bar would sit under
// it. So publish the height as `--m-kb` and let any bottom bar pad itself by
// `var(--m-kb, 0px)`. In a browser (`quasar dev`) these listeners never fire and
// the default of 0 is correct, because there the viewport really does shrink.
export default defineBoot(() => {
  if (!Capacitor.isNativePlatform()) return

  const setKb = (px: number) =>
    document.documentElement.style.setProperty('--m-kb', `${px}px`)

  void Keyboard.addListener('keyboardWillShow', (info) => setKb(info.keyboardHeight))
  void Keyboard.addListener('keyboardWillHide', () => setKb(0))
})
