<template>
  <div class="chat">
    <header class="bar">
      <button type="button" class="bar-back" aria-label="Back to messages" @click="emit('close')">
        <IconifyIcon icon="lucide:arrow-left" width="20" />
      </button>
      <!-- The header opens the other person's profile: the same screen a scan
           lands on, so "who am I talking to" has an answer in both roles. -->
      <button type="button" class="bar-person" @click="openProfile">
        <span class="bar-avatar" :class="other.color ? [`bg-${other.color}`, 'text-white'] : []">
          <img v-if="other.avatarUrl" :src="other.avatarUrl" alt="" class="bar-avatar-img" @error="other.avatarUrl = null" />
          <template v-else>{{ other.initials }}</template>
        </span>
        <span class="bar-id">
          <span class="bar-name">{{ other.name }}</span>
          <span class="bar-role">{{ other.role }}</span>
        </span>
        <IconifyIcon icon="lucide:info" width="17" class="bar-info" />
      </button>
    </header>

    <PhotoViewer v-model="viewerUrl" />

    <ApplicationCard
      ref="applicationCard"
      :conversation-id="props.conversationId"
      :role="props.role"
      :me="me"
      :other-id="otherId"
      :other-name="other.name"
      :room-id="props.roomId"
      @system="postSystemMessage"
    />

    <div ref="scroller" class="feed">
      <div v-if="loading" class="feed-note">Loading…</div>
      <div v-else-if="error" class="feed-note feed-note--bad">{{ error }}</div>
      <div v-else-if="!messages.length" class="feed-note">
        Say hello — this is the start of your conversation.
      </div>

      <button v-if="hasMore && !loading" type="button" class="feed-older" :disabled="loadingOlder" @click="loadOlder">
        {{ loadingOlder ? 'Loading…' : 'Load earlier messages' }}
      </button>

      <template v-for="group in grouped" :key="group.day">
        <div class="day"><span>{{ group.day }}</span></div>
        <MessageBubble
          v-for="msg in group.items"
          :key="msg.id"
          :msg="msg"
          :me="me"
          :reply="replyOf(msg)"
          :listing="msg.accommodationId ? listings.get(msg.accommodationId) : undefined"
          :lifted="menu?.msg.id === msg.id"
          @menu="openMenu(msg.id, $event)"
          @photo="viewerUrl = $event"
          @file="openExternal"
          @listing="openListing"
          @jump="jumpTo"
          @react="react(msg.id, $event)"
        />
      </template>
    </div>

    <MessageMenu
      v-if="menu"
      :anchor="menu.rect"
      :actions="menuActions"
      :align="menu.msg.senderId === me ? 'end' : 'start'"
      :mine="menu.msg.reactions?.[me]"
      react
      dim
      @close="menu = null"
      @pick="onPick"
      @react="onMenuReact"
    />

    <ListingPicker v-model="pickerOpen" :landlord-id="landlordId" @pick="shareListing" />

    <p v-if="otherTyping" class="typing-note">{{ other.name }} is typing…</p>

    <div v-if="replyTo || editing" class="compose-ctx">
      <IconifyIcon :icon="editing ? 'lucide:pencil' : 'lucide:reply'" width="16" class="compose-ctx-icon" />
      <span class="compose-ctx-body">
        <span class="compose-ctx-title">
          {{ editing ? 'Editing message' : `Replying to ${replyTo?.senderId === me ? 'yourself' : other.name}` }}
        </span>
        <span class="compose-ctx-text">{{ snippet((editing ?? replyTo)!) }}</span>
      </span>
      <button type="button" class="compose-ctx-x" aria-label="Cancel" @click="cancelCompose">
        <IconifyIcon icon="lucide:x" width="16" />
      </button>
    </div>

    <form class="composer" @submit.prevent="submit">
      <div class="composer-attach-wrap">
        <button
          type="button"
          class="composer-attach"
          :class="{ 'composer-attach--open': attachMenuOpen }"
          aria-label="Attach"
          :disabled="sending || loading || !!editing"
          @click="attachMenuOpen = !attachMenuOpen"
        >
          <IconifyIcon icon="lucide:plus" width="20" />
        </button>
        <template v-if="attachMenuOpen">
          <div class="composer-attach-backdrop" @click="attachMenuOpen = false" />
          <div class="composer-attach-menu" role="menu" aria-label="Attach">
            <button type="button" role="menuitem" @click="onTakePhotoClick">
              <IconifyIcon icon="lucide:camera" width="16" />
              Take photo
            </button>
            <button type="button" role="menuitem" @click="onUploadClick">
              <IconifyIcon icon="lucide:image-plus" width="16" />
              Upload photo
            </button>
            <button type="button" role="menuitem" @click="onFileClick">
              <IconifyIcon icon="lucide:file-text" width="16" />
              Send a PDF
            </button>
            <button type="button" role="menuitem" @click="onListingClick">
              <IconifyIcon icon="lucide:house" width="16" />
              Share a listing
            </button>
          </div>
        </template>
        <input
          ref="fileInputRef"
          type="file"
          accept="image/*"
          class="composer-attach-input-hidden"
          :disabled="sending || loading"
          @change="onAttach"
        />
        <input
          ref="pdfInputRef"
          type="file"
          accept="application/pdf"
          class="composer-attach-input-hidden"
          :disabled="sending || loading"
          @change="onAttach"
        />
      </div>
      <textarea
        ref="inputRef"
        v-model="outgoing"
        class="composer-input"
        rows="1"
        placeholder="Message…"
        :disabled="sending || loading"
        @keydown.enter.exact.prevent="submit"
        @keydown.esc="cancelCompose"
        @input="notifyTyping"
      />
      <button
        type="submit"
        class="composer-send"
        :disabled="!outgoing.trim() || sending || loading"
        :aria-label="editing ? 'Save edit' : 'Send'"
      >
        <IconifyIcon :icon="editing ? 'lucide:check' : 'lucide:send-horizontal'" width="18" />
      </button>
    </form>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, nextTick, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { initialsOf, dayLabel, clockTime, landlordTitle } from '@/utils/format'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'
