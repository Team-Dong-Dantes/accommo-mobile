import { describe, expect, it } from 'vitest'
import { resolveHasPin } from './pin'

// The lock screen used to fail open. `has_pin` is asked once at startup, any
// error meant "no PIN", and requirePin() waves everything through on that — so a
// phone force-stopped and reopened in airplane mode came up unlocked, and
// restoring the network afterwards gave full access without the PIN ever being
// asked for.
describe('resolveHasPin', () => {
  it('trusts a successful answer over anything cached', () => {
    expect(resolveHasPin(false, true, false)).toBe(true)
    // Someone who cleared their PIN elsewhere must stop being gated here, or
    // they are stranded at a lock screen for a PIN that no longer exists.
    expect(resolveHasPin(false, false, true)).toBe(false)
  })

  it('treats a non-true answer as no PIN', () => {
    expect(resolveHasPin(false, null, false)).toBe(false)
    expect(resolveHasPin(false, undefined, false)).toBe(false)
  })

  // The fix: offline, fall back to what was last known for this account.
  it('falls back to the cache when the call fails', () => {
    expect(resolveHasPin(true, null, true)).toBe(true)
    expect(resolveHasPin(true, null, false)).toBe(false)
  })

  // The regression guard. If this ever returns false again, the gate is open to
  // anyone who can turn off the radio on a phone they are holding.
  it('still gates an account known to have a PIN when offline', () => {
    expect(resolveHasPin(true, undefined, true)).toBe(true)
  })

  // Nobody who never set a PIN gets locked out by a bad connection.
  it('does not invent a PIN for an account that never had one', () => {
    expect(resolveHasPin(true, undefined, false)).toBe(false)
  })
})
