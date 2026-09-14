import { supabase } from '@/utils/supabase';

// Use the same demo mode check pattern as the rest of the app
// supabase.ts checks: const demoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';
const isDemoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';

// This file used to also export fetchNotifications, markNotificationRead,
// markAllNotificationsRead and a showToast() that only console.logged a pretend
// toast. None of the four had a single caller — reading and marking both live in
// stores/notifications.ts — and fetchNotifications ordered by `id`, a
// gen_random_uuid() column, while its comment claimed "newest first". Deleted
// rather than fixed: the working version already exists in the store.

// Create a notification stored in Supabase notifications table
export async function createNotification(
  userId: string,
  title: string,
  body: string,
  type: string = 'system',
  link_url?: string
) {
  // In demo mode, just log and return true (no actual DB write)
  if (isDemoMode) {
    console.log('[Demo Mode] Notification would be created:', { title, body, userId });
    return true;
  }

  // NOTE: do NOT send `id`. `notifications.id` is a uuid column with a
  // `gen_random_uuid()` default; passing a base36 string made every insert fail
  // with `invalid input syntax for type uuid`, so notifications never worked.
  const { error } = await supabase.from('notifications').insert({
    title,
    body,
    type,
    user_id: userId,
    link_url: link_url ?? null,
    read_at: null,
  });

  if (error) {
    console.error('Failed to create notification:', error.message);
    return false;
  }
  return true;
}
