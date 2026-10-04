// Network calls that give up. supabase-js's fetch has no deadline of its own,
// so on a weak signal a read could stall for minutes with its screen stuck on
// a skeleton, instead of failing over to cached rows or a Retry.

/** A signal that aborts after `ms`, or when `parent` does. */
export function timeoutSignal(ms: number, parent?: AbortSignal | null): AbortSignal {
  // Built by hand rather than AbortSignal.timeout/any: older Android WebViews
  // the APK still installs on lack AbortSignal.any.
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(new DOMException('Request timed out', 'TimeoutError')), ms)
  const stop = () => clearTimeout(timer)
  controller.signal.addEventListener('abort', stop, { once: true })
  if (parent) {
    if (parent.aborted) controller.abort(parent.reason)
    else parent.addEventListener('abort', () => controller.abort(parent.reason), { once: true })
  }
  return controller.signal
}

export const READ_TIMEOUT_MS = 15_000

/**
 * Whether a request may be cut off client-side. Only reads: a write that times
 * out here may still commit on the server, and the screen would then report a
 * failure for something that happened. Storage is excluded too — a photo
 * download on a slow line can legitimately take longer than any deadline.
 */
export function isTimeoutSafe(url: string, method = 'GET'): boolean {
  const m = method.toUpperCase()
  return (m === 'GET' || m === 'HEAD') && !url.includes('/storage/v1/')
}

/** `fetch` with a deadline on reads; everything else passes straight through. */
export function createTimeoutFetch(base: typeof fetch = fetch, ms = READ_TIMEOUT_MS): typeof fetch {
  return (input, init) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url
    const method = init?.method ?? (input instanceof Request ? input.method : 'GET')
    if (!isTimeoutSafe(url, method)) return base(input, init)
    return base(input, { ...init, signal: timeoutSignal(ms, init?.signal) })
  }
}
