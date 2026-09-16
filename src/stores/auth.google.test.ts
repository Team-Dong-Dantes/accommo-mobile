import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

// The native Google branch of loginWithGoogle(): Android's account picker hands
// back an ID token that Supabase trades for a session in place. The three cases
// worth pinning are the ones that used to be invisible failures — a build with
// no client ID, a picker the user backs out of, and the happy path actually
// reaching signInWithIdToken with the token Google returned.

const login = vi.fn()
const signInWithIdToken = vi.fn()
const signInWithOAuth = vi.fn()

vi.mock('@capacitor/core', () => ({ Capacitor: { isNativePlatform: () => true } }))
vi.mock('@capgo/capacitor-social-login', () => ({
  SocialLogin: { initialize: vi.fn(), login: (...a: unknown[]) => login(...a) },
}))
vi.mock('@/utils/supabase', () => ({
  supabase: { auth: { signInWithIdToken, signInWithOAuth } },
  getCurrentUser: vi.fn(),
}))

const { useAuthStore } = await import('./auth')

describe('loginWithGoogle on a device', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    // vitest has no quasar.config define step, so this stands in for it.
    vi.stubEnv('VITE_GOOGLE_WEB_CLIENT_ID', 'web-client-id.apps.googleusercontent.com')
  })

  it('never falls back to a browser redirect', async () => {
    login.mockResolvedValue({ provider: 'google', result: { idToken: 'jwt' } })
    signInWithIdToken.mockResolvedValue({ data: { session: { access_token: 'a' } }, error: null })

    await useAuthStore().loginWithGoogle('/login')

    expect(signInWithIdToken).toHaveBeenCalledWith({ provider: 'google', token: 'jwt' })
    expect(signInWithOAuth).not.toHaveBeenCalled()
  })

  it('treats a dismissed account sheet as no session, not an error', async () => {
    login.mockRejectedValue(new Error('activity is cancelled by the user.'))
    await expect(useAuthStore().loginWithGoogle('/login')).resolves.toBeNull()
  })

  it('says so when the build has no client ID instead of silently redirecting', async () => {
    vi.stubEnv('VITE_GOOGLE_WEB_CLIENT_ID', '')
    await expect(useAuthStore().loginWithGoogle('/login')).rejects.toThrow(
      /VITE_GOOGLE_WEB_CLIENT_ID/,
    )
    expect(signInWithOAuth).not.toHaveBeenCalled()
  })
})
