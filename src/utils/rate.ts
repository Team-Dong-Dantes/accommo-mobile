// Small shared helpers the tall list screens (Discover, Messages, Concerns,
// Tenants, Payments) should use during the rebuild to keep input-triggered
// work off the main thread.

/** Dedupe trailing calls: fires `fn` only after `wait` ms of quiet. Use for
 *  search-as-you-type queries (150–250ms) and window/resize recalculations. */
export function debounce<A extends unknown[]>(fn: (...args: A) => void, wait = 200) {
  let timer: ReturnType<typeof setTimeout> | undefined
  const wrapped = (...args: A) => {
    if (timer !== undefined) clearTimeout(timer)
    timer = setTimeout(() => {
      timer = undefined
      fn(...args)
    }, wait)
  }
  wrapped.cancel = () => {
    if (timer !== undefined) {
      clearTimeout(timer)
      timer = undefined
    }
  }
  return wrapped
}

/** Fire immediately, then suppress for `wait` ms. Optional leading=true default
 *  — use for scroll-position saves and "last read" marks. */
export function throttle<A extends unknown[]>(fn: (...args: A) => void, wait = 150) {
  let last = 0
  let timer: ReturnType<typeof setTimeout> | undefined
  const wrapped = (...args: A) => {
    const now = Date.now()
    const remaining = wait - (now - last)
    if (remaining <= 0) {
      if (timer !== undefined) clearTimeout(timer)
      last = now
      fn(...args)
      return
    }
    if (timer === undefined) {
      timer = setTimeout(
        () => {
          timer = undefined
          last = Date.now()
          fn(...args)
        },
        remaining,
      )
    }
  }
  wrapped.cancel = () => {
    if (timer !== undefined) clearTimeout(timer)
    timer = undefined
  }
  return wrapped
}
