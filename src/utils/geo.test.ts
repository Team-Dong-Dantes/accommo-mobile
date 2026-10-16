import { afterEach, describe, expect, it, vi } from 'vitest'
import { reversePlace, searchPlaces } from './geo'

const reply = (body: unknown, ok = true) => vi.fn(async () => ({ ok, json: async () => body }))

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('searchPlaces', () => {
  it('maps features to places and skips ones without coordinates', async () => {
    vi.stubGlobal('fetch', reply({
      features: [
        {
          id: 'a',
          geometry: { coordinates: [121.68, 16.72] },
          properties: { name: 'ISU Echague', place_formatted: 'Echague, Isabela', context: { locality: { name: 'San Fabian' }, place: { name: 'Echague' } } },
        },
        { id: 'b', properties: { name: 'No pin' } },
      ],
    }))
    const places = await searchPlaces('isu', 't')
    expect(places).toEqual([
      { id: 'a', name: 'ISU Echague', addressGuess: 'Echague, Isabela', barangayGuess: 'San Fabian', cityGuess: 'Echague', lng: 121.68, lat: 16.72 },
    ])
  })

  it('throws when the search fails', async () => {
    vi.stubGlobal('fetch', reply({}, false))
    await expect(searchPlaces('isu', 't')).rejects.toThrow('Search failed.')
  })
})

describe('reversePlace', () => {
  it('falls back to the neighborhood when there is no locality', async () => {
    vi.stubGlobal('fetch', reply({
      features: [{ properties: { full_address: 'Rizal St.', context: { neighborhood: { name: 'Purok 3' }, place: { name: 'Ilagan' } } } }],
    }))
    expect(await reversePlace(121.5, 16.7, 't')).toEqual({ address: 'Rizal St.', barangay: 'Purok 3', city: 'Ilagan' })
  })

  it('is null with no answer', async () => {
    vi.stubGlobal('fetch', reply({ features: [] }))
    expect(await reversePlace(0, 0, 't')).toBeNull()
  })
})
