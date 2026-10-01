import { describe, expect, it } from 'vitest'
import { emptyUtilities, utilitiesHint, utilityColumns, utilitiesFromRow, type UtilityKey, type UtilityTerms } from './listings'

const terms = (water: string | null, electric: string | null, wifi: string | null, fee: number | null = null) =>
  ({
    water: { billing: water, flatFee: water === 'flat_fee' ? fee : null },
    electric: { billing: electric, flatFee: electric === 'flat_fee' ? fee : null },
    wifi: { billing: wifi, flatFee: wifi === 'flat_fee' ? fee : null },
  }) as Record<UtilityKey, UtilityTerms>

describe('utilitiesHint', () => {
  it('says included only when all three are', () => {
    expect(utilitiesHint(terms('included', 'included', 'included'))).toBe('Utilities included')
  })

  it('lists only what differs from included', () => {
    expect(utilitiesHint(terms('included', 'own_meter', 'not_available'))).toBe('Electricity: own meter · No Wi-Fi')
  })

  it('shows a flat fee as an add-on', () => {
    expect(utilitiesHint(terms('flat_fee', 'included', 'included', 150))).toBe('Water +₱150')
  })

  // A room with only water set to "included" says nothing about the rest.
  it('stays quiet rather than guess', () => {
    expect(utilitiesHint(emptyUtilities())).toBe('')
    expect(utilitiesHint(terms('included', null, null))).toBe('')
  })
})

describe('utilityColumns', () => {
  it('saves a flat fee with no amount as unspecified, and drops stray fees', () => {
    const cols = utilityColumns({
      water: { billing: 'flat_fee', flatFee: null },
      electric: { billing: 'included', flatFee: 300 },
      wifi: { billing: 'flat_fee', flatFee: 200 },
    })
    expect(cols).toEqual({
      water_billing: null, water_flat_fee: null,
      electric_billing: 'included', electric_flat_fee: null,
      wifi_billing: 'flat_fee', wifi_flat_fee: 200,
    })
    expect(utilitiesFromRow(cols).wifi).toEqual({ billing: 'flat_fee', flatFee: 200 })
  })
})
