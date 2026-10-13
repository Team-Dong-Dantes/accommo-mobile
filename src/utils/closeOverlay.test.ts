import { describe, it, expect, vi } from 'vitest'
import type { Router } from 'vue-router'
import { closeOverlay } from './closeOverlay'

function run(back: string | null) {
  vi.stubGlobal('window', { history: { state: { back } } })
  const router = { back: vi.fn(), push: vi.fn(), currentRoute: { value: { path: '/student/messages' } } }
  closeOverlay(router as unknown as Router, 'c')
  return router.back.mock.calls.length ? 'back' : 'list'
}

describe('closeOverlay', () => {
  it('returns to the page the thread was opened from', () => {
    expect(run('/student/room/r1')).toBe('back')
    expect(run('/student/messages')).toBe('back')
  })
  it('falls to the list when another thread or nothing is behind it', () => {
    expect(run('/student/messages?c=other')).toBe('list')
    expect(run(null)).toBe('list')
  })
})
