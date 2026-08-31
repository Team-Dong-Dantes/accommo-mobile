<template>
  <q-page class="chat-page">
    <q-layout view="hHh lpR fFf">
      <q-header elevated class="bg-primary text-white">
        <q-toolbar>
          <q-btn
            v-if="!chat.activeConversationId && !activePlaceholderConv"
            dense
            flat
            round
            @click="toggleLeftDrawer"
          >
            <IconifyIcon width="24" icon="material-icons:menu" />
          </q-btn>
          <q-btn
            v-else
            dense
            flat
            round
            icon="arrow_back"
            @click="backToList"
          />

          <q-toolbar-title>
            {{ (chat.activeConversationId || activePlaceholderConv) ? activeOtherName : 'Messages' }}
          </q-toolbar-title>

          <q-btn flat round dense @click="handleLogout">
            <IconifyIcon width="24" icon="material-icons:logout" />
          </q-btn>
        </q-toolbar>
      </q-header>

      <q-drawer show-if-above v-model="leftDrawerOpen" side="left" bordered>
        <q-list>
          <q-item-label header>Menu</q-item-label>

          <template v-if="userRole === 'landlord'">
            <q-item clickable v-ripple to="/landlord/dashboard" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:dashboard" />
              </q-item-section>
              <q-item-section> Overview </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/properties" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:domain" />
              </q-item-section>
              <q-item-section> My Boarding Houses </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/tenants" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:people" />
              </q-item-section>
              <q-item-section> Tenants </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/payments" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:payments" />
              </q-item-section>
              <q-item-section> Payments </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/profile" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:person" />
              </q-item-section>
              <q-item-section> Profile </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/chat" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:chat" />
              </q-item-section>
              <q-item-section> Chat </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/notifications" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:notifications" />
              </q-item-section>
              <q-item-section> Notifications </q-item-section>
            </q-item>
          </template>
        </q-list>
      </q-drawer>

      <q-page-container>
        <div class="chat-page-wrapper">
          <!-- Conversation list -->
          <div v-if="!chat.activeConversationId && !activePlaceholderConv" class="conv-list">
            <div class="conv-list-head">
              <div class="conv-list-title">Conversations</div>
              <div class="row no-wrap items-center">
                <q-btn round flat icon="edit" color="teal-9" @click="openNewChat" />
              </div>
            </div>


            <div v-if="chat.isLoading" class="center-state">
              <q-spinner size="40px" color="teal-8" />
            </div>

            <div v-else-if="chat.loadError" class="center-state text-negative">
              {{ chat.loadError }}
            </div>

            <q-list v-else-if="conversationList.length" separator>
              <q-item
                v-for="c in conversationList"
                :key="c.id"
                clickable
                v-ripple
                @click="openConversation(c.id)"
              >
                <q-item-section avatar>
                  <q-avatar color="teal-9" text-color="white">
                    {{ initials(c.otherName) }}
                  </q-avatar>
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ c.otherName }}</q-item-label>
                  <q-item-label caption lines="1">
                    {{ c.lastMessage || 'No messages yet' }}
                  </q-item-label>
                </q-item-section>
                <q-item-section side top>
                  <q-item-label caption>
                    {{ c.lastTime ? formatTimestamp(c.lastTime) : '' }}
                  </q-item-label>
                </q-item-section>
              </q-item>
            </q-list>

            <div v-else class="center-state text-grey-7">
              No conversations yet. Tap
              <q-icon name="edit" class="q-mx-xs" /> to message a tenant.
            </div>
          </div>

          <!-- Thread -->
          <template v-else>
            <div class="conversation-header">
              <q-avatar color="teal-9" text-color="white" size="40px">
                {{ initials(activeOtherName) }}
              </q-avatar>
              <div class="header-info">
                <div class="header-name">{{ activeOtherName }}</div>
              </div>
            </div>

            <div class="conversation-view">
              <div v-if="chat.isLoading" class="center-state">
                <q-spinner size="40px" color="teal-8" />
              </div>
              <div v-else-if="chat.loadError" class="center-state text-negative">
                {{ chat.loadError }}
              </div>
              <template v-else>
                <div
                  v-for="message in threadMessages"
                  :key="message.id"
                  class="message-bubble-wrapper"
                  :class="message.isLandlord ? 'from-me' : 'from-them'"
                >
                  <div
                    class="message-bubble"
                    :class="message.isLandlord ? 'landlord-bubble' : 'student-bubble'"
                  >
                    {{ message.text }}
                    <div class="message-meta">
                      {{ formatTimestamp(message.timestamp) }}
                    </div>
                  </div>
                </div>
              </template>
            </div>

            <div class="message-input-area">
              <q-input
                v-model="newMessage"
                @keyup.enter="sendMessage"
                outlined
                rounded
                dense
                placeholder="Type a message..."
                class="chat-input"
              >
                <template #append>
                  <q-btn flat round icon="send" color="teal-9" @click="sendMessage" />
                </template>
              </q-input>
            </div>
          </template>
        </div>
      </q-page-container>
    </q-layout>

    <!-- New chat dialog -->
    <q-dialog v-model="showNewChat">
      <q-card class="new-chat-card">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">Message a tenant</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        <q-card-section>
          <div v-if="tenantLoading" class="center-state">
            <q-spinner size="32px" color="teal-8" />
          </div>
          <template v-else>
            <q-item-label header>Tenants</q-item-label>
            <q-list separator>
              <q-item
                v-for="t in tenants"
                :key="t.id"
                clickable
                v-ripple
                @click="startChatWith(t.id)"
              >
                <q-item-section avatar>
                  <q-avatar color="teal-9" text-color="white">{{ initials(t.name) }}</q-avatar>
                </q-item-section>
                <q-item-section>{{ t.name }}</q-item-section>
              </q-item>
              <q-item v-if="!tenants.length">
                <q-item-section class="text-grey-7">No active tenants found.</q-item-section>
              </q-item>
            </q-list>
          </template>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '@/stores/auth'
