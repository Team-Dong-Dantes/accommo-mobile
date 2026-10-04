import { supabase } from '@/utils/supabase'
import { clearAllCache } from '@/utils/persistCache'
import { useNotificationsStore } from '@/stores/notifications'
import { useMessagesStore } from '@/stores/messages'
import { stopPush } from '@/utils/push'
import { usePinStore } from '@/stores/pin'

/** The explicit Sign out (Settings). Callers navigate to /login afterwards. */
export async function signOut() {
  // Stop the realtime subscriptions before dropping the session: leaving them
  // open would carry one user's channels into the next sign-in on the same device.
  useNotificationsStore().stop()
  useMessagesStore().stop()
  // Drop the unlock and the has-PIN answer with the session, so the next
  // account on this device is never treated as already unlocked.
  // Before signOut(): dropping this device's token is the user's own delete under RLS.
  await stopPush().catch(() => {})
  const pin = usePinStore()
  pin.lock()
  pin.hasPin = false
  pin.ready = false
  // Same reasoning as the channels above: a cached dashboard/listing from
  // this account must not flash on screen for the next one who signs in.
  clearAllCache()
  await supabase.auth.signOut()
}
