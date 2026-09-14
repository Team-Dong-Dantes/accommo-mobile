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

export function requirePin(options: RequirePinOptions = {}): Promise<boolean> {
  const pin = usePinStore()

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
    settle = resolve
    prompt.value = {
      mode,
      title: options.title ?? (mode === 'confirm' ? 'Are you sure?' : 'Enter your PIN'),
      ...(options.message ? { message: options.message } : {}),
    }
  })
}

/** Covers the app after it has been in the background too long. Not cancellable. */
export function lockApp() {
  const pin = usePinStore()
  if (!pin.hasPin || prompt.value?.mode === 'lock') return
  pin.lock()
  prompt.value = {
    mode: 'lock',
    title: 'Welcome back',
    message: 'Enter your PIN to unlock Accommo.',
  }
}

/** Called by PinGate when the user succeeds or backs out. */
export function settlePin(ok: boolean) {
  prompt.value = null
  const resolve = settle
  settle = null
  resolve?.(ok)
}
