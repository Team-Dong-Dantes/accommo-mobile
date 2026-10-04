import { describe, expect, it, vi } from 'vitest'

vi.mock('@/utils/supabase', () => ({ supabase: {} }))
vi.mock('@/utils/upload', () => ({ uploadSecureDocument: vi.fn() }))

const { expiryProblem, isTooSmall, permitReplaceOpen, sha256Hex, shrinkTarget } = await import('./permits')

describe('isTooSmall', () => {
  it('refuses a photo under 1000 px on its short side', () => {
    expect(isTooSmall(800, 1600)).toBe(true)
    expect(isTooSmall(1600, 999)).toBe(true)
  })
  it('accepts one at or over it, either orientation', () => {
    expect(isTooSmall(1000, 1500)).toBe(false)
    expect(isTooSmall(4000, 3000)).toBe(false)
  })
})

describe('shrinkTarget', () => {
  it('leaves a photo already within 2000 px alone', () => {
    expect(shrinkTarget(2000, 1500)).toBeNull()
  })
  it('scales the long side to 2000 and keeps the shape', () => {
    expect(shrinkTarget(4000, 3000)).toEqual({ width: 2000, height: 1500 })
    expect(shrinkTarget(3000, 4000)).toEqual({ width: 1500, height: 2000 })
  })
})

describe('expiryProblem', () => {
  const today = new Date('2026-10-02T09:00:00')
  it('needs a date', () => {
    expect(expiryProblem('', today)).toMatch(/expiry date/)
  })
  it('refuses one already past', () => {
    expect(expiryProblem('2026-10-01', today)).toMatch(/already expired/)
  })
  it('accepts today and later', () => {
    expect(expiryProblem('2026-10-02', today)).toBeNull()
    expect(expiryProblem('2027-06-30', today)).toBeNull()
  })
})

describe('sha256Hex', () => {
  it('is the standard SHA-256 of the bytes', async () => {
    expect(await sha256Hex(new Blob(['abc']))).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
  })
  it('tells two different files apart', async () => {
    expect(await sha256Hex(new Blob(['permit']))).not.toBe(await sha256Hex(new Blob(['permit2'])))
  })
})

describe('permitReplaceOpen', () => {
  const today = new Date('2026-10-03T12:00:00')
  it('is open on any listing OSAS has not accredited', () => {
    for (const status of ['draft', 'pending', 'needs_revision', 'rejected', 'expired', 'suspended']) {
      expect(permitReplaceOpen(status, '2030-01-01', false, today)).toBe(true)
    }
  })
  it('locks a current permit on an accredited or delisted listing', () => {
    expect(permitReplaceOpen('accredited', '2027-10-25', false, today)).toBe(false)
    expect(permitReplaceOpen('delisted', '2027-10-25', false, today)).toBe(false)
  })
  it('opens within 30 days of expiry, past it, or with no date', () => {
    expect(permitReplaceOpen('accredited', '2026-10-20', false, today)).toBe(true)
    expect(permitReplaceOpen('accredited', '2026-09-01', false, today)).toBe(true)
    expect(permitReplaceOpen('accredited', null, false, today)).toBe(true)
  })
  it('opens when OSAS flagged it', () => {
    expect(permitReplaceOpen('accredited', '2027-10-25', true, today)).toBe(true)
  })
})
