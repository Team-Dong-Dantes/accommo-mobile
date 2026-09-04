<template>
  <q-page class="messages-page">
    <main class="conversation-list" aria-labelledby="manager-messages-title">
      <header class="list-header">
        <div>
          <h1 id="manager-messages-title" class="sr-only">Messages</h1>
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
          v-for="conversation in filteredConversations"
          :key="conversation.id"
          type="button"
          class="thread-row"
          :class="{ 'thread-row--unread': conversation.unread > 0 }"
          @click="openConversation(conversation.id)"
        >
          <q-avatar class="thread-avatar" size="44px">{{ conversation.initials }}</q-avatar>
          <span class="thread-copy">
            <span class="thread-topline">
              <span class="thread-name">{{ conversation.name }}</span>
              <time v-if="conversation.lastTime" class="thread-time" :datetime="conversation.lastTime">{{ formatListTime(conversation.lastTime) }}</time>
            </span>
            <span class="thread-subtitle">{{ conversation.role }}</span>
            <span class="thread-preview">{{ conversation.lastMessage || 'No messages yet' }}</span>
          </span>
          <span v-if="conversation.unread > 0" class="unread-indicator">
            <span class="sr-only">{{ conversation.unread }} unread messages</span>{{ conversation.unread > 99 ? '99+' : conversation.unread }}
          </span>
          <IconifyIcon v-else icon="lucide:chevron-right" class="row-chevron" width="18" aria-hidden="true" />
        </button>
      </section>
      <EmptyState v-else icon="lucide:message-circle" :title="searchText ? 'No conversations match your search.' : 'No conversations yet.'" :message="searchText ? '' : 'Messages from students will appear here.'" />
    </main>

    <!-- Fixed bottom search + filter (discover-style) -->
    <div class="messages-action-bar">
      <button type="button" class="messages-filter-button" :class="{ 'has-active': activeFilter !== 'all' }" aria-label="Filter conversations" @click="filterDialog = true">
        <IconifyIcon icon="mdi:tune" width="21" aria-hidden="true" />
      </button>
      <label class="messages-search-field" for="manager-message-search">
        <IconifyIcon icon="lucide:search" width="20" aria-hidden="true" />
        <span class="sr-only">Search conversations</span>
        <input id="manager-message-search" v-model="searchText" type="search" placeholder="Search messages" autocomplete="off" />
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
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'
import EmptyState from '@/components/shared/EmptyState.vue'

interface ConversationRow { id: string; user_a_id: string; user_b_id: string; last_message: string | null; last_time: string | null; unread_a: number | null; unread_b: number | null }
interface UserRow { id: string; full_name: string | null; email: string | null; role: string | null }
interface ConversationItem { id: string; initials: string; name: string; role: string; lastMessage: string; lastTime: string | null; unread: number }

const router = useRouter()
const searchText = ref('')
const filterDialog = ref(false)
const activeFilter = ref<'all' | 'students' | 'landlords'>('all')
const filterOptions: { value: 'all' | 'students' | 'landlords'; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'students', label: 'Students' },
  { value: 'landlords', label: 'Managers' },
]
const loading = ref(true)
const error = ref<string | null>(null)
const conversations = ref<ConversationItem[]>([])
const currentUserId = ref<string | null>(null)
const conversationChannel = ref<any>(null)
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
    await fetchConversationsQuietly()
  }, 2000)
}

