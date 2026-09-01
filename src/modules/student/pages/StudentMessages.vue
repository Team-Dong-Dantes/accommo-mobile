<template>
  <q-page class="messages-page">
    <main v-if="!activeConversation" class="conversation-list" aria-labelledby="messages-title">
      <header class="list-header">
        <div>
          <h1 id="messages-title" class="sr-only">Messages</h1>
          <p class="list-summary">{{ unreadCount }} unread {{ unreadCount === 1 ? 'message' : 'messages' }}</p>
        </div>
      </header>

      <label class="search-field" for="student-message-search">
        <IconifyIcon icon="lucide:search" width="19" aria-hidden="true" />
        <span class="sr-only">Search conversations</span>
        <input id="student-message-search" v-model="searchText" type="search" placeholder="Search messages" autocomplete="off" />
        <button v-if="searchText" type="button" class="clear-search" aria-label="Clear conversation search" @click="searchText = ''">
          <IconifyIcon icon="lucide:x" width="17" aria-hidden="true" />
        </button>
      </label>

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
      <section v-else class="list-state" aria-live="polite">
        <IconifyIcon icon="lucide:message-circle" width="28" aria-hidden="true" />
        <strong>{{ searchText ? 'No conversations match your search.' : 'No conversations yet.' }}</strong>
        <span v-if="!searchText">Start a conversation with a landlord when you need help.</span>
      </section>
    </main>

    <main v-else class="chat-view" :aria-label="`Conversation with ${activeChat.name}`">
      <header class="chat-header">
        <button type="button" class="icon-button" aria-label="Back to conversations" @click="closeConversation">
          <IconifyIcon icon="lucide:arrow-left" width="21" aria-hidden="true" />
        </button>
        <q-avatar class="thread-avatar" size="36px">{{ activeChat.initials }}</q-avatar>
        <div class="chat-title">
          <strong>{{ activeChat.name }}</strong>
          <span>{{ activeChat.role }}</span>
        </div>
      </header>

      <q-scroll-area ref="scrollArea" class="message-scroll">
        <div v-if="messagesLoading" class="list-state" role="status" aria-live="polite">
          <q-spinner color="primary" size="28px" />
          <span>Loading messages...</span>
        </div>
        <div v-else-if="messagesError" class="list-state list-state--error" role="alert">
          <IconifyIcon icon="lucide:circle-alert" width="25" aria-hidden="true" />
          <strong>We couldn't load this conversation.</strong>
          <span>{{ messagesError }}</span>
          <button type="button" class="retry-button" @click="openConversation(activeConversation!)">
            <IconifyIcon icon="lucide:refresh-cw" width="16" aria-hidden="true" />
            Try again
          </button>
        </div>
        <div v-else class="message-stack">
          <p v-if="messages.length === 0" class="empty-thread">No messages yet. Say hello!</p>
          <template v-for="(msg, index) in messages" :key="msg.id">
            <div v-if="index === 0 || isDifferentDay(messages[index - 1]?.sentAt, msg.sentAt)" class="date-label">
              {{ formatDay(msg.sentAt) }}
            </div>
            <div class="message-row" :class="{ 'message-row--mine': msg.isMine }">
              <article class="message-bubble" :class="{ 'message-bubble--mine': msg.isMine }">
                <p>{{ msg.body }}</p>
                <time :datetime="msg.sentAt">{{ formatTime(msg.sentAt) }}</time>
              </article>
            </div>
          </template>
        </div>
      </q-scroll-area>

      <form class="composer" @submit.prevent="sendMessage">
        <label class="sr-only" for="student-message-composer">Message</label>
        <textarea id="student-message-composer" v-model="newMessage" rows="1" placeholder="Write a message" :disabled="sending" @keydown.enter.exact.prevent="sendMessage" />
        <button type="submit" class="send-button" :disabled="!newMessage.trim() || sending" :aria-label="sending ? 'Sending message' : 'Send message'">
          <q-spinner v-if="sending" size="18px" />
          <IconifyIcon v-else icon="lucide:send" width="18" aria-hidden="true" />
        </button>
      </form>
    </main>

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

