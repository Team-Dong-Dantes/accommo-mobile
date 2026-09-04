// Shared vocabulary for the Discover list and the listing detail.

export const AMENITY_META: Record<string, { icon: string; label: string }> = {
  wifi: { icon: 'lucide:wifi', label: 'Wi-Fi' },
  water: { icon: 'lucide:droplets', label: 'Water' },
  electric: { icon: 'lucide:zap', label: 'Electricity' },
  aircon: { icon: 'lucide:air-vent', label: 'Air-con' },
  parking: { icon: 'lucide:car', label: 'Parking' },
  kitchen: { icon: 'lucide:cooking-pot', label: 'Kitchen' },
  laundry: { icon: 'lucide:washing-machine', label: 'Laundry' },
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
  other: { icon: 'lucide:box', label: 'Facility' },
};

export const ROOM_TYPE_LABEL: Record<string, string> = {
  solo: 'Solo',
  duo: 'Duo',
  triple: 'Triple',
  bedspace: 'Bedspace',
  studio: 'Studio',
};

export function roomTypeLabel(value: string | null | undefined): string {
  if (!value) return 'Room';
  return ROOM_TYPE_LABEL[value] ?? value;
}

// accommodation_type holds a mix of real building types and, on some rows, a
// room type that was written into the wrong field. Only recognised building
// types get rendered; anything else is dropped rather than shown as a lie.
export const BUILDING_TYPE_LABEL: Record<string, string> = {
  boarding_house: 'Boarding house',
  apartment_building: 'Apartment',
  residence_hall: 'Residence hall',
  condominium_unit: 'Condominium',
  dormitory: 'Dormitory',
};

export function buildingTypeLabel(value: string | null | undefined): string {
  if (!value) return '';
  return BUILDING_TYPE_LABEL[value] ?? '';
}

/** Two letters for the monogram used when a listing has no photo. */
export function listingMonogram(name: string): string {
  const words = (name || '').trim().split(/\s+/).filter(Boolean);
  if (!words.length) return '??';
  if (words.length === 1) return (words[0] ?? '').slice(0, 2).toUpperCase();
  return ((words[0]?.[0] ?? '') + (words[1]?.[0] ?? '')).toUpperCase();
}
