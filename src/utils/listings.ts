// Shared vocabulary for the Discover list and the listing detail.

/**
 * Amenities are the utilities and services that come with the whole place.
 * Spaces (kitchen, laundry, parking) are shared facilities and air-con is a
 * private facility of a room — see FACILITY_META. The database's
 * `accommodation_amenities_utilities_only` constraint holds the same list.
 */
export const AMENITY_META: Record<string, { icon: string; label: string }> = {
  wifi: { icon: 'lucide:wifi', label: 'Wi-Fi' },
  water: { icon: 'lucide:droplets', label: 'Water' },
  electric: { icon: 'lucide:zap', label: 'Electricity' },
  cctv: { icon: 'lucide:cctv', label: 'CCTV' },
};

export const AMENITY_KEYS = Object.keys(AMENITY_META);

export const FACILITY_META: Record<string, { icon: string; label: string }> = {
  bathroom: { icon: 'lucide:bath', label: 'Bathroom' },
  kitchen: { icon: 'lucide:cooking-pot', label: 'Kitchen' },
  laundry: { icon: 'lucide:washing-machine', label: 'Laundry area' },
  balcony: { icon: 'lucide:door-open', label: 'Balcony' },
  common_area: { icon: 'lucide:sofa', label: 'Common area' },
  study_area: { icon: 'lucide:book-open', label: 'Study area' },
  parking: { icon: 'lucide:car', label: 'Parking' },
  aircon: { icon: 'lucide:air-vent', label: 'Air-con' },
  other: { icon: 'lucide:box', label: 'Facility' },
};

/** Facility types that only make sense inside a room, never as a shared space. */
export const PRIVATE_ONLY_FACILITY_TYPES = ['aircon'];

/**
 * What students can filter listings by: the amenities plus the facilities they
 * most often look for. Keys match AMENITY_META or FACILITY_META; a listing
 * matches a key when it has that amenity or a facility of that type.
 */
export const SEARCH_FEATURES: { key: string; icon: string; label: string }[] = [
  ...Object.entries(AMENITY_META).map(([key, m]) => ({ key, ...m })),
  ...['aircon', 'kitchen', 'laundry', 'parking'].map((key) => ({
    key,
    icon: FACILITY_META[key]?.icon ?? 'lucide:box',
    label: key === 'laundry' ? 'Laundry' : (FACILITY_META[key]?.label ?? key),
  })),
];

export const ROOM_TYPE_LABEL: Record<string, string> = {
  solo: 'Solo',
  duo: 'Duo',
  triple: 'Triple',
  bedspace: 'Bedspace',
  studio: 'Studio',
};

// Solo/Duo/Triple have an implied bed count; Bedspace/Studio/Custom don't, so
// only these three get a locked (non-editable) capacity in the room form.
export const ROOM_TYPE_DEFAULT_CAPACITY: Record<string, number> = {
  solo: 1,
  duo: 2,
  triple: 3,
};

export function roomTypeLabel(value: string | null | undefined): string {
  if (!value) return 'Room';
  return ROOM_TYPE_LABEL[value] ?? value;
}

// accommodation_type holds a mix of real building types and, on some rows, a
// room type that was written into the wrong field. Only recognised building
// types get rendered; anything else is dropped rather than shown as a lie.
/**
 * The only three kinds of place an accommodation can be. The database enforces
 * the same three (`accommodations_accommodation_type_check`), so anything not
 * in here cannot be saved.
 *
 * `apartment_building`, `condominium_unit` and `residence_hall` are retired —
 * the rows that held them were rewritten to `residence`. Do not reintroduce
 * them here without lifting the check constraint first.
 */
export const BUILDING_TYPE_LABEL: Record<string, string> = {
  boarding_house: 'Boarding house',
  residence: 'Residence',
  dormitory: 'Dormitory',
};

export function buildingTypeLabel(value: string | null | undefined): string {
  if (!value) return '';
  return BUILDING_TYPE_LABEL[value] ?? '';
}

// Who an accommodation accepts. Rows created before this field existed hold
// null and render as nothing rather than a guess — see the gender_policy
// migration for why there is no backfill.
export const GENDER_POLICY_LABEL: Record<string, string> = {
  male: 'Male only',
  female: 'Female only',
  co_ed: 'Co-ed',
};

export function genderPolicyLabel(value: string | null | undefined): string {
  if (!value) return '';
  return GENDER_POLICY_LABEL[value] ?? '';
}

/** Two letters for the monogram used when a listing has no photo. */
export function listingMonogram(name: string): string {
  const words = (name || '').trim().split(/\s+/).filter(Boolean);
  if (!words.length) return '??';
  if (words.length === 1) return (words[0] ?? '').slice(0, 2).toUpperCase();
  return ((words[0]?.[0] ?? '') + (words[1]?.[0] ?? '')).toUpperCase();
}