import { useMessagesStore } from '@/stores/messages'
import { useNotify } from '@/utils/notify'
import { isDesktop } from '@/utils/useTabletMode'
import { uploadSecureDocument, signRows, signRef } from '@/utils/upload'
import { capturePhoto } from '@/utils/camera'
import { openExternal } from '@/utils/openExternal'
import { confirmAction } from '@/utils/confirmAction'
import { isFileRef, snippet, LISTING_COLS, toListingCard, type ChatMsg, type ListingCard } from '@/utils/chat'
import ApplicationCard from '@/components/messages/ApplicationCard.vue'
import MessageBubble, { type BubbleMsg } from '@/components/messages/MessageBubble.vue'
import MessageMenu, { type MenuAction } from '@/components/messages/MessageMenu.vue'
import ListingPicker from '@/components/messages/ListingPicker.vue'
import PhotoViewer from '@/components/shared/PhotoViewer.vue'

const props = defineProps<{ conversationId: string; role: 'manager' | 'student'; roomId?: string | undefined }>()

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
const emit = defineEmits<{ close: []; profile: [userId: string] }>()

/** Newest page first; older pages on request. */
const PAGE = 50
// One literal, so postgrest-js can type the rows.
const MSG_COLS = 'id, body, sender_id, sent_at, status, attachment_url, edited_at, deleted_at, reply_to_id, reactions, accommodation_id'

interface MsgRow {
  id: string
  body: string
  sender_id: string
  sent_at: string
  status: string
  attachment_url: string | null
  edited_at: string | null
  deleted_at: string | null
  reply_to_id: string | null
  reactions: unknown
  accommodation_id: string | null
}

