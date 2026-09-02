<template>
  <q-page class="messages-page">
    <main v-if="!activeConversation" class="conversation-list" aria-labelledby="messages-title">
      <header class="list-header">
        <div>
          <h1 id="messages-title" class="sr-only">Messages</h1>
          <p class="list-summary">{{ unreadCount }} unread {{ unreadCount === 1 ? 'message' : 'messages' }}</p>
        </div>
      </header>

      <section v-if="loading" class="list-state" role="status" aria-live="polite">
        <q-spinner color="primary" size="28px" />
        <span>Loading conversations...</span>
      </section>
      <section v-else-if="error" class="list-state list-state--error" role="alert">
        <IconifyIcon icon="lucide:circle-alert" width="25" aria-hidden="true" />
        <strong>We couldn't load your messages.</strong>
        <span>{{ error }}</span>
        <button type="button" class="retry-button" @click="loadConversations">
          <IconifyIcon icon="lucide:refresh-cw" width="16" aria-hidden="true" />
          Try again
        </button>
      </section>
      <section v-else-if="filteredConversations.length" class="thread-list" aria-label="Conversations">
        <button
          v-for="chat in filteredConversations"
          :key="chat.id"
          type="button"
          class="thread-row"
          :class="{ 'thread-row--unread': chat.unread > 0 }"
          @click="openConversation(chat.id)"
        >
          <q-avatar class="thread-avatar" size="44px">{{ chat.initials }}</q-avatar>
          <span class="thread-copy">
            <span class="thread-topline">
              <span class="thread-name">{{ chat.name }}</span>
              <time v-if="chat.lastTime" class="thread-time" :datetime="chat.lastTime">{{ formatListTime(chat.lastTime) }}</time>
            </span>
            <span class="thread-subtitle">{{ chat.role }}</span>
            <span class="thread-preview">{{ chat.lastMessage || 'No messages yet' }}</span>
          </span>
          <span v-if="chat.unread > 0" class="unread-indicator">
            <span class="sr-only">{{ chat.unread }} unread messages</span>{{ chat.unread > 99 ? '99+' : chat.unread }}
          </span>
          <IconifyIcon v-else icon="lucide:chevron-right" class="row-chevron" width="18" aria-hidden="true" />
        </button>
      </section>
      <EmptyState v-else icon="lucide:message-circle" :title="searchText ? 'No conversations match your search.' : 'No conversations yet.'" :message="searchText ? '' : 'Messages from landlords and managers will appear here.'" />
    </main>

    <!-- 2. Active Chat Screen (Messenger Style with Teal Theme) -->
    <main v-else class="messenger-chat-view" :aria-label="`Chat with ${activeChat.name}`">
      <!-- Messenger Top Header -->
      <header class="messenger-header">
        <button type="button" class="back-btn" aria-label="Back to chats" @click="closeConversation">
          <IconifyIcon icon="lucide:chevron-left" width="28" aria-hidden="true" />
        </button>
        
        <div class="header-user-info">
          <q-avatar size="38px" class="header-avatar">
            {{ activeChat.initials }}
          </q-avatar>
          <div class="header-titles">
            <strong class="user-name">{{ activeChat.name }}</strong>
            <span class="user-subtitle">{{ activeChat.role }}</span>
          </div>
        </div>

        <div class="header-actions">
          <button type="button" class="action-circle-btn" aria-label="Info">
            <IconifyIcon icon="lucide:info" width="20" aria-hidden="true" />
          </button>
        </div>
      </header>

      <!-- Scrollable Message Bubble Area -->
      <q-scroll-area ref="scrollArea" class="messenger-scroll">
        <div v-if="messagesLoading" class="chat-loading">
          <q-spinner-dots color="teal-8" size="32px" />
        </div>
        
        <div v-else-if="messagesError" class="chat-error">
          <IconifyIcon icon="lucide:alert-triangle" width="28" aria-hidden="true" />
          <span>{{ messagesError }}</span>
          <button type="button" class="retry-pill" @click="openConversation(activeConversation!)">Retry</button>
        </div>

        <div v-else class="bubble-stack">
          <!-- Profile Banner at Top of Conversation -->
          <div class="chat-intro-banner">
            <q-avatar size="72px" class="intro-avatar">
              {{ activeChat.initials }}
            </q-avatar>
            <h2 class="intro-name">{{ activeChat.name }}</h2>
            <span class="intro-meta">{{ activeChat.role }} · Accommo Platform</span>
            <span class="intro-hint">You're connected on Accommo</span>
          </div>

          <template v-for="(msg, index) in messages" :key="msg.id">
            <!-- Date Separator -->
            <div
              v-if="index === 0 || isDifferentDay(messages[index - 1]?.sentAt, msg.sentAt)"
              class="messenger-date-pill"
            >
              {{ formatDay(msg.sentAt) }}
            </div>

            <!-- Message Row -->
            <div
              class="bubble-row"
              :class="{
                'bubble-row--mine': msg.isMine,
                'bubble-row--theirs': !msg.isMine,
                'bubble-row--seq': isSequence(index)
              }"
            >
              <!-- Their Avatar on cluster -->
              <q-avatar
                v-if="!msg.isMine"
                size="28px"
                class="sender-avatar"
                :class="{ 'sender-avatar--hidden': isFollowedByTheirs(index) }"
              >
                {{ activeChat.initials }}
              </q-avatar>

              <div class="bubble-content-wrap">
                <article
                  class="messenger-bubble"
                  :class="{
                    'messenger-bubble--mine': msg.isMine,
                    'messenger-bubble--theirs': !msg.isMine,
                    'radius-bottom-right': msg.isMine && isFollowedByMine(index),
                    'radius-top-right': msg.isMine && isPrecededByMine(index),
                    'radius-bottom-left': !msg.isMine && isFollowedByTheirs(index),
                    'radius-top-left': !msg.isMine && isPrecededByTheirs(index),
                  }"
                >
                  <p class="bubble-text">{{ msg.body }}</p>
                </article>

                <!-- Status / Seen indicator below message -->
                <div v-if="msg.isMine && index === messages.length - 1" class="delivery-status">
                  <span v-if="msg.status === 'read'" class="seen-label">
                    <IconifyIcon icon="lucide:check-check" width="13" class="seen-check" /> Seen
                  </span>
                  <span v-else class="sent-label">
                    <IconifyIcon icon="lucide:check" width="13" /> Sent
                  </span>
                </div>
              </div>
            </div>
          </template>
        </div>
      </q-scroll-area>

      <!-- Messenger Bottom Composer Bar -->
      <footer class="messenger-composer-bar">
        <form class="composer-form" @submit.prevent="submitMessage">
          <div class="input-pill">
            <textarea
              id="student-message-composer"
              v-model="newMessage"
              rows="1"
              placeholder="Message..."
              :disabled="sending"
              @keydown.enter.exact.prevent="submitMessage"
            />
            <button
              type="submit"
              class="send-icon-btn"
              :disabled="!newMessage.trim() || sending"
              aria-label="Send"
            >
              <q-spinner v-if="sending" size="16px" />
              <IconifyIcon v-else icon="lucide:send" width="18" aria-hidden="true" />
            </button>
          </div>
        </form>
      </footer>
    </main>

    <!-- Fixed bottom search + filter (discover-style) -->
    <div v-if="!activeConversation" class="messages-action-bar">
      <button type="button" class="messages-filter-button" :class="{ 'has-active': activeFilter !== 'all' }" aria-label="Filter conversations" @click="filterDialog = true">
        <IconifyIcon icon="mdi:tune" width="21" aria-hidden="true" />
      </button>
      <label class="messages-search-field" for="student-message-search">
        <IconifyIcon icon="lucide:search" width="20" aria-hidden="true" />
        <span class="sr-only">Search conversations</span>
        <input id="student-message-search" v-model="searchText" type="search" placeholder="Search messages" autocomplete="off" />
        <button v-if="searchText" type="button" class="messages-clear-search" aria-label="Clear conversation search" @click="searchText = ''">
          <IconifyIcon icon="lucide:x" width="18" aria-hidden="true" />
        </button>
      </label>
    </div>

    <!-- Filter bottom sheet -->
    <q-dialog v-model="filterDialog" position="bottom">
      <q-card class="messages-filter-sheet">
        <q-card-section class="messages-filter-heading">
          <div>
            <h2>Filter conversations</h2>
            <p>Show only the messages you want.</p>
          </div>
          <q-btn flat round aria-label="Close filters" @click="filterDialog = false"><IconifyIcon icon="lucide:x" width="20" /></q-btn>
        </q-card-section>
        <q-card-section>
          <h3>Who</h3>
          <div class="messages-filter-options">
            <button v-for="opt in filterOptions" :key="opt.value" type="button" class="f-chip"
              :class="{ active: activeFilter === opt.value }" @click="activeFilter = opt.value">
              {{ opt.label }}
            </button>
          </div>
        </q-card-section>
        <q-card-actions class="messages-filter-actions">
          <q-btn flat no-caps @click="activeFilter = 'all'; filterDialog = false">Clear</q-btn>
          <q-btn unelevated no-caps class="primary-button" @click="filterDialog = false">Show messages</q-btn>
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- New Conversation Sheet -->
    <q-dialog v-model="newConvoDialog" position="bottom">
      <q-card class="new-conversation-dialog">
        <q-card-section class="dialog-heading">
          <div><p class="eyebrow">New message</p><h2>Choose a landlord</h2></div>
          <button type="button" class="icon-button" aria-label="Close new conversation dialog" @click="newConvoDialog = false">
            <IconifyIcon icon="lucide:x" width="20" aria-hidden="true" />
          </button>
        </q-card-section>
        <q-card-section v-if="newConvoLoading" class="list-state" role="status"><q-spinner color="primary" size="24px" /><span>Loading landlords...</span></q-card-section>
        <q-card-section v-else-if="landlords.length === 0" class="list-state"><span>No landlords are available to message.</span></q-card-section>
        <q-card-section v-else class="dialog-list">
          <button v-for="landlord in landlords" :key="landlord.id" type="button" class="thread-row" @click="startChatWith(landlord.id, landlord.name)">
            <q-avatar class="thread-avatar" size="40px">{{ initialsOf(landlord.name) }}</q-avatar>
            <span class="thread-copy"><span class="thread-name">{{ landlord.name }}</span><span class="thread-subtitle">Landlord</span></span>
            <IconifyIcon icon="lucide:chevron-right" class="row-chevron" width="18" aria-hidden="true" />
          </button>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'
