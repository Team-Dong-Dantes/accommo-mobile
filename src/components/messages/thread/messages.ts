// The conversation: who it is with, its messages a page at a time, the replies
// and listings they point at, and keeping the list current.
import { AVATAR, resolveAsset } from '@/utils/cloudinaryUrl'
import { type BubbleMsg } from '@/components/messages/MessageBubble.vue'
import { type ChatMsg, LISTING_COLS, type ListingCard, isFileRef, snippet, toListingCard } from '@/utils/chat'
import { MSG_COLS, PAGE, toMsg } from './model'
import { type Seed } from './model'
import { authUser, supabase } from '@/utils/supabase'
import { clockTime, dayLabel, initialsOf, landlordTitle } from '@/utils/format'
import { computed, nextTick, reactive, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { isDesktop } from '@/utils/useTabletMode'
import { signRows } from '@/utils/upload'
import { useMessagesStore } from '@/stores/messages'
import { useNotify } from '@/utils/notify'
import { useRouter } from 'vue-router'

export function createMessages(ctx: Seed) {
  const { props, emit } = ctx
  const router = useRouter()

  function openProfile() {
    if (!otherId.value) return
    // Desktop: MessagesPage shows the profile in this same panel instead of
    // leaving the page, so the conversation list stays beside it.
    if (isDesktop.value) {
      emit('profile', otherId.value)
      return
    }
    void router.push(`/${props.role}/person/${otherId.value}`)
  }

  const store = useMessagesStore()
  const notify = useNotify()

  const loading = ref(true)
  const loadingOlder = ref(false)
  const hasMore = ref(false)
  const error = ref('')
  const sending = ref(false)
  const outgoing = ref('')
  const attachMenuOpen = ref(false)
  const pickerOpen = ref(false)
  const fileInputRef = ref<HTMLInputElement | null>(null)
  const pdfInputRef = ref<HTMLInputElement | null>(null)
  const inputRef = ref<HTMLTextAreaElement | null>(null)
  const scroller = ref<HTMLElement | null>(null)
  const me = ref('')
  const otherId = ref('')
  const messages = ref<ChatMsg[]>([])
  const other = reactive({ name: 'Conversation', initials: '?', role: '', color: '' as string | null, avatarUrl: '' as string | null })

  /** Reply targets older than the loaded page, fetched on demand. */
  const replyCache = reactive(new Map<string, ChatMsg>())
  /** Shared listings by id; null once RLS no longer shows one. */
  const listings = reactive(new Map<string, ListingCard | null>())

  /** The listings in this chat are always the landlord/landlady's own. */
  const landlordId = computed(() => (props.role === 'manager' ? me.value : otherId.value))

  const replyTo = ref<ChatMsg | null>(null)
  const editing = ref<ChatMsg | null>(null)
  const menu = ref<{ msg: ChatMsg; rect: DOMRect } | null>(null)

  // The tenancy handshake lives in its own component; the thread only tells it
  // when something may have changed, and posts the transcript lines it asks for.
  //
  // Every step of that handshake posts a system message, so an incoming message is
  // the cue to re-check the card. But ordinary chat posts messages too, and each
  // refresh is 3-4 queries — a ten-message exchange fired ~40 of them, nearly all
  // returning identical rows. A trailing debounce collapses a burst into one call;
  // the card itself already collapses genuinely concurrent ones onto one promise.
  const applicationCard = ref<{ refresh: () => Promise<void> } | null>(null)

  const otherTyping = ref(false)
  /** Non-empty while the full-screen photo viewer is open; the URL is the state. */
  const viewerUrl = ref('')

  const grouped = computed(() => {
    const out: { day: string; items: BubbleMsg[] }[] = []
    for (const m of messages.value) {
      const day = dayLabel(m.sentAt)
      let bucket = out[out.length - 1]
      if (!bucket || bucket.day !== day) {
        bucket = { day, items: [] }
        out.push(bucket)
      }
      bucket.items.push({
        ...m,
        mine: m.senderId === me.value,
        read: m.status === 'read',
        delivered: m.status === 'delivered',
        time: clockTime(m.sentAt),
        // Filled in below, once the following message is known.
        showMeta: true,
      })
    }

    // Five messages fired off inside one minute used to stamp "11:14 pm" five
    // times. The stamp now belongs to the LAST message of a run — same sender,
    // same clock minute — so a burst reads as one block with a single time, and
    // the tick still lands where the eye looks for it.
    for (const bucket of out) {
      for (let i = 0; i < bucket.items.length - 1; i++) {
        const row = bucket.items[i]
        const next = bucket.items[i + 1]
        if (!row || !next) continue
        row.showMeta = next.senderId !== row.senderId || next.time !== row.time
      }
    }
    return out
  })

  function findMsg(id: string) {
    return messages.value.find((m) => m.id === id)
  }

  function replyOf(m: ChatMsg) {
    if (!m.replyToId) return null
    const target = findMsg(m.replyToId) ?? replyCache.get(m.replyToId)
    const replier = m.senderId === me.value ? 'You' : other.name
    if (!target) return { caption: `${replier} replied to a message`, text: 'Original message' }
    const toMine = target.senderId === me.value
    const to = m.senderId === target.senderId ? (toMine ? 'yourself' : 'their message') : toMine ? 'you' : other.name
    return { caption: `${replier} replied to ${to}`, text: snippet(target) }
  }

  async function toBottom() {
    await nextTick()
    const el = scroller.value
    if (el) el.scrollTop = el.scrollHeight
  }

  function jumpTo(id: string) {
    document.getElementById(`msg-${id}`)?.scrollIntoView({ block: 'center', behavior: 'smooth' })
  }

  function openListing(id: string) {
    void router.push(props.role === 'manager' ? `/manager/properties/${id}` : `/student/listing/${id}`)
  }

  /* ---- Composer ------------------------------------------------------------ */

  /** One page of messages ending just before `before` (or the newest), oldest first. */
  async function fetchPage(before?: string) {
    let query = supabase
      .from('messages')
      .select(MSG_COLS)
      .eq('conversation_id', props.conversationId)
      .order('sent_at', { ascending: false })
      .limit(PAGE)
    if (before) query = query.lt('sent_at', before)
    const { data, error: e } = await query
    if (e) throw e
    const rows = (data ?? []).reverse()
    const files = new Set(rows.filter((r) => isFileRef(r.attachment_url)).map((r) => r.id))
    await signRows('messages', rows, 'attachment_url')
    return { msgs: rows.map((r) => toMsg(r, r.attachment_url, files.has(r.id))), more: rows.length === PAGE }
  }

  /** Quotes and cards that point outside what's loaded. */
  async function fillReplies() {
    const missing = [...new Set(messages.value.map((m) => m.replyToId))].filter(
      (id): id is string => !!id && !findMsg(id) && !replyCache.has(id),
    )
    if (!missing.length) return
    const { data } = await supabase.from('messages').select(MSG_COLS).in('id', missing)
    // The unsigned ref is enough here: a quote only needs to know there was a photo.
    for (const r of data ?? []) replyCache.set(r.id, toMsg(r, r.attachment_url, isFileRef(r.attachment_url)))
  }

  async function fillListings() {
    const missing = [...new Set(messages.value.map((m) => m.accommodationId))].filter(
      (id): id is string => !!id && !listings.has(id),
    )
    if (!missing.length) return
    const { data } = await supabase.from('accommodations').select(LISTING_COLS).in('id', missing)
    for (const id of missing) listings.set(id, null)
    for (const row of data ?? []) listings.set(row.id, toListingCard(row))
  }

  async function loadOlder() {
    const first = messages.value[0]
    if (!first || loadingOlder.value) return
    loadingOlder.value = true
    try {
      const el = scroller.value
      const height = el?.scrollHeight ?? 0
      const { msgs, more } = await fetchPage(first.sentAt)
      messages.value = [...msgs, ...messages.value]
      hasMore.value = more
      void fillReplies()
      void fillListings()
      // Keep the message that was on screen where it was, rather than jumping.
      await nextTick()
      if (el) el.scrollTop += el.scrollHeight - height
    } catch (e) {
      notify.error(errorMessage(e, 'Could not load earlier messages.'))
    } finally {
      loadingOlder.value = false
    }
  }

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const { data: auth } = await authUser()
      const user = auth?.user
      if (!user) return
      me.value = user.id

      const { data: convo, error: convoError } = await supabase
        .from('conversations')
        // Must stay one literal for postgrest-js to type the result.
        .select('user_a_id,user_b_id,a:users!conversations_user_a_id_fkey(full_name,initials,role,sex,avatar_color,avatar_url),b:users!conversations_user_b_id_fkey(full_name,initials,role,sex,avatar_color,avatar_url)')
        .eq('id', props.conversationId)
        .maybeSingle()
      if (convoError) throw convoError

      if (convo) {
        const mine = convo.user_a_id === user.id
        otherId.value = mine ? convo.user_b_id : convo.user_a_id
        const person = (mine ? convo.b : convo.a) as unknown as {
          full_name: string | null
          initials: string | null
          role: string | null
          sex: string | null
          avatar_color: string | null
          avatar_url: string | null
        } | null
        other.name = person?.full_name || 'Conversation'
        other.initials = person?.initials || initialsOf(other.name)
        other.role = person?.role === 'landlord' ? landlordTitle(person.sex) : 'Student'
        other.color = person?.avatar_color ?? null
        other.avatarUrl = person?.avatar_url ? resolveAsset(person.avatar_url, AVATAR) : null
      }

      // This used to be the OLDEST 200, ascending — a long thread opened on
      // months-old messages and never showed the newest. Newest page now, older
      // ones on request.
      const { msgs, more } = await fetchPage()
      messages.value = msgs
      hasMore.value = more
      void fillReplies()
      void fillListings()

      // Zeroes my counter and flips the other side's messages to read, which
      // reaches their device as a realtime UPDATE and lights their ticks.
      await supabase.rpc('mark_conversation_read', { p_conversation: props.conversationId })
      store.clearUnread(props.conversationId)

      void toBottom()
      void applicationCard.value?.refresh()
    } catch (e) {
      error.value = errorMessage(e, 'Could not open this conversation.')
    } finally {
      loading.value = false
    }
  }

  /**
   * The one way a row enters the list. Three paths deliver the same message and
   * any of them can arrive first: the insert's own response, the realtime INSERT
   * (which regularly beats that response on a fast connection), and
   * postSystemMessage. The old code deduped on id alone, which cannot match an
   * optimistic row that has no real id yet — so a realtime row arriving mid-send
   * was appended as a second bubble and stayed.
   */
  function upsertMessage(msg: ChatMsg, tempId?: string) {
    if (tempId) {
      const temp = messages.value.findIndex((m) => m.id === tempId)
      if (temp !== -1) {
        const dupe = messages.value.findIndex((m) => m.id === msg.id)
        // Realtime already delivered it: drop the placeholder rather than keep both.
        if (dupe !== -1 && dupe !== temp) {
          messages.value.splice(temp, 1)
          messages.value[dupe > temp ? dupe - 1 : dupe] = msg
          return
        }
        messages.value[temp] = msg
        return
      }
    }
    const at = messages.value.findIndex((m) => m.id === msg.id)
    if (at !== -1) messages.value[at] = msg
    else messages.value.push(msg)
  }

  return {
    router,
    openProfile,
    store,
    notify,
    loading,
    loadingOlder,
    hasMore,
    error,
    sending,
    outgoing,
    attachMenuOpen,
    pickerOpen,
    fileInputRef,
    pdfInputRef,
    inputRef,
    scroller,
    me,
    otherId,
    messages,
    other,
    replyCache,
    listings,
    landlordId,
    replyTo,
    editing,
    menu,
    applicationCard,
    otherTyping,
    viewerUrl,
    grouped,
    findMsg,
    replyOf,
    toBottom,
    jumpTo,
    openListing,
    fetchPage,
    fillReplies,
    fillListings,
    loadOlder,
    load,
    upsertMessage,
  }
}