/** `file` is passed in because signing replaces the ref that says so. */
function toMsg(r: MsgRow, attachmentUrl: string | null | undefined, file: boolean): ChatMsg {
  return {
    id: r.id,
    body: r.body,
    senderId: r.sender_id,
    sentAt: r.sent_at,
    status: r.status,
    attachmentUrl: attachmentUrl || undefined,
    file,
    editedAt: r.edited_at,
    deletedAt: r.deleted_at,
    replyToId: r.reply_to_id,
    reactions: (r.reactions ?? {}) as Record<string, string>,
    accommodationId: r.accommodation_id,
  }
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
let refreshCardTimer: ReturnType<typeof setTimeout> | null = null

function refreshCardSoon() {
  if (refreshCardTimer) clearTimeout(refreshCardTimer)
  refreshCardTimer = setTimeout(() => {
    refreshCardTimer = null
    void applicationCard.value?.refresh()
  }, 1500)
}

const otherTyping = ref(false)
/** Non-empty while the full-screen photo viewer is open; the URL is the state. */
const viewerUrl = ref('')

let channel: RealtimeChannel | null = null
let typingSendAt = 0
let typingClearTimer: ReturnType<typeof setTimeout> | null = null

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
  if (!target) return { who: '', text: 'Original message' }
  return { who: target.senderId === me.value ? 'You' : other.name, text: snippet(target) }
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

function onAttach(e: Event) {
  const input = e.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (file) void send({ file })
}

async function takePhoto() {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (file) void send({ file })
}

function onTakePhotoClick() {
  attachMenuOpen.value = false
  void takePhoto()
}

function onUploadClick() {
  attachMenuOpen.value = false
  fileInputRef.value?.click()
}

function onFileClick() {
  attachMenuOpen.value = false
  pdfInputRef.value?.click()
}

function onListingClick() {
  attachMenuOpen.value = false
  pickerOpen.value = true
}

function shareListing(id: string) {
  pickerOpen.value = false
  void send({ accommodationId: id })
}

function cancelCompose() {
  if (editing.value) outgoing.value = ''
  editing.value = null
  replyTo.value = null
}

function submit() {
  void (editing.value ? saveEdit() : send())
}

/**
 * Text, a photo, a PDF or a listing card — whatever is typed goes along with
 * the attachment, as it always has for photos.
 */
async function send(extra: { file?: File; accommodationId?: string } = {}) {
  const body = outgoing.value.trim()
  const { file, accommodationId } = extra
  if ((!body && !file && !accommodationId) || sending.value || !me.value) return

  sending.value = true
  outgoing.value = ''
  const reply = replyTo.value
  replyTo.value = null
  const isFile = file?.type === 'application/pdf'

  // Optimistic: the bubble appears at once (a local object URL stands in for
  // the attachment until the real Cloudinary URL comes back) and is replaced
  // by the row the insert returns, so a slow network never looks dropped.
  const tempId = `pending-${Date.now()}`
  const localPreview = file && !isFile ? URL.createObjectURL(file) : undefined
  messages.value.push({
    id: tempId,
    body,
    senderId: me.value,
    sentAt: new Date().toISOString(),
    status: 'sent',
    pending: true,
    attachmentUrl: localPreview,
    file: isFile,
    replyToId: reply?.id ?? null,
    accommodationId: accommodationId ?? null,
  })
  void toBottom()
  if (accommodationId) void fillListings()

  try {
    let attachmentUrl: string | null = null
    if (file) {
      // Chat photos are private: the row stores a cld: ref, readable only
      // through a signed link.
      attachmentUrl = await uploadSecureDocument(file)
    }

    const { data, error: sendError } = await supabase
      .from('messages')
      .insert({
        conversation_id: props.conversationId,
        sender_id: me.value,
        body,
        attachment_url: attachmentUrl,
        reply_to_id: reply?.id ?? null,
        accommodation_id: accommodationId ?? null,
      })
      .select(MSG_COLS)
      .single()
    if (sendError) throw sendError

    // Keep showing the local copy of a photo: the stored value is a ref, not a
    // URL. A PDF has no local copy worth opening, so it gets its signed link.
    const shown = isFile ? await signRef('messages', data.id, data.attachment_url) : localPreview
    upsertMessage(toMsg(data, data.attachment_url ? shown : undefined, isFile), tempId)

    // No notification row for a chat message. tg_message_after_insert already
    // bumps conversations.unread_a/unread_b, which is what the Messages tab
    // badge reads — a bell row on top of that is a second unread counter for
    // the same event, on a screen you have to leave the chat to reach.
  } catch (e) {
    messages.value = messages.value.filter((m) => m.id !== tempId)
    if (localPreview) URL.revokeObjectURL(localPreview)
    outgoing.value = body
    replyTo.value = reply
    error.value = errorMessage(e, file ? (isFile ? 'File not sent.' : 'Photo not sent.') : accommodationId ? 'Listing not shared.' : 'Message not sent.')
  } finally {
    sending.value = false
  }
}

async function saveEdit() {
  const target = editing.value
  const body = outgoing.value.trim()
  if (!target || !body || sending.value) return
  if (body === target.body) {
    cancelCompose()
    return
  }
  sending.value = true
  try {
    const { data, error: e } = await supabase
      .from('messages')
      .update({ body })
      .eq('id', target.id)
      .select('body, edited_at')
      .single()
    if (e) throw e
    target.body = data.body
    target.editedAt = data.edited_at
    editing.value = null
    outgoing.value = ''
  } catch (e) {
    notify.error(errorMessage(e, 'Could not edit that message.'))
  } finally {
    sending.value = false
  }
}

/* ---- Message actions ----------------------------------------------------- */

function openMenu(id: string, el: HTMLElement) {
  const msg = findMsg(id)
  if (!msg || msg.pending || msg.deletedAt) return
  menu.value = { msg, rect: el.getBoundingClientRect() }
}

const menuActions = computed<MenuAction[]>(() => {
  const m = menu.value?.msg
  if (!m) return []
  const mine = m.senderId === me.value
  const actions: MenuAction[] = [{ key: 'reply', label: 'Reply', icon: 'lucide:reply' }]
  if (m.body) actions.push({ key: 'copy', label: 'Copy', icon: 'lucide:copy' })
  if (mine && m.body) actions.push({ key: 'edit', label: 'Edit', icon: 'lucide:pencil' })
  if (mine) actions.push({ key: 'unsend', label: 'Unsend', icon: 'lucide:trash-2', danger: true })
  return actions
})

function onPick(key: string) {
  const m = menu.value?.msg
  menu.value = null
  if (!m) return
  if (key === 'reply') {
    editing.value = null
    replyTo.value = m
    inputRef.value?.focus()
  } else if (key === 'copy') {
    void copy(m.body)
  } else if (key === 'edit') {
    replyTo.value = null
    editing.value = m
    outgoing.value = m.body
    inputRef.value?.focus()
  } else if (key === 'unsend') {
    void unsend(m)
  }
}

function onMenuReact(emoji: string) {
  const m = menu.value?.msg
  menu.value = null
  if (m) void react(m.id, emoji)
}

async function copy(text: string) {
  try {
    await navigator.clipboard.writeText(text)
    notify.success('Copied')
  } catch {
    notify.error('Could not copy that message.')
  }
}

async function unsend(m: ChatMsg) {
  const ok = await confirmAction({
    title: 'Unsend this message?',
    message: 'It is removed for both of you. This cannot be undone.',
    confirmLabel: 'Unsend',
  })
  if (!ok) return
  // The trigger stamps the real time and clears the content; this just asks.
  const { error: e } = await supabase.from('messages').update({ deleted_at: new Date().toISOString() }).eq('id', m.id)
  if (e) {
    notify.error(errorMessage(e, 'Could not unsend that message.'))
    return
  }
  if (editing.value?.id === m.id) cancelCompose()
  Object.assign(m, { deletedAt: new Date().toISOString(), body: '', attachmentUrl: undefined, accommodationId: null, reactions: {} })
}

/** '' takes my reaction off. Optimistic; rolled back if the RPC refuses. */
async function react(id: string, emoji: string) {
  const m = findMsg(id)
  if (!m || m.pending || m.deletedAt) return
  const before = m.reactions ?? {}
  const next = { ...before }
  if (emoji) next[me.value] = emoji
  else delete next[me.value]
  m.reactions = next
  const { error: e } = await supabase.rpc('react_to_message', { p_message: id, p_emoji: emoji })
  if (e) {
    m.reactions = before
    notify.error(errorMessage(e, 'Could not react to that message.'))
  }
}

/* ---- Loading ------------------------------------------------------------- */

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
      // eslint-disable-next-line max-len
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

async function postSystemMessage(body: string) {
  const { data, error: sendError } = await supabase
    .from('messages')
    .insert({ conversation_id: props.conversationId, sender_id: me.value, body })
    .select(MSG_COLS)
    .single()
  if (sendError) throw sendError
  upsertMessage(toMsg(data, null, false))
  void toBottom()
}

async function listen() {
  if (typeof supabase.channel !== 'function') return

  // supabase-js hands back the EXISTING channel for a topic, and .on() throws
  // once that channel has subscribed. Re-opening the same thread lands exactly
  // there: MessagesPage is kept alive, so this component can remount before the
  // previous instance's removeChannel() has finished. Drop any leftover on this
  // topic and WAIT for it, rather than racing it.
  //
  // The topic cannot be made unique per mount — both participants have to share
  // it for the typing broadcast to reach the other side.
  const topic = `messages:${props.conversationId}`
  if (typeof supabase.getChannels === 'function') {
    await Promise.all(
      supabase
        .getChannels()
        .filter((c) => c.topic === topic || c.topic === `realtime:${topic}`)
        .map((c) => supabase.removeChannel(c)),
    )
  }

  channel = supabase
    .channel(topic)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'messages',
        filter: `conversation_id=eq.${props.conversationId}`,
      },
      async (payload) => {
        if (payload.eventType === 'INSERT') {
          const row = payload.new as MsgRow
          upsertMessage(
            toMsg(row, await signRef('messages', row.id, row.attachment_url), isFileRef(row.attachment_url)),
          )
          void fillReplies()
          void fillListings()
          void toBottom()
          // Their message arrived while the thread is open, so it is read.
          if (row.sender_id !== me.value) {
            void supabase.rpc('mark_conversation_read', {
              p_conversation: props.conversationId,
            }).then(() => undefined, () => undefined)
            // Every step of the tenancy handshake posts a system message, so an
            // incoming one is the cue that the card above may have changed: the
            // form was issued, an application arrived, or it was decided. Without
            // this the other side reads "Sent you an application form" and then
            // has to reopen the thread before the form actually appears.
            refreshCardSoon()
          }
        } else if (payload.eventType === 'UPDATE') {
          // Ticks, edits, unsends and reactions. The signed photo link is kept:
          // the stored value is a ref, and it only ever changes by being removed.
          const row = payload.new as MsgRow
          const found = findMsg(row.id)
          if (!found) return
          Object.assign(found, {
            status: row.status,
            body: row.body,
            editedAt: row.edited_at,
            deletedAt: row.deleted_at,
            reactions: (row.reactions ?? {}) as Record<string, string>,
          })
          if (row.deleted_at) Object.assign(found, { attachmentUrl: undefined, accommodationId: null })
          if (row.deleted_at && menu.value?.msg.id === row.id) menu.value = null
        }
      },
    )
    // Ephemeral typing signal — broadcast, not a DB write, so it never
    // touches `messages` and there's nothing to clean up if it's missed.
    .on('broadcast', { event: 'typing' }, (msg) => {
      const from = (msg.payload as { from?: string } | undefined)?.from
      if (from !== otherId.value) return
      otherTyping.value = true
      if (typingClearTimer) clearTimeout(typingClearTimer)
      typingClearTimer = setTimeout(() => { otherTyping.value = false }, 3000)
    })
    .subscribe()
}

