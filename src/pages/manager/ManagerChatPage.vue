<template>
  <q-page class="chat-page">
    <!-- No conversation selected state -->
    <div v-if="!chat.activeConversationId" class="no-conv">
      <div class="no-conv-icon">
        <IconifyIcon icon="lucide:message-square" width="40" aria-hidden="true" />
      </div>
      <strong>No chat selected</strong>
      <span>Select a tenant conversation to start messaging.</span>
      <button type="button" class="back-pill" @click="goToList">
        <IconifyIcon icon="lucide:chevron-left" width="18" aria-hidden="true" /> Back to Chats
      </button>
    </div>

    <!-- Active Messenger Conversation (Teal Theme) -->
    <main v-else class="messenger-chat-view" :aria-label="`Chat with ${activeOtherName}`">
      <!-- Messenger Header -->
      <header class="messenger-header">
        <button type="button" class="back-btn" aria-label="Back to messages" @click="goToList">
          <IconifyIcon icon="lucide:chevron-left" width="28" aria-hidden="true" />
        </button>
        
        <div class="header-user-info">
          <q-avatar size="38px" class="header-avatar">
            {{ initials(activeOtherName) }}
          </q-avatar>
          <div class="header-titles">
            <strong class="user-name">{{ activeOtherName }}</strong>
            <span class="user-subtitle">{{ activeOtherRole }}</span>
          </div>
        </div>

        <div class="header-actions">
          <button type="button" class="action-circle-btn" aria-label="Info">
            <IconifyIcon icon="lucide:info" width="20" aria-hidden="true" />
          </button>
        </div>
      </header>

      <!-- Scrollable Message Stack -->
      <q-scroll-area ref="scrollArea" class="messenger-scroll">
        <div v-if="chat.isLoading" class="chat-loading">
          <q-spinner-dots color="teal-8" size="32px" />
        </div>
        
        <div v-else-if="chat.loadError" class="chat-error">
          <IconifyIcon icon="lucide:alert-triangle" width="28" aria-hidden="true" />
          <span>{{ chat.loadError }}</span>
          <button type="button" class="retry-pill" @click="reloadThread">Retry</button>
        </div>

        <div v-else class="bubble-stack">
          <!-- Intro Profile Card -->
          <div class="chat-intro-banner">
            <q-avatar size="72px" class="intro-avatar">
              {{ initials(activeOtherName) }}
            </q-avatar>
            <h2 class="intro-name">{{ activeOtherName }}</h2>
            <span class="intro-meta">{{ activeOtherRole }} · Accommo Platform</span>
            <span class="intro-hint">You are connected on Accommo</span>
          </div>

          <template v-for="(msg, index) in threadMessages" :key="msg.id">
            <!-- Date Separator -->
            <div
              v-if="index === 0 || isDifferentDay(threadMessages[index - 1]?.timestamp, msg.timestamp)"
              class="messenger-date-pill"
            >
              {{ formatDay(msg.timestamp) }}
            </div>

            <!-- Message Row -->
            <div
              class="bubble-row"
              :class="{
                'bubble-row--mine': msg.isManager,
                'bubble-row--theirs': !msg.isManager,
                'bubble-row--seq': isSequence(index)
              }"
            >
              <!-- Their Avatar on cluster -->
              <q-avatar
                v-if="!msg.isManager"
                size="28px"
                class="sender-avatar"
                :class="{ 'sender-avatar--hidden': isFollowedByTheirs(index) }"
              >
                {{ initials(activeOtherName) }}
              </q-avatar>

              <div class="bubble-content-wrap">
                <article
                  class="messenger-bubble"
                  :class="{
                    'messenger-bubble--mine': msg.isManager,
                    'messenger-bubble--theirs': !msg.isManager,
                    'radius-bottom-right': msg.isManager && isFollowedByMine(index),
                    'radius-top-right': msg.isManager && isPrecededByMine(index),
                    'radius-bottom-left': !msg.isManager && isFollowedByTheirs(index),
                    'radius-top-left': !msg.isManager && isPrecededByTheirs(index),
                  }"
                >
                  <template v-if="!msg.isManager && applyPayload(msg)">
                    <div class="apply-card">
                      <div class="apply-card-head">
                        <span class="apply-card-icon" aria-hidden="true"><IconifyIcon icon="lucide:door-open" width="16" /></span>
                        <div>
                          <strong>Room request</strong>
                          <span>{{ (applyPayload(msg) || {}).label || 'Room' }}{{ (applyPayload(msg) || {}).propertyName ? ' · ' + (applyPayload(msg) || {}).propertyName : '' }}</span>
                        </div>
                      </div>
                      <p class="apply-card-body">{{ (applyPayload(msg) || {}).rent ? `${formatPesoInline((applyPayload(msg) || {}).rent || 0)} / month` : 'Rent: to discuss' }} · move-in on request</p>
                      <button type="button" class="apply-btn apply-btn--tenants" @click="goToTenants">
                        <IconifyIcon icon="lucide:users" width="15" /> View in Tenants
                      </button>
                    </div>
                  </template>
                  <p v-else class="bubble-text">{{ msg.text }}</p>
                </article>

                <!-- Status Indicator below message -->
                <div v-if="msg.isManager && index === threadMessages.length - 1" class="delivery-status">
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

      <!-- Messenger Composer -->
      <footer class="messenger-composer-bar">
        <form class="composer-form" @submit.prevent="submitMessage">
          <div class="input-pill">
            <textarea
              id="manager-chat-composer"
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
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { useChatStore } from '@/stores/chat'
import { supabase } from '@/shared/utils/supabase'
import { chatFullscreen } from '@/shared/utils/chatFullscreen'

