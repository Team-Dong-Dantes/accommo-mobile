// One data-freshness policy for the whole app.
//
// Every screen used to hand-roll three separate things: `onMounted(load)`, a
// Supabase realtime channel that refetched on change, and an `onUnmounted`
// that tore the channel down. That last part was quietly wrong on the screens
// that matter most: `onUnmounted` never fires when you navigate away from a
// kept-alive screen (see MainLayout's KEEP_ALIVE_PAGES), so every screen you
// visited held its channel open for the rest of the session. The screens with
// no channel at all had the opposite bug — `onMounted` runs once under
// keep-alive, so they fetched on first visit and stayed stale until restart.
//
// This composable owns the whole policy instead:
//   * first mount             -> load
//   * while the screen is on  -> realtime pushes drive the refetches
//   * navigating away         -> channels released
//   * coming back             -> refetch only if the data is older than `ttl`
//
// It deliberately does not cache rows. Each screen keeps its own refs, and a
// kept-alive screen keeps them across navigation, so there is nothing to
// re-serve; the only question worth answering in one place is *when* to fetch
// again. A screen that is on-screen and subscribed never refetches without a
// database change behind it.
import { onActivated, onDeactivated, onMounted, onUnmounted } from 'vue'
import type { RealtimeChannel, RealtimePostgresChangesPayload } from '@supabase/supabase-js'
import { supabase, authUser } from '@/utils/supabase'

export type LivePayload = RealtimePostgresChangesPayload<Record<string, unknown>>

export interface LiveWatch {
  table: string
  /** PostgREST filter, e.g. `student_id=eq.${uid}`. Omit to follow the table. */
  filter?: string
  event?: '*' | 'INSERT' | 'UPDATE' | 'DELETE'
  /** Apply the change by hand instead of refetching the whole screen. */
  onChange?: (payload: LivePayload) => void
}

export interface LiveDataOptions {
  /** Freshness identity. Per-id screens must fold the id into it. */
  key: string | (() => string)
  /** The screen's own loader. `silent` skips its loading skeleton. */
  load: (silent?: boolean) => unknown
  /**
   * Tables to follow while the screen is on, given the signed-in user id.
   * Evaluated after each load, so it can read refs that `load` filled in.
   */
  watch?: (uid: string) => LiveWatch[]
  /** How long a loaded screen stays trustworthy on return. Default 60s. */
  ttl?: number
}

const DEFAULT_TTL = 60_000

/** Last successful load per key, shared across mounts of the same screen. */
const loadedAt = new Map<string, number>()

/** Forget a screen's freshness so its next activation refetches. */
export function invalidateLiveData(keyPrefix: string) {
  for (const key of loadedAt.keys()) {
    if (key === keyPrefix || key.startsWith(`${keyPrefix}:`)) loadedAt.delete(key)
  }
}

export function useLiveData(options: LiveDataOptions) {
  const ttl = options.ttl ?? DEFAULT_TTL
  const channels: RealtimeChannel[] = []
  // A kept-alive screen fires onActivated on its first mount as well; that one
  // is the mount onMounted already handled.
  let firstActivate = true

  const keyOf = () => (typeof options.key === 'function' ? options.key() : options.key)

  async function run(silent: boolean) {
    await options.load(silent)
    loadedAt.set(keyOf(), Date.now())
  }

  function isStale() {
    const at = loadedAt.get(keyOf())
    return at === undefined || Date.now() - at > ttl
  }

  async function subscribe() {
    // `supabase.channel` is absent when realtime is disabled or stubbed.
    if (!options.watch || channels.length || typeof supabase.channel !== 'function') return
    const { data } = await authUser()
    const uid = data?.user?.id
    if (!uid) return
    const key = keyOf()
    options.watch(uid).forEach((w, index) => {
      channels.push(
        supabase
          .channel(`${key}:${w.table}:${index}`)
          .on(
            'postgres_changes',
            { event: w.event ?? '*', schema: 'public', table: w.table, filter: w.filter } as never,
            (payload: LivePayload) => {
              if (w.onChange) w.onChange(payload)
              else void run(true)
            },
          )
          .subscribe(),
      )
    })
  }

  function unsubscribe() {
    while (channels.length) {
      const channel = channels.pop()
      if (channel) void supabase.removeChannel(channel)
    }
  }

  onMounted(async () => {
    await run(false)
    await subscribe()
  })

  onActivated(() => {
    if (firstActivate) {
      firstActivate = false
      return
    }
    void subscribe()
    if (isStale()) void run(true)
  })

  onDeactivated(() => {
    firstActivate = false
    unsubscribe()
  })
  onUnmounted(unsubscribe)

  return { refresh: () => run(true) }
}
