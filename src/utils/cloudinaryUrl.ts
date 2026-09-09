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

function viaCloudinaryFetch(url: string): string {
  // No cloud configured — better a broken-but-honest URL than a malformed one.
  if (!CLOUD_NAME) return url;
  return `https://res.cloudinary.com/${CLOUD_NAME}/image/fetch/f_auto,q_auto/${encodeURIComponent(url)}`;
}

/** True when the URL points at a Cloudinary image delivery. */
function isCloudinaryUrl(url: string | null | undefined): boolean {
  return !!url && /res\.cloudinary\.com\/[^/]+\/(image|video|raw|auto)\/upload\//.test(url);
}

/**
 * Normalize a Cloudinary image URL to the optimized delivery
 * (`/f_auto,q_auto/`) form. Idempotent — safe to call on any stored value.
 * PDFs and raw/video assets are returned unchanged.
 */
function optimizeCloudinaryUrl(url: string | null | undefined): string {
  if (!url) return ''
  // Already optimized (f_auto present) → leave alone.
  if (url.includes('/f_auto,q_auto/')) return url
  return url.replace(CLOUD_DELIVERY_RE, (m) => `${m}f_auto,q_auto/`)
}

/**
 * Give any stored asset URL its best run-time form. Cloudinary images become
 * optimized; everything else (PDFs, legacy Supabase, absolute paths) is passed
 * through unchanged. This is the one call sites should use before <img src>.
 */
export function resolveAsset(url: string | null | undefined): string {
  if (!url) return ''
  if (isCloudinaryUrl(url)) return optimizeCloudinaryUrl(url)
  if (GOOGLE_USERCONTENT_RE.test(url)) return viaCloudinaryFetch(url)
  return url
}

/** True when a stored asset URL points at a PDF rather than an image. */
export function isPdf(url: string | null | undefined): boolean {
  return !!url && /\.pdf(\?|$)/i.test(url)
}