import { chatFullscreen } from '@/shared/utils/chatFullscreen'
import EmptyState from '@/shared/components/EmptyState.vue'

interface ConversationRow { id: string; user_a_id: string; user_b_id: string; last_message: string | null; last_time: string | null; unread_a: number | null; unread_b: number | null }
interface UserRow { id: string; full_name: string | null; role: string | null }
interface ConversationItem { id: string; name: string; initials: string; role: string; lastMessage: string; lastTime: string | null; unread: number; otherUserId: string }
interface MessageRow { id: string; conversation_id: string; sender_id: string; body: string; sent_at: string; status: 'sent' | 'delivered' | 'read' }
interface MessageItem { id: string; body: string; sentAt: string; isMine: boolean; status: 'sent' | 'delivered' | 'read' }

const $q = useQuasar()
const route = useRoute()
const loading = ref(true)
const error = ref<string | null>(null)
const searchText = ref('')
const filterDialog = ref(false)
const activeFilter = ref<'all' | 'students' | 'landlords'>('all')
const filterOptions = [
  { value: 'all', label: 'All' },
  { value: 'students', label: 'Students' },
  { value: 'landlords', label: 'Landlords' },
] as const

const conversations = ref<ConversationItem[]>([])
const currentUserId = ref<string | null>(null)
const activeConversation = ref<string | null>(null)
const activeChat = ref<ConversationItem>({ id: '', name: '', initials: '', role: '', lastMessage: '', lastTime: null, unread: 0, otherUserId: '' })
const messages = ref<MessageItem[]>([])
const messagesLoading = ref(false)
const messagesError = ref<string | null>(null)
const newMessage = ref('')
const sending = ref(false)
const newConvoDialog = ref(false)
const newConvoLoading = ref(false)
const landlords = ref<{ id: string; name: string }[]>([])
const messageChannel = ref<{ unsubscribe: () => void } | null>(null)
const conversationChannel = ref<{ unsubscribe: () => void } | null>(null)
const scrollArea = ref<any>(null)
let pollTimer: any = null
let listPollTimer: any = null

