import { supabase } from '@/utils/supabase'
import { clearAllCache } from '@/utils/persistCache'
import { useNotificationsStore } from '@/stores/notifications'
import { useMessagesStore } from '@/stores/messages'
import { stopPush } from '@/utils/push'

/** The explicit Sign out (Settings). Callers navigate to /login afterwards. */
export async function signOut() {
  // Stop the realtime subscriptions before dropping the session: leaving them
  // open would carry one user's channels into the next sign-in on the same device.
  useNotificationsStore().stop()
  useMessagesStore().stop()
  // Before signOut(): dropping this device's token is the user's own delete under RLS.
  await stopPush().catch(() => {})
  // Same reasoning as the channels above: a cached dashboard/listing from
  // this account must not flash on screen for the next one who signs in.
  clearAllCache()
  await supabase.auth.signOut()
}
