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
// Nothing reads --m-kb or .kb-open at the moment. The register sheet used to
// shrink by the height, and later hid its action bar on the class; both were
// tried and both were worse than simply letting the keyboard cover the bar, so
// the layout no longer reacts to the keyboard at all. This stays because it is
// the hook any bottom bar would need if one ever does — the chat composer is the
// likely candidate — and it costs two listeners. Delete it if that never comes.
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