function stopListPolling() {
  if (listPollTimer) {
    clearInterval(listPollTimer)
    listPollTimer = null
  }
}

function startListPolling() {
  stopListPolling()
  listPollTimer = setInterval(async () => {
    if (activeConversation.value) return // Don't poll list when inside an active conversation
    await fetchConversationsQuietly()
  }, 2000)
}

async function fetchConversationsQuietly() {
  if (!currentUserId.value) return
  try {
    const { data: convData } = await supabase
      .from('conversations')
      .select('id, user_a_id, user_b_id, last_message, last_time, unread_a, unread_b')
      .or(`user_a_id.eq.${currentUserId.value},user_b_id.eq.${currentUserId.value}`)
      .order('last_time', { ascending: false, nullsFirst: false })

    if (!convData) return
    const rows = convData as ConversationRow[]
    const otherIds = [...new Set(rows.map((r) => r.user_a_id === currentUserId.value ? r.user_b_id : r.user_a_id))]
    const { data: users } = otherIds.length
      ? await supabase.from('users').select('id, full_name, role').in('id', otherIds)
      : { data: [] }
    const userMap = new Map((users ?? []).map((u) => [u.id, u as UserRow]))

    const updated = rows.map((r) => {
      const otherUserId = r.user_a_id === currentUserId.value ? r.user_b_id : r.user_a_id
      const p = userMap.get(otherUserId)
      const name = p?.full_name ?? roleLabel(p?.role)
      return {
        id: r.id,
        name,
        initials: initialsOf(name),
        role: roleLabel(p?.role),
        lastMessage: r.last_message ?? '',
        lastTime: r.last_time,
        unread: r.user_a_id === currentUserId.value ? r.unread_a ?? 0 : r.unread_b ?? 0,
        otherUserId,
      }
    })

    // Check if list changed
    const hasDiff = updated.length !== conversations.value.length ||
      updated.some((item, idx) => {
        const curr = conversations.value[idx]
        return !curr || curr.id !== item.id || curr.lastMessage !== item.lastMessage || curr.unread !== item.unread
      })

    if (hasDiff) {
      conversations.value = updated
    }
  } catch {
    // quiet
  }
}

