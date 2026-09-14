import { beforeEach, describe, expect, it } from 'vitest'
import { prompt, settlePin, type PinPrompt } from './requirePin'

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
