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

    <!-- Full-screen photo viewer. Tapping the backdrop closes it, which is what
         a thumb reaches for first on a phone. -->
    <q-dialog :model-value="!!viewerUrl" maximized @update:model-value="viewerUrl = ''">
      <div class="viewer" @click="viewerUrl = ''">
        <img :src="viewerUrl" alt="Photo" class="viewer-img" />
        <button type="button" class="viewer-close" aria-label="Close photo" @click.stop="viewerUrl = ''">
          <IconifyIcon icon="lucide:x" width="20" />
        </button>
      </div>
    </q-dialog>

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

      <template v-for="group in grouped" :key="group.day">
        <div class="day"><span>{{ group.day }}</span></div>
        <div
          v-for="msg in group.items"
          :key="msg.id"
          class="msg"
          :class="{ 'msg--mine': msg.mine, 'msg--pending': msg.pending }"
        >
          <span class="msg-bubble" :class="{ 'msg-bubble--media': msg.attachmentUrl }">
            <button
              v-if="msg.attachmentUrl"
              type="button"
              class="msg-img-btn"
              aria-label="View photo"
              @click="viewerUrl = msg.attachmentUrl ?? ''"
            >
              <img :src="msg.attachmentUrl" alt="Photo" class="msg-img" />
            </button>
            <template v-if="msg.body">{{ msg.body }}</template>
          </span>
          <!-- Only on the last message of a same-sender, same-minute run — see
               `showMeta` in the grouped computed. A still-sending bubble always
               shows its own clock so the pending state stays visible. -->
          <span v-if="msg.showMeta || msg.pending" class="msg-meta">
            {{ msg.time }}
            <IconifyIcon
              v-if="msg.mine"
              :icon="msg.pending ? 'lucide:clock' : msg.read || msg.delivered ? 'lucide:check-check' : 'lucide:check'"
              width="13"
              :class="{ 'tick-read': msg.read }"
            />
          </span>
        </div>
      </template>
    </div>

    <p v-if="otherTyping" class="typing-note">{{ other.name }} is typing…</p>

    <form class="composer" @submit.prevent="send">
      <div class="composer-attach-wrap">
        <button
          type="button"
          class="composer-attach"
          :class="{ 'composer-attach--open': attachMenuOpen }"
          aria-label="Add a photo"
          :disabled="sending || loading"
          @click="attachMenuOpen = !attachMenuOpen"
        >
          <IconifyIcon icon="lucide:plus" width="20" />
        </button>
        <template v-if="attachMenuOpen">
          <div class="composer-attach-backdrop" @click="attachMenuOpen = false" />
          <div class="composer-attach-menu" role="menu" aria-label="Add a photo">
            <button type="button" role="menuitem" @click="onTakePhotoClick">
              <IconifyIcon icon="lucide:camera" width="16" />
              Take photo
            </button>
            <button type="button" role="menuitem" @click="onUploadClick">
              <IconifyIcon icon="lucide:image-plus" width="16" />
              Upload photo
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
      </div>
      <textarea
        v-model="outgoing"
        class="composer-input"
        rows="1"
        placeholder="Message…"
        :disabled="sending || loading"
        @keydown.enter.exact.prevent="send"
        @input="notifyTyping"
      />
      <button
        type="submit"
        class="composer-send"
        :disabled="!outgoing.trim() || sending || loading"
        aria-label="Send"
      >
        <IconifyIcon icon="lucide:send-horizontal" width="18" />
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
import { initialsOf, dayLabel, clockTime } from '@/utils/format'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'
import { useMessagesStore } from '@/stores/messages'
import { useNotify } from '@/utils/notify'
import { isDesktop } from '@/utils/useTabletMode'
import { uploadToCloudinary } from '@/utils/upload'
import { capturePhoto } from '@/utils/camera'
import ApplicationCard from '@/components/messages/ApplicationCard.vue'

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

interface Msg {
  id: string
  body: string
  senderId: string
  sentAt: string
  status: string
  pending?: boolean
  attachmentUrl?: string | undefined
}

