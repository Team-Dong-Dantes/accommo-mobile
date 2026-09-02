import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { Keyboard, KeyboardResize } from '@capacitor/keyboard'

// On a real Android/iOS device (Capacitor), make the onscreen keyboard overlay
// instead of resizing the WebView. With resize mode "none" the layout keeps its
// height and the form/background no longer jumps when an input is focused.
export default defineBoot(() => {
  if (Capacitor.isNativePlatform()) {
    void Keyboard.setResizeMode({ mode: KeyboardResize.None })
  }
})
