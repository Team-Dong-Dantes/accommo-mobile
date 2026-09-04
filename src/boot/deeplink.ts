import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'
import { supabase } from '@/utils/supabase'

// Handles the OAuth return via the app's custom scheme:
//   com.accommo.app://auth/callback#access_token=...&refresh_token=...&...
// Android routes this VIEW intent into MainActivity and the plugin fires
// `appUrlOpen` with the raw URL. We hand the returned tokens to supabase
// (setSession persists them), then reload so the router guard routes the user
// to the right place by role.
async function applyOAuthTokens(fragmentOrQuery: string): Promise<boolean> {
  const raw = fragmentOrQuery.startsWith('#') || fragmentOrQuery.startsWith('?')
    ? fragmentOrQuery.slice(1)
    : fragmentOrQuery
  const params = new URLSearchParams(raw)

  const accessToken = params.get('access_token')
  const refreshToken = params.get('refresh_token')
  const expiresIn = params.get('expires_in')

  if (!accessToken) {
    // Maybe a PKCE code was returned instead; exchange it for a session.
    const code = params.get('code')
    if (code) {
      const { error } = await supabase.auth.exchangeCodeForSession(code)
      return !error
    }
    return false
  }

  const session: {
    access_token: string
    refresh_token?: string
    token_type: string
    expires_at?: number
  } = {
    access_token: accessToken,
    token_type: 'bearer',
  }
  if (refreshToken) session.refresh_token = refreshToken
  if (expiresIn) session.expires_at = Math.floor(Date.now() / 1000) + Number(expiresIn)
  const { error } = await supabase.auth.setSession(session as Parameters<typeof supabase.auth.setSession>[0])
  return !error
}

export default defineBoot(() => {
  if (!Capacitor.isNativePlatform()) return

  void App.addListener('appUrlOpen', (event) => {
    const url = String((event && event.url) || '')
    const m = /^com\.accommo\.app:\/\/auth\/callback([#?].*)$/.exec(url)
    if (!m || !m[1]) return
    void (async () => {
      const ok = await applyOAuthTokens(m[1]!)
      if (ok) window.location.reload()
    })()
  })
})
