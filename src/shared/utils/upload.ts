// Cloudinary client-side upload helper (unsigned) — mobile.
//
// Mirrors the web app's Cloudinary setup (accommo-web/src/utils/cloudinary.ts)
// so every file/image in the app is stored in Cloudinary instead of Supabase
// Storage. Unsigned upload: NO API secret is exposed to the client.
//
//   VITE_CLOUDINARY_CLOUD_NAME    — e.g. n5mhxcnb
//   VITE_CLOUDINARY_UPLOAD_PRESET — an UNSIGNED upload preset ('accommo')
//
// Images go to /image/upload (auto WebP + q_auto), PDFs/other files go to
// /file/upload on the same cloud.

const CLOUD_NAME = import.meta.env.VITE_CLOUDINARY_CLOUD_NAME as string | undefined;
const UPLOAD_PRESET = import.meta.env.VITE_CLOUDINARY_UPLOAD_PRESET as string | undefined;

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_IMAGE = ['image/jpeg', 'image/png', 'image/webp'];
const ALLOWED_ALL = [...ALLOWED_IMAGE, 'application/pdf'];

export interface CloudinaryUploadResult {
  publicId: string;
  /** Optimized, ready-to-use URL (auto format + auto quality for images). */
  url: string;
  /** Original secure URL. */
  secureUrl: string;
  width: number | null;
  height: number | null;
  format: string;
  bytes: number;
}

function isConfigured(): boolean {
  return Boolean(CLOUD_NAME && UPLOAD_PRESET);
}

function imageEndpoint(): string {
  return `https://api.cloudinary.com/v1_1/${CLOUD_NAME}/image/upload`;
}
function fileEndpoint(): string {
  return `https://api.cloudinary.com/v1_1/${CLOUD_NAME}/auto/upload`;
}

/** Appends Cloudinary auto-optimization params (auto format + auto quality). */
function optimizeUrl(rawUrl: string): string {
  return rawUrl.replace(
    /(https:\/\/res\.cloudinary\.com\/[^/]+\/(?:image)\/upload\/)/,
    (m) => `${m}f_auto,q_auto/`,
  );
}

function emptyMessage(): string {
  return 'Cloudinary is not configured. Add VITE_CLOUDINARY_CLOUD_NAME and VITE_CLOUDINARY_UPLOAD_PRESET to your environment.';
}

export function validateFile(file: File): string | null {
  if (file.size > MAX_FILE_SIZE) {
    return 'File size must be less than 5MB.';
  }
  if (!ALLOWED_ALL.includes(file.type)) {
    return 'Only JPEG, PNG, WebP images and PDF files are allowed.';
  }
  return null;
}

async function performUpload(file: File): Promise<CloudinaryUploadResult> {
  const validationError = validateFile(file);
  if (validationError) throw new Error(validationError);
  if (!isConfigured()) throw new Error(emptyMessage());

  const form = new FormData();
  form.append('file', file);
  form.append('upload_preset', UPLOAD_PRESET!);

  // Images → image endpoint; PDFs/other files → the generic (resource-aware)
  // auto endpoint on the same cloud.
  const endpoint = ALLOWED_IMAGE.includes(file.type) ? imageEndpoint() : fileEndpoint();

  const withTimeout = new Promise<CloudinaryUploadResult>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Upload timed out. Please try again.')), 60000);
    fetch(endpoint, { method: 'POST', body: form })
      .then(async (response) => {
        if (!response.ok) {
          const body = await response.text().catch(() => '');
          throw new Error(`Cloudinary upload failed (${response.status}): ${body || response.statusText}`);
        }
        return response.json();
      })
      .then((json) => {
        clearTimeout(timer);
        resolve({
          publicId: json.public_id,
          url: optimizeUrl(json.secure_url || json.url || ''),
          secureUrl: json.secure_url || json.url || '',
          width: json.width ?? null,
          height: json.height ?? null,
          format: json.format ?? file.type,
          bytes: json.bytes ?? file.size,
        });
      })
      .catch((err) => {
        clearTimeout(timer);
        reject(err);
      });
  });

  return withTimeout;
}

/** Uploads one or more files / images to Cloudinary. */
export async function uploadToCloudinary(
  files: File | File[],
  _folder?: string,
): Promise<CloudinaryUploadResult[]> {
  const list = Array.isArray(files) ? files : [files];
  return Promise.all(list.map((file) => performUpload(file)));
}

/**
 * Legacy/central upload entry point. Keeps the previous signature used by the
 * rest of the app (LandlordOSASCompliance, PropertyDetail, StudentPayments,
 * StudentProfile, stores, AddPropertyWizard, …). Returns the Cloudinary URL.
 *
 * @param file    the File to upload (image or PDF)
 * @param _userId kept for signature parity (paths no longer used on Supabase)
 * @param _docType kept for signature parity (used as a hint only)
 */
export async function uploadDocument(
  file: File,
  _userId: string,
  _docType: string,
): Promise<string> {
  const result = await performUpload(file);
  return result.url || result.secureUrl;
}
