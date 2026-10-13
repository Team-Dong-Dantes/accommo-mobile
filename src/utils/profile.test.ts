import { describe, expect, it, vi } from 'vitest'

vi.mock('@/utils/supabase', () => ({ supabase: {} }))

const { listGaps, profileGaps } = await import('./profile')

describe('profileGaps', () => {
  it('a blank student owes five things, four of them needed', () => {
    const gaps = profileGaps({}, true)
    expect(gaps.map((g) => g.key)).toEqual(['photo', 'sex', 'dob', 'studentId', 'emergency'])
    expect(gaps.filter((g) => g.needed)).toHaveLength(4)
  })

  it('a landlord/landlady is never asked for a student ID or emergency contact', () => {
    expect(profileGaps({}, false).map((g) => g.key)).toEqual(['photo', 'sex', 'dob'])
  })

  it('an emergency contact without a phone still counts as missing', () => {
    const full = { avatar_url: 'x', sex: 'F', date_of_birth: '2000-01-01', student_id: '25-01234' }
    expect(profileGaps({ ...full, emergency_contact_json: { name: 'Ana' } }, true).map((g) => g.key)).toEqual(['emergency'])
    expect(profileGaps({ ...full, emergency_contact_json: { name: 'Ana', phone: '+639171234567' } }, true)).toEqual([])
  })

  it('lists missing items as a sentence', () => {
    const gaps = profileGaps({ avatar_url: 'x' }, true)
    expect(listGaps(gaps)).toBe('sex, date of birth, student ID and emergency contact')
    expect(listGaps(gaps.slice(0, 1))).toBe('sex')
  })
})
