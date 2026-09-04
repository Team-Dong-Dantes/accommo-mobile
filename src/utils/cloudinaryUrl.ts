// Cloudinary URL helpers (mobile). Mirrors how accommo-web optimizes stored
// Cloudinary asset URLs so that everywhere an upload lives, the stored URL is
// served compressed (auto format + auto quality). Non-Cloudinary URLs (legacy
// Supabase storage, passport images, etc.) pass through untouched.

const CLOUD_DELIVERY_RE = /(https:\/\/res\.cloudinary\.com\/[^/]+\/image\/upload\/)/;

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
  return isCloudinaryUrl(url) ? optimizeCloudinaryUrl(url) : url
}