const filteredConversations = computed(() => {
  let list = conversations.value
  if (activeFilter.value === 'students') list = list.filter((chat) => chat.role === 'Student')
  else if (activeFilter.value === 'landlords') list = list.filter((chat) => chat.role === 'Landlord')
  const term = searchText.value.trim().toLowerCase()
  if (!term) return list
  return list.filter((chat) => [chat.name, chat.role, chat.lastMessage].some((val) => val.toLowerCase().includes(term)))
})
const unreadCount = computed(() => conversations.value.reduce((total, chat) => total + chat.unread, 0))

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  return parts.length > 1 ? `${parts[0]?.[0] ?? ''}${parts[parts.length - 1]?.[0] ?? ''}`.toUpperCase() : (parts[0] ?? 'U').slice(0, 2).toUpperCase()
}
function roleLabel(role: string | null | undefined): string {
  return role === 'accommodation_manager' || role === 'landlord' ? 'Landlord' : role === 'student' ? 'Student' : 'Participant'
}
function formatListTime(timestamp: string): string {
  const date = new Date(timestamp)
  return date.toDateString() === new Date().toDateString()
    ? formatTime(timestamp)
    : date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })
}
function isDifferentDay(prev: string | undefined, curr: string): boolean {
  return !prev || new Date(prev).toDateString() !== new Date(curr).toDateString()
}
function formatDay(timestamp: string): string {
  const date = new Date(timestamp)
  const today = new Date().toDateString()
  const yesterday = new Date(Date.now() - 86400000).toDateString()
  if (date.toDateString() === today) return 'Today'
  if (date.toDateString() === yesterday) return 'Yesterday'
  return date.toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' })
}
function formatTime(timestamp: string): string {
  return new Date(timestamp).toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' })
}

