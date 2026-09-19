import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'
import { Browser } from '@capacitor/browser'
import { supabase } from '@/utils/supabase'

// Handles the OAuth return via the app's custom scheme:
//   com.accommo.app://auth/callback?code=...
// Android routes this VIEW intent into MainActivity and the plugin fires
// `appUrlOpen` with the raw URL. We exchange the returned code for a session,
// then reload so the router guard routes the user to the right place by role.
//
// ONLY a PKCE `code` is accepted. This used to also take `access_token` /
// `refresh_token` straight out of the URL and hand them to setSession(), and
// the intent filter that delivers them (see AndroidManifest.xml) is exported
// with no host or path restriction — so any other app on the device, and any
// web page the user tapped, could plant a session of its own choosing here.
// The victim then carried on inside the attacker's account, filing their
// government ID and their messages into it.
//
// A code cannot be planted the same way: exchangeCodeForSession() needs the
// code_verifier this client generated and kept locally, so a code minted for
// anyone else fails the exchange. Nothing legitimate is lost — native sign-in
// goes through signInWithIdToken() and never reaches this file at all.
async function applyOAuthTokens(fragmentOrQuery: string): Promise<boolean> {
  const raw = fragmentOrQuery.startsWith('#') || fragmentOrQuery.startsWith('?')
    ? fragmentOrQuery.slice(1)
    : fragmentOrQuery
  const params = new URLSearchParams(raw)

  const code = params.get('code')
  if (!code) return false

  const { error } = await supabase.auth.exchangeCodeForSession(code)
  return !error
}

export default defineBoot(() => {
  if (!Capacitor.isNativePlatform()) return

  void App.addListener('appUrlOpen', (event) => {
    const url = String((event && event.url) || '')
    const m = /^com\.accommo\.app:\/\/auth\/callback([#?].*)$/.exec(url)
    if (!m || !m[1]) return
    void (async () => {
      // Dismiss the Custom Tab the sign-in was handed to. Android has already
      // brought the app back to the front by this point, so the tab is sitting
      // behind it — without this it is still there, showing a spent callback
      // URL, the next time they swipe through their apps.
      try {
        await Browser.close()
      } catch {
        // Nothing was open: the e-mail path never opens one, and on the web
        // there is no plugin behind this at all.
      }

      const ok = await applyOAuthTokens(m[1]!)
      if (ok) window.location.reload()
    })()
  })
})
