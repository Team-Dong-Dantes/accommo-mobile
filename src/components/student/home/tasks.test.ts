import { describe, expect, it } from 'vitest'
import { overdueRentTasks, unreadTasks, verificationTasks } from './tasks'

describe('verificationTasks', () => {
  it('is a done row once verified', () => {
    expect(verificationTasks('verified', [], null)[0]).toMatchObject({ label: 'OSAS verified', tone: 'done', rank: 99 })
  })

  it('waits while documents are pending review', () => {
    const [t] = verificationTasks('pending', [{ status: 'pending' }, { status: 'pending' }], null)
    expect(t).toMatchObject({ label: 'OSAS is reviewing your requirements', hint: '2 requirements submitted', action: '' })
  })

  it('asks for documents when nothing is pending', () => {
    expect(verificationTasks('unverified', [], null)[0]).toMatchObject({ label: 'Finish your OSAS verification', rank: 2 })
  })

  it("leads with OSAS's own reason when sent back", () => {
    const [t] = verificationTasks('needs_resubmission', [], { reason: 'Blurry ID', restrictions: null })
    expect(t).toMatchObject({ label: 'OSAS asked for new requirements', hint: 'Blurry ID', tone: 'danger' })
  })
})

describe('overdueRentTasks', () => {
  it('only reports rent that is overdue', () => {
    expect(overdueRentTasks(null)).toEqual([])
  })
})

describe('unreadTasks', () => {
  it('counts unread messages from the landlord/landlady', () => {
    expect(unreadTasks(0, 'landlady')).toEqual([])
    expect(unreadTasks(2, 'landlady')[0]).toMatchObject({ label: '2 unread messages', hint: 'From your landlady' })
  })
})