// Bubble clustering helpers
function isSequence(index: number): boolean {
  if (index === 0) return false
  return messages.value[index]?.isMine === messages.value[index - 1]?.isMine
}
function isFollowedByMine(index: number): boolean {
  return messages.value[index + 1]?.isMine === true
}
function isPrecededByMine(index: number): boolean {
  return messages.value[index - 1]?.isMine === true
}
function isFollowedByTheirs(index: number): boolean {
  return messages.value[index + 1]?.isMine === false
}
function isPrecededByTheirs(index: number): boolean {
  return messages.value[index - 1]?.isMine === false
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

function startPolling(conversationId: string) {
  stopPolling()
  pollTimer = setInterval(async () => {
    if (activeConversation.value !== conversationId) return
    try {
      const { data } = await supabase
        .from('messages')
        .select('id, conversation_id, sender_id, body, sent_at, status')
        .eq('conversation_id', conversationId)
        .order('sent_at', { ascending: true })

      if (data && data.length) {
        const incoming = (data as any[]).map((m: any) => ({
          id: m.id,
          body: m.body,
          sentAt: m.sent_at,
          isMine: m.sender_id === currentUserId.value,
          status: m.status || 'sent',
        }))

        if (incoming.length !== messages.value.length || incoming[incoming.length - 1]?.id !== messages.value[messages.value.length - 1]?.id) {
          messages.value = incoming
          void scrollToBottom()
          void markConversationRead(conversationId)
        }
      }
    } catch {
      // quiet poll fallback
    }
  }, 1500)
}

async function loadConversations() {
  loading.value = true
  error.value = null
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { conversations.value = []; return }
    currentUserId.value = user.id
    const { data, error: queryError } = await supabase
      .from('conversations')
      .select('id, user_a_id, user_b_id, last_message, last_time, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
      .order('last_time', { ascending: false, nullsFirst: false })
    if (queryError) throw queryError
    subscribeToConversations(user.id)
    const rows = (data ?? []) as ConversationRow[]
    const otherIds = [...new Set(rows.map((r) => r.user_a_id === user.id ? r.user_b_id : r.user_a_id))]
    const { data: users, error: usersError } = otherIds.length
      ? await supabase.from('users').select('id, full_name, role').in('id', otherIds)
      : { data: [], error: null }
    if (usersError) throw usersError
    const userMap = new Map((users ?? []).map((u) => [u.id, u as UserRow]))
    conversations.value = rows.map((r) => {
      const otherUserId = r.user_a_id === user.id ? r.user_b_id : r.user_a_id
      const p = userMap.get(otherUserId)
      const name = p?.full_name ?? roleLabel(p?.role)
      return {
        id: r.id,
        name,
        initials: initialsOf(name),
        role: roleLabel(p?.role),
        lastMessage: r.last_message ?? '',
        lastTime: r.last_time,
        unread: r.user_a_id === user.id ? r.unread_a ?? 0 : r.unread_b ?? 0,
        otherUserId,
      }
    })
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : 'Failed to load messages'
    conversations.value = []
  } finally {
    loading.value = false
  }
}

async function openConversation(id: string) {
  const chat = conversations.value.find((c) => c.id === id)
  if (!chat) return
  activeChat.value = chat
  activeConversation.value = id
  messagesLoading.value = true
  messagesError.value = null
  messages.value = []
  chatFullscreen.value = true
  try {
    const { data, error: queryError } = await supabase
      .from('messages')
      .select('id, conversation_id, sender_id, body, sent_at, status')
      .eq('conversation_id', id)
      .order('sent_at', { ascending: true })
    if (queryError) throw queryError
    messages.value = ((data ?? []) as MessageRow[]).map((m) => ({
      id: m.id,
      body: m.body,
      sentAt: m.sent_at,
      isMine: m.sender_id === currentUserId.value,
      status: m.status || 'sent',
    }))
    await markConversationRead(id)
    subscribeToConversation(id)
    void scrollToBottom(0)
    setTimeout(() => { void scrollToBottom(0) }, 60)
    setTimeout(() => { void scrollToBottom(0) }, 200)
  } catch (caught) {
    messagesError.value = caught instanceof Error ? caught.message : 'Failed to load messages'
  } finally {
    messagesLoading.value = false
  }
}

async function markConversationRead(id: string) {
  if (!currentUserId.value) return
  const chat = conversations.value.find((item) => item.id === id)
  if (!chat) return
  try {
    const { data, error: queryError } = await supabase.from('conversations').select('user_a_id').eq('id', id).maybeSingle()
    if (queryError || !data) return
    if ((data as { user_a_id: string }).user_a_id === currentUserId.value) {
      await supabase.from('conversations').update({ unread_a: 0 }).eq('id', id)
    } else {
      await supabase.from('conversations').update({ unread_b: 0 }).eq('id', id)
    }
    chat.unread = 0
  } catch (e) {
    console.warn('Failed to mark conversation read:', e)
  }
}

function unsubscribeMessages() {
  stopPolling()
  if (messageChannel.value) {
    messageChannel.value.unsubscribe()
    messageChannel.value = null
  }
}
function unsubscribeConversations() {
  stopListPolling()
  if (conversationChannel.value) {
    conversationChannel.value.unsubscribe()
    conversationChannel.value = null
  }
}
function closeConversation() {
  unsubscribeMessages()
  activeConversation.value = null
  messages.value = []
  messagesError.value = null
  chatFullscreen.value = false
  startListPolling()
}

function subscribeToConversations(userId: string) {
  unsubscribeConversations()
  startListPolling()
  conversationChannel.value = supabase
    .channel(`student-conversations-${userId}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'conversations' }, () => {
      void fetchConversationsQuietly()
    })
    .subscribe()
}

function subscribeToConversation(id: string) {
  startPolling(id)
  unsubscribeMessages()
  messageChannel.value = supabase
    .channel(`conversation-${id}`, {
      config: { broadcast: { self: false, ack: false } },
    })
    .on('broadcast', { event: 'new_message' }, (payload) => {
      const msg = payload?.payload || payload
      if (!msg || msg.conversationId !== id) return
      if (messages.value.some((m) => m.id === msg.id)) return
      messages.value.push({
        id: msg.id,
        body: msg.text,
        sentAt: msg.timestamp,
        isMine: msg.senderId === currentUserId.value,
        status: 'read',
      })
      if (msg.senderId !== currentUserId.value) {
        void markConversationRead(id)
      }
      void scrollToBottom()
    })
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, (payload) => {
      const row = payload.new as MessageRow
      if (row.conversation_id !== id) return
      if (messages.value.some((m) => m.id === row.id)) return
      messages.value.push({
        id: row.id,
        body: row.body,
        sentAt: row.sent_at,
        isMine: row.sender_id === currentUserId.value,
        status: row.status || 'sent',
      })
      if (row.sender_id !== currentUserId.value) {
        void markConversationRead(id)
      }
      void scrollToBottom()
    })
    .subscribe()
}

async function scrollToBottom(duration = 120) {
  await nextTick()
  const area = scrollArea.value
  if (!area) return
  if (typeof area.setScrollPercentage === 'function') {
    area.setScrollPercentage('vertical', 1, duration)
  } else if (typeof area.setScrollPosition === 'function') {
    area.setScrollPosition('vertical', 999999, duration)
  }
}

async function submitMessage() {
  void sendMessage()
}

async function sendMessage(textOverride?: string) {
  const body = (typeof textOverride === 'string' ? textOverride : newMessage.value).trim()
  const conversationId = activeConversation.value
  const userId = currentUserId.value
  if (!body || !conversationId || !userId || sending.value) return
  sending.value = true
  try {
    const messageId = crypto.randomUUID()
    const nowIso = new Date().toISOString()
    const { error: insertError } = await supabase.from('messages').insert({
      id: messageId,
      conversation_id: conversationId,
      sender_id: userId,
      body,
      sent_at: nowIso,
      status: 'sent',
    } as any)
    if (insertError) throw insertError

    if (messageChannel.value) {
      void (messageChannel.value as any).send({
        type: 'broadcast',
        event: 'new_message',
        payload: { id: messageId, conversationId, senderId: userId, text: body, timestamp: nowIso },
      })
    }

    const { data: conversation } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id, unread_a, unread_b')
      .eq('id', conversationId)
      .maybeSingle()
    if (conversation) {
      const row = conversation as any
      if (row.user_b_id === userId) {
        await supabase.from('conversations').update({ last_message: body, last_time: nowIso, unread_a: (row.unread_a ?? 0) + 1 }).eq('id', conversationId)
      } else {
        await supabase.from('conversations').update({ last_message: body, last_time: nowIso, unread_b: (row.unread_b ?? 0) + 1 }).eq('id', conversationId)
      }
    }

    const chat = conversations.value.find((c) => c.id === conversationId)
    if (chat) {
      chat.lastMessage = body
      chat.lastTime = nowIso
      chat.unread = 0
      conversations.value = [chat, ...conversations.value.filter((c) => c.id !== conversationId)]
    }
    newMessage.value = ''
    messages.value.push({
      id: messageId,
      body,
      sentAt: nowIso,
      isMine: true,
      status: 'sent',
    })
    void scrollToBottom()
  } catch (caught) {
    $q.notify({ message: caught instanceof Error ? caught.message : 'Failed to send message', color: 'negative', position: 'top' })
  } finally {
    sending.value = false
  }
}

function sendQuickLike() {
  void sendMessage('👍')
}

async function startNewConversation() {
  newConvoDialog.value = true
  newConvoLoading.value = true
  try {
    const { data, error: queryError } = await supabase.from('users').select('id, full_name').eq('role', 'accommodation_manager' as any)
    if (queryError) throw queryError
    landlords.value = ((data ?? []) as any[]).map((u) => ({ id: u.id, name: u.full_name ?? 'Manager' }))
  } catch {
    landlords.value = []
  } finally {
    newConvoLoading.value = false
  }
}

async function ensureConversation(otherUserId: string): Promise<string | null> {
  if (!currentUserId.value) return null
  const me = currentUserId.value
  const { data: existing } = await supabase
    .from('conversations')
    .select('id')
    .or(`and(user_a_id.eq.${me},user_b_id.eq.${otherUserId}),and(user_a_id.eq.${otherUserId},user_b_id.eq.${me})`)
    .limit(1)
  if (existing && existing[0]) return (existing[0] as any).id
  const { data: created, error: createError } = await supabase
    .from('conversations')
    .insert({ user_a_id: me, user_b_id: otherUserId, last_message: null, last_time: new Date().toISOString(), unread_a: 0, unread_b: 0 } as any)
    .select('id')
    .single()
  if (createError) throw createError
  return (created as any)?.id ?? null
}

async function startChatWith(otherUserId: string, name: string) {
  newConvoDialog.value = false
  try {
    const cid = await ensureConversation(otherUserId)
    if (!cid) return
    await loadConversations()
    await openConversation(cid)
  } catch (caught) {
    $q.notify({ message: caught instanceof Error ? caught.message : 'Failed to start chat', color: 'negative', position: 'top' })
  }
}

async function openLandlordFromQuery() {
  const landlordId = route.query.landlord as string | undefined
  if (!landlordId || !currentUserId.value) return
  // If a conversation with this manager already exists on this page, open it.
  const existing = conversations.value.find((c) => c.otherUserId === landlordId)
  if (existing) {
    await openConversation(existing.id)
    return
  }
  // Otherwise ensure one exists (creates if needed), then open it.
  try {
    const cid = await ensureConversation(landlordId)
    if (cid) {
      await loadConversations()
      await openConversation(cid)
    }
  } catch (caught) {
    $q.notify({ message: caught instanceof Error ? caught.message : 'Could not open that conversation', color: 'negative', position: 'top' })
  }
}

onMounted(async () => {
  await loadConversations()
  await openLandlordFromQuery()
})
onUnmounted(() => {
  unsubscribeMessages()
  unsubscribeConversations()
  chatFullscreen.value = false
})
</script>

<style scoped>
.messages-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.conversation-list { min-height: 100vh; max-width: 720px; margin: 0 auto; padding: var(--m-space-5) var(--m-page-gutter) calc(168px + env(safe-area-inset-bottom)); }
.list-header { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); margin-bottom: var(--m-space-4); }
h1, h2 { margin: 0; color: var(--m-ink); letter-spacing: -.03em; } h1 { font-size: 28px; line-height: 1.1; } h2 { font-size: 20px; }
.list-summary { margin: var(--m-space-1) 0 0; color: var(--m-muted); font-size: 13px; }
.icon-button { display: grid; width: 44px; height: 44px; flex: 0 0 44px; padding: 0; place-items: center; border: 0; border-radius: 50%; background: transparent; color: var(--m-ink); cursor: pointer; }

/* Fixed bottom search (discover-style matching discover-action-bar) */
.messages-action-bar { position: fixed; z-index: 59; right: 72px; bottom: 68px; left: var(--m-page-gutter); display: flex; gap: var(--m-space-2); align-items: center; }
.messages-search-field { display: flex; min-width: 0; flex: 1; align-items: center; gap: var(--m-space-2); min-height: 44px; padding: 0 var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-muted); box-shadow: 0 4px 12px rgba(15, 23, 42, .08); }
.messages-search-field input { min-width: 0; flex: 1; border: 0; outline: 0; background: transparent; color: var(--m-ink); font: inherit; }
.messages-search-field input::placeholder { color: var(--m-muted); }
.messages-clear-search { display: grid; width: 28px; height: 28px; padding: 0; place-items: center; border: 0; border-radius: 50%; background: transparent; color: var(--m-muted); cursor: pointer; }
.messages-filter-button { display: grid; width: 44px; height: 44px; flex: 0 0 44px; padding: 0; place-items: center; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-primary-dark); box-shadow: 0 4px 12px rgba(15, 23, 42, .08); cursor: pointer; }
.messages-filter-button.has-active { border-color: var(--m-primary); background: color-mix(in srgb, var(--m-primary-soft) 60%, var(--m-surface)); }
.messages-filter-sheet { border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; padding-bottom: env(safe-area-inset-bottom); }
.messages-filter-heading { display: flex; justify-content: space-between; align-items: flex-start; }
.messages-filter-heading h2 { margin: 0; font-size: 17px; }
.messages-filter-heading p { margin: 4px 0 0; color: var(--m-muted); font-size: 13px; }
.messages-filter-sheet h3 { margin: 4px 0 10px; color: var(--m-muted); font-size: 12px; letter-spacing: .04em; text-transform: uppercase; }
.messages-filter-options { display: flex; flex-wrap: wrap; gap: var(--m-space-2); }
.f-chip { min-height: 38px; padding: 0 16px; border: 1px solid var(--m-border); border-radius: 999px; background: var(--m-surface); color: var(--m-text); font: inherit; font-weight: 600; font-size: 13px; cursor: pointer; }
.f-chip.active { color: #fff; background: var(--m-primary-dark); border-color: var(--m-primary-dark); }
.messages-filter-actions { display: flex; justify-content: space-between; padding: 12px 16px; }
.primary-button { color: #fff; background: var(--m-primary-dark); border-radius: var(--m-radius-sm); font-weight: 700; }

.thread-list { margin-top: var(--m-space-4); overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.thread-row { display: flex; width: 100%; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3); border: 0; border-bottom: 1px solid var(--m-border); background: var(--m-surface); color: inherit; text-align: left; cursor: pointer; }.thread-row:last-child { border-bottom: 0; }.thread-row--unread { background: var(--m-primary-soft); }
.thread-avatar { flex: 0 0 auto; background: var(--m-primary-dark); color: var(--m-surface); font-size: 13px; font-weight: 800; }.thread-copy { display: grid; min-width: 0; flex: 1; gap: 2px; }.thread-topline { display: flex; min-width: 0; align-items: baseline; gap: var(--m-space-2); }.thread-name { overflow: hidden; color: var(--m-ink); font-size: 14px; font-weight: 750; text-overflow: ellipsis; white-space: nowrap; }.thread-time { margin-left: auto; flex: 0 0 auto; color: var(--m-muted); font-size: 11px; }.thread-subtitle { color: var(--m-muted); font-size: 12px; }.thread-preview { overflow: hidden; color: var(--m-text); font-size: 13px; line-height: 1.3; text-overflow: ellipsis; white-space: nowrap; }.thread-row--unread .thread-preview { color: var(--m-ink); font-weight: 650; }
.unread-indicator { display: grid; min-width: 20px; height: 20px; padding: 0 var(--m-space-1); place-items: center; border-radius: 999px; background: var(--m-primary-dark); color: var(--m-surface); font-size: 10px; font-weight: 800; }.row-chevron { flex: 0 0 auto; color: var(--m-muted); }
.list-state { display: grid; min-height: 180px; place-items: center; align-content: center; gap: var(--m-space-2); padding: var(--m-space-6); color: var(--m-muted); text-align: center; }.list-state strong { color: var(--m-ink); }.list-state--error { color: var(--m-danger); }.list-state--error strong { color: var(--m-danger); }.retry-button { display: inline-flex; min-height: 40px; align-items: center; gap: var(--m-space-2); padding: 0 var(--m-space-3); border: 1px solid currentColor; border-radius: var(--m-radius-sm); background: transparent; color: var(--m-danger); font: inherit; font-weight: 700; cursor: pointer; }

.new-conversation-dialog { max-width: 720px; margin: 0 auto; border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; }.dialog-heading { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); }.dialog-list { padding: 0; max-height: 50vh; overflow-y: auto; }.dialog-list .thread-row { padding-left: var(--m-space-4); padding-right: var(--m-space-4); }

/* =========================================================
   2. MESSENGER ACTIVE CHAT SCREEN (TEAL THEME)
   ========================================================= */
.messenger-chat-view {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: #ffffff;
}

.messenger-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
  background: #ffffff;
  z-index: 10;
}

.back-btn {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark, #00695c);
  cursor: pointer;
  border-radius: 50%;
}
.back-btn:hover {
  background: #f0f2f5;
}

.header-user-info {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  margin-left: 2px;
}
.header-avatar {
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
  font-weight: 700;
  font-size: 14px;
}
.header-titles {
  display: flex;
  flex-direction: column;
}
.user-name {
  font-size: 15px;
  font-weight: 700;
  color: #050505;
  line-height: 1.2;
}
.user-subtitle {
  font-size: 11px;
  color: #65676b;
}

.action-circle-btn {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark, #00695c);
  cursor: pointer;
}
.action-circle-btn:hover {
  background: #f0f2f5;
}

/* Scrollable Messages Area */
.messenger-scroll {
  flex: 1;
  background: #ffffff;
}

.bubble-stack {
  padding: 16px 14px 24px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

/* Chat Intro Profile Card */
.chat-intro-banner {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin: 16px 0 28px;
  text-align: center;
}
.intro-avatar {
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
  font-weight: 700;
  font-size: 24px;
  margin-bottom: 8px;
}
.intro-name {
  margin: 0;
  font-size: 18px;
  font-weight: 700;
  color: #050505;
}
.intro-meta {
  font-size: 12px;
  color: #65676b;
  margin-top: 2px;
}
.intro-hint {
  font-size: 11px;
  color: #8a8d91;
  margin-top: 6px;
}

/* Date Pill */
.messenger-date-pill {
  align-self: center;
  font-size: 11px;
  font-weight: 600;
  color: #65676b;
  margin: 14px 0 8px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

/* Bubble Rows */
.bubble-row {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  margin-top: 2px;
}
.bubble-row--mine {
  justify-content: flex-end;
}
.bubble-row--theirs {
  justify-content: flex-start;
}
.bubble-row--seq {
  margin-top: 1px;
}

.sender-avatar {
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
  font-size: 10px;
  font-weight: 700;
  flex-shrink: 0;
  margin-bottom: 2px;
}
.sender-avatar--hidden {
  visibility: hidden;
}

.bubble-content-wrap {
  display: flex;
  flex-direction: column;
  max-width: 72%;
}
.bubble-row--mine .bubble-content-wrap {
  align-items: flex-end;
}
.bubble-row--theirs .bubble-content-wrap {
  align-items: flex-start;
}

/* Messenger Teal Bubbles */
.messenger-bubble {
  padding: 10px 14px;
  border-radius: 18px;
  font-size: 15px;
  line-height: 1.35;
  word-break: break-word;
}
.messenger-bubble--mine {
  background: linear-gradient(135deg, #00897b 0%, #00695c 100%);
  color: #ffffff;
  border-bottom-right-radius: 4px;
}
.messenger-bubble--theirs {
  background: #f0f2f5;
  color: #050505;
  border-bottom-left-radius: 4px;
}

.radius-bottom-right { border-bottom-right-radius: 4px !important; }
.radius-top-right { border-top-right-radius: 4px !important; }
.radius-bottom-left { border-bottom-left-radius: 4px !important; }
.radius-top-left { border-top-left-radius: 4px !important; }

.bubble-text {
  margin: 0;
}

/* Delivery Status / Seen */
.delivery-status {
  margin-top: 3px;
  font-size: 11px;
  color: #65676b;
  display: flex;
  align-items: center;
  gap: 3px;
}
.seen-label {
  display: flex;
  align-items: center;
  gap: 2px;
  color: var(--m-primary-dark, #00695c);
  font-weight: 600;
}
.sent-label {
  display: flex;
  align-items: center;
  gap: 2px;
  color: #65676b;
}

/* Bottom Composer */
.messenger-composer-bar {
  padding: 8px 12px calc(8px + env(safe-area-inset-bottom));
  border-top: 1px solid rgba(0, 0, 0, 0.08);
  background: #ffffff;
}

.composer-form {
  display: flex;
  align-items: center;
}

.input-pill {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1;
  background: #f0f2f5;
  border-radius: 20px;
  padding: 4px 6px 4px 14px;
}
.input-pill textarea {
  flex: 1;
  border: 0;
  outline: 0;
  background: transparent;
  font-size: 15px;
  line-height: 20px;
  max-height: 100px;
  resize: none;
  color: #050505;
  padding: 4px 0;
}
.input-pill textarea::placeholder {
  color: #8a8d91;
}

.send-icon-btn {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark, #00695c);
  cursor: pointer;
  transition: opacity 0.15s ease, background 0.15s ease;
}
.send-icon-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}
.send-icon-btn:not(:disabled):hover {
  background: rgba(0, 105, 92, 0.1);
}

.chat-loading, .chat-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 32px;
  gap: 8px;
  color: #65676b;
}
.retry-pill {
  margin-top: 6px;
  padding: 4px 14px;
  border-radius: 12px;
  border: 0;
  background: #f0f2f5;
  font-weight: 600;
  cursor: pointer;
}
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
@media (prefers-reduced-motion: no-preference) { .thread-row { transition: background .15s ease; } }
</style>
