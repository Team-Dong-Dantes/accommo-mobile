import { describe, expect, it } from 'vitest'
import {
  CAPACITY_MAX,
  MONTHS_MAX,
  RENT_MAX,
  clampNum,
  clampOptional,
  nextFloorNumber,
  nextRoomNumber,
  partitionFacilities,
  rentBasisConversion,
} from './roomInventory'

// The safety net for splitting AccommodationDetail.vue. These assertions are
// what a regression in the property editor would break, and there was nothing
// checking any of it before.

describe('clampNum', () => {
  it('keeps a value already in range', () => {
    expect(clampNum(2500, 0, RENT_MAX)).toBe(2500)
  })

  it('caps a value typed past the ceiling', () => {
    expect(clampNum(999999, 0, RENT_MAX)).toBe(RENT_MAX)
    expect(clampNum(50, 1, CAPACITY_MAX)).toBe(CAPACITY_MAX)
  })

  it('raises a value below the floor', () => {
    expect(clampNum(-1, 0, RENT_MAX)).toBe(0)
  })

  // Number('') is 0 and Number(undefined) is NaN, so these have to be
  // distinguished explicitly or an empty field silently becomes zero rent.
  it('treats anything unparseable as the minimum', () => {
    expect(clampNum(null, 1, MONTHS_MAX)).toBe(1)
    expect(clampNum(undefined, 1, MONTHS_MAX)).toBe(1)
    expect(clampNum(NaN, 1, MONTHS_MAX)).toBe(1)
  })
})

describe('clampOptional', () => {
  it('keeps "not set" as null rather than collapsing it to the minimum', () => {
    expect(clampOptional(null, 1, MONTHS_MAX)).toBeNull()
    expect(clampOptional(undefined, 1, MONTHS_MAX)).toBeNull()
  })

  it('still clamps a real value', () => {
    expect(clampOptional(99, 1, MONTHS_MAX)).toBe(MONTHS_MAX)
    expect(clampOptional(3, 1, MONTHS_MAX)).toBe(3)
  })

  // Zero is a real answer — "no advance months" is not the same as "unset".
  it('does not confuse zero with unset', () => {
    expect(clampOptional(0, 0, MONTHS_MAX)).toBe(0)
  })
})

describe('nextRoomNumber', () => {
  it('numbers the first room on a floor', () => {
    expect(nextRoomNumber([], 2)).toBe('201')
  })

  it('continues the sequence on that floor only', () => {
    const rooms = [{ floor: 2 }, { floor: 2 }, { floor: 3 }]
    expect(nextRoomNumber(rooms, 2)).toBe('203')
    expect(nextRoomNumber(rooms, 3)).toBe('302')
  })

  it('pads to two digits', () => {
    expect(nextRoomNumber([], 1)).toBe('101')
  })

  it('treats an unassigned floor as ground', () => {
    expect(nextRoomNumber([{ floor: null }], null)).toBe('002')
  })
})

describe('nextFloorNumber', () => {
  it('starts at 1 when there is nothing', () => {
    expect(nextFloorNumber([], [])).toBe(1)
  })

  it('goes one above the highest floor that has rooms', () => {
    expect(nextFloorNumber([{ floor: 1 }, { floor: 3 }], [])).toBe(4)
  })

  // Adding two floors in a row must not hand out the same number twice, so an
  // empty tracked floor still counts.
  it('counts tracked floors that have no rooms yet', () => {
    expect(nextFloorNumber([{ floor: 1 }], [2, 3])).toBe(4)
  })

  it('ignores rooms with no floor', () => {
    expect(nextFloorNumber([{ floor: null }, { floor: 2 }], [])).toBe(3)
  })
})

describe('rentBasisConversion', () => {
  it('shows the room total when rent is quoted per person', () => {
    expect(rentBasisConversion(1500, 4, 'person')).toEqual({ amount: 6000, perPerson: false })
  })

  it('shows the per-person share when rent is quoted for the room', () => {
    expect(rentBasisConversion(6000, 4, 'room')).toEqual({ amount: 1500, perPerson: true })
  })

  // For a solo room both readings are the same number, so the hint is noise.
  it('says nothing for a single-occupancy room', () => {
    expect(rentBasisConversion(3500, 1, 'room')).toBeNull()
    expect(rentBasisConversion(3500, null, 'person')).toBeNull()
  })

  it('treats missing rent as zero rather than throwing', () => {
    expect(rentBasisConversion(null, 2, 'room')).toEqual({ amount: 0, perPerson: true })
  })
})

describe('partitionFacilities', () => {
  const facilities = [
    { roomId: null, label: 'Shared bathroom' },
    { roomId: 'room-1', label: 'Private bathroom' },
    { roomId: 'room-2', label: 'Balcony' },
    { roomId: null, label: 'Kitchen' },
  ]

  it('puts facilities with no room in shared', () => {
    expect(partitionFacilities(facilities, 'room-1').shared.map((f) => f.label)).toEqual([
      'Shared bathroom',
      'Kitchen',
    ])
  })

  it('returns only the given room’s private facilities', () => {
    expect(partitionFacilities(facilities, 'room-1').privateToRoom.map((f) => f.label)).toEqual([
      'Private bathroom',
    ])
  })

  // No room open means no private facilities to show — not "all of them".
  it('returns no private facilities when no room is being edited', () => {
    expect(partitionFacilities(facilities, null).privateToRoom).toEqual([])
    expect(partitionFacilities(facilities, null).shared).toHaveLength(2)
  })

  it('never puts a facility in both halves', () => {
    const { shared, privateToRoom } = partitionFacilities(facilities, 'room-2')
    const overlap = shared.filter((s) => privateToRoom.includes(s))
    expect(overlap).toEqual([])
  })
})
