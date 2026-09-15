import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { Keyboard, KeyboardResize } from '@capacitor/keyboard'

// On a real Android/iOS device (Capacitor), make the onscreen keyboard overlay
// instead of resizing the WebView. With resize mode "none" the layout keeps its
// height and the form/background no longer jumps when an input is focused.
//
// The cost of overlaying is that nothing pinned to the bottom of the screen
// knows the keyboard is there — the register sheet's action bar would sit under
// it. So publish the height as `--m-kb` and let any bottom bar pad itself by
// `var(--m-kb, 0px)`. In a browser (`quasar dev`) these listeners never fire and
// the default of 0 is correct, because there the viewport really does shrink.
export default defineBoot(() => {
  if (!Capacitor.isNativePlatform()) return

  void Keyboard.setResizeMode({ mode: KeyboardResize.None })

  const setKb = (px: number) =>
    document.documentElement.style.setProperty('--m-kb', `${px}px`)

  void Keyboard.addListener('keyboardWillShow', (info) => setKb(info.keyboardHeight))
  void Keyboard.addListener('keyboardWillHide', () => setKb(0))
})
