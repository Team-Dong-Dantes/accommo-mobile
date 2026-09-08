import { supabase } from '@/utils/supabase';

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

function validateFile(file: File): string | null {
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
 * rest of the app (ManagerOSASCompliance, PropertyDetail, StudentPayments,
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

/**
 * Uploads a new profile photo and stores it where the app already looks.
 *
 * Written to two places: the auth user's metadata (what MainLayout reads for
 * your own chrome/profile, unchanged from before) and `users.avatar_url` —
 * without the latter, nobody else can ever see this photo, since a client can
 * only read its own session's auth metadata, never another user's. The
 * accommo:avatar-change event refreshes the bottom-nav avatar without
 * waiting for a reload.
 */
export async function uploadAvatar(file: File, userId: string): Promise<string> {
  if (!ALLOWED_IMAGE.includes(file.type)) {
    throw new Error('An avatar must be a JPEG, PNG or WebP image.');
  }

  const result = await performUpload(file);
  const url = result.url || result.secureUrl;

  const { error } = await supabase.auth.updateUser({ data: { avatar_url: url } });
  if (error) throw error;

  const { error: dbError } = await supabase.from('users').update({ avatar_url: url }).eq('id', userId);
  if (dbError) throw dbError;

  window.dispatchEvent(new CustomEvent('accommo:avatar-change', { detail: { url } }));
  return url;
}

/* -------------------------------------------------------------------------- */
/* Sensitive documents: Cloudinary `authenticated` delivery                    */
/* -------------------------------------------------------------------------- */
//
// Identity documents, enrolment records and accommodation permits must not sit at
// a public URL — with the default `upload` delivery type the link itself is the
// credential, readable by anyone who ever sees it and unaffected by a later
// rejection. These upload with delivery type `authenticated` and are read back
// through short-lived signed URLs.
//
// Both signatures come from the `doc-access` edge function, because computing
// them needs the Cloudinary API secret and that must never reach client code.
// Photos, avatars and listing images deliberately keep using the public,
// unsigned path above.

/** What we store in file_url: cld:<resource_type>:<type>:<format>:<public_id> */
export type DocumentRef = string;

export type DocumentTable = 'verification_documents' | 'accommodation_documents';

/** Uploads a document to Cloudinary with authenticated delivery; returns the ref to store. */
export async function uploadSecureDocument(file: File): Promise<DocumentRef> {
  const validationError = validateFile(file);
  if (validationError) throw new Error(validationError);

  const isPdf = file.type === 'application/pdf';
  const { data: params, error } = await supabase.functions.invoke('doc-access', {
    body: { action: 'upload-params', resourceType: isPdf ? 'raw' : 'image' },
  });
  if (error) throw error;

  const form = new FormData();
  form.append('file', file);
  form.append('api_key', params.apiKey);
  form.append('timestamp', String(params.timestamp));
  form.append('folder', params.folder);
  form.append('type', params.type);
  form.append('signature', params.signature);

  const endpoint = `https://api.cloudinary.com/v1_1/${params.cloudName}/${params.resourceType}/upload`;
  const response = await fetch(endpoint, { method: 'POST', body: form });
  const json = await response.json();
  if (!response.ok) {
    throw new Error(`Upload failed (${response.status}): ${json?.error?.message || response.statusText}`);
  }
  return ['cld', params.resourceType, json.type || 'authenticated', json.format || '', json.public_id].join(':');
}

/**
 * Short-lived signed URL for one document row. Authorization happens inside the
 * function via this caller's own RLS, so a row you cannot select yields nothing.
 * Returns '' when the document is missing or not permitted.
 */
export async function secureDocUrl(table: DocumentTable, id: string | null | undefined): Promise<string> {
  if (!id) return '';
  const { data, error } = await supabase.functions.invoke('doc-access', {
    body: { action: 'view', table, id },
  });
  if (error) return '';
  return (data?.url as string) || '';
}
