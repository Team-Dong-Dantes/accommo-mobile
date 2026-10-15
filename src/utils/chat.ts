import { normalizePhPhone } from '@/utils/format'
import { isPdf, resolveAsset, CARD } from '@/utils/cloudinaryUrl'

export interface ChatMsg {
  id: string
  body: string
  senderId: string
  sentAt: string
  status: string
  pending?: boolean
  attachmentUrl?: string | undefined
  /** The attachment is a PDF, not a photo. Decided from the stored ref, before signing hides it. */
  file?: boolean
  editedAt?: string | null
  deletedAt?: string | null
  replyToId?: string | null
  /** user id -> emoji, one each. */
  reactions?: Record<string, string>
  accommodationId?: string | null
}

/** Must match the list react_to_message() accepts. */
export const REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🙏'] as const

/** What a shared listing shows in the thread and in the picker. */
export interface ListingCard {
  id: string
  name: string
  place: string
  cover: string | null
}

export const LISTING_COLS = 'id,name,barangay,city,accommodation_images(url,sort_order)'

export function toListingCard(row: {
  id: string
  name: string | null
  barangay: string | null
  city: string | null
  accommodation_images: { url: string; sort_order: number | null }[] | null
}): ListingCard {
  const first = [...(row.accommodation_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))[0]
  return {
    id: row.id,
    name: row.name?.trim() || 'Unnamed accommodation',
    place: [row.barangay, row.city].filter(Boolean).join(', '),
    cover: first ? resolveAsset(first.url, CARD) : null,
  }
}

/** PDFs upload as Cloudinary `raw`; a pre-private plain URL still ends in .pdf. */
export function isFileRef(ref: string | null | undefined): boolean {
  return !!ref && (ref.startsWith('cld:raw:') || isPdf(ref))
}

/** One line standing in for a message — a reply quote, the menu's context. */
export function snippet(m: Pick<ChatMsg, 'body' | 'deletedAt' | 'accommodationId' | 'file' | 'attachmentUrl'>): string {
  if (m.deletedAt) return 'Message removed'
  if (m.body) return m.body
  if (m.accommodationId) return 'Listing'
  if (m.file) return 'File'
  if (m.attachmentUrl) return 'Photo'
  return ''
}

/** Reactions folded into chips: each emoji once, with a count and whether one is mine. */
export function reactionChips(reactions: Record<string, string> | undefined, me: string) {
  const chips: { emoji: string; count: number; mine: boolean }[] = []
  for (const [user, emoji] of Object.entries(reactions ?? {})) {
    const chip = chips.find((c) => c.emoji === emoji)
    if (chip) {
      chip.count++
      chip.mine ||= user === me
    } else {
      chips.push({ emoji, count: 1, mine: user === me })
    }
  }
  return chips
}

export interface Segment {
  text: string
  href?: string
  /** Opens outside the app (openExternal) rather than as a plain link. */
  external?: boolean
}

// A URL, or a PH mobile number (09xx / +639xx, spaces or dashes allowed) that
// is not part of a longer run of digits.
const LINK_RE = /(https?:\/\/[^\s<]+|www\.[^\s<]+)|(?<!\d)((?:\+63|0)9\d{2}[\s-]?\d{3}[\s-]?\d{4})(?!\d)/gi

/** Splits message text into plain runs and tappable links / phone numbers. */
export function linkify(text: string): Segment[] {
  const out: Segment[] = []
  let last = 0
  for (const m of text.matchAll(LINK_RE)) {
    let raw = m[0]
    // "see https://x.com." — the sentence's full stop is not part of the link.
    if (m[1]) raw = raw.replace(/[.,!?;:)\]'"]+$/, '')
    const at = m.index
    if (at > last) out.push({ text: text.slice(last, at) })
    out.push(
      m[1]
        ? { text: raw, href: /^https?:/i.test(raw) ? raw : `https://${raw}`, external: true }
        : { text: raw, href: `tel:${normalizePhPhone(raw)}` },
    )
    last = at + raw.length
  }
  if (last < text.length) out.push({ text: text.slice(last) })
  return out
}

/**
 * Long-press (touch hold, or right-click on desktop) for a list of items.
 * `v-on="press.on(item)"` on each element; check `press.swallow()` at the top
 * of its click handler so the release that ends a hold doesn't also tap it.
 */
export function longPress<T>(fire: (item: T, el: HTMLElement) => void, ms = 450) {
  let timer: ReturnType<typeof setTimeout> | null = null
  let fired = false
  let x = 0
  let y = 0
  const cancel = () => {
    if (timer) clearTimeout(timer)
    timer = null
  }
  const trigger = (item: T, el: HTMLElement) => {
    cancel()
    fired = true
    fire(item, el)
  }
  return {
    swallow() {
      const was = fired
      fired = false
      return was
    },
    on(item: T) {
      return {
        pointerdown: (e: PointerEvent) => {
          if (e.button !== 0) return
          fired = false
          x = e.clientX
          y = e.clientY
          const el = e.currentTarget as HTMLElement
          cancel()
          timer = setTimeout(() => trigger(item, el), ms)
        },
        // A finger never holds perfectly still; only a real drag (a scroll) cancels.
        pointermove: (e: PointerEvent) => {
          if (Math.abs(e.clientX - x) > 8 || Math.abs(e.clientY - y) > 8) cancel()
        },
        pointerup: cancel,
        pointerleave: cancel,
        pointercancel: cancel,
        // Android's own long-press and desktop right-click both land here.
        contextmenu: (e: Event) => {
          e.preventDefault()
          if (!fired) trigger(item, e.currentTarget as HTMLElement)
        },
      }
    },
  }
}
