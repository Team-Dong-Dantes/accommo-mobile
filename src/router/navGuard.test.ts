import { describe, expect, it, vi } from 'vitest'
import { createNavGuard, type Account, type NavGuardDeps, type SessionInfo } from './navGuard'

const ACTIVE: Account = {
  role: 'student',
  status: 'active',
  emailVerified: true,
  registered: true,
  lookupFailed: false,
}

function setup(opts: { user?: string | null; live?: boolean; accounts?: Account[] } = {}) {
  let user = opts.user === undefined ? 'u1' : opts.user
  const accounts = [...(opts.accounts ?? [ACTIVE])]
  let path = '/student/home'
  const deps = {
    session: vi.fn(async (): Promise<SessionInfo<string> | null> =>
      user ? { userId: user, live: opts.live ?? true, raw: user } : null,
    ),
    // Each read answers with the next queued account, the last one repeating.
    lookup: vi.fn(async () => (accounts.length > 1 ? accounts.shift()! : accounts[0]!)),
    signOut: vi.fn(async () => {
      user = null
    }),
    markActive: vi.fn(),
    currentPath: () => path,
    replace: vi.fn(),
  } satisfies NavGuardDeps<string>
  const nav = createNavGuard(deps)
  // Navigate the way the router does: guard, then (if allowed) land and revalidate.
  const go = async (to: string) => {
    const d = await nav.guard(to)
    if (d.to === true) path = to
    await nav.revalidate()
    return d
  }
  return {
    deps,
    nav,
    go,
    setUser: (u: string) => {
      user = u
    },
  }
}

describe('when the guard waits for the network', () => {
  it('waits on the first navigation, with nothing remembered', async () => {
    const { deps, go } = setup()
    expect((await go('/student/home')).to).toBe(true)
    expect(deps.lookup).toHaveBeenCalledTimes(1)
  })

  it('lets a later navigation through without waiting for the read', async () => {
    const { deps, nav, go } = setup()
    await go('/student/home')
    // A read that never answers: the guard must not be stuck behind it.
    deps.lookup.mockImplementation(() => new Promise<Account>(() => {}))
    await expect(nav.guard('/student/stay')).resolves.toEqual({ to: true, signOut: false })
  })

  it('does not reuse one account’s answer for another', async () => {
    const { deps, go, setUser } = setup()
    await go('/student/home')
    setUser('u2')
    deps.lookup.mockClear()
    await go('/student/stay')
    expect(deps.lookup).toHaveBeenCalled()
  })

  it('never redirects on a remembered answer — a stale "not registered" is re-read first', async () => {
    // Remembered from before registration finished; the database now says done.
    const { deps, go } = setup({ accounts: [{ ...ACTIVE, registered: false }, ACTIVE] })
    expect((await go('/register/role')).to).toBe(true)
    const d = await go('/student/home')
    expect(d).toEqual({ to: true, signOut: false })
    expect(deps.signOut).not.toHaveBeenCalled()
  })
})

describe('suspended mid-session', () => {
  it('is signed out by the background check after the screen opens', async () => {
    const { deps, go } = setup({ accounts: [ACTIVE, { ...ACTIVE, status: 'suspended' }] })
    await go('/student/home')
    await go('/student/stay')
    expect(deps.signOut).toHaveBeenCalledTimes(1)
    expect(deps.replace).toHaveBeenCalledWith('/login?suspended=true')
  })

  it('is signed out before the screen when the account was never remembered as active', async () => {
    const { deps, go } = setup({ accounts: [{ ...ACTIVE, status: 'suspended' }] })
    expect((await go('/student/home')).to).toBe('/login?suspended=true')
    expect(deps.signOut).toHaveBeenCalledTimes(1)
  })
})

describe('offline', () => {
  it('keeps the user in when the row cannot be read', async () => {
    const offline: Account = { role: 'student', status: null, emailVerified: null, registered: null, lookupFailed: true }
    const { deps, go } = setup({ accounts: [ACTIVE, offline] })
    await go('/student/home')
    expect((await go('/student/stay')).to).toBe(true)
    expect(deps.signOut).not.toHaveBeenCalled()
    expect(deps.replace).not.toHaveBeenCalled()
  })
})
