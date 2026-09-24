// The navigation decision, separated from the session lookup that feeds it.
//
// index.ts used to interleave "ask Supabase who this is" with "decide where
// they may go", which made the decision impossible to test and easy to get
// subtly wrong — two of its rules had already drifted from the comments above
// them. Everything here is a pure function of the state the guard has already
// fetched; index.ts keeps the awaits and the side effects.

export type GuardRole = 'student' | 'manager' | 'admin' | null

export interface GuardState {
  /** The path being navigated to. */
  path: string
  authenticated: boolean
  /** `null` when the users row is missing or its role is unrecognised. */
  role: GuardRole
  /** `users.status`, or null when it could not be read. */
  status: string | null
  /** `users.email_verified_at !== null`, or null when unread. */
  emailVerified: boolean | null
  /** `users.registered_at !== null`, or null when unread. */
  registered: boolean | null
  /**
   * The users row could not be read at all (offline, RLS answering an
   * unattached JWT on a cold launch). `role` may still be filled in from the
   * token's own claim, but nothing here was confirmed by the database — so no
   * decision that ends the session may be taken on it.
   */
  lookupFailed?: boolean
}

export interface GuardDecision {
  /** `true` allows the navigation; a string redirects to it. */
  to: true | string
  /** When set, the caller must sign the session out before honouring `to`. */
  signOut: boolean
}

/**
 * Routes reachable without a session. Kept here rather than in index.ts so the
 * tests and the guard cannot disagree about what "public" means.
 */
export const PUBLIC_ROUTES = ['/', '/login', '/register', '/register/role', '/register/manager']

const ALLOW: GuardDecision = { to: true, signOut: false }
const go = (to: string, signOut = false): GuardDecision => ({ to, signOut })

export function resolveDestination(s: GuardState): GuardDecision {
  const isPublicRoute = PUBLIC_ROUTES.includes(s.path)
  const isRegister = s.path.startsWith('/register')

  if (!s.authenticated) return isPublicRoute ? ALLOW : go('/login')

  if (!isRegister) {
    // Suspension bites on every navigation, not just at sign-in, or a session
    // minted before the suspension keeps working until its token expires.
    if (s.role !== null && s.status === 'suspended') return go('/login?suspended=true', true)

    // Signed in but never proved they read their e-mail. The session is kept so
    // the login screen can offer them a code instead of a dead end.
    //
    // /login must be ALLOWED here rather than redirected to: redirecting
    // unconditionally also redirected the navigation to /login?verifyEmail=true
    // itself, which Vue Router aborts as an infinite redirect, and the app never
    // booted.
    if (s.role !== null && s.emailVerified === false) {
      if (s.path === '/login') return ALLOW
      return go('/login?verifyEmail=true')
    }

    // The account exists but its owner never finished registering — the normal
    // state right after "Continue with Google", which provisions a user whether
    // they came from login or register. Send them to pick a role rather than
    // dropping them into the app as a student.
    if (s.role !== null && s.registered === false) {
      if (s.path === '/login') return ALLOW
      return go('/register/role')
    }
  }

  if (isRegister) {
    // Only a FINISHED account is barred from re-registering. The check used to
    // be "has a users row", but the auth trigger always creates one, so a
    // brand-new Google signup was evicted with "account already exists" and
    // could never complete its profile.
    //
    // A landlord/landlady OSAS has sent back is registered but must still reach this
    // screen to correct the application, or the eviction below would sign them
    // out before the resubmission redirect could run.
    const resubmitting =
      s.role === 'manager' && (s.status === 'rejected' || s.status === 'reviewing')
    if (s.role !== null && s.registered === true && !resubmitting) {
      return go('/login?accountExists=true', true)
    }
    return ALLOW
  }

  if (s.path === '/profile') {
    if (s.role === 'manager') return go('/manager/profile')
    if (s.role === 'student') return go('/student/profile')
  }

  if (isPublicRoute) {
    if (s.role === 'student') return go('/student/home')
    if (s.role === 'manager') return go('/manager/dashboard')
    // Admin/OSAS lives in the web client; this app has no admin surface.
    if (s.role === 'admin') return go('/login?adminUsesWeb=true', true)
    // We hold a session but never got an answer about it. Stay put rather than
    // evicting someone over a failed read — the next navigation asks again,
    // and by then the network is usually up.
    if (s.lookupFailed) return ALLOW
    // Missing or unrecognised role: an invalid account state. Land somewhere
    // still public rather than returning '/' again, which would re-enter this
    // guard and loop forever.
    return go('/register?newUser=true', true)
  }

  // Without this, LoginPage's push to an admin route fell through to a 404
  // instead of saying the admin console is elsewhere.
  if (s.role === 'admin') return go('/login?adminUsesWeb=true', true)

  // A landlord/landlady uses the app before OSAS verifies them — pending, or sent
  // back for changes — and only adding inventory waits. The one screen that
  // exists for nothing else is the new-accommodation form, so it bounces to the
  // list, where the reason is shown. Only on a status actually read: a failed
  // lookup (status null) must not lock a verified account out.
  if (
    s.role === 'manager' &&
    s.status !== null &&
    s.status !== 'verified' &&
    s.path === '/manager/properties/new'
  ) {
    return go('/manager/properties')
  }

  if (s.path.startsWith('/student') && s.role !== 'student') {
    return go(s.role === 'manager' ? '/manager/dashboard' : '/login')
  }
  if (s.path.startsWith('/manager') && s.role !== 'manager') {
    return go(s.role === 'student' ? '/student/home' : '/login')
  }

  return ALLOW
}
