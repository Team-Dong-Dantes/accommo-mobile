<template>
  <q-page class="chat-page">
    <q-layout view="hHh lpR fFf">
      <q-header elevated class="bg-primary text-white">
        <q-toolbar>
          <q-btn dense flat round @click="toggleLeftDrawer">
            <IconifyIcon width="24" icon="material-icons:menu" />
          </q-btn>

          <q-toolbar-title>Messages</q-toolbar-title>

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
              <q-item-section> My Properties </q-item-section>
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
          <!-- Conversation Header -->
          <div class="conversation-header">
            <div class="header-avator">
              <q-avatar
                size="40"
                color="teal-9"
                text-color="white"
                font-size="20px"
              >
                {{ currentTenantName }}
              </q-avatar>
            </div>

            <div class="header-info">
              <div class="text-h6 text-weight-bold">{{ currentTenantName }}</div>
              <div class="text-subtitle2 text-grey-7">{{ currentTenantProperty }}</div>
            </div>

            <div class="header-actions">
              <q-btn
                flat
                round
                icon="info"
                color="teal-3"
                @click="showInquiryCard = true"
              />
            </div>
          </div>

          <!-- Message Input Area -->
          <div class="message-input-area q-bg-grey-1">
            <q-input
              v-model="newMessage"
              @keyup.enter="sendMessage"
              :counter="true"
              bordered
              :placeholder=" 'Type a message...' "
              class="chat-input"
              stand-alone
              inverted
            >
              <template #append>
                <q-btn
                  flat
                  size="sm"
                  icon="send"
                  color="teal-9"
                  @click="sendMessage"
                />
              </template>

              <template #prepend>
                <IconifyIcon icon="material-icons:forum" class="q-mr-sm" />
              </template>
            </q-input>
          </div>

          <!-- Quick Reply Suggestions -->
          <div
            v-if="quickReplies.length > 0"
            class="quick-replies-chip-area q-bg-white q-pa-md q-shadow-small"
          >
            <q-chip
              v-for="reply in quickReplies"
              :key="reply"
              color="teal-2"
              text-color="teal-9"
              @click="selectQuickReply(reply)"
            >
              {{ reply }}
            </q-chip>
          </div>

          <!-- Conversation View -->
          <div class="conversation-view" style="flex: 1;">
            <div
              v-for="message in messages"
              :key="message.id"
              class="message-bubble-wrapper"
            >
              <div
                v-if="message.isLandlord"
                class="message-bubble landlord-bubble"
              >
                {{ message.text }}
                <div class="message-meta">
                  {{ formatTimestamp(message.timestamp) }}
                </div>
              </div>

              <div
                v-else
                class="message-bubble student-bubble"
              >
                {{ message.text }}
                <div class="message-meta">
                  {{ formatTimestamp(message.timestamp) }}
                </div>
              </div>
            </div>

            <!-- System / Inquiry Card -->
            <div
              v-if="showInquiryCard"
              class="inquiry-card q-bg-white q-pa-md q-shadow-medium q-mt-4"
            >
              <div class="row items-center q-gutter-md">
                <div class="col-6">
                  <q-icon
                    name="material-icons:error_outline"
                    color="purple"
                    class="q-mr-sm"
                  />
                  <span>New Tenant Inquiry</span>
                </div>

                <div class="col-6 text-right">
                  <q-btn
                    flat
                    color="green"
                    label="Accept"
                    @click="acceptInquiry"
                  />
                  <q-btn
                    flat
                    color="red"
                    label="Decline"
                    @click="declineInquiry"
                  />
                </div>
              </div>

              <p class="q-mt-2 text-subtitle2 text-grey-7">
                {{ inquiryText }}
              </p>
            </div>
          </div>
        </div>
      </q-page-container>
    </q-layout>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '@/stores/auth'
import { useChatStore } from '@/stores/chat'
import { supabase } from '@/shared/utils/supabase'

const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()
const chatStore = useChatStore()

const userRole = ref<'landlord' | 'student' | ''>('landlord')
const leftDrawerOpen = ref(false)

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

function handleLogout() {
  authStore.clearCachedRole()
  void supabase.auth.signOut()
  void router.push('/login')
}

