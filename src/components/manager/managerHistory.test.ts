import { describe, expect, it } from 'vitest'
import { stayMonths, monthsText, periodText } from './managerHistory'

describe('managerHistory', () => {
  it('counts months in 30.44-day steps, at least one', () => {
    expect(stayMonths('2025-06-01', '2026-03-31')).toBe(10)
    expect(stayMonths('2026-01-01', '2026-01-03')).toBe(1)
  })
  it('pluralises', () => {
    expect(monthsText(1)).toBe('1 month')
    expect(monthsText(7)).toBe('7 months')
  })
  it('formats a period', () => {
    expect(periodText('2025-08-05', '2026-05-31')).toContain('2026')
  })
})