interface ConversationRow { id: string; user_a_id: string; user_b_id: string; last_message: string | null; last_time: string | null; unread_a: number | null; unread_b: number | null }
interface UserRow { id: string; full_name: string | null; role: string | null }
interface ConversationItem { id: string; name: string; initials: string; role: string; lastMessage: string; lastTime: string | null; unread: number; otherUserId: string }
interface MessageRow { id: string; conversation_id: string; sender_id: string; body: string; sent_at: string }
interface MessageItem { id: string; body: string; sentAt: string; isMine: boolean }

const $q = useQuasar()
const route = useRoute()
const loading = ref(true)
const error = ref<string | null>(null)
const searchText = ref('')
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
const scrollArea = ref<{ setScrollPosition: (position: number) => void } | null>(null)

const filteredConversations = computed(() => {
  const term = searchText.value.trim().toLowerCase()
  if (!term) return conversations.value
  return conversations.value.filter((chat) => [chat.name, chat.role, chat.lastMessage].some((value) => value.toLowerCase().includes(term)))
})
const unreadCount = computed(() => conversations.value.reduce((total, chat) => total + chat.unread, 0))

function initialsOf(name: string): string { const parts = name.trim().split(/\s+/).filter(Boolean); return parts.length > 1 ? `${parts[0]?.[0] ?? ''}${parts[parts.length - 1]?.[0] ?? ''}`.toUpperCase() : (parts[0] ?? 'U').slice(0, 2).toUpperCase() }
function roleLabel(role: string | null | undefined): string { return role === 'accommodation_manager' || role === 'landlord' ? 'Landlord' : role === 'student' ? 'Student' : 'Participant' }
function formatListTime(timestamp: string): string { const date = new Date(timestamp); return date.toDateString() === new Date().toDateString() ? formatTime(timestamp) : date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) }
function isDifferentDay(previous: string | undefined, current: string): boolean { return !previous || new Date(previous).toDateString() !== new Date(current).toDateString() }
function formatDay(timestamp: string): string { const date = new Date(timestamp); const today = new Date().toDateString(); const yesterday = new Date(Date.now() - 86400000).toDateString(); if (date.toDateString() === today) return 'Today'; if (date.toDateString() === yesterday) return 'Yesterday'; return date.toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' }) }
function formatTime(timestamp: string): string { return new Date(timestamp).toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' }) }

async function loadConversations() {
  loading.value = true; error.value = null
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { conversations.value = []; return }
    currentUserId.value = user.id
    const { data, error: queryError } = await supabase.from('conversations').select('id, user_a_id, user_b_id, last_message, last_time, unread_a, unread_b').or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`).order('last_time', { ascending: false, nullsFirst: false })
    if (queryError) throw queryError
    const rows = (data ?? []) as ConversationRow[]
    const otherIds = [...new Set(rows.map((row) => row.user_a_id === user.id ? row.user_b_id : row.user_a_id))]
    const { data: users, error: usersError } = otherIds.length ? await supabase.from('users').select('id, full_name, role').in('id', otherIds) : { data: [], error: null }
    if (usersError) throw usersError
    const userMap = new Map((users ?? []).map((participant) => { const person = participant as UserRow; return [person.id, person] }))
    conversations.value = rows.map((row) => { const otherUserId = row.user_a_id === user.id ? row.user_b_id : row.user_a_id; const participant = userMap.get(otherUserId); const name = participant?.full_name ?? roleLabel(participant?.role); return { id: row.id, name, initials: initialsOf(name), role: roleLabel(participant?.role), lastMessage: row.last_message ?? '', lastTime: row.last_time, unread: row.user_a_id === user.id ? row.unread_a ?? 0 : row.unread_b ?? 0, otherUserId } })
  } catch (caught) { error.value = caught instanceof Error ? caught.message : 'Failed to load messages'; conversations.value = [] } finally { loading.value = false }
}

async function openConversation(id: string) {
  const chat = conversations.value.find((item) => item.id === id)
  if (!chat) return
  activeChat.value = chat; activeConversation.value = id; messagesLoading.value = true; messagesError.value = null; messages.value = []
  try {
    const { data, error: queryError } = await supabase.from('messages').select('id, conversation_id, sender_id, body, sent_at').eq('conversation_id', id).order('sent_at', { ascending: true })
    if (queryError) throw queryError
    messages.value = ((data ?? []) as MessageRow[]).map((message) => ({ id: message.id, body: message.body, sentAt: message.sent_at, isMine: message.sender_id === currentUserId.value }))
    await markConversationRead(id)
    subscribeToConversation(id)
    void scrollToBottom()
  } catch (caught) { messagesError.value = caught instanceof Error ? caught.message : 'Failed to load messages' } finally { messagesLoading.value = false }
}

async function markConversationRead(id: string) {
  if (!currentUserId.value) return
  const chat = conversations.value.find((item) => item.id === id)
  if (!chat || chat.unread === 0) return
  const { data, error: queryError } = await supabase.from('conversations').select('user_a_id').eq('id', id).maybeSingle()
  if (queryError || !data) return
  if ((data as { user_a_id: string }).user_a_id === currentUserId.value) {
    await supabase.from('conversations').update({ unread_a: 0 }).eq('id', id)
  } else {
    await supabase.from('conversations').update({ unread_b: 0 }).eq('id', id)
  }
  chat.unread = 0
}

function unsubscribeMessages() { if (messageChannel.value) { messageChannel.value.unsubscribe(); messageChannel.value = null } }
function closeConversation() { unsubscribeMessages(); activeConversation.value = null; messages.value = []; messagesError.value = null }
function subscribeToConversation(id: string) { unsubscribeMessages(); messageChannel.value = supabase.channel(`messages-${id}`).on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${id}` }, (payload) => { const row = payload.new as MessageRow; if (row.sender_id === currentUserId.value || messages.value.some((message) => message.id === row.id)) return; messages.value.push({ id: row.id, body: row.body, sentAt: row.sent_at, isMine: false }); void scrollToBottom() }).subscribe() }
async function scrollToBottom() { await nextTick(); scrollArea.value?.setScrollPosition(100000) }

