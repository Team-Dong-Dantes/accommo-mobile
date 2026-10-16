// The wizard's fixed lists: house-rule toggles and the four permits.
import { type Database } from '@/types/database.gen'

export type AmenityKey = Database['public']['Enums']['amenity']

export const RULE_TOGGLES = [
  { key: 'cooking' as const, label: 'Cooking allowed' },
  { key: 'laundry' as const, label: 'Laundry allowed' },
  { key: 'pets' as const, label: 'Pets allowed' },
]

export const DOC_TYPES = [
  { key: 'sanitary_permit' as const, label: 'Sanitary permit' },
  { key: 'fire_safety' as const, label: 'Fire safety certificate' },
  { key: 'business_permit' as const, label: 'Business permit' },
  { key: 'building_permit' as const, label: 'Building permit' },
]