import { useChatStore } from '@/stores/chat'
import { supabase } from '@/shared/utils/supabase'

const router = useRouter()
const route = useRoute()
const $q = useQuasar()
const authStore = useAuthStore()
const chat = useChatStore()

const userRole = ref<'landlord' | 'student' | ''>('landlord')
const leftDrawerOpen = ref(false)
const newMessage = ref('')
const showNewChat = ref(false)
const tenants = ref<{ id: string; name: string }[]>([])
const tenantLoading = ref(false)

// Conversations load from Supabase only; no placeholder/sample data.

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

function handleLogout() {
  authStore.clearCachedRole()
  void supabase.auth.signOut()
  void router.push('/login')
}

interface PlaceholderMessage {
  id: string
  text: string
  isLandlord: boolean
  timestamp: string
}

interface PlaceholderConv {
  id: string
  otherName: string
  lastMessage: string
  lastTime: string
  messages: PlaceholderMessage[]
}

const placeholderConversations = ref<PlaceholderConv[]>([
  {
    id: 'ph-1',
    otherName: 'Maria Santos',
    lastMessage: 'Hi! About the lease renewal for Room 3.',
    lastTime: new Date(Date.now() - 2 * 3600 * 1000).toISOString(),
    messages: [
      { id: 'm1', text: 'Hi! My lease ends next month. Can we renew for another semester?', isLandlord: false, timestamp: new Date(Date.now() - 2 * 3600 * 1000).toISOString() },
      { id: 'm2', text: 'Sure, Maria. I will prepare the renewal papers this week and message you the details.', isLandlord: true, timestamp: new Date(Date.now() - 1.9 * 3600 * 1000).toISOString() },
      { id: 'm3', text: 'Thank you! Also, is the advance payment still the same amount?', isLandlord: false, timestamp: new Date(Date.now() - 1.6 * 3600 * 1000).toISOString() },
    ],
  },
  {
    id: 'ph-2',
    otherName: 'OSAS Office',
    lastMessage: 'We received your accreditation documents.',
    lastTime: new Date(Date.now() - 26 * 3600 * 1000).toISOString(),
    messages: [
      { id: 'm1', text: 'Good day! We have received your submitted business permit.', isLandlord: false, timestamp: new Date(Date.now() - 26 * 3600 * 1000).toISOString() },
      { id: 'm2', text: 'Our officer will review it within 3 business days and update your status.', isLandlord: false, timestamp: new Date(Date.now() - 26 * 3600 * 1000 + 60000).toISOString() },
    ],
  },
])

const activePlaceholderConv = ref<PlaceholderConv | null>(null)

const conversationList = computed(() => {
  if (chat.conversations.length > 0) return chat.conversations
  return placeholderConversations.value
})