const store = useMessagesStore()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const sending = ref(false)
const outgoing = ref('')
const pendingFile = ref<File | null>(null)
const attachMenuOpen = ref(false)
const fileInputRef = ref<HTMLInputElement | null>(null)
const scroller = ref<HTMLElement | null>(null)
const me = ref('')
const otherId = ref('')
const messages = ref<Msg[]>([])
const other = reactive({ name: 'Conversation', initials: '?', role: '', color: '' as string | null, avatarUrl: '' as string | null })

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


type Row = Msg & { mine: boolean; read: boolean; delivered: boolean; time: string; showMeta: boolean }

const grouped = computed(() => {
  const out: { day: string; items: Row[] }[] = []
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

async function toBottom() {
  await nextTick()
  const el = scroller.value
  if (el) el.scrollTop = el.scrollHeight
}

function onAttach(e: Event) {
  const input = e.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  pendingFile.value = file
  void send()
}

async function takePhoto() {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (!file) return
  pendingFile.value = file
  void send()
}

function onTakePhotoClick() {
  attachMenuOpen.value = false
  void takePhoto()
}

function onUploadClick() {
  attachMenuOpen.value = false
  fileInputRef.value?.click()
}

async function send() {
  const body = outgoing.value.trim()
  const file = pendingFile.value
  if ((!body && !file) || sending.value || !me.value) return

  sending.value = true
  outgoing.value = ''
  pendingFile.value = null

  // Optimistic: the bubble appears at once (a local object URL stands in for
  // the attachment until the real Cloudinary URL comes back) and is replaced
  // by the row the insert returns, so a slow network never looks dropped.
  const tempId = `pending-${Date.now()}`
  const localPreview = file ? URL.createObjectURL(file) : undefined
  messages.value.push({
    id: tempId,
    body,
    senderId: me.value,
    sentAt: new Date().toISOString(),
    status: 'sent',
    pending: true,
    attachmentUrl: localPreview,
  })
  void toBottom()

  try {
    let attachmentUrl: string | null = null
    if (file) {
      const [uploaded] = await uploadToCloudinary(file)
      if (!uploaded) throw new Error('Upload failed.')
      attachmentUrl = uploaded.url
    }

    const { data, error: sendError } = await supabase
      .from('messages')
      .insert({ conversation_id: props.conversationId, sender_id: me.value, body, attachment_url: attachmentUrl })
      .select('id, body, sender_id, sent_at, status, attachment_url')
      .single()
    if (sendError) throw sendError

    upsertMessage(
      {
        id: data.id,
        body: data.body,
        senderId: data.sender_id,
        sentAt: data.sent_at,
        status: data.status,
        attachmentUrl: data.attachment_url ?? undefined,
      },
      tempId,
    )
    if (localPreview) URL.revokeObjectURL(localPreview)

    // No notification row for a chat message. tg_message_after_insert already
    // bumps conversations.unread_a/unread_b, which is what the Messages tab
    // badge reads — a bell row on top of that is a second unread counter for
    // the same event, on a screen you have to leave the chat to reach.
  } catch (e) {
    messages.value = messages.value.filter((m) => m.id !== tempId)
    if (localPreview) URL.revokeObjectURL(localPreview)
    outgoing.value = body
    error.value = errorMessage(e, file ? 'Photo not sent.' : 'Message not sent.')
  } finally {
    sending.value = false
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
      .select('user_a_id,user_b_id,a:users!conversations_user_a_id_fkey(full_name,initials,role,avatar_color,avatar_url),b:users!conversations_user_b_id_fkey(full_name,initials,role,avatar_color,avatar_url)')
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
        avatar_color: string | null
        avatar_url: string | null
      } | null
      other.name = person?.full_name || 'Conversation'
      other.initials = person?.initials || initialsOf(other.name)
      other.role = person?.role === 'landlord' ? 'Landlord/Landlady' : 'Student'
      other.color = person?.avatar_color ?? null
      other.avatarUrl = person?.avatar_url ? resolveAsset(person.avatar_url, AVATAR) : null
    }

    const { data: rows, error: rowsError } = await supabase
      .from('messages')
      .select('id, body, sender_id, sent_at, status, attachment_url')
      .eq('conversation_id', props.conversationId)
      .order('sent_at', { ascending: true })
      .limit(200)
    if (rowsError) throw rowsError

    messages.value = (rows ?? []).map((m) => ({
      id: m.id,
      body: m.body,
      senderId: m.sender_id,
      sentAt: m.sent_at,
      status: m.status,
      attachmentUrl: m.attachment_url ?? undefined,
    }))

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
function upsertMessage(msg: Msg, tempId?: string) {
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
    .select('id, body, sender_id, sent_at, status')
    .single()
  if (sendError) throw sendError
  upsertMessage({
    id: data.id,
    body: data.body,
    senderId: data.sender_id,
    sentAt: data.sent_at,
    status: data.status,
  })
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
      (payload) => {
        if (payload.eventType === 'INSERT') {
          const row = payload.new as {
            id: string
            body: string
            sender_id: string
            sent_at: string
            status: string
            attachment_url: string | null
          }
          upsertMessage({
            id: row.id,
            body: row.body,
            senderId: row.sender_id,
            sentAt: row.sent_at,
            status: row.status,
            attachmentUrl: row.attachment_url ?? undefined,
          })
          void toBottom()
          // Their message arrived while the thread is open, so it is read.
          if (row.sender_id !== me.value) {
            void supabase.rpc('mark_conversation_read', {
              p_conversation: props.conversationId,
            })
            // Every step of the tenancy handshake posts a system message, so an
            // incoming one is the cue that the card above may have changed: the
            // form was issued, an application arrived, or it was decided. Without
            // this the other side reads "Sent you an application form" and then
            // has to reopen the thread before the form actually appears.
            refreshCardSoon()
          }
        } else if (payload.eventType === 'UPDATE') {
          const row = payload.new as { id: string; status: string }
          const found = messages.value.find((m) => m.id === row.id)
          if (found) found.status = row.status
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

.msg {
  display: flex;
  max-width: 82%;
  flex-direction: column;
  align-items: flex-start;
  align-self: flex-start;
  gap: 2px;
}
.msg--mine {
  align-items: flex-end;
  align-self: flex-end;
}
.msg--pending {
  opacity: 0.65;
}
.msg-bubble {
  padding: 8px 12px;
  border: 1px solid var(--m-border);
  border-radius: 16px 16px 16px 4px;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 13.5px;
  line-height: 1.4;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
/* A photo is its own bubble — no frame, no padding, no fill behind it. The
   `.msg--mine` selector has to be repeated here or its border-colour and
   primary background win on specificity and put a coloured edge back. */
.msg-bubble--media,
.msg--mine .msg-bubble--media {
  padding: 0;
  border: 0;
  background: none;
  overflow: hidden;
}
.msg-img-btn {
  display: block;
  padding: 0;
  border: 0;
  background: none;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
/* Keeps the bubble silhouette now that the wrapper no longer draws it. */
.msg-img {
  display: block;
  max-width: 100%;
  max-height: 260px;
  border-radius: 16px 16px 16px 4px;
  object-fit: cover;
}
.msg--mine .msg-img {
  border-radius: 16px 16px 4px 16px;
}
.viewer {
  display: grid;
  width: 100%;
  height: 100%;
  place-items: center;
  padding: 16px;
  background: rgba(0, 0, 0, 0.92);
}
.viewer-img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}
.viewer-close {
  position: absolute;
  top: calc(12px + env(safe-area-inset-top));
  right: 12px;
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.msg--mine .msg-bubble {
  border-color: transparent;
  border-radius: 16px 16px 4px 16px;
  background: var(--m-primary);
  color: #fff;
}
.msg-meta {
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 0 3px;
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 600;
}
.tick-read {
  color: var(--m-info);
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
