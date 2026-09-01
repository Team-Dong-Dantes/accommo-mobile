<template>
  <q-page class="messages-page">
    <main class="conversation-list" aria-labelledby="landlord-messages-title">
      <header class="list-header">
        <div>
          <h1 id="landlord-messages-title" class="sr-only">Messages</h1>
          <p class="list-summary">{{ unreadCount }} unread {{ unreadCount === 1 ? 'message' : 'messages' }}</p>
        </div>
      </header>

      <label class="search-field" for="landlord-message-search">
        <IconifyIcon icon="lucide:search" width="19" aria-hidden="true" />
        <span class="sr-only">Search conversations</span>
        <input id="landlord-message-search" v-model="searchText" type="search" placeholder="Search messages" autocomplete="off" />
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
      <section v-else class="list-state" aria-live="polite">
        <IconifyIcon icon="lucide:message-circle" width="28" aria-hidden="true" />
        <strong>{{ searchText ? 'No conversations match your search.' : 'No conversations yet.' }}</strong>
        <span v-if="!searchText">Messages from students will appear here.</span>
      </section>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

interface ConversationRow { id: string; user_a_id: string; user_b_id: string; last_message: string | null; last_time: string | null; unread_a: number | null; unread_b: number | null }
interface UserRow { id: string; full_name: string | null; email: string | null; role: string | null }
interface ConversationItem { id: string; initials: string; name: string; role: string; lastMessage: string; lastTime: string | null; unread: number }

const router = useRouter()
const searchText = ref('')
const loading = ref(true)
const error = ref<string | null>(null)
const conversations = ref<ConversationItem[]>([])

const unreadCount = computed(() => conversations.value.reduce((total, conversation) => total + conversation.unread, 0))
const filteredConversations = computed(() => {
  const term = searchText.value.trim().toLowerCase()
  if (!term) return conversations.value
  return conversations.value.filter((conversation) => [conversation.name, conversation.role, conversation.lastMessage].some((field) => field.toLowerCase().includes(term)))
})

function initialsOf(name: string): string { const parts = name.trim().split(/\s+/).filter(Boolean); return parts.length > 1 ? `${parts[0]?.[0] ?? ''}${parts[parts.length - 1]?.[0] ?? ''}`.toUpperCase() : (parts[0] ?? 'U').slice(0, 2).toUpperCase() }
function roleLabel(role: string | null | undefined): string { return role === 'student' ? 'Student' : role === 'landlord' || role === 'accommodation_manager' ? 'Landlord' : 'Participant' }
function formatListTime(timestamp: string): string { const date = new Date(timestamp); return date.toDateString() === new Date().toDateString() ? date.toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' }) : date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) }

async function loadConversations() {
  loading.value = true
  error.value = null
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { conversations.value = []; return }
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

function openConversation(conversationId: string) {
  void router.push(`/landlord/chat?conv=${conversationId}`)
}

onMounted(() => { void loadConversations() })
</script>

<style scoped>
.messages-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.conversation-list { min-height: 100vh; max-width: 720px; margin: 0 auto; padding: var(--m-space-5) var(--m-page-gutter) calc(var(--m-space-8) + 72px); }
.list-header { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); margin-bottom: var(--m-space-4); }.list-summary { margin: 0; color: var(--m-muted); font-size: 13px; }
.search-field { display: flex; align-items: center; gap: var(--m-space-2); min-height: 48px; padding: 0 var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-muted); }.search-field input { width: 100%; border: 0; outline: 0; background: transparent; color: var(--m-ink); font: inherit; }.search-field input::placeholder { color: var(--m-muted); }.clear-search { display: grid; width: 32px; height: 32px; padding: 0; place-items: center; border: 0; border-radius: 50%; background: transparent; color: var(--m-muted); cursor: pointer; }
.thread-list { margin-top: var(--m-space-4); overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }.thread-row { display: flex; width: 100%; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3); border: 0; border-bottom: 1px solid var(--m-border); background: var(--m-surface); color: inherit; text-align: left; cursor: pointer; }.thread-row:last-child { border-bottom: 0; }.thread-row--unread { background: var(--m-primary-soft); }.thread-avatar { flex: 0 0 auto; background: var(--m-primary-dark); color: var(--m-surface); font-size: 13px; font-weight: 800; }.thread-copy { display: grid; min-width: 0; flex: 1; gap: 2px; }.thread-topline { display: flex; min-width: 0; align-items: baseline; gap: var(--m-space-2); }.thread-name { overflow: hidden; color: var(--m-ink); font-size: 14px; font-weight: 750; text-overflow: ellipsis; white-space: nowrap; }.thread-time { margin-left: auto; flex: 0 0 auto; color: var(--m-muted); font-size: 11px; }.thread-subtitle { color: var(--m-muted); font-size: 12px; }.thread-preview { overflow: hidden; color: var(--m-text); font-size: 13px; line-height: 1.3; text-overflow: ellipsis; white-space: nowrap; }.thread-row--unread .thread-preview { color: var(--m-ink); font-weight: 650; }.unread-indicator { display: grid; min-width: 20px; height: 20px; padding: 0 var(--m-space-1); place-items: center; border-radius: 999px; background: var(--m-primary); color: var(--m-surface); font-size: 10px; font-weight: 800; }.row-chevron { flex: 0 0 auto; color: var(--m-muted); }
.list-state { display: grid; min-height: 180px; place-items: center; align-content: center; gap: var(--m-space-2); padding: var(--m-space-6); color: var(--m-muted); text-align: center; }.list-state strong { color: var(--m-ink); }.list-state--error { color: var(--m-danger); }.list-state--error strong { color: var(--m-danger); }.retry-button { display: inline-flex; min-height: 40px; align-items: center; gap: var(--m-space-2); padding: 0 var(--m-space-3); border: 1px solid currentColor; border-radius: var(--m-radius-sm); background: transparent; color: var(--m-danger); font: inherit; font-weight: 700; cursor: pointer; }
.clear-search:focus-visible, .thread-row:focus-visible, .retry-button:focus-visible, .search-field:focus-within { outline: 2px solid var(--m-primary-dark); outline-offset: 2px; }.thread-row:hover { background: var(--m-primary-soft); }.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }@media (prefers-reduced-motion: no-preference) { .thread-row { transition: background .15s ease; } }
</style>
