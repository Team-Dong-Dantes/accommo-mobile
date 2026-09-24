/**
 * The decisions the landlord/landlady's property editor makes about its own inventory,
 * pulled out of AccommodationDetail.vue so they can be tested.
 *
 * That component is 2,200 lines with ten dialogs and no test of any kind. The
 * blocker on splitting it further is that nothing would catch a regression —
 * so the logic worth protecting comes out first. These are the functions whose
 * failure is expensive and silent: the clamps guard what gets written as rent
 * and capacity, and the numbering decides what a new room is called.
 *
 * Deliberately free of Vue: no refs, no component state. Every input is an
 * argument, which is what makes them testable and what will let the dialogs
 * move without the maths moving with them.
 */

/** Ceilings the editor enforces before anything reaches the database. */
export const RENT_MAX = 100000
export const CAPACITY_MAX = 20
export const MONTHS_MAX = 12

/**
 * Force a number into range, treating anything unparseable as the minimum.
 *
 * Applied at the save payload rather than on the input, so a pasted value or
 * a number typed past the cap cannot reach the row. `Number('')` is 0 and
 * `Number(undefined)` is NaN, hence the explicit finite check.
 */
export function clampNum(value: number | null | undefined, min: number, max: number): number {
  const n = Number(value)
  if (!Number.isFinite(n)) return min
  return Math.min(Math.max(n, min), max)
}

/** As `clampNum`, but "not set" stays null instead of collapsing to the minimum. */
export function clampOptional(
  value: number | null | undefined,
  min: number,
  max: number,
): number | null {
  if (value === null || value === undefined || value === ('' as unknown)) return null
  return clampNum(value, min, max)
}

/** Anything with a floor — a room, as far as the numbering is concerned. */
export interface FloorBearing {
  floor: number | null
}

/**
 * The next room number on a floor: the floor, then a two-digit sequence.
 * Floor 2 with three rooms already on it gives "204".
 *
 * A null floor counts as 0, which is what the ground/unassigned case produces.
 */
export function nextRoomNumber(rooms: readonly FloorBearing[], floor: number | null): string {
  const f = floor ?? 0
  const onFloor = rooms.filter((r) => r.floor === floor).length
  return `${f}${String(onFloor + 1).padStart(2, '0')}`
}

/**
 * The next floor to add. Counts floors that are tracked but still empty, so
 * adding two floors in a row does not hand out the same number twice.
 */
export function nextFloorNumber(
  rooms: readonly FloorBearing[],
  trackedFloors: readonly number[],
): number {
  const floors = [
    ...rooms.map((r) => r.floor).filter((f): f is number => f !== null),
    ...trackedFloors,
  ]
  return floors.length ? Math.max(...floors) + 1 : 1
}

/**
 * The other way of reading the rent a landlord/landlady just typed.
 *
 * Rent is quoted either for the whole room or per head, and the editor shows
 * the converse so a bedspace priced at 1,500 per person reads as 6,000 for a
 * four-bed room. Returns null for a single-occupancy room, where the two
 * numbers are the same and the hint is noise.
 */
export function rentBasisConversion(
  monthlyRent: number | null | undefined,
  capacity: number | null | undefined,
  basis: 'room' | 'person',
): { amount: number; perPerson: boolean } | null {
  const rent = monthlyRent || 0
  const cap = capacity || 1
  if (cap <= 1) return null
  return basis === 'person'
    ? { amount: rent * cap, perPerson: false }
    : { amount: rent / cap, perPerson: true }
}

/** A facility hangs off the accommodation (shared) or off one room (private). */
export interface ScopedFacility {
  roomId: string | null
}

/**
 * Split facilities by scope.
 *
 * This is the coupling that keeps the room dialog and the facility dialog
 * joined at the hip: a room's private facilities render inside the room
 * editor, so whichever component ends up owning them has to agree on the
 * partition. Naming it here means a future split cannot quietly change it.
 */
export function partitionFacilities<T extends ScopedFacility>(
  facilities: readonly T[],
  roomId: string | null,
): { shared: T[]; privateToRoom: T[] } {
  return {
    shared: facilities.filter((f) => !f.roomId),
    privateToRoom: roomId ? facilities.filter((f) => f.roomId === roomId) : [],
  }
}
