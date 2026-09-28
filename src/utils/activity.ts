// "Last active": tell the database this person is using the app right now.
//
// Called by the router guard once a session is confirmed, and whenever the tab
// comes back into view. touch_last_active() writes at most once per 5 minutes
// per person; the same window here just saves the request. A failed ping is
// ignored — it must never get in the way of the page. Same file in
// accommo-web/src/utils/activity.ts.

import { supabase } from '@/utils/supabase'

const WINDOW_MS = 5 * 60 * 1000
let lastPing = 0

export function markActive(): void {
  if (Date.now() - lastPing < WINDOW_MS) return
  lastPing = Date.now()
  void supabase.auth.getSession().then(({ data }) => {
    if (data.session) void supabase.rpc('touch_last_active').then(() => undefined, () => undefined)
  })
}

// Returning to the app (the WebView fires this on Capacitor resume) or to the tab counts too.
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') markActive()
  })
}

// A new session (another person on the same device) gets its own first ping.
supabase.auth.onAuthStateChange((event) => {
  if (event === 'SIGNED_IN' || event === 'SIGNED_OUT') lastPing = 0
})
