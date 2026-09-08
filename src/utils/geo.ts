// Distance is measured from the CAMPUS, not from the student's device.
// Students searching for a boarding house are typically not near Echague yet —
// they are somewhere else deciding where to move — so "near me" would answer a
// question nobody is asking. "How far is this from school?" is the real one,
// and it needs no location permission.

/** Isabela State University — Echague campus gate. */
export const CAMPUS = { lat: 16.721560301578872, lng: 121.68526268921849, label: 'ISU Echague' };

const EARTH_KM = 6371;

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

/** Great-circle distance in kilometres. */
export function kmBetween(
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number,
): number {
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_KM * Math.asin(Math.sqrt(h));
}

/**
 * Kilometres from campus, or null when the listing has no coordinates — which
 * is most of them, so every caller must render happily without it.
 */
export function kmFromCampus(
  lat: number | null | undefined,
  lng: number | null | undefined,
): number | null {
  if (typeof lat !== 'number' || typeof lng !== 'number') return null;
  return kmBetween(CAMPUS.lat, CAMPUS.lng, lat, lng);
}

/** "450 m from campus" / "1.2 km from campus" / "" when unknown. */
export function campusDistanceLabel(
  lat: number | null | undefined,
  lng: number | null | undefined,
): string {
  const km = kmFromCampus(lat, lng);
  if (km === null) return '';
  if (km < 1) return `${Math.round(km * 1000)} m from campus`;
  return `${km.toFixed(1)} km from campus`;
}

/**
 * Why a location lookup failed, in words a student can act on.
 *
 * Browsers only hand out position on a secure origin, and served over a plain
 * LAN address (`http://192.168.x.x`) every call fails with a bare permission
 * error — indistinguishable from the user actually denying it. Check the
 * origin first so the message says which it was.
 */
export function geolocationErrorMessage(error?: { code?: number } | null): string {
  if (typeof window !== 'undefined' && !window.isSecureContext) {
    return 'Location needs a secure connection (https, or localhost). Opened over a plain http address, the browser withholds it.';
  }
  if (!error) return 'Could not get your location.';
  // 1 PERMISSION_DENIED, 2 POSITION_UNAVAILABLE, 3 TIMEOUT
  if (error.code === 1) return 'Location permission is blocked for this app.';
  if (error.code === 2) return 'Your device could not get a fix right now.';
  if (error.code === 3) return 'Timed out getting your location.';
  return 'Could not get your location.';
}

const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined;

/**
 * A static map image showing the listing and the campus. Static rather than an
 * interactive canvas: it is one request, needs no library, and a detail page
 * only has to answer "roughly where is this".
 */
export function staticMapUrl(
  lat: number | null | undefined,
  lng: number | null | undefined,
  width = 640,
  height = 320,
): string {
  if (typeof lat !== 'number' || typeof lng !== 'number' || !MAPBOX_TOKEN) return '';
  const place = `pin-l-home+00897b(${lng},${lat})`;
  const campus = `pin-s-college+17202a(${CAMPUS.lng},${CAMPUS.lat})`;
  // Auto-fit so both pins are always in frame, however far apart they are.
  return (
    `https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/` +
    `${place},${campus}/auto/${width}x${height}@2x` +
    `?padding=60&access_token=${MAPBOX_TOKEN}`
  );
}