const router = useRouter()
const route = useRoute()
const $q = useQuasar()
const chat = useChatStore()

const newMessage = ref('')
const sending = ref(false)
const scrollArea = ref<any>(null)

const activeOtherName = computed(() => {
  const c = chat.conversations.find((x) => x.id === chat.activeConversationId)
  return c?.otherName ?? 'Tenant'
})

const activeOtherRole = computed(() => {
  const c = chat.conversations.find((x) => x.id === chat.activeConversationId)
  return c?.otherRole ?? 'Tenant'
})

type ChatMessage = { id: string; text: string; isManager: boolean; timestamp: string; status: 'sent' | 'delivered' | 'read' }
const threadMessages = computed<ChatMessage[]>(() => chat.messages as ChatMessage[])

function initials(name: string): string {
  return (name || '?')
    .split(' ')
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function goToList() {
  void router.replace('/manager/messages')
}

function isDifferentDay(previous: string | undefined, current: string): boolean {
  return !previous || new Date(previous).toDateString() !== new Date(current).toDateString()
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
  const date = new Date(timestamp)
  if (isNaN(date.getTime())) return ''
  return date.toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' })
}

// Cluster helpers
function isSequence(index: number): boolean {
  if (index === 0) return false
  return threadMessages.value[index]?.isManager === threadMessages.value[index - 1]?.isManager
}
function isFollowedByMine(index: number): boolean {
  return threadMessages.value[index + 1]?.isManager === true
}
function isPrecededByMine(index: number): boolean {
  return threadMessages.value[index - 1]?.isManager === true
}
function isFollowedByTheirs(index: number): boolean {
  return threadMessages.value[index + 1]?.isManager === false
}
function isPrecededByTheirs(index: number): boolean {
  return threadMessages.value[index - 1]?.isManager === false
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

watch(() => threadMessages.value.length, () => {
  void scrollToBottom()
})

async function reloadThread() {
  if (!chat.activeConversationId) return
  await chat.loadMessages(chat.activeConversationId)
  void scrollToBottom(0)
  setTimeout(() => { void scrollToBottom(0) }, 60)
  setTimeout(() => { void scrollToBottom(0) }, 200)
}

async function submitMessage() {
  void sendMessage()
}

async function sendMessage(textOverride?: string) {
  const text = (typeof textOverride === 'string' ? textOverride : newMessage.value).trim()
  if (!text || sending.value || !chat.activeConversationId) return
  sending.value = true
  try {
    await chat.sendMessage(text)
    newMessage.value = ''
    void scrollToBottom()
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to send message' })
  } finally {
    sending.value = false
  }
}

function sendQuickLike() {
  void sendMessage('👍')
}

onMounted(async () => {
  chatFullscreen.value = true
  chat.onNewMessage = () => {
    void scrollToBottom()
  }
  if (!chat.conversations.length) {
    await chat.loadConversations()
  }
  const convId = (route.query.conv as string | undefined) || chat.activeConversationId
  if (convId) {
    await chat.loadMessages(convId)
    void scrollToBottom(0)
    setTimeout(() => { void scrollToBottom(0) }, 60)
    setTimeout(() => { void scrollToBottom(0) }, 200)
  }
})

onUnmounted(() => {
  chatFullscreen.value = false
  chat.clearActive()
})

// ---- Room application card (approve/decline in chat) ----
interface ApplyPayload { kind?: string; studentId?: string; roomId?: string; label?: string; propertyName?: string; rent?: number; startDate?: string; endDate?: string }

function applyPayload(msg: { text?: string }): ApplyPayload | null {
  const text = msg?.text || ''
  const marker = '@@apply@@\n'
  const at = text.indexOf(marker)
  if (at === -1) return null
  try {
    return JSON.parse(text.slice(at + marker.length).trim()) as ApplyPayload
  } catch {
    return null
  }
}

function formatPesoInline(value: number): string {
  return '₱' + (value || 0).toLocaleString('en-PH', { maximumFractionDigits: 0 })
}

function goToTenants() {
  void router.push('/manager/tenants')
}



</script>

<style scoped>
.chat-page {
  height: 100vh;
  background: #ffffff;
  color: #050505;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}

/* No-conversation fallback */
.no-conv {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  height: 100%;
  padding: 24px;
  color: #65676b;
  text-align: center;
}
.no-conv-icon {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: #f0f2f5;
  display: grid;
  place-items: center;
  color: #8a8d91;
}
.no-conv strong { color: #050505; font-size: 18px; }
.back-pill {
  margin-top: 8px;
  height: 38px;
  padding: 0 18px;
  border-radius: 19px;
  border: 0;
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  font-weight: 600;
  font-size: 14px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
}

/* Messenger Chat View */
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
.back-btn:hover { background: #f0f2f5; }

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
.action-circle-btn:hover { background: #f0f2f5; }

/* Scroll Area */
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

/* Chat Intro Profile Banner */
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
.bubble-row--mine { justify-content: flex-end; }
.bubble-row--theirs { justify-content: flex-start; }
.bubble-row--seq { margin-top: 1px; }

.sender-avatar {
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
  font-size: 10px;
  font-weight: 700;
  flex-shrink: 0;
  margin-bottom: 2px;
}
.sender-avatar--hidden { visibility: hidden; }

.bubble-content-wrap {
  display: flex;
  flex-direction: column;
  max-width: 72%;
}
.bubble-row--mine .bubble-content-wrap { align-items: flex-end; }
.bubble-row--theirs .bubble-content-wrap { align-items: flex-start; }

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

.bubble-text { margin: 0; }

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

/* Composer Bar */
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
.input-pill textarea::placeholder { color: #8a8d91; }

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

/* Room application card inside the chat */
.apply-card { min-width: 232px; max-width: 280px; }
.apply-card-head { display: flex; align-items: center; gap: 8px; }
.apply-card-icon { display: grid; width: 30px; height: 30px; flex: 0 0 auto; place-items: center; border-radius: 8px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.apply-card-head > div { display: flex; flex-direction: column; }
.apply-card-head strong { color: var(--m-ink); font-size: 13px; line-height: 1.2; }
.apply-card-head span { color: var(--m-muted); font-size: 11px; line-height: 1.3; }
.apply-card-body { margin: 8px 0 10px; color: var(--m-text); font-size: 12px; }
.apply-card-actions { display: flex; gap: 8px; }
.apply-btn { display: inline-flex; min-height: 34px; align-items: center; gap: 5px; padding: 0 10px; border: 0; border-radius: 8px; font-size: 12px; font-weight: 800; cursor: pointer; }
.apply-btn--accept { background: var(--m-success, #15803d); color: #fff; }
.apply-btn--decline { background: var(--m-surface); border: 1px solid var(--m-border); color: var(--m-danger); }
.apply-card-outcome { margin: 0; color: var(--m-muted); font-size: 12px; font-weight: 600; }

</style>
