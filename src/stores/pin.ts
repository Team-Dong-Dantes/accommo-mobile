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
      const { data, error } = await supabase.rpc('has_pin')
      // A failure here must not lock anyone out of their own app: treat an
      // unknown answer as "no PIN" rather than prompting for one they may not
      // have. The server still refuses every protected RPC on its own terms.
      this.hasPin = !error && data === true
      this.ready = true
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
