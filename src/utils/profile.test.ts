import { describe, expect, it, vi } from 'vitest'

vi.mock('@/utils/supabase', () => ({ supabase: {} }))

const { accountDocItem, accountHistory, listGaps, profileGaps } = await import('./profile')

describe('accountDocItem while sent back', () => {
  const row = (uploaded_at: string) => ({ id: 'r', doc_type: 'government_id', file_url: 'x', status: 'pending', uploaded_at, verified_at: null })
  const decided = '2026-10-10T00:00:00Z'

  it('a file from before the decision is what OSAS sent back', () => {
    expect(accountDocItem('government_id', row('2026-10-01T00:00:00Z'), 'rejected', decided).statusLabel).toBe('Sent back')
  })

  it('a file from after it waits for the resubmit', () => {
    expect(accountDocItem('government_id', row('2026-10-12T00:00:00Z'), 'rejected', decided).statusLabel).toBe('Ready to resubmit')
  })

  it('reads as in review once resubmitted', () => {
    expect(accountDocItem('government_id', row('2026-10-12T00:00:00Z'), 'pending', decided).statusLabel).toBe('In review')
  })
})

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

describe('accountHistory', () => {
  it('merges uploads and OSAS decisions, newest first', () => {
    const items = accountHistory(
      [{ id: 'd1', status: 'resubmission_requested', reviewed_at: '2026-10-02T00:00:00Z', decision_notes: 'Blurry ID', rejection_reasons: null }],
      [
        { id: 'u1', doc_type: 'school_id', file_url: '', status: 'pending', uploaded_at: '2026-10-05T00:00:00Z', verified_at: null },
        { id: 'u2', doc_type: 'assessment_of_fees', file_url: '', status: 'pending', uploaded_at: '2026-10-01T00:00:00Z', verified_at: null },
      ],
    )
    expect(items.map((i) => i.id)).toEqual(['u1', 'd1', 'u2'])
    expect(items[1]).toMatchObject({ verdict: 'sent back for changes', tone: 'returned', lines: ['“Blurry ID”'] })
    expect(items[0]).toMatchObject({ title: 'School ID', tone: 'sent' })
  })
})
