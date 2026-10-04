import { describe, expect, it, vi } from 'vitest'
import { createTimeoutFetch, isTimeoutSafe } from './fetchTimeout'

describe('isTimeoutSafe', () => {
  it('cuts off reads only', () => {
    expect(isTimeoutSafe('https://x.supabase.co/rest/v1/users', 'GET')).toBe(true)
    expect(isTimeoutSafe('https://x.supabase.co/rest/v1/users', 'post')).toBe(false)
    expect(isTimeoutSafe('https://x.supabase.co/rest/v1/rpc/f', 'PATCH')).toBe(false)
  })

  it('never cuts off storage, even a read', () => {
    expect(isTimeoutSafe('https://x.supabase.co/storage/v1/object/a.jpg', 'GET')).toBe(false)
  })
})

describe('createTimeoutFetch', () => {
  // A fetch that only settles when its signal aborts.
  const hanging = vi.fn(
    (_: RequestInfo | URL, init?: RequestInit) =>
      new Promise<Response>((_, reject) => init?.signal?.addEventListener('abort', () => reject(init.signal!.reason))),
  )

  it('gives up on a stalled read', async () => {
    vi.useFakeTimers()
    const p = createTimeoutFetch(hanging, 1000)('https://x.supabase.co/rest/v1/users')
    const check = expect(p).rejects.toMatchObject({ name: 'TimeoutError' })
    await vi.advanceTimersByTimeAsync(1000)
    await check
    vi.useRealTimers()
  })

  it('still honours the caller’s own abort', async () => {
    const caller = new AbortController()
    const p = createTimeoutFetch(hanging, 60_000)('https://x.supabase.co/rest/v1/users', { signal: caller.signal })
    caller.abort(new Error('cancelled'))
    await expect(p).rejects.toThrow('cancelled')
  })

  it('leaves writes untouched', async () => {
    const base = vi.fn(async () => new Response('ok'))
    const init = { method: 'POST' }
    await createTimeoutFetch(base, 1)('https://x.supabase.co/rest/v1/users', init)
    expect(base).toHaveBeenCalledWith('https://x.supabase.co/rest/v1/users', init)
  })
})
