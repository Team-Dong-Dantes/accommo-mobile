import { describe, expect, it, vi } from 'vitest'

vi.mock('@/utils/supabase', () => ({ supabase: {} }))

const { shrinkTarget } = await import('./upload')

describe('shrinkTarget', () => {
  it('leaves a photo already within the limit alone', () => {
    expect(shrinkTarget(2000, 1500, 2000)).toBeNull()
  })
  it('scales the long side to the limit and keeps the shape', () => {
    expect(shrinkTarget(4000, 3000, 2000)).toEqual({ width: 2000, height: 1500 })
    expect(shrinkTarget(3000, 4000, 1600)).toEqual({ width: 1200, height: 1600 })
  })
})
