// @quasar/app-vite v3 dropped support for capacitor.config.json — it errors out
// at the end of `quasar build -m capacitor`, AFTER writing src-capacitor/www.
// That is why the APK kept shipping Sep 2 assets while the build looked like it
// had mostly worked: the web bundle was fresh, the native sync never ran.
//
// `bundledWebRuntime` is deliberately gone: it was removed from CapacitorConfig
// in Capacitor 6 and this project is on 8.
import type { CapacitorConfig } from '@capacitor/cli'

// `cap sync` runs as a child process of `quasar dev`, which forwards
// QUASAR_DEV into its env (see @quasar/app-vite's CapacitorConfigFile) — so
// this is true only for `npm run dev:android`, never for a real build.
// ponytail: IP hardcoded to this machine's LAN adapter (see package.json's
// `-H` flag on dev:android) — update both if the network changes.
const isDev = process.env.QUASAR_DEV === 'true'

const config: CapacitorConfig = {
  appId: 'com.accommo.app',
  appName: 'Accommo Mobile',
  webDir: 'www',
  backgroundColor: '#f6f7f8',
  ...(isDev ? { server: { url: 'http://192.168.1.8:9000', cleartext: true } } : {}),
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
