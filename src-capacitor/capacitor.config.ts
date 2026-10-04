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
//
// The phone reaches the dev server over the USB cable, not Wi-Fi: run
// `adb reverse tcp:9500 tcp:9500` once the phone is plugged in. The LAN route
// was blocked by the PC's firewall, and localhost needs no IP that changes with
// the network. Keep the port in step with `-p` on dev:android in package.json.
const isDev = process.env.QUASAR_DEV === 'true'

const config: CapacitorConfig = {
  appId: 'com.accommo.app',
  appName: 'Accommo Mobile',
  webDir: 'www',
  backgroundColor: '#f6f7f8',
  ...(isDev ? { server: { url: 'http://localhost:9500', cleartext: true } } : {}),
  plugins: {
    // @capgo/capacitor-social-login enables all four providers by default, which
    // links the Facebook, Apple and Twitter SDKs into the APK for nothing.
    // Accommo only ever signs in with Google; the rest compile away.
    SocialLogin: {
      providers: { google: true, facebook: false, apple: false, twitter: false },
    },
    // Self-hosted OTA (src/utils/liveUpdate.ts drives it by hand): no Capgo
    // cloud checks, and no stats sent to Capgo's servers.
    CapacitorUpdater: {
      autoUpdate: false,
      statsUrl: '',
    },
  },
}

export default config
