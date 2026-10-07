import { ref } from 'vue'

/**
 * One confirmation card for the whole app, driven by a module-level request
 * rather than a component tree, so a call site stays one line:
 *
 *   if (!(await confirmAction({ title: 'Accept this application?' }))) return
 *
 * For actions that fire on one tap and cannot be taken back. Leave it off where
 * the caller has its own confirmation (a delete dialog, a sheet demanding a
 * written reason) — a pointless "are you sure?" is exactly the kind of prompt
 * people learn to tap through.
 *
 * `ConfirmGate.vue` (mounted once in MainLayout) renders whatever is in
 * `prompt` and calls `settleConfirm`.
 */
export interface ConfirmPrompt {
  title: string
  message?: string
}

export const prompt = ref<ConfirmPrompt | null>(null)

let settle: ((ok: boolean) => void) | null = null

/**
 * Hands the pending request its answer and clears the slot. There is one
 * `settle` for the whole app, so a new request must answer whatever was already
 * waiting — otherwise the first caller hangs forever behind its `busy` flag.
 */
function release(ok: boolean) {
  const resolve = settle
  settle = null
  resolve?.(ok)
}

export function confirmAction(options: { title?: string; message?: string } = {}): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    // Superseding a prompt cancels the request it belonged to: the user never
    // saw that question through.
    release(false)
    settle = resolve
    prompt.value = {
      title: options.title ?? 'Are you sure?',
      ...(options.message ? { message: options.message } : {}),
    }
  })
}

/** Called by ConfirmGate when the user confirms or backs out. */
export function settleConfirm(ok: boolean) {
  prompt.value = null
  release(ok)
}
