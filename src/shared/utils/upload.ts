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

  const { error: uploadError } = await supabase.storage
    .from('documents')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type,
    });

  if (uploadError) throw uploadError;

  const { data: urlData } = supabase.storage
    .from('documents')
    .getPublicUrl(filePath);

  return urlData.publicUrl;
}
