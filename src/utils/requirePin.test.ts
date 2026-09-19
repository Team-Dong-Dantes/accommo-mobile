import { beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { usePinStore } from '@/stores/pin'
import { lockApp, prompt, requirePin, settlePin, type PinPrompt } from './requirePin'

// The bug this guards against, which shipped once: the resume lock IS
// `prompt.value` — nothing else covers the app — and settlePin cleared it
// unconditionally. "Forgot your PIN?" called settlePin(false) and navigated to
// Settings, so the cover came off and the app sat open with the PIN never
// entered.
//
// settlePin is the only place in the codebase that writes `prompt.value = null`,
// so these four cases cover every way the prompt can be dismissed.

const lock: PinPrompt = { mode: 'lock', title: 'Welcome back' }

beforeEach(() => {
  prompt.value = null
})

describe('a lock prompt', () => {
  it('survives a failed settle', () => {
    prompt.value = { ...lock }
    settlePin(false)
    expect(prompt.value).not.toBeNull()
  })

  it('survives repeated failed settles', () => {
    prompt.value = { ...lock }
    settlePin(false)
    settlePin(false)
    expect(prompt.value?.mode).toBe('lock')
  })

  it('clears only on success', () => {
    prompt.value = { ...lock }
    settlePin(true)
    expect(prompt.value).toBeNull()
  })
})

// The guard must not make the ordinary prompts un-cancellable: an action asked
// for by a screen is dismissed by Cancel or a backdrop tap, and that still has
// to work.
describe('the cancellable prompts', () => {
  it('lets an action prompt be cancelled', () => {
    prompt.value = { mode: 'action', title: 'Enter your PIN' }
    settlePin(false)
    expect(prompt.value).toBeNull()
  })

  it('lets a confirm prompt be dismissed', () => {
    prompt.value = { mode: 'confirm', title: 'Are you sure?' }
    settlePin(false)
    expect(prompt.value).toBeNull()
  })
})

// There is one resolver for the whole app, so anything that replaces
// `prompt.value` owes an answer to whatever was already waiting on it. Both
// directions of getting that wrong shipped, and one of them was destructive.
describe('a superseded request', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    prompt.value = null
    const pin = usePinStore()
    pin.hasPin = true
    pin.ready = true
  })

  // Let requirePin's `await pin.ensureReady()` settle so the prompt is up.
  const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

  // The one that could destroy data: ask for the PIN to delete an
  // accommodation, background the phone past the resume window, come back, and
  // the PIN typed at the lock screen used to resolve the DELETE underneath it
  // as `true`. Unlocking your own phone deleted the accommodation.
  it('does not let the resume lock confirm the action it covered', async () => {
    const pending = requirePin({ title: 'Delete this accommodation?' })
    await flush()
    expect(prompt.value?.mode).toBe('action')

    await lockApp()
    expect(prompt.value?.mode).toBe('lock')

    settlePin(true)
    await expect(pending).resolves.toBe(false)
  })

  // The other direction: a second prompt used to overwrite the first one's
  // resolver, so the first promise never settled and its caller sat behind a
  // `busy` flag for the rest of the session.
  it('answers the request it replaced instead of dropping it', async () => {
    const first = requirePin({ title: 'Delete this room?' })
    await flush()
    const second = requirePin({ title: 'Change this room’s rent?' })
    await flush()

    await expect(first).resolves.toBe(false)
    expect(prompt.value?.title).toBe('Change this room’s rent?')

    settlePin(true)
    await expect(second).resolves.toBe(true)
  })
})
