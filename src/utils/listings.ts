// Shared vocabulary for the Discover list and the listing detail.
import { formatPeso } from '@/utils/format';
import type { Database } from '@/types/database.gen';

type UtilityBilling = Database['public']['Enums']['utility_billing'];

/**
 * Amenities are what the whole place has or doesn't have, parking included.
 * Spaces on a floor (kitchen, laundry area) are shared facilities and air-con
 * is a private facility of a room — see FACILITY_META. Water, electricity and Wi-Fi are not amenities:
 * what matters about them is how they are paid — see UTILITIES. The database's
 * `accommodation_amenities_utilities_only` constraint holds the same list.
 */
export const AMENITY_META: Record<string, { icon: string; label: string }> = {
  cctv: { icon: 'lucide:cctv', label: 'CCTV' },
  water_dispenser: { icon: 'lucide:glass-water', label: 'Water dispenser' },
  generator: { icon: 'lucide:battery-charging', label: 'Generator' },
  fire_extinguisher: { icon: 'lucide:fire-extinguisher', label: 'Fire extinguisher' },
  parking: { icon: 'lucide:square-parking', label: 'Parking' },
};

export const AMENITY_KEYS = Object.keys(AMENITY_META);

/**
 * The utilities, keyed as in `utility_bills.utility`, each with the billing
 * modes that make sense for it.
 */
export const UTILITIES = [
  { key: 'water', label: 'Water', icon: 'lucide:droplets', modes: ['included', 'own_meter', 'split', 'flat_fee'] },
  { key: 'electric', label: 'Electricity', icon: 'lucide:zap', modes: ['included', 'own_meter', 'split', 'flat_fee'] },
  // No meter for Wi-Fi, and unlike water and power plenty of places have none.
  { key: 'wifi', label: 'Wi-Fi', icon: 'lucide:wifi', modes: ['included', 'split', 'flat_fee', 'not_available'] },
] as const;
export type UtilityKey = (typeof UTILITIES)[number]['key'];

/**
 * How a utility is paid (`rooms.<utility>_billing`). own_meter and
 * split vary month to month, so the landlord/landlady posts them as bills;
 * a flat fee is folded into the rent payment; included costs nothing extra.
 */
export const UTILITY_BILLING_LABEL: Record<string, string> = {
  included: 'Included in rent',
  own_meter: 'Own meter',
  split: 'Split among tenants',
  flat_fee: 'Flat fee',
  not_available: 'Not available',
};

/** Billing modes whose amount the landlord/landlady posts each month. */
export function isBilledMonthly(billing: string | null | undefined): boolean {
  return billing === 'own_meter' || billing === 'split';
}

export interface UtilityTerms {
  billing: string | null;
  flatFee: number | null;
}

/** Whether students get this utility at all (Wi-Fi can be absent). */
export function isUtilityAvailable(t: UtilityTerms): boolean {
  return Boolean(t.billing) && t.billing !== 'not_available';
}

/** "Flat fee · ₱300/mo", "Own meter", or "Not specified". */
export function utilityTermsLabel(t: UtilityTerms): string {
  if (!t.billing) return 'Not specified';
  const label = UTILITY_BILLING_LABEL[t.billing] ?? t.billing;
  return t.billing === 'flat_fee' && t.flatFee ? `${label} · ${formatPeso(t.flatFee)}/mo` : label;
}

/** The six utility columns a room row carries (`<utility>_billing` / `_flat_fee`). */
export interface UtilityColumns {
  water_billing: UtilityBilling | null;
  water_flat_fee: number | null;
  electric_billing: UtilityBilling | null;
  electric_flat_fee: number | null;
  wifi_billing: UtilityBilling | null;
  wifi_flat_fee: number | null;
}

/** A room row's columns as the form/display model. */
export function utilitiesFromRow(row: Partial<UtilityColumns> | null | undefined): Record<UtilityKey, UtilityTerms> {
  return {
    water: { billing: row?.water_billing ?? null, flatFee: row?.water_flat_fee ?? null },
    electric: { billing: row?.electric_billing ?? null, flatFee: row?.electric_flat_fee ?? null },
    wifi: { billing: row?.wifi_billing ?? null, flatFee: row?.wifi_flat_fee ?? null },
  };
}

