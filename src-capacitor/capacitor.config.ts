// @quasar/app-vite v3 dropped support for capacitor.config.json — it errors out
// at the end of `quasar build -m capacitor`, AFTER writing src-capacitor/www.
// That is why the APK kept shipping Sep 2 assets while the build looked like it
// had mostly worked: the web bundle was fresh, the native sync never ran.
//
// `bundledWebRuntime` is deliberately gone: it was removed from CapacitorConfig
// in Capacitor 6 and this project is on 8.
import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.accommo.app',
  appName: 'Accommo Mobile',
  webDir: 'www',
  backgroundColor: '#f6f7f8',
}

export default config
