import { supabase } from '@/utils/supabase';

// Use the same demo mode check pattern as the rest of the app
// supabase.ts checks: const demoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';
const isDemoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';

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

// Fetch unread notifications for a user, ordered newest first
export async function fetchNotifications(userId: string) {
  // In demo mode, return empty array - no real data
  if (isDemoMode) {
    console.log('[Demo Mode] fetchNotifications returning empty (no real Supabase)');
    return [];
  }

  const { data, error } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .order('id', { ascending: false })
    .limit(50);

  if (error) {
    console.error('Failed to fetch notifications:', error.message);
    return [];
  }
  return data ?? [];
}

// Mark a single notification as read
export async function markNotificationRead(notificationId: string) {
  // In demo mode, just log and return true
  if (isDemoMode) {
    console.log('[Demo Mode] markNotificationRead:', notificationId);
    return true;
  }

  const { error } = await supabase
    .from('notifications')
    .update({ read_at: new Date().toISOString() })
    .eq('id', notificationId);

  if (error) {
    console.error('Failed to mark notification as read:', error.message);
    return false;
  }
  return true;
}

// Mark all notifications as read for a user
export async function markAllNotificationsRead(userId: string) {
  // In demo mode, just log and return true
  if (isDemoMode) {
    console.log('[Demo Mode] markAllNotificationsRead:', userId);
    return true;
  }

  const { error } = await supabase
    .from('notifications')
    .update({ read_at: new Date().toISOString() })
    .eq('user_id', userId);

  if (error) {
    console.error('Failed to mark all notifications as read:', error.message);
    return false;
  }
  return true;
}

// Show a Quasar Notify toast notification
// This should be called from a component that has $q context
export function showToast(title: string, message: string, type: 'positive' | 'negative' | 'warning' | 'info' = 'info') {
  // Quasar Notify is available as $q.notify in components
  // We'll use a simple console fallback for now
  // In actual usage, call: $q.notify({ title, message, type })
  console.log(`[Quasar Notify] ${title}: ${message} [type: ${type}]`);
}