async function sendMessage() {
  const body = newMessage.value.trim(); const conversationId = activeConversation.value; const userId = currentUserId.value
  if (!body || !conversationId || !userId || sending.value) return
  sending.value = true
  try {
    const { error: insertError } = await supabase.from('messages').insert({ conversation_id: conversationId, sender_id: userId, body, sent_at: new Date().toISOString() })
    if (insertError) throw insertError
    const { data: conversation, error: conversationError } = await supabase.from('conversations').select('user_a_id, user_b_id, unread_a, unread_b').eq('id', conversationId).maybeSingle()
    if (conversationError) throw conversationError
    if (conversation) { const row = conversation as { user_a_id: string; user_b_id: string; unread_a: number | null; unread_b: number | null }; if (row.user_b_id === userId) { await supabase.from('conversations').update({ last_message: body, last_time: new Date().toISOString(), unread_a: (row.unread_a ?? 0) + 1 }).eq('id', conversationId) } else { await supabase.from('conversations').update({ last_message: body, last_time: new Date().toISOString(), unread_b: (row.unread_b ?? 0) + 1 }).eq('id', conversationId) } const recipientId = row.user_a_id === userId ? row.user_b_id : row.user_a_id; await supabase.from('notifications').insert({ id: crypto.randomUUID(), user_id: recipientId, title: 'New message', body, type: 'message', read_at: null } as any) }
    const chat = conversations.value.find((item) => item.id === conversationId); if (chat) { chat.lastMessage = body; chat.lastTime = new Date().toISOString(); chat.unread = 0; conversations.value = [chat, ...conversations.value.filter((item) => item.id !== conversationId)] }
    newMessage.value = ''
    const { data, error: refreshError } = await supabase.from('messages').select('id, conversation_id, sender_id, body, sent_at').eq('conversation_id', conversationId).order('sent_at', { ascending: true })
    if (refreshError) throw refreshError
    messages.value = ((data ?? []) as MessageRow[]).map((message) => ({ id: message.id, body: message.body, sentAt: message.sent_at, isMine: message.sender_id === userId }))
    void scrollToBottom()
  } catch (caught) { $q.notify({ message: caught instanceof Error ? caught.message : 'Failed to send message', color: 'negative', position: 'top' }) } finally { sending.value = false }
}

