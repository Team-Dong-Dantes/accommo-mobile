import { formatPeso } from '@/utils/format';
import { kmFromCampus } from '@/utils/geo';

// The Discover map's pins answer a student's first questions without a tap:
// what it costs, whether there's room, and whether it takes them at all. The
// rules live here, away from the page, so they can be tested.

export interface PinFacts {
  vacancies: number;
  /** Cheapest rent among vacant rooms; null when none is vacant or priced. */
  minVacantRent: number | null;
  /** accommodations.gender_policy: male | female | co_ed | null. */
  genderKind: string | null;
  /** accommodations.accommodation_type: boarding_house | residence | dormitory | null. */
  buildingKind: string | null;
}

/** What the pin says: the cheapest vacant rent, "Vacant" when that rent isn't
 * listed, or "Full". */
export function pinLabel(p: PinFacts): string {
  if (!p.vacancies) return 'Full';
  return p.minVacantRent ? formatPeso(p.minVacantRent) : 'Vacant';
}

/** Whether a student of this sex (users.sex: M | F | U) may live there. An
 * unknown sex or an unset policy never rules a place out — no guessing. */
export function takesSex(genderKind: string | null, sex: string | null | undefined): boolean {
  if (!genderKind || genderKind === 'co_ed') return true;
  if (sex === 'M') return genderKind === 'male';
  if (sex === 'F') return genderKind === 'female';
  return true;
}

/** Walking minutes to campus before Directions answers. ponytail: straight
 * line × 1.3 detour at 4.8 km/h; the selected place swaps in the real route
 * time, so only unselected cards ever show this guess. */
export function walkMinutesGuess(lat: number | null, lng: number | null): number | null {
  const km = kmFromCampus(lat, lng);
  if (km === null) return null;
  return Math.max(1, Math.round(((km * 1.3) / 4.8) * 60));
}

export interface MapChips {
  vacant: boolean;
  fitsMe: boolean;
  under3k: boolean;
  dorm: boolean;
  boarding: boolean;
}

export const UNDER_RENT = 3000;

/** The quick chips on the map. Dorm and Boarding house widen each other (either
 * kind); every other chip narrows. */
export function passesChips(p: PinFacts, chips: MapChips, sex: string | null): boolean {
  if (chips.vacant && !p.vacancies) return false;
  if (chips.fitsMe && !takesSex(p.genderKind, sex)) return false;
  if (chips.under3k && !(p.minVacantRent && p.minVacantRent <= UNDER_RENT)) return false;
  const kinds = [chips.dorm && 'dormitory', chips.boarding && 'boarding_house'].filter(Boolean);
  if (kinds.length && !kinds.includes(p.buildingKind ?? '')) return false;
  return true;
}

/** A price pill with a tail. `anchor` goes to mapboxgl.Marker({ element,
 * anchor: 'bottom' }); `pin` is the pill, styled by .price-pin in
 * StudentDiscoverPage. Two elements because Mapbox places a marker by setting
 * its `transform` and `position`: styling those on the marker itself (the
 * picked pin's scale-up) overrode the placement and the pins drifted. */
export function pricePinElement(
  name: string,
  label: string,
  opts: { full: boolean; dim: boolean },
): { anchor: HTMLElement; pin: HTMLElement } {
  const anchor = document.createElement('div');
  const el = document.createElement('button');
  anchor.appendChild(el);
  el.type = 'button';
  el.className = 'price-pin';
  if (opts.full) el.classList.add('price-pin--full');
  if (opts.dim) el.classList.add('price-pin--dim');
  el.textContent = label;
  el.setAttribute('aria-label', `${name}, ${label}`);
  return { anchor, pin: el };
}

// Lucide graduation-cap.
const CAP_SVG =
  '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z"/><path d="M22 10v6"/><path d="M6 12.5V16a6 3 0 0 0 12 0v-3.5"/></svg>';

/** The campus landmark: a badge, not a pin, so it never reads as a listing. */
export function campusBadgeElement(label: string): HTMLElement {
  const el = document.createElement('div');
  el.className = 'campus-badge';
  el.setAttribute('aria-label', `${label} campus`);
  el.innerHTML = `<span class="campus-badge-icon">${CAP_SVG}</span>`;
  const text = document.createElement('span');
  text.textContent = label;
  el.appendChild(text);
  return el;
}
