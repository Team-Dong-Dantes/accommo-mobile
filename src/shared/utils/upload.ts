import { supabase } from '@/shared/utils/supabase';

const MAX_FILE_SIZE = 5 * 1024 * 1024;
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

export function validateFile(file: File): string | null {
  if (file.size > MAX_FILE_SIZE) {
    return 'File size must be less than 5MB.';
  }
  if (!ALLOWED_TYPES.includes(file.type)) {
    return 'Only JPEG, PNG, WebP images and PDF files are allowed.';
  }
  return null;
}

export async function uploadDocument(
  file: File,
  userId: string,
  docType: string,
): Promise<string> {
  const validationError = validateFile(file);
  if (validationError) throw new Error(validationError);

  const ext = file.name.split('.').pop() ?? 'jpg';
  const filePath = `${userId}/${docType}_${Date.now()}.${ext}`;

  const uploadPromise = supabase.storage
    .from('documents')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type,
    });

  // Cap the upload time so a stalled connection can't hang the caller
  // (e.g. registration) indefinitely. On timeout the pending request is
  // abandoned and the caller's catch treats it as a failed upload.
  const withTimeout = new Promise<{ data: unknown; error: unknown }>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Upload timed out')), 60000);
    uploadPromise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value as { data: unknown; error: unknown });
      },
      (err) => {
        clearTimeout(timer);
        reject(err);
      },
    );
  });

  const { error: uploadError } = await withTimeout;
  if (uploadError) throw uploadError;

  const { data: urlData } = supabase.storage
    .from('documents')
    .getPublicUrl(filePath);

  return urlData.publicUrl;
}
