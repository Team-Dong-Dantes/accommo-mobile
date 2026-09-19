// Disk-backed sibling to useLiveData.ts's in-memory freshness policy. That
// composable deliberately keeps no rows of its own (see its header comment) —
// this is the opt-in layer a screen reaches for when it wants its last-loaded
// data to survive an app kill instead of going blank on next launch.
//
// localStorage, not IndexedDB: Capacitor's WebView backs it with real on-disk
// storage that survives a kill, and it's the same mechanism the app already
// uses elsewhere (BroadcastBanner's SEEN_KEY, theme.ts). Reach for IndexedDB
// only if a cached payload gets large enough to threaten its ~5MB ceiling.
//
// Deliberately opt-in per screen, not a blanket cache-everything: some tables
// (messages, tenant phone numbers, uploaded IDs) are gated behind PinGate
// specifically so they don't sit around outside an active session — writing
// them to disk here would undo that. Only cache screens that show nothing a
// PIN would otherwise cover.
import { storedUserId } from '@/utils/supabase'

const PREFIX = 'accommo:cache:'

/**
 * Cache keys are per account, not per screen.
 *
 * The screen keys are global names — `student-dashboard`, `manager-tenants` —
 * and clearAllCache() only runs on the explicit Sign out button. Every other way
 * a session ends (it expires, OSAS suspends the account, the router guard signs
 * it out) left the previous account's rows on disk under a key the next account
 * reads, and useLiveData hydrates from it synchronously before its first fetch —
 * so the next person to sign in on a shared phone opened on someone else's
 * dashboard. Folding the owner into the key means a mismatch simply misses.
 *
 * Read from local storage rather than awaited, because the hydrate that needs it
 * happens before the first paint.
 */
function scopedKey(key: string): string | null {
  const uid = storedUserId()
  return uid ? `${PREFIX}${uid}:${key}` : null
}

export function loadCached<T>(key: string): T | null {
  try {
    const scoped = scopedKey(key)
    if (!scoped) return null
    const raw = localStorage.getItem(scoped)
    return raw ? (JSON.parse(raw) as T) : null
  } catch {
    return null
  }
}

export function saveCache<T>(key: string, data: T) {
  try {
    const scoped = scopedKey(key)
    if (!scoped) return
    localStorage.setItem(scoped, JSON.stringify(data))
  } catch {
    // Storage full or private mode: best-effort, next launch just fetches fresh.
  }
}

/** Called on sign-out so the next account on this device never sees a stale screen. */
export function clearAllCache() {
  try {
    for (let i = localStorage.length - 1; i >= 0; i--) {
      const k = localStorage.key(i)
      if (k?.startsWith(PREFIX)) localStorage.removeItem(k)
    }
  } catch {
    // ignore
  }
}