/**
 * The model back to columns. A fee is dropped unless the mode is flat_fee, and
 * a flat fee with no amount is saved as unspecified — the shapes the database's
 * `rooms_<utility>_flat_fee` checks accept.
 */
export function utilityColumns(u: Record<UtilityKey, UtilityTerms>): UtilityColumns {
  const col = (t: UtilityTerms) =>
    t.billing === 'flat_fee' && !t.flatFee
      ? { billing: null, fee: null }
      : { billing: (t.billing as UtilityBilling | null) ?? null, fee: t.billing === 'flat_fee' ? t.flatFee : null };
  const w = col(u.water), e = col(u.electric), i = col(u.wifi);
  return {
    water_billing: w.billing, water_flat_fee: w.fee,
    electric_billing: e.billing, electric_flat_fee: e.fee,
    wifi_billing: i.billing, wifi_flat_fee: i.fee,
  };
}

/** The select-list fragment for those columns. */
export const UTILITY_SELECT = 'water_billing,water_flat_fee,electric_billing,electric_flat_fee,wifi_billing,wifi_flat_fee';

/**
 * One line for a room card: "Utilities included", or only what differs from
 * that — "Electricity: own meter · No Wi-Fi". Empty when nothing is known yet,
 * or when only some utilities are set and all of those are included: saying
 * "included" there would be a guess about the rest.
 */
export function utilitiesHint(u: Record<UtilityKey, UtilityTerms>): string {
  const parts: string[] = [];
  for (const { key, label } of UTILITIES) {
    const t = u[key];
    if (!t.billing || t.billing === 'included') continue;
    if (t.billing === 'not_available') parts.push(`No ${label}`);
    else if (t.billing === 'flat_fee' && t.flatFee) parts.push(`${label} +${formatPeso(t.flatFee)}`);
    else parts.push(`${label}: ${(UTILITY_BILLING_LABEL[t.billing] ?? t.billing).toLowerCase()}`);
  }
  if (parts.length) return parts.join(' · ');
  return UTILITIES.every(({ key }) => u[key].billing === 'included') ? 'Utilities included' : '';
}

/** Every utility, none specified yet. */
export function emptyUtilities(): Record<UtilityKey, UtilityTerms> {
  return {
    water: { billing: null, flatFee: null },
    electric: { billing: null, flatFee: null },
    wifi: { billing: null, flatFee: null },
  };
}

/** What's still missing from the utilities form, or '' when both are complete. */
export function utilitiesProblem(u: Record<UtilityKey, UtilityTerms>): string {
  for (const { key, label } of UTILITIES) {
    const noun = key === 'wifi' ? label : label.toLowerCase();
    if (!u[key].billing) return `Choose how ${noun} is paid.`;
    if (u[key].billing === 'flat_fee' && !u[key].flatFee) return `Enter the monthly ${noun} fee.`;
  }
  return '';
}

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
 * Facility types no longer offered. Parking is property-wide, so it is an
 * amenity now; FACILITY_META keeps its entry only so a row an older APK still
 * creates renders by name instead of as "Facility".
 */
export const RETIRED_FACILITY_TYPES = ['parking'];

/**
 * What students can filter listings by: the amenities plus the facilities they
 * most often look for. Keys match AMENITY_META or FACILITY_META; a listing
 * matches a key when it has that amenity or a facility of that type.
 */
export const SEARCH_FEATURES: { key: string; icon: string; label: string }[] = [
  // Wi-Fi is a utility now, but still the first thing students filter on: a
  // listing matches when any of its rooms has Wi-Fi that isn't "not available".
  { key: 'wifi', icon: 'lucide:wifi', label: 'Wi-Fi' },
  ...Object.entries(AMENITY_META).map(([key, m]) => ({ key, ...m })),
  ...['aircon', 'kitchen', 'laundry'].map((key) => ({
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
