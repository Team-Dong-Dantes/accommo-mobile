import { ref } from 'vue'
import { usePinStore } from '@/stores/pin'

/**
 * One PIN pad for the whole app, driven by a module-level request rather than a
 * component tree. Any action can `await requirePin()` and get a boolean back,
 * the same trick a confirm dialog uses, so a call site stays one line:
 *
 *   if (!(await requirePin())) return
 *
 * `PinGate.vue` (mounted once in MainLayout) renders whatever is in `prompt`
 * and calls `settlePin`.
 */
export interface PinPrompt {
  /**
   * 'action'  asks for the PIN and can be cancelled
   * 'lock'    covers the app after a long background, and cannot be cancelled
   * 'confirm' the same card asking the same question in words, for accounts
   *           with no PIN — see `confirm` below
   */
  mode: 'action' | 'lock' | 'confirm'
  title: string
  message?: string
}

export const prompt = ref<PinPrompt | null>(null)

let settle: ((ok: boolean) => void) | null = null

/**
 * Hands the pending request its answer and clears the slot.
 *
 * There is one `settle` for the whole app, so anything that replaces
 * `prompt.value` must answer whatever was already waiting on it — otherwise the
 * resolver is simply dropped. That went wrong in both directions: two
 * overlapping `requirePin()` calls left the first promise unresolved forever
 * (its caller stuck behind a `busy` flag), and `lockApp()` swapped the prompt
 * without touching `settle`, so entering the PIN at the resume lock resolved the
 * *action* underneath it as `true` — backgrounding the app with "Delete this
 * accommodation?" on screen deleted the accommodation on unlock.
 */
function release(ok: boolean) {
  const resolve = settle
  settle = null
  resolve?.(ok)
}

export interface RequirePinOptions {
  /**
   * Ignore the grace window and always ask. For changing an e-mail or password:
   * those are the only actions nobody can undo, and they are rare enough that
   * the extra entry costs nothing.
   */
  always?: boolean
  /**
   * For an action that fires on one tap and cannot be taken back: with no PIN
   * on the account, ask the same question in words instead of proceeding
   * silently. Leave it off where the caller has its own confirmation (a delete
   * dialog, a sheet demanding a written reason) or where the gate protects a
   * read rather than a decision — a pointless "are you sure?" is exactly the
   * kind of prompt people learn to tap through.
   */
  confirm?: boolean
  title?: string
  message?: string
}

export async function requirePin(options: RequirePinOptions = {}): Promise<boolean> {
  const pin = usePinStore()

  // `hasPin` defaults to false and is only filled in by an RPC, so until that
  // answers every gate here waved everything through — a window wide enough to
  // tap a gated action on the screen the app opens on. `ready` existed to say
  // exactly this and nothing consulted it.
  await pin.ensureReady()

  // No PIN on the account: nothing to ask for, so either confirm in words or
  // proceed silently, exactly as this action behaved before the PIN existed.
  if (!pin.hasPin) {
    return options.confirm ? ask('confirm', options) : Promise.resolve(true)
  }
  // Inside the grace window the PIN was entered moments ago; asking again is
  // what makes people stop reading the prompt.
  if (!options.always && pin.unlocked) return Promise.resolve(true)

  return ask('action', options)
}

function ask(mode: 'action' | 'confirm', options: RequirePinOptions): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    // Superseding a prompt cancels the request it belonged to. Answering `false`
    // is the only safe reading: the user never saw that question through.
    release(false)
    settle = resolve
    prompt.value = {
      mode,
      title: options.title ?? (mode === 'confirm' ? 'Are you sure?' : 'Enter your PIN'),
      ...(options.message ? { message: options.message } : {}),
    }
  })
}

/** Covers the app after it has been in the background too long. Not cancellable. */
export async function lockApp() {
  const pin = usePinStore()
  // Same reason requirePin() awaits it: a cold launch reaches here before the
  // has-PIN answer does, and an unanswered `hasPin` used to mean "no lock".
  await pin.ensureReady()
  if (!pin.hasPin || prompt.value?.mode === 'lock') return
  pin.lock()
  // Whatever was waiting on the PIN when the app went away does not get to
  // resume on the back of the unlock — see release().
  release(false)
  prompt.value = {
    mode: 'lock',
    title: 'Welcome back',
    message: 'Enter your PIN to unlock Accommo.',
  }
}

/** Called by PinGate when the user succeeds or backs out. */
export function settlePin(ok: boolean) {
  // A lock prompt IS the cover over the app — there is nothing else hiding it.
  // So it may only be cleared by success: a correct PIN, or a completed reset.
  // The guard lives here rather than in each caller because every path routes
  // through this one function, and a caller that forgot ("Forgot your PIN?"
  // used to call settlePin(false) and navigate) silently unlocked the app.
  if (!ok && prompt.value?.mode === 'lock') return

  prompt.value = null
  release(ok)
}