const newMessage = ref('')
const showInquiryCard = ref(false)
const inquiryText = 'A student would like to inquire about your available room.'

// Current tenant for the chat
const currentTenantName = computed(() => 'Maria Santos')
const currentTenantProperty = computed(() => 'Rose Dormitory, Unit 3A')

// Messages - loaded from store
const messages = ref(chatStore.messages)

// Quick replies
const quickReplies = ref([
  'How much is the monthly rate?',
  'When is the availability date?',
  'What are the house rules?',
  'Is OSAS verified?',
])

// Load messages on mount
onMounted(async () => {
  await chatStore.loadMessages()
  messages.value = chatStore.messages
})

// --- Methods ---

async function sendMessage() {
  if (!newMessage.value.trim()) return

  await chatStore.sendMessage(newMessage.value)
  newMessage.value = ''
  messages.value = chatStore.messages
}

function selectQuickReply(reply: string) {
  newMessage.value = reply
  // Auto-send after a brief delay or just populate the input
  $q.notify({
    message: `Quick reply selected: ${reply}`,
    position: 'top',
    color: 'grey-9',
    textColor: 'white',
    icon: 'lightbulb',
    iconColor: 'teal-4',
    classes: 'custom-notify',
  })
}

function acceptInquiry() {
  chatStore.acceptInquiry('inquiry-1')
  showInquiryCard.value = false
  messages.value = chatStore.messages
}

function declineInquiry() {
  chatStore.declineInquiry('inquiry-1')
  showInquiryCard.value = false
  messages.value = chatStore.messages
}

function formatTimestamp(ts: string): string {
  const date = new Date(ts)
  const now = new Date()
  const diffMinutes = Math.floor((now.getTime() - date.getTime()) / 60000)

  if (diffMinutes < 1) {
    return 'Just now'
  } else if (diffMinutes < 60) {
    return `${diffMinutes} min ago`
  } else if (diffMinutes < 1440) {
    const diffHours = Math.floor(diffMinutes / 60)
    return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`
  } else {
    const diffDays = Math.floor(diffMinutes / 1440)
    return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`
  }
}
</script>

<style scoped>
.chat-page {
  background: #F7F9FA;
}

.conversation-header {
  background: white;
  padding: 24px;
  border-radius: 24px 24px 0 0;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.header-avator {
  flex-shrink: 0;
}

.header-info {
  flex: 1;
  text-align: center;
  margin: 0 24px;
}

.header-info .text-h6 {
  margin: 4px 0;
}

.header-info .text-subtitle2 {
  color: #8b8b8b;
  font-size: 13px;
}

.header-actions {
  display: flex;
  align-items: center;
}

.message-input-area {
  padding: 0 24px;
  background: #F7F9FA;
  border-radius: 0 0 24px 24px;
}

.chat-input {
  border-radius: 24px;
  border: 1px solid #e2e8f0;
  height: 56px;
  font-size: 15px;
}

.chat-input .ql-toolbar.ql-snow,
.chat-input .ql-toolbar.ql-density .ql-toolbar-format {
  height: 32px !important;
}

.conversation-view {
  padding: 24px;
  max-height: calc(100vh - 200px);
  overflow-y: auto;
  flex: 1;
}

.message-bubble-wrapper {
  margin-bottom: 16px;
  display: flex;
  justify-content: flex-end;
  align-items: flex-end;
}

.message-bubble {
  max-width: 70%;
  padding: 12px 16px;
  border-radius: 16px 16px 4px 16px;
  font-size: 14px;
  line-height: 1.4;
  position: relative;
}

.student-bubble {
  background: #00897B;
  color: white;
  margin-left: auto;
  border-radius: 16px 16px 16px 4px;
}

.landlord-bubble {
  background: #F7F9FA;
  color: #222;
  margin-right: auto;
  border-radius: 16px 16px 16px 4px;
}

.message-meta {
  margin-top: 4px;
  font-size: 10px;
  color: #8b8b8b;
  text-align: right;
}

.inquiry-card {
  position: sticky;
  bottom: 0;
  background: white;
  border-radius: 24px 24px 0 0;
  padding: 24px;
  box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.05);
}

.inquiry-card .q-btn {
  margin-right: 8px;
}
</style>