async function startNewConversation() { newConvoDialog.value = true; newConvoLoading.value = true; try { const { data, error: queryError } = await supabase.from('users').select('id, full_name').or('role.eq.accommodation_manager'); if (queryError) throw queryError; landlords.value = ((data ?? []) as Array<{ id: string; full_name: string | null }>).map((user) => ({ id: user.id, name: user.full_name ?? 'Landlord' })) } catch { landlords.value = [] } finally { newConvoLoading.value = false } }
async function ensureConversation(otherUserId: string): Promise<string | null> { if (!currentUserId.value) return null; const me = currentUserId.value; const { data: existing, error: existingError } = await supabase.from('conversations').select('id').or(`and(user_a_id.eq.${me},user_b_id.eq.${otherUserId}),and(user_a_id.eq.${otherUserId},user_b_id.eq.${me})`).limit(1); if (existingError) throw existingError; const first = (existing ?? []) as Array<{ id: string }>; if (first[0]) return first[0].id; const { data: created, error: createError } = await supabase.from('conversations').insert({ user_a_id: me, user_b_id: otherUserId, last_message: null, last_time: new Date().toISOString(), unread_a: 0, unread_b: 0 }).select('id').single(); if (createError) throw createError; return (created as { id: string }).id }
async function startChatWith(otherUserId: string, name: string) { newConvoDialog.value = false; try { const conversationId = await ensureConversation(otherUserId); if (!conversationId) return; await loadConversations(); if (!conversations.value.some((item) => item.id === conversationId)) conversations.value.unshift({ id: conversationId, name, initials: initialsOf(name), role: 'Landlord', lastMessage: '', lastTime: null, unread: 0, otherUserId }); await openConversation(conversationId) } catch (caught) { $q.notify({ message: caught instanceof Error ? caught.message : 'Failed to start chat', color: 'negative', position: 'top' }) } }
async function handleLandlordQuery() { const landlordId = route.query.landlord as string | undefined; if (!landlordId) return; const { data } = await supabase.from('users').select('full_name').eq('id', landlordId).maybeSingle(); await startChatWith(landlordId, (data as { full_name: string | null } | null)?.full_name ?? 'Landlord') }

onMounted(async () => { await loadConversations(); await handleLandlordQuery() })
onUnmounted(unsubscribeMessages)
</script>

