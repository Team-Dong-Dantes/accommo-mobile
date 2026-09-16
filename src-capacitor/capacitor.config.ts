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
  plugins: {
    // @capgo/capacitor-social-login enables all four providers by default, which
    // links the Facebook, Apple and Twitter SDKs into the APK for nothing.
    // Accommo only ever signs in with Google; the rest compile away.
    SocialLogin: {
      providers: { google: true, facebook: false, apple: false, twitter: false },
    },
  },
}

export default config
