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

  // Two facts, one source. The height is what the scrollers pad themselves by;
  // the class is what lets CSS ask the yes/no question, which a custom property
  // alone cannot answer in a selector.
  const setKb = (px: number) => {
    document.documentElement.style.setProperty('--m-kb', `${px}px`)
    document.documentElement.classList.toggle('kb-open', px > 0)
  }

  // Moving from one field to the next makes Android close and reopen the IME,
  // so the raw events arrive as hide-then-show a few milliseconds apart. Acting
  // on that hide drops the footer to the floor and hauls it straight back up —
  // the jump. Holding the hide briefly lets the following show cancel it, and a
  // real dismissal being 120ms late is not something anyone can see.
  let hideTimer: ReturnType<typeof setTimeout> | undefined

  void Keyboard.addListener('keyboardWillShow', (info) => {
    clearTimeout(hideTimer)
    setKb(info.keyboardHeight)
  })
  void Keyboard.addListener('keyboardWillHide', () => {
    clearTimeout(hideTimer)
    hideTimer = setTimeout(() => setKb(0), 120)
  })
})
