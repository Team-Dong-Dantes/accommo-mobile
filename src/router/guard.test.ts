import { describe, expect, it } from 'vitest'
import { resolveDestination, type GuardState } from './guard'

// A fully-approved, signed-in student. Each test overrides only what it is about.
const student = (over: Partial<GuardState> = {}): GuardState => ({
  path: '/student/home',
  authenticated: true,
  role: 'student',
  status: 'active',
  emailVerified: true,
  registered: true,
  ...over,
})

describe('signed out', () => {
  it('allows the public routes', () => {
    for (const path of ['/', '/login', '/register', '/register/role', '/register/manager']) {
      expect(resolveDestination(student({ path, authenticated: false, role: null }))).toEqual({
        to: true,
        signOut: false,
      })
    }
  })

  it('sends everything else to login', () => {
    expect(resolveDestination(student({ path: '/student/home', authenticated: false, role: null })).to)
      .toBe('/login')
  })
})

describe('suspension', () => {
  // The bug this guards: status was cached for the life of the app, so a
  // suspension mid-session did not bite until a restart.
  it('evicts a suspended student and signs them out', () => {
    expect(resolveDestination(student({ status: 'suspended' }))).toEqual({
      to: '/login?suspended=true',
      signOut: true,
    })
  })

  it('evicts a suspended manager too', () => {
    const d = resolveDestination(student({ role: 'manager', path: '/manager/dashboard', status: 'suspended' }))
    expect(d).toEqual({ to: '/login?suspended=true', signOut: true })
  })

  it('does not evict on a register path, so a resubmission can still be reached', () => {
    expect(resolveDestination(student({ path: '/register/manager', status: 'suspended', registered: false })).to)
      .toBe(true)
  })
})

describe('unverified e-mail', () => {
  it('redirects an app route to the verify prompt', () => {
    expect(resolveDestination(student({ emailVerified: false })).to).toBe('/login?verifyEmail=true')
  })

  // Regression: redirecting unconditionally also redirected the navigation to
  // /login?verifyEmail=true itself, which Vue Router aborts as an infinite
  // redirect — the app never booted.
  it('allows /login itself rather than redirecting it to /login', () => {
    expect(resolveDestination(student({ path: '/login', emailVerified: false })).to).toBe(true)
  })

  it('never signs the session out — the login screen needs it to send a code', () => {
    expect(resolveDestination(student({ emailVerified: false })).signOut).toBe(false)
  })
})

describe('unfinished registration', () => {
  // The state right after "Continue with Google": the auth trigger made a users
  // row, but the person never picked a role.
  it('sends an unregistered account to pick a role', () => {
    expect(resolveDestination(student({ registered: false })).to).toBe('/register/role')
  })

  it('lets them reach /login', () => {
    expect(resolveDestination(student({ path: '/login', registered: false })).to).toBe(true)
  })

  it('lets them reach the register screens', () => {
    expect(resolveDestination(student({ path: '/register/role', registered: false })).to).toBe(true)
  })
})

describe('re-registering', () => {
  it('evicts a finished account from the register screens', () => {
    expect(resolveDestination(student({ path: '/register' }))).toEqual({
      to: '/login?accountExists=true',
      signOut: true,
    })
  })

  // A manager OSAS sent back is registered but must still reach the form.
  it.each(['rejected', 'reviewing'])('lets a %s manager back in to resubmit', (status) => {
    expect(resolveDestination(student({ path: '/register/manager', role: 'manager', status })).to)
      .toBe(true)
  })
})

describe('manager approval', () => {
  it('holds a pending manager out entirely', () => {
    expect(resolveDestination(student({ path: '/manager/dashboard', role: 'manager', status: 'pending' })))
      .toEqual({ to: '/login?awaitingApproval=true', signOut: true })
  })

  // Students are deliberately not treated this way — a pending student may browse.
  it('lets a pending student browse', () => {
    expect(resolveDestination(student({ status: 'pending' })).to).toBe(true)
  })

  it.each(['rejected', 'reviewing'])('routes a %s manager to the resubmission form', (status) => {
    expect(resolveDestination(student({ path: '/manager/dashboard', role: 'manager', status })).to)
      .toBe('/register/manager?resubmit=true')
  })
})

describe('role separation', () => {
  it('keeps a manager out of student routes', () => {
    expect(resolveDestination(student({ path: '/student/home', role: 'manager' })).to)
      .toBe('/manager/dashboard')
  })

  it('keeps a student out of manager routes', () => {
    expect(resolveDestination(student({ path: '/manager/dashboard', role: 'student' })).to)
      .toBe('/student/home')
  })

  it('sends an admin to the web client instead of a 404', () => {
    expect(resolveDestination(student({ path: '/manager/dashboard', role: 'admin' })))
      .toEqual({ to: '/login?adminUsesWeb=true', signOut: true })
  })

  it('sends an admin away from a public route too', () => {
    expect(resolveDestination(student({ path: '/', role: 'admin' })))
      .toEqual({ to: '/login?adminUsesWeb=true', signOut: true })
  })
})

describe('landing a signed-in user', () => {
  it('sends a student home', () => {
    expect(resolveDestination(student({ path: '/' })).to).toBe('/student/home')
  })

  it('sends a manager to their dashboard', () => {
    expect(resolveDestination(student({ path: '/login', role: 'manager' })).to).toBe('/manager/dashboard')
  })

  // An unrecognised role is an invalid account state. It must not return '/'
  // again — that re-enters this guard and loops forever.
  it('signs out an account with no usable role', () => {
    const d = resolveDestination(student({ path: '/', role: null }))
    expect(d).toEqual({ to: '/register?newUser=true', signOut: true })
    expect(d.to).not.toBe('/')
  })
})

describe('/profile shortcut', () => {
  it('resolves to the role-specific profile', () => {
    expect(resolveDestination(student({ path: '/profile' })).to).toBe('/student/profile')
    expect(resolveDestination(student({ path: '/profile', role: 'manager' })).to).toBe('/manager/profile')
  })
})
