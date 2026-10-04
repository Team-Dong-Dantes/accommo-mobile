// When the guard has to wait for the network, and when it doesn't.
//
// The guard used to read the users row before EVERY navigation, so on a slow
// connection each tab tap and back press sat on a round-trip before the next
// screen appeared. Now the last answer is remembered per user:
//
//   * no answer yet (cold launch, another account) -> read, and wait for it
//   * the remembered answer lets the navigation through -> go at once, and
//     re-read in the background once the new screen is up (`revalidate`)
//   * the remembered answer would redirect or sign out -> read fresh first;
//     nothing that moves or evicts the user is decided on a stale answer
//
// A suspension still bites mid-session: the background read evicts the user
// from whatever screen they are on, one round-trip later instead of before.
//
// Kept free of Vue Router and Supabase so the timing rules can be tested; the
// wiring lives in index.ts.
import { resolveDestination, type GuardDecision, type GuardRole } from './guard'

/** What the users row said, or the token's claim when it could not be read. */
export interface Account {
  role: GuardRole
  status: string | null
  emailVerified: boolean | null
  registered: boolean | null
  /** The row could not be read; see GuardState.lookupFailed. */
  lookupFailed: boolean
}

export interface SessionInfo<S> {
  userId: string
  /** False when only the stored copy remains (token expired, refresh pending). */
  live: boolean
  raw: S
}

export interface NavGuardDeps<S> {
  session(): Promise<SessionInfo<S> | null>
  /** Reads the users row. Must not throw; a failed read sets lookupFailed. */
  lookup(session: S): Promise<Account>
  signOut(): Promise<void>
  /** Called when a navigation is let through on a live session. */
  markActive(): void
  currentPath(): string
  replace(to: string): unknown
}

export const allows = (d: GuardDecision) => d.to === true && !d.signOut

export function createNavGuard<S>(deps: NavGuardDeps<S>) {
  let known: { userId: string; account: Account } | null = null
  let inFlight: Promise<Account> | null = null
  // Set when a navigation went through on the remembered answer.
  let unconfirmed = false

  const read = (s: SessionInfo<S>) => {
    inFlight ??= deps
      .lookup(s.raw)
      .then((account) => {
        known = { userId: s.userId, account }
        return account
      })
      .finally(() => {
        inFlight = null
      })
    return inFlight
  }

  const decide = (path: string, s: SessionInfo<S>, a: Account) =>
    resolveDestination({
      path,
      authenticated: true,
      role: a.role,
      status: a.status,
      emailVerified: a.emailVerified,
      registered: a.registered,
      // Running on the stored copy alone, nothing the database says can be
      // trusted to end the session either.
      lookupFailed: a.lookupFailed || !s.live,
    })

  const evict = async () => {
    await deps.signOut()
    known = null
  }

  /** The beforeEach handler, minus Vue Router. */
  async function guard(path: string): Promise<GuardDecision> {
    const s = await deps.session()
    if (!s) {
      return resolveDestination({
        path,
        authenticated: false,
        role: null,
        status: null,
        emailVerified: null,
        registered: null,
      })
    }

    let decision: GuardDecision | null = null
    if (known?.userId === s.userId) {
      const remembered = decide(path, s, known.account)
      if (allows(remembered)) {
        decision = remembered
        unconfirmed = true
      }
    }
    decision ??= decide(path, s, await read(s))

    if (decision.signOut) await evict()
    else if (s.live) deps.markActive()
    return decision
  }

  /** Confirms the last remembered answer against the database. Run after each navigation. */
  async function revalidate() {
    if (!unconfirmed) return
    unconfirmed = false
    const s = await deps.session()
    if (!s) return
    const decision = decide(deps.currentPath(), s, await read(s))
    if (allows(decision)) return
    if (decision.signOut) await evict()
    await deps.replace(decision.to as string)
  }

  return { guard, revalidate }
}