async function fetchConversationsQuietly() {
  if (!currentUserId.value) return
  try {
    const { data: conversationData } = await supabase
      .from('conversations')
      .select('id, user_a_id, user_b_id, last_message, last_time, unread_a, unread_b')
      .or(`user_a_id.eq.${currentUserId.value},user_b_id.eq.${currentUserId.value}`)
      .order('last_time', { ascending: false, nullsFirst: false })

    if (!conversationData) return
    const rows = conversationData as ConversationRow[]
    const otherUserIds = [...new Set(rows.map((row) => row.user_a_id === currentUserId.value ? row.user_b_id : row.user_a_id))]
    const { data: users } = otherUserIds.length
      ? await supabase.from('users').select('id, full_name, email, role').in('id', otherUserIds)
      : { data: [] }
    const usersById = new Map((users ?? []).map((value) => { const participant = value as UserRow; return [participant.id, participant] }))

    const updated = rows.map((row) => {
      const otherUserId = row.user_a_id === currentUserId.value ? row.user_b_id : row.user_a_id
      const participant = usersById.get(otherUserId)
      const role = roleLabel(participant?.role)
      const name = participant?.full_name ?? participant?.email ?? role
      return {
        id: row.id,
        initials: initialsOf(name),
        name,
        role,
        lastMessage: row.last_message ?? '',
        lastTime: row.last_time,
        unread: row.user_a_id === currentUserId.value ? row.unread_a ?? 0 : row.unread_b ?? 0,
      }
    })

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

const unreadCount = computed(() => conversations.value.reduce((total, conversation) => total + conversation.unread, 0))
const filteredConversations = computed(() => {
  let list = conversations.value
  if (activeFilter.value === 'students') list = list.filter((conversation) => conversation.role === 'Student')
  else if (activeFilter.value === 'landlords') list = list.filter((conversation) => conversation.role === 'Manager')
  const term = searchText.value.trim().toLowerCase()
  if (!term) return list
  return list.filter((conversation) => [conversation.name, conversation.role, conversation.lastMessage].some((field) => field.toLowerCase().includes(term)))
})

function initialsOf(name: string): string { const parts = name.trim().split(/\s+/).filter(Boolean); return parts.length > 1 ? `${parts[0]?.[0] ?? ''}${parts[parts.length - 1]?.[0] ?? ''}`.toUpperCase() : (parts[0] ?? 'U').slice(0, 2).toUpperCase() }
function roleLabel(role: string | null | undefined): string { return role === 'student' ? 'Student' : role === 'manager' || role === 'accommodation_manager' ? 'Manager' : 'Participant' }
function formatListTime(timestamp: string): string { const date = new Date(timestamp); return date.toDateString() === new Date().toDateString() ? date.toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' }) : date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) }

async function loadConversations() {
  loading.value = true
  error.value = null
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { conversations.value = []; return }
    currentUserId.value = user.id
    subscribeToConversations(user.id)
    const { data, error: conversationError } = await supabase
      .from('conversations')
      .select('id, user_a_id, user_b_id, last_message, last_time, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
      .order('last_time', { ascending: false, nullsFirst: false })
    if (conversationError) throw conversationError

    const rows = (data ?? []) as ConversationRow[]
    const otherUserIds = [...new Set(rows.map((row) => row.user_a_id === user.id ? row.user_b_id : row.user_a_id))]
    const { data: users, error: usersError } = otherUserIds.length
      ? await supabase.from('users').select('id, full_name, email, role').in('id', otherUserIds)
      : { data: [], error: null }
    if (usersError) throw usersError
    const usersById = new Map((users ?? []).map((value) => { const participant = value as UserRow; return [participant.id, participant] }))

    conversations.value = rows.map((row) => {
      const otherUserId = row.user_a_id === user.id ? row.user_b_id : row.user_a_id
      const participant = usersById.get(otherUserId)
      const role = roleLabel(participant?.role)
      const name = participant?.full_name ?? participant?.email ?? role
      return {
        id: row.id,
        initials: initialsOf(name),
        name,
        role,
        lastMessage: row.last_message ?? '',
        lastTime: row.last_time,
        unread: row.user_a_id === user.id ? row.unread_a ?? 0 : row.unread_b ?? 0,
      }
    })
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : 'Failed to load messages'
    conversations.value = []
  } finally {
    loading.value = false
  }
}

async function markConversationSeen(conversationId: string) {
  if (!currentUserId.value) return
  try {
    const { data, error: queryError } = await supabase.from('conversations').select('user_a_id').eq('id', conversationId).maybeSingle()
    if (queryError || !data) return
    if ((data as { user_a_id: string }).user_a_id === currentUserId.value) {
      await supabase.from('conversations').update({ unread_a: 0 }).eq('id', conversationId)
    } else {
      await supabase.from('conversations').update({ unread_b: 0 }).eq('id', conversationId)
    }
  } catch (e) {
    console.warn('Failed to mark conversation read:', e)
  }
}

function unsubscribeConversations() {
  stopListPolling()
  // removeChannel(), not unsubscribe(): unsubscribe() leaves the channel in the
  // client cache, so re-subscribing to the same channel name later throws
  // "cannot add postgres_changes callbacks after subscribe()".
  if (conversationChannel.value) {
    void supabase.removeChannel(conversationChannel.value)
  }
  conversationChannel.value = null
}

function subscribeToConversations(userId: string) {
  unsubscribeConversations()
  startListPolling()
  conversationChannel.value = supabase
    .channel(`manager-conversations-${userId}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'conversations' }, () => {
      void fetchConversationsQuietly()
    })
    .subscribe()
}

async function openConversation(conversationId: string) {
  const chat = conversations.value.find((item) => item.id === conversationId)
  if (chat) chat.unread = 0
  await markConversationSeen(conversationId)
  void router.push(`/manager/chat?conv=${conversationId}`)
}

onMounted(() => { void loadConversations() })
onUnmounted(() => { unsubscribeConversations() })
</script>

<style scoped>
.messages-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.conversation-list { min-height: 100vh; max-width: 720px; margin: 0 auto; padding: var(--m-space-5) var(--m-page-gutter) calc(168px + env(safe-area-inset-bottom)); }
.list-header { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); margin-bottom: var(--m-space-4); }.list-summary { margin: 0; color: var(--m-muted); font-size: 13px; }

/* Fixed bottom search (discover-style matching manager tenants / discover action-bar) */
.messages-action-bar { position: fixed; z-index: 59; right: 72px; bottom: 68px; left: var(--m-page-gutter); display: flex; gap: var(--m-space-2); align-items: center; }
.messages-search-field { display: flex; min-width: 0; flex: 1; align-items: center; gap: var(--m-space-2); min-height: 44px; padding: 0 var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-muted); box-shadow: 0 4px 12px rgba(15, 23, 42, .08); }.messages-search-field input { min-width: 0; flex: 1; border: 0; outline: 0; background: transparent; color: var(--m-ink); font: inherit; }.messages-search-field input::placeholder { color: var(--m-muted); }.messages-clear-search { display: grid; width: 28px; height: 28px; padding: 0; place-items: center; border: 0; border-radius: 50%; background: transparent; color: var(--m-muted); cursor: pointer; }
.messages-filter-button { display: grid; width: 44px; height: 44px; flex: 0 0 44px; padding: 0; place-items: center; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-primary-dark); box-shadow: 0 4px 12px rgba(15, 23, 42, .08); cursor: pointer; }
.messages-filter-button.has-active { border-color: var(--m-primary); background: color-mix(in srgb, var(--m-primary-soft) 60%, var(--m-surface)); }
.messages-filter-sheet { border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; padding-bottom: env(safe-area-inset-bottom); }
.messages-filter-heading { display: flex; justify-content: space-between; align-items: flex-start; }
.messages-filter-heading h2 { margin: 0; font-size: 17px; }
.messages-filter-heading p { margin: 4px 0 0; color: var(--m-muted); font-size: 13px; }
.messages-filter-sheet h3 { margin: 4px 0 10px; color: var(--m-muted); font-size: 12px; letter-spacing: .04em; text-transform: uppercase; }
.messages-filter-options { display: flex; flex-wrap: wrap; gap: var(--m-space-2); }
.f-chip { min-height: 38px; padding: 0 16px; border: 1px solid var(--m-border); border-radius: 999px; background: var(--m-surface); color: var(--m-text); font: inherit; font-weight: 600; font-size: 13px; cursor: pointer; }
.f-chip.active { color: #fff; background: var(--m-primary); border-color: var(--m-primary); }
.messages-filter-actions { display: flex; justify-content: space-between; padding: 12px 16px; }
.primary-button { color: #fff; background: var(--m-primary); border-radius: var(--m-radius-sm); font-weight: 700; }
.thread-list { margin-top: var(--m-space-4); overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }.thread-row { display: flex; width: 100%; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3); border: 0; border-bottom: 1px solid var(--m-border); background: var(--m-surface); color: inherit; text-align: left; cursor: pointer; }.thread-row:last-child { border-bottom: 0; }.thread-row--unread { background: var(--m-primary-soft); }.thread-avatar { flex: 0 0 auto; background: var(--m-primary-dark); color: var(--m-surface); font-size: 13px; font-weight: 800; }.thread-copy { display: grid; min-width: 0; flex: 1; gap: 2px; }.thread-topline { display: flex; min-width: 0; align-items: baseline; gap: var(--m-space-2); }.thread-name { overflow: hidden; color: var(--m-ink); font-size: 14px; font-weight: 750; text-overflow: ellipsis; white-space: nowrap; }.thread-time { margin-left: auto; flex: 0 0 auto; color: var(--m-muted); font-size: 11px; }.thread-subtitle { color: var(--m-muted); font-size: 12px; }.thread-preview { overflow: hidden; color: var(--m-text); font-size: 13px; line-height: 1.3; text-overflow: ellipsis; white-space: nowrap; }.thread-row--unread .thread-preview { color: var(--m-ink); font-weight: 650; }.unread-indicator { display: grid; min-width: 20px; height: 20px; padding: 0 var(--m-space-1); place-items: center; border-radius: 999px; background: var(--m-primary); color: var(--m-surface); font-size: 10px; font-weight: 800; }.row-chevron { flex: 0 0 auto; color: var(--m-muted); }
.list-state { display: grid; min-height: 180px; place-items: center; align-content: center; gap: var(--m-space-2); padding: var(--m-space-6); color: var(--m-muted); text-align: center; }.list-state strong { color: var(--m-ink); }.list-state--error { color: var(--m-danger); }.list-state--error strong { color: var(--m-danger); }.retry-button { display: inline-flex; min-height: 40px; align-items: center; gap: var(--m-space-2); padding: 0 var(--m-space-3); border: 1px solid currentColor; border-radius: var(--m-radius-sm); background: transparent; color: var(--m-danger); font: inherit; font-weight: 700; cursor: pointer; }
.messages-clear-search:focus-visible, .thread-row:focus-visible, .retry-button:focus-visible, .messages-search-field:focus-within { outline: 2px solid var(--m-primary-dark); outline-offset: 2px; }.thread-row:hover { background: var(--m-primary-soft); }.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }@media (prefers-reduced-motion: no-preference) { .thread-row { transition: background .15s ease; } }
</style>
