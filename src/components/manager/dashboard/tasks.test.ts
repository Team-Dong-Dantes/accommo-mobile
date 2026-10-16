import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { paymentTasks, permitTasks, titleCase, utilityTasks } from './tasks'

describe('permitTasks', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-10-16T09:00:00+08:00'))
  })
  afterEach(() => {
    vi.useRealTimers()
  })

  const accName = new Map([['a1', 'Casa Luna']])
  const row = (id: string, expires_at: string | null) => ({ id, doc_type: 'fire_safety', expires_at, accommodation_id: 'a1' })

  it('splits expired from expiring within 30 days, and skips the rest', () => {
    const { items, expiredByAcc, expiringSoonByAcc } = permitTasks(
      [row('d1', '2026-10-01'), row('d2', '2026-11-01'), row('d3', '2027-06-01'), row('d4', null)],
      accName,
    )
    expect(items.map((t) => t.id)).toEqual(['doc-d1', 'doc-soon-d2'])
    expect(items[0]).toMatchObject({ label: 'Fire safety expired', tone: 'danger', rank: 1 })
    expect(items[1]).toMatchObject({ label: 'Fire safety expires soon', tone: 'warn', rank: 3 })
    expect(expiredByAcc.get('a1')).toBe(1)
    expect(expiringSoonByAcc.get('a1')).toBe(1)
  })
})

describe('utilityTasks', () => {
  it('groups rooms without utility terms per accommodation', () => {
    const room = (billing: string | null) => ({ accommodation_id: 'a1', water_billing: billing, electric_billing: billing, wifi_billing: billing })
    const items = utilityTasks([room(null), room(null), room('included')], new Map([['a1', 'Casa Luna']]))
    expect(items).toHaveLength(1)
    expect(items[0]).toMatchObject({ id: 'utilities-a1', label: 'Set utilities on 2 rooms' })
  })
})

describe('paymentTasks', () => {
  it('is one grouped row, or none', () => {
    expect(paymentTasks(0)).toEqual([])
    expect(paymentTasks(1)[0]?.label).toBe('Verify 1 payment')
    expect(paymentTasks(3)[0]?.label).toBe('Verify 3 payments')
  })
})

describe('titleCase', () => {
  it('turns a snake_case value into words', () => {
    expect(titleCase('business_permit')).toBe('Business permit')
    expect(titleCase(null)).toBe('')
  })
})
