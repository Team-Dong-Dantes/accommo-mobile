import { describe, expect, it } from 'vitest'
import { verificationSteps } from './verificationSteps'

const base = { role: 'student' as const, status: 'unverified', docsSentAt: null, profileComplete: true }

describe('verificationSteps', () => {
  it('is 1 of 3 and asks for requirements before anything is sent', () => {
    const v = verificationSteps(base)
    expect(v.done).toBe(1)
    expect(v.next).toEqual({ label: 'Upload requirements', route: '/student/support' })
  })
  it('asks for the profile first when it is incomplete', () => {
    expect(verificationSteps({ ...base, profileComplete: false }).next?.route).toBe('/student/profile/complete')
  })
  it('is 2 of 3 and in review once requirements are sent', () => {
    const v = verificationSteps({ ...base, status: 'pending', docsSentAt: '2026-10-13T01:00:00Z' })
    expect(v).toMatchObject({ done: 2, inReview: true, next: null })
  })
  it('drops back to 1 when OSAS sends them back', () => {
    const v = verificationSteps({ ...base, status: 'needs_resubmission', docsSentAt: '2026-10-13T01:00:00Z' })
    expect(v.done).toBe(1)
    expect(v.next?.label).toBe('Re-upload requirements')
  })
  it('is 3 of 3 when verified, with nothing next', () => {
    expect(verificationSteps({ ...base, status: 'verified', docsSentAt: 'x' })).toMatchObject({ done: 3, next: null })
  })
  it('routes landlords to their own requirements on /manager/osas', () => {
    expect(verificationSteps({ ...base, role: 'manager' }).next?.route).toBe('/manager/osas?tab=mine')
  })
})