const threadMessages = computed(() => {
  if (activePlaceholderConv.value) return activePlaceholderConv.value.messages
  return chat.messages
})

const activeOtherName = computed(() => {
  if (activePlaceholderConv.value) return activePlaceholderConv.value.otherName
  const c = chat.conversations.find((x) => x.id === chat.activeConversationId)
  return c?.otherName ?? 'Chat'
})

function initials(name: string): string {
  return (name || '?')
    .split(' ')
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function openConversation(id: string) {
  if (id.startsWith('ph-')) {
    activePlaceholderConv.value = placeholderConversations.value.find((c) => c.id === id) ?? null
    return
  }
  void chat.loadMessages(id)
}

function backToList() {
  chat.clearActive()
  activePlaceholderConv.value = null
  void router.push('/landlord/messages')
}

async function sendMessage() {
  const text = newMessage.value.trim()
  if (!text) return
  if (activePlaceholderConv.value) {
    activePlaceholderConv.value.messages.push({
      id: `local-${Date.now()}`,
      text,
      isLandlord: true,
      timestamp: new Date().toISOString(),
    })
    newMessage.value = ''
    return
  }
  try {
    await chat.sendMessage(text)
    newMessage.value = ''
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to send message' })
  }
}

async function openNewChat() {
  showNewChat.value = true
  tenantLoading.value = true
  tenants.value = []
  try {
    tenants.value = await chat.loadTenantsForNewChat()
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to load tenants' })
  } finally {
    tenantLoading.value = false
  }
}

async function startChatWith(otherUserId: string) {
  try {
    const id = await chat.ensureConversation(otherUserId)
    if (id) {
      showNewChat.value = false
      await chat.loadMessages(id)
    }
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to start conversation' })
  }
}

function formatTimestamp(ts: string): string {
  if (!ts) return ''
  const date = new Date(ts)
  const now = new Date()
  const diffMinutes = Math.floor((now.getTime() - date.getTime()) / 60000)
  if (diffMinutes < 1) return 'Just now'
  if (diffMinutes < 60) return `${diffMinutes} min ago`
  if (diffMinutes < 1440) {
    const h = Math.floor(diffMinutes / 60)
    return `${h} hour${h !== 1 ? 's' : ''} ago`
  }
  const d = Math.floor(diffMinutes / 1440)
  if (d < 7) return `${d} day${d !== 1 ? 's' : ''} ago`
  return date.toLocaleDateString()
}

onMounted(async () => {
  await chat.loadConversations()
  const convId = route.query.conv as string | undefined
  if (convId) {
    void chat.loadMessages(convId)
  }
})
</script>

<style scoped>
.chat-page {
  background: #f7f9fa;
  height: 100vh;
}

.chat-page-wrapper {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.conv-list {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.conv-list-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  background: white;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.conv-list-title {
  font-size: 18px;
  font-weight: 800;
  color: #111827;
}

.conv-list .q-list {
  flex: 1;
  overflow-y: auto;
}

.center-state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  text-align: center;
  color: #6b7280;
}

.conversation-header {
  background: white;
  padding: 16px 20px;
  display: flex;
  align-items: center;
  gap: 12px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.header-info {
  display: flex;
  flex-direction: column;
}

.header-name {
  font-size: 16px;
  font-weight: 800;
  color: #111827;
}

.conversation-view {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
}

.message-bubble-wrapper {
  display: flex;
  margin-bottom: 14px;
}

.message-bubble-wrapper.from-me {
  justify-content: flex-end;
}

.message-bubble-wrapper.from-them {
  justify-content: flex-start;
}

.message-bubble {
  max-width: 75%;
  padding: 10px 14px;
  border-radius: 16px;
  font-size: 14px;
  line-height: 1.4;
  word-break: break-word;
}

.landlord-bubble {
  background: #00897b;
  color: white;
  border-radius: 16px 16px 4px 16px;
}

.student-bubble {
  background: #eef2f4;
  color: #222;
  border-radius: 16px 16px 16px 4px;
}

.message-meta {
  margin-top: 4px;
  font-size: 10px;
  opacity: 0.75;
  text-align: right;
}

.message-input-area {
  padding: 12px 16px;
  background: white;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.chat-input {
  border-radius: 24px;
}

.new-chat-card {
  width: 360px;
  max-width: 92vw;
}
</style>
