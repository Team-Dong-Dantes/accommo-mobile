import { describe, expect, it } from 'vitest'
import { pinLabel, takesSex, passesChips, walkMinutesGuess, type MapChips, type PinFacts } from './mapPins'
import { CAMPUS } from './geo'

const place = (over: Partial<PinFacts> = {}): PinFacts => ({
  vacancies: 2,
  minVacantRent: 2500,
  genderKind: 'co_ed',
  buildingKind: 'boarding_house',
  ...over,
})
const none: MapChips = { vacant: false, fitsMe: false, under3k: false, dorm: false, boarding: false }

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

describe('passesChips', () => {
  it('passes everything with no chip on', () => {
    expect(passesChips(place({ vacancies: 0 }), none, null)).toBe(true)
  })

  it('narrows on vacancy, sex and price', () => {
    expect(passesChips(place({ vacancies: 0 }), { ...none, vacant: true }, null)).toBe(false)
    expect(passesChips(place({ genderKind: 'male' }), { ...none, fitsMe: true }, 'F')).toBe(false)
    expect(passesChips(place({ minVacantRent: 3500 }), { ...none, under3k: true }, null)).toBe(false)
    expect(passesChips(place({ minVacantRent: 3000 }), { ...none, under3k: true }, null)).toBe(true)
  })

  it('treats Dorm and Boarding house as either-or', () => {
    const both = { ...none, dorm: true, boarding: true }
    expect(passesChips(place({ buildingKind: 'dormitory' }), both, null)).toBe(true)
    expect(passesChips(place({ buildingKind: 'residence' }), both, null)).toBe(false)
    expect(passesChips(place(), { ...none, dorm: true }, null)).toBe(false)
  })
})

describe('walkMinutesGuess', () => {
  it('is at least a minute and unknown without coordinates', () => {
    expect(walkMinutesGuess(CAMPUS.lat, CAMPUS.lng)).toBe(1)
    expect(walkMinutesGuess(null, null)).toBe(null)
  })
})
