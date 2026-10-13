import { describe, expect, it } from 'vitest'
import { pinLabel, takesSex, walkMinutesGuess, type PinFacts } from './mapPins'
import { CAMPUS } from './geo'

const place = (over: Partial<PinFacts> = {}): PinFacts => ({
  vacancies: 2,
  minVacantRent: 2500,
  genderKind: 'co_ed',
  buildingKind: 'boarding_house',
  ...over,
})

describe('pinLabel', () => {
  it('shows the cheapest vacant rent, Vacant when unpriced, Full when none free', () => {
    expect(pinLabel(place())).toBe('₱2,500')
    expect(pinLabel(place({ minVacantRent: null }))).toBe('Vacant')
    expect(pinLabel(place({ vacancies: 0 }))).toBe('Full')
  })
})

describe('takesSex', () => {
  it('matches single-sex places to the student and never guesses', () => {
    expect(takesSex('female', 'M')).toBe(false)
    expect(takesSex('female', 'F')).toBe(true)
    expect(takesSex('co_ed', 'M')).toBe(true)
    expect(takesSex(null, 'F')).toBe(true)
    expect(takesSex('male', 'U')).toBe(true)
    expect(takesSex('male', null)).toBe(true)
  })
})

describe('walkMinutesGuess', () => {
  it('is at least a minute and unknown without coordinates', () => {
    expect(walkMinutesGuess(CAMPUS.lat, CAMPUS.lng)).toBe(1)
    expect(walkMinutesGuess(null, null)).toBe(null)
  })
})
