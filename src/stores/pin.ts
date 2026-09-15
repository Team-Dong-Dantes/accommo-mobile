import { defineStore } from 'pinia'
import { supabase } from '@/utils/supabase'

/**
 * How long one correct entry keeps the app unlocked. A manager verifying six
 * payments should not type the PIN six times; five minutes is long enough to
 * finish a task and short enough that a phone left on a table re-locks.
 */
const GRACE_MS = 5 * 60_000

/**
 * How long the app may sit in the background before it locks. Low enough to
 * matter, high enough that switching to the camera or a messaging app and
 * coming straight back does not demand the PIN.
 */
export const RESUME_LOCK_MS = 2 * 60_000

/**
 * Remembers, per account, whether that account has a PIN.
 *
 * The lock screen used to fail open: `has_pin` was asked once at startup and any
 * error meant `hasPin = false`, which makes `requirePin()` wave everything
 * through and `lockApp()` return immediately. Since nothing asks again, a phone
 * force-stopped and reopened in airplane mode came up unlocked, and restoring
 * the network afterwards gave full access with the PIN never asked for. The
 * PIN's whole threat model is someone holding the phone, and that person
 * controls the radio.
 *
 * Failing open is still right for *data* — the server refuses protected calls on
 * its own terms — but not for the gate itself. Keyed by user id so a shared
 * device never gates one account on another's answer.
 */
const CACHE_PREFIX = 'accommo.pin.has.'

/**
 * What `hasPin` should be. Split out from the store so the branch that matters
 * is testable without standing up Supabase.
 *
 * A successful answer always wins and is what gets cached. A failed one falls
 * back to what was last known for this account, so only someone who has actually
 * set a PIN is gated offline — nobody who never set one is locked out by a bad
 * connection.
 */
export function resolveHasPin(rpcFailed: boolean, rpcValue: unknown, cached: boolean): boolean {
  return rpcFailed ? cached : rpcValue === true
}

async function cacheKey(): Promise<string | null> {
  // getSession reads local storage rather than calling the server, so it still
  // answers with no network — which is the case this whole thing exists for.
  const { data } = await supabase.auth.getSession()
  const id = data?.session?.user?.id
  return id ? `${CACHE_PREFIX}${id}` : null
}

function readCache(key: string | null): boolean {
  if (!key) return false
  try {
    return localStorage.getItem(key) === '1'
  } catch {
    return false
  }
}

function writeCache(key: string | null, value: boolean) {
  if (!key) return
  try {
    if (value) localStorage.setItem(key, '1')
    else localStorage.removeItem(key)
  } catch {
    // Storage unavailable. The next successful refresh will try again.
  }
}

export const usePinStore = defineStore('pin', {
  state: () => ({
    /** Whether this account has a PIN at all. Everything is a no-op when false. */
    hasPin: false,
    /** False until `refresh()` has answered, so nothing gates on a guess. */
    ready: false,
    unlockedUntil: 0,
    /** When the app went to the background; 0 while it is in the foreground. */
    backgroundedAt: 0,
  }),

  getters: {
    unlocked: (state) => Date.now() < state.unlockedUntil,
  },

  actions: {
    async refresh() {
      const key = await cacheKey()
      const { data, error } = await supabase.rpc('has_pin')
      this.hasPin = resolveHasPin(!!error, data, readCache(key))
      // Only a real answer updates the cache; a failure must not erase what we
      // knew, or airplane mode would clear the gate a second time.
      if (!error) writeCache(key, this.hasPin)
      this.ready = true
    },

    /**
     * Records that a PIN was just set or cleared. The setup dialog used to
     * assign `hasPin` directly, which left the cache stale — and a stale "has a
     * PIN" after clearing one would strand someone at a lock screen for a PIN
     * that no longer exists.
     */
    async setHasPin(value: boolean) {
      this.hasPin = value
      writeCache(await cacheKey(), value)
    },

    /** True when the PIN was right. Throws on lockout, which the pad shows. */
    async verify(pin: string): Promise<boolean> {
      const { data, error } = await supabase.rpc('verify_pin', { p_pin: pin })
      if (error) throw new Error(error.message)
      if (data === true) {
        this.unlockedUntil = Date.now() + GRACE_MS
        return true
      }
      return false
    },

    /** Ends the grace window — used on sign-out and when the app is locked. */
    lock() {
      this.unlockedUntil = 0
    },
  },
})
