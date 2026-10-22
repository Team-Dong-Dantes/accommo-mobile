// The accommodation editor's shapes and fixed tables, shared by its state
// modules and components.
import type { Database } from '@/types/database.gen'
import { type UtilityKey, type UtilityTerms, BUILDING_TYPE_LABEL, GENDER_POLICY_LABEL, ACCOMMODATION_STATUS_LABEL, ACCOMMODATION_STATUS_TONE } from '@/utils/listings'

export type AmenityKey = Database['public']['Enums']['amenity']

export const STATUS_LABEL = ACCOMMODATION_STATUS_LABEL
export const STATUS_TONE = ACCOMMODATION_STATUS_TONE
export const ROOM_STATUS_TONE: Record<string, string> = {
  available: 'green',
  occupied: 'amber',
  maintenance: 'grey',
}

export const DOC_TYPES = ['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] as const
export const DOC_TYPE_LABEL: Record<string, string> = {
  sanitary_permit: 'Sanitary permit',
  fire_safety: 'Fire safety certificate',
  business_permit: 'Business permit',
  building_permit: 'Building permit',
}

export const TABS = [
  { key: 'overview', label: 'Overview' },
  { key: 'rooms', label: 'Rooms' },
  { key: 'settings', label: 'Settings' },
] as const

export const RULE_TOGGLES = [
  { key: 'cooking' as const, label: 'Cooking allowed' },
  { key: 'laundry' as const, label: 'Laundry allowed' },
  { key: 'pets' as const, label: 'Pets allowed' },
]

export interface Room {
  id: string
  label: string | null
  roomNumber: string | null
  roomType: string | null
  customRoomType: string | null
  floor: number | null
  capacity: number | null
  currentPax: number
  monthlyRent: number
  advanceMonths: number | null
  depositMonths: number | null
  rentBasis: 'room' | 'person'
  /** How this room's water, electricity and Wi-Fi are paid. */
  utilities: Record<UtilityKey, UtilityTerms>
  status: string
  images: Img[]
  photoUrl: string
}
export interface Img {
  id: string
  url: string
  /** Still uploading; `url` is the device's local copy. */
  pending?: boolean
}
export type FacilityStatus = 'available' | 'under_repair'

export interface Facility {
  id: string
  facilityType: string
  label: string
  description: string
  roomId: string | null
  floor: number | null
  status: FacilityStatus
  /** Rooms that share it; only a shared facility has any. */
  roomIds: string[]
  images: Img[]
}

export const FACILITY_STATUS_LABEL: Record<FacilityStatus, string> = { available: 'Available', under_repair: 'Under repair' }

export type FieldKey =
  | 'name' | 'accommodationType' | 'genderPolicy' | 'purok' | 'barangay' | 'city' | 'description'
  | 'curfewTime' | 'quietHours' | 'visitorPolicy'

// `options` is what a 'select' field offers; the sheet renders straight from it,
// so a second select needs an entry here rather than another branch in the template.
export const FIELD_META: Record<FieldKey, { label: string; type: 'text' | 'select' | 'textarea' | 'time' | 'timerange'; table: 'accommodations' | 'accommodation_policies'; column: string; options?: Record<string, string> }> = {
  name: { label: 'Name', type: 'text', table: 'accommodations', column: 'name' },
  accommodationType: { label: 'Type', type: 'select', table: 'accommodations', column: 'accommodation_type', options: BUILDING_TYPE_LABEL },
  genderPolicy: { label: 'Accepts', type: 'select', table: 'accommodations', column: 'gender_policy', options: GENDER_POLICY_LABEL },
  purok: { label: 'Purok', type: 'text', table: 'accommodations', column: 'purok' },
  barangay: { label: 'Barangay', type: 'text', table: 'accommodations', column: 'barangay' },
  city: { label: 'City', type: 'text', table: 'accommodations', column: 'city' },
  description: { label: 'Description', type: 'textarea', table: 'accommodations', column: 'description' },
  curfewTime: { label: 'Curfew', type: 'time', table: 'accommodation_policies', column: 'curfew_time' },
  quietHours: { label: 'Quiet hours', type: 'timerange', table: 'accommodation_policies', column: 'quiet_hours' },
  visitorPolicy: { label: 'Visitor policy', type: 'text', table: 'accommodation_policies', column: 'visitor_policy' },
}

export interface FloorGroup { floor: number | null; label: string; rooms: Room[]; facilities: Facility[] }

export const MAX_FLOORS = 6

// leases.room_id is ON DELETE RESTRICT at the database level (and leases
// cascade further to payments/concerns/tickets/reviews) — the count check
// below is just an early, friendly warning; the '23503' branch is what
// actually stops a delete if a lease slipped in between the check and here.
export function isLeaseRestrictError(e: unknown): boolean {
  return typeof e === 'object' && e !== null && (e as { code?: string }).code === '23503'
}