<style scoped>
.messages-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.conversation-list, .chat-view { min-height: 100vh; max-width: 720px; margin: 0 auto; }
.conversation-list { padding: var(--m-space-5) var(--m-page-gutter) calc(var(--m-space-8) + 72px); }
.list-header { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); margin-bottom: var(--m-space-4); }
h1, h2 { margin: 0; color: var(--m-ink); letter-spacing: -.03em; } h1 { font-size: 28px; line-height: 1.1; } h2 { font-size: 20px; }
.list-summary { margin: var(--m-space-1) 0 0; color: var(--m-muted); font-size: 13px; }
.icon-button, .send-button, .clear-search { display: grid; width: 44px; height: 44px; flex: 0 0 44px; padding: 0; place-items: center; border: 0; border-radius: 50%; background: transparent; color: var(--m-ink); cursor: pointer; }
.icon-button--primary, .send-button { background: var(--m-primary); color: var(--m-surface); }
.search-field { display: flex; align-items: center; gap: var(--m-space-2); min-height: 48px; padding: 0 var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-muted); }
.search-field input, .composer textarea { width: 100%; border: 0; outline: 0; background: transparent; color: var(--m-ink); font: inherit; }
.search-field input::placeholder, .composer textarea::placeholder { color: var(--m-muted); }.clear-search { width: 32px; height: 32px; color: var(--m-muted); }
.thread-list { margin-top: var(--m-space-4); overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.thread-row { display: flex; width: 100%; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3); border: 0; border-bottom: 1px solid var(--m-border); background: var(--m-surface); color: inherit; text-align: left; cursor: pointer; }.thread-row:last-child { border-bottom: 0; }.thread-row--unread { background: var(--m-primary-soft); }
.thread-avatar { flex: 0 0 auto; background: var(--m-primary-dark); color: var(--m-surface); font-size: 13px; font-weight: 800; }.thread-copy { display: grid; min-width: 0; flex: 1; gap: 2px; }.thread-topline { display: flex; min-width: 0; align-items: baseline; gap: var(--m-space-2); }.thread-name { overflow: hidden; color: var(--m-ink); font-size: 14px; font-weight: 750; text-overflow: ellipsis; white-space: nowrap; }.thread-time { margin-left: auto; flex: 0 0 auto; color: var(--m-muted); font-size: 11px; }.thread-subtitle { color: var(--m-muted); font-size: 12px; }.thread-preview { overflow: hidden; color: var(--m-text); font-size: 13px; line-height: 1.3; text-overflow: ellipsis; white-space: nowrap; }.thread-row--unread .thread-preview { color: var(--m-ink); font-weight: 650; }
.unread-indicator { display: grid; min-width: 20px; height: 20px; padding: 0 var(--m-space-1); place-items: center; border-radius: 999px; background: var(--m-primary); color: var(--m-surface); font-size: 10px; font-weight: 800; }.row-chevron { flex: 0 0 auto; color: var(--m-muted); }
.list-state { display: grid; min-height: 180px; place-items: center; align-content: center; gap: var(--m-space-2); padding: var(--m-space-6); color: var(--m-muted); text-align: center; }.list-state strong { color: var(--m-ink); }.list-state--error { color: var(--m-danger); }.list-state--error strong { color: var(--m-danger); }.retry-button { display: inline-flex; min-height: 40px; align-items: center; gap: var(--m-space-2); padding: 0 var(--m-space-3); border: 1px solid currentColor; border-radius: var(--m-radius-sm); background: transparent; color: var(--m-danger); font: inherit; font-weight: 700; cursor: pointer; }
.chat-view { display: flex; flex-direction: column; height: 100vh; }.chat-header { display: flex; min-height: 60px; align-items: center; gap: var(--m-space-2); padding: var(--m-space-2) var(--m-page-gutter); border-bottom: 1px solid var(--m-border); background: var(--m-surface); }.chat-title { display: grid; min-width: 0; gap: 1px; }.chat-title strong { overflow: hidden; color: var(--m-ink); font-size: 14px; text-overflow: ellipsis; white-space: nowrap; }.chat-title span { color: var(--m-muted); font-size: 12px; }.message-scroll { flex: 1; }.message-stack { padding: var(--m-space-4) var(--m-page-gutter); }.date-label { width: max-content; margin: var(--m-space-3) auto; padding: var(--m-space-1) var(--m-space-2); border-radius: 999px; background: var(--m-surface); color: var(--m-muted); font-size: 11px; font-weight: 700; }.message-row { display: flex; margin: var(--m-space-1) 0; }.message-row--mine { justify-content: flex-end; }.message-bubble { max-width: 78%; padding: var(--m-space-2) var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); border-bottom-left-radius: var(--m-space-1); background: var(--m-surface); }.message-bubble--mine { border-color: var(--m-primary); border-bottom-right-radius: var(--m-space-1); border-bottom-left-radius: var(--m-radius-sm); background: var(--m-primary); color: var(--m-surface); }.message-bubble p { margin: 0; overflow-wrap: anywhere; font-size: 14px; line-height: 1.4; }.message-bubble time { display: block; margin-top: var(--m-space-1); color: var(--m-muted); font-size: 10px; text-align: right; }.message-bubble--mine time { color: var(--m-primary-soft); }.empty-thread { margin: var(--m-space-8) 0; color: var(--m-muted); text-align: center; }.composer { display: flex; align-items: flex-end; gap: var(--m-space-2); padding: var(--m-space-2) var(--m-page-gutter); border-top: 1px solid var(--m-border); background: var(--m-surface); }.composer textarea { min-height: 44px; max-height: 120px; resize: none; padding: 12px; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); line-height: 18px; }.send-button:disabled { background: var(--m-border); color: var(--m-muted); cursor: not-allowed; }
.new-conversation-dialog { max-width: 720px; margin: 0 auto; border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; }.dialog-heading { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); }.dialog-list { padding: 0; max-height: 50vh; overflow-y: auto; }.dialog-list .thread-row { padding-left: var(--m-space-4); padding-right: var(--m-space-4); }
.icon-button:focus-visible, .send-button:focus-visible, .clear-search:focus-visible, .thread-row:focus-visible, .retry-button:focus-visible, .search-field:focus-within, .composer textarea:focus { outline: 2px solid var(--m-primary-dark); outline-offset: 2px; }.thread-row:hover { background: var(--m-primary-soft); }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
@media (prefers-reduced-motion: no-preference) { .thread-row { transition: background .15s ease; } }
</style>
