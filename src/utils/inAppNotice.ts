import { ref } from 'vue'

// In-app notifications: the card that drops in under the header when
// something arrives while the app is open and in use. A push that lands in the
// foreground is never shown by Android (startPush sets no presentation
// options), so this is the only place a live event surfaces on screen.
//
// The stores feed it from the realtime channels they already hold; the card
// itself is components/shared/InAppNotice.vue, in the header.

export interface InAppNotice {
  /** Same key replaces: a burst of messages in one thread is one card. */
  key: string
  /** A notifications type ('message', 'payment', ...) — picks icon and tone. */
  type: string
  title: string
  body: string
  /** Opens this conversation when tapped. */
  threadId?: string
  /** Otherwise where the bell row would go (resolveNotifLink). */
  linkUrl?: string | null
  refId?: string | null
  /** The bell row it came from, marked read when the card is tapped. */
  notifId?: string
}

export const notices = ref<InAppNotice[]>([])

/** Nobody reads a queue deeper than this off a transient card. */
const MAX = 3

export function showNotice(n: InAppNotice) {
  // Realtime keeps running for a while after the app is backgrounded; a card
  // nobody can see would only be waiting there, stale, on return.
  if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return
  notices.value = [...notices.value.filter((x) => x.key !== n.key), n].slice(-MAX)
}

export function dropNotice(key: string) {
  notices.value = notices.value.filter((x) => x.key !== key)
}
