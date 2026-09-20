// Cloudinary URL helpers (mobile). Mirrors how accommo-web optimizes stored
// Cloudinary asset URLs so that everywhere an upload lives, the stored URL is
// served compressed (auto format + auto quality). Non-Cloudinary URLs (legacy
// Supabase storage, passport images, etc.) pass through untouched.

const CLOUD_DELIVERY_RE = /(https:\/\/res\.cloudinary\.com\/[^/]+\/image\/upload\/)/;

const CLOUD_NAME = import.meta.env.VITE_CLOUDINARY_CLOUD_NAME as string | undefined;

/**
 * Google's profile pictures (a Google sign-in's avatar) can't be hotlinked:
 * the browser refuses to paint them in an `<img>` and the load fails, so the
 * avatar silently degrades to initials. Re-serving the very same image
 * through Cloudinary's fetch delivery puts it back on res.cloudinary.com,
 * which does load — and picks up f_auto,q_auto on the way.
 */
const GOOGLE_USERCONTENT_RE = /^https:\/\/[a-z0-9-]+\.googleusercontent\.com\//i;

function viaCloudinaryFetch(url: string, size?: AssetSize): string {
  // No cloud configured — better a broken-but-honest URL than a malformed one.
  if (!CLOUD_NAME) return url;
  const transform = `f_auto,q_auto${sizeParams(size)}`;
  return `https://res.cloudinary.com/${CLOUD_NAME}/image/fetch/${transform}/${encodeURIComponent(url)}`;
}

/** True when the URL points at a Cloudinary image delivery. */
function isCloudinaryUrl(url: string | null | undefined): boolean {
  return !!url && /res\.cloudinary\.com\/[^/]+\/(image|video|raw|auto)\/upload\//.test(url);
}

/**
 * How big the image will actually be drawn, in CSS pixels. Cloudinary's
 * `dpr_auto` handles retina from there, so pass the layout size, not the device
 * size.
 *
 * Without this a manager's 3000x4000 phone photo is delivered whole into a
 * 120px card — megabytes to paint a thumbnail, and far too large to survive in
 * the HTTP cache, so it is re-fetched on every visit.
 */
export interface AssetSize {
  /** Target width in CSS pixels. */
  w?: number
  /** Target height in CSS pixels. Only needed when cropping to a fixed box. */
  h?: number
  /** `fill` crops to the box (default); `fit` letterboxes inside it. */
  fit?: 'fill' | 'fit'
  /**
   * Which part of the image to keep when a `fill` crop has to discard some of
   * it. Cloudinary defaults to the geometric centre, which is the wrong answer
   * for a photo of a person — phone cameras put the face in the upper third.
   */
  gravity?: string
}

/**
 * The three sizes this app actually draws at. Using a shared constant rather
 * than a per-screen number matters for caching as much as for bytes: the same
 * avatar requested at the same width from the bottom nav, a chat header and a
 * profile hero is ONE cached file, not three.
 */
/**
 * Every avatar in the app: 36px in the nav, 84px on a profile hero.
 *
 * Square, because every surface that draws it draws it in a circle. With a
 * width and no height, `c_fill` has nothing to crop against and keeps the
 * original aspect ratio — a portrait phone photo arrived 96x128 and each
 * avatar box then cropped it to a circle in CSS, from the middle, cutting off
 * the head the picture was taken of. Cropping here instead means one square
 * image serves every surface identically.
 *
 * `faces:auto` keeps the faces in frame and falls back to Cloudinary's own
 * subject detection when it cannot find one, so a photo of something other
 * than a person still crops sensibly.
 *
 * 192 rather than 96: `dpr_auto` only upscales when the browser sends a DPR
 * client hint, which it does not do unless the page opts in with Accept-CH.
 * In the Capacitor WebView it silently resolves to 1x, so a 96px file was
 * being painted into an 84px circle on a 3x screen and looked soft.
 */
export const AVATAR: AssetSize = { w: 192, h: 192, gravity: 'faces:auto' }
/** List and card thumbnails, roughly full phone width. */
export const CARD: AssetSize = { w: 400 }
/** Full-bleed hero and detail images. */
export const COVER: AssetSize = { w: 800 }

function sizeParams(size?: AssetSize): string {
  if (!size?.w && !size?.h) return ''
  const parts: string[] = []
  if (size.w) parts.push(`w_${Math.round(size.w)}`)
  if (size.h) parts.push(`h_${Math.round(size.h)}`)
  const fit = size.fit === 'fit' ? 'fit' : 'fill'
  parts.push(`c_${fit}`)
  // Gravity only means anything to a crop; `fit` discards nothing.
  if (size.gravity && fit === 'fill') parts.push(`g_${size.gravity}`)
  parts.push('dpr_auto')
  return `,${parts.join(',')}`
}

/**
 * Normalize a Cloudinary image URL to the optimized delivery
 * (`/f_auto,q_auto/`) form, optionally sized. Idempotent — safe to call on any
 * stored value. PDFs and raw/video assets are returned unchanged.
 */
function optimizeCloudinaryUrl(url: string | null | undefined, size?: AssetSize): string {
  if (!url) return ''
  const transform = `f_auto,q_auto${sizeParams(size)}`
  // Already carries a transform: swap it rather than stacking a second one,
  // since these URLs get re-resolved on every render.
  if (url.includes('/f_auto,q_auto')) {
    return url.replace(/\/f_auto,q_auto[^/]*\//, `/${transform}/`)
  }
  return url.replace(CLOUD_DELIVERY_RE, (m) => `${m}${transform}/`)
}

/**
 * Give any stored asset URL its best run-time form. Cloudinary images become
 * optimized; everything else (PDFs, legacy Supabase, absolute paths) is passed
 * through unchanged. This is the one call sites should use before <img src>.
 *
 * Pass `size` wherever the display size is known — a card thumbnail, an avatar,
 * a chat photo. Omitting it keeps the original full-resolution behaviour, so
 * existing call sites are unaffected and surfaces can be sized one at a time.
 */
export function resolveAsset(url: string | null | undefined, size?: AssetSize): string {
  if (!url) return ''
  if (isCloudinaryUrl(url)) return optimizeCloudinaryUrl(url, size)
  if (GOOGLE_USERCONTENT_RE.test(url)) return viaCloudinaryFetch(url, size)
  return url
}

/** True when a stored asset URL points at a PDF rather than an image. */
export function isPdf(url: string | null | undefined): boolean {
  return !!url && /\.pdf(\?|$)/i.test(url)
}