// Fires at most once every ~1.5s while the user is actively typing, so a
// whole sentence doesn't turn into a broadcast per keystroke.
function notifyTyping() {
  if (!channel || !outgoing.value.trim()) return
  const now = Date.now()
  if (now - typingSendAt < 1500) return
  typingSendAt = now
  void channel.send({ type: 'broadcast', event: 'typing', payload: { from: me.value } })
}

onMounted(async () => {
  await load()
  await listen()
})

onUnmounted(() => {
  if (channel) {
    void supabase.removeChannel(channel)
    channel = null
  }
  if (typingClearTimer) clearTimeout(typingClearTimer)
  if (refreshCardTimer) clearTimeout(refreshCardTimer)
})
</script>

<style scoped>
.chat {
  position: fixed;
  inset: 0;
  z-index: 3000;
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}

.bar {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 10px;
  padding: calc(8px + env(safe-area-inset-top)) 12px 8px;
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
}
.bar-back {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  margin-left: -8px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.bar-person {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 10px;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
/* Pushed to the far edge of the bar rather than trailing the name — the slack
   in .bar-person collects before it. */
.bar-info {
  flex: 0 0 auto;
  margin-left: auto;
  color: var(--m-muted);
}
.bar-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}
.bar-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.bar-id {
  display: flex;
  min-width: 0;
  flex-direction: column;
}
.bar-name {
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.bar-role {
  color: var(--m-muted);
  font-size: 11.5px;
}


.feed {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 3px;
  padding: 12px var(--m-page-gutter);
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}
.feed-note {
  margin: auto;
  max-width: 240px;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
.feed-note--bad {
  color: var(--m-danger);
}

.typing-note {
  margin: 0;
  padding: 2px var(--m-page-gutter) 0;
  color: var(--m-muted);
  font-size: 12px;
  font-style: italic;
}

.day {
  display: flex;
  justify-content: center;
  margin: 10px 0 6px;
}
.day span {
  padding: 3px 11px;
  border-radius: 999px;
  background: var(--m-border);
  color: var(--m-text);
  font-size: 11px;
  font-weight: 700;
}

.feed-older {
  align-self: center;
  margin: 4px 0 8px;
  padding: 6px 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
}

/* What the composer is doing besides a new message: replying, or editing. */
.compose-ctx {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 10px;
  padding: 8px var(--m-page-gutter);
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.compose-ctx-icon {
  flex: 0 0 auto;
  color: var(--m-primary);
}
.compose-ctx-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
}
.compose-ctx-title {
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 700;
}
.compose-ctx-text {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.compose-ctx-x {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
}

.composer {
  display: flex;
  flex: 0 0 auto;
  align-items: flex-end;
  gap: 8px;
  padding: 8px var(--m-page-gutter) calc(8px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.composer-attach-wrap {
  position: relative;
  flex: 0 0 auto;
}
.composer-attach {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.composer-attach svg {
  transition: transform 200ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
.composer-attach--open svg {
  transform: rotate(45deg);
}
.composer-attach-input-hidden {
  display: none;
}
.composer-attach-backdrop {
  position: fixed;
  inset: 0;
  z-index: 5;
}
.composer-attach-menu {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 0;
  z-index: 6;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 6px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.12);
  animation: composer-attach-menu-in 160ms ease-out both;
}
.composer-attach-menu button {
  display: flex;
  min-height: 40px;
  align-items: center;
  gap: 8px;
  padding: 0 10px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  white-space: nowrap;
  text-align: left;
}
.composer-attach-menu button:hover {
  background: var(--m-primary-soft);
}
@keyframes composer-attach-menu-in {
  from {
    opacity: 0;
    transform: translateY(6px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
.composer-input {
  flex: 1 1 auto;
  max-height: 110px;
  min-height: 44px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: 22px;
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  line-height: 1.35;
  resize: none;
}
.composer-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.composer-send {
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.composer-send:disabled {
  opacity: 0.45;
}
</style>
