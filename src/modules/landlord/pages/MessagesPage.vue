<template>
  <q-page class="messages-page">
    <div class="messages-shell">
      <!-- HEADER + SEARCH -->
      <div class="msgs-header q-px-md">
        <div class="msgs-title">Messages</div>
        <div class="msgs-subtitle">{{ pendingInquiries }} pending inquiries</div>

        <q-input
          v-model="searchText"
          outlined
          dense
          class="msgs-search q-mt-md"
          placeholder="Search conversations..."
        >
          <template #prepend>
            <q-icon name="search" color="grey-6" />
          </template>
        </q-input>
      </div>

      <!-- CONVERSATION LIST -->
      <div class="msgs-list q-px-md q-mt-md">
        <q-card
          v-for="conv in filteredConversations"
          :key="conv.id"
          flat
          bordered
          class="conv-card"
          :class="conv.badge === 'Inquiring' ? 'conv-inquiring' : 'conv-current'"
          @click="openConversation(conv)"
        >
          <q-card-section class="row no-wrap items-start q-pa-md">
            <!-- AVATAR + INDICATORS -->
            <div class="avatar-wrap q-mr-md">
              <q-avatar size="52px" :color="conv.avatarColor" text-color="white" class="conv-avatar">
                {{ conv.initials }}
              </q-avatar>
              <span v-if="conv.active" class="active-dot" />
              <span v-if="conv.unread > 0" class="unread-badge">{{ conv.unread }}</span>
            </div>

            <!-- MESSAGE BODY -->
            <div class="col conv-body">
              <div class="row items-center justify-between no-wrap">
                <div class="row items-center no-wrap conv-head">
                  <span class="conv-name">{{ conv.name }}</span>
                  <span
                    class="conv-pill"
                    :class="conv.badge === 'Inquiring' ? 'pill-inquiring' : 'pill-current'"
                  >{{ conv.badge }}</span>
                </div>
                <span class="conv-time">{{ conv.timestamp }}</span>
              </div>

              <div
                class="conv-context"
                :class="conv.badge === 'Inquiring' ? 'context-inquiring' : 'context-current'"
              >{{ conv.context }}</div>

              <div class="conv-snippet" :class="conv.read ? 'snippet-read' : 'snippet-unread'">
                {{ conv.snippet }}
              </div>
            </div>
          </q-card-section>
        </q-card>

        <div v-if="filteredConversations.length === 0" class="empty-state">
          No conversations found
        </div>
      </div>
    </div>

  </q-page>
</template>

<script lang="ts">
import { ref } from 'vue'

interface Conversation {
  id: string
  initials: string
  avatarColor: string
  name: string
  badge: 'Inquiring' | 'Current'
  timestamp: string
  unread: number
  active: boolean
  context: string
  snippet: string
  read: boolean
}

// Module-level singleton: the read/unread state must survive tab switches and
// component remounts (the page is recreated on each navigation). Keeping the
// data here instead of inside setup means it is not re-seeded on every mount.
const conversations = ref<Conversation[]>([
  { id: 'c1', initials: 'MS', avatarColor: 'teal-9', name: 'Maria Santos', badge: 'Inquiring', timestamp: 'Just now', unread: 2, active: true, context: 'Inquiring - Pinzon Student Hub - Rm 101-A', snippet: 'Is the room still available this semester?', read: false },
  { id: 'c2', initials: 'CR', avatarColor: 'purple-6', name: 'Carlo Reyes', badge: 'Inquiring', timestamp: '2h ago', unread: 1, active: true, context: 'Inquiring - Pinzon Student Hub - Rm 203', snippet: 'Thank you! I will bring the requirements on Saturday.', read: false },
  { id: 'c3', initials: 'AV', avatarColor: 'orange-6', name: 'Ana Villanueva', badge: 'Inquiring', timestamp: 'Yesterday', unread: 0, active: false, context: 'Inquiring - ISU Gate Apartment - Unit 3B', snippet: 'Got it. See you then!', read: true },
  { id: 'c4', initials: 'BC', avatarColor: 'green-6', name: 'Ben Castillo', badge: 'Current', timestamp: '2d ago', unread: 0, active: false, context: 'Camarag View - Rm 05', snippet: 'Okay, I will reconsider and get back to you.', read: true },
  { id: 'c5', initials: 'LD', avatarColor: 'red-6', name: 'Lea Domingo', badge: 'Current', timestamp: '3d ago', unread: 0, active: false, context: 'Pinzon Student Hub - Rm 110', snippet: 'Thank you for the quick reply!', read: true },
])
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { useQuasar } from 'quasar'

const $q = useQuasar()

const searchText = ref('')

// Mock conversation data for the Messages inbox. Swap for a store or API
// fetch once the backend conversations table is ready to use.
const pendingInquiries = computed(
  () => conversations.value.filter((c) => c.badge === 'Inquiring').length,
)

const filteredConversations = computed(() => {
  const term = searchText.value.trim().toLowerCase()
  if (!term) return conversations.value
  return conversations.value.filter((c) =>
    [c.name, c.context, c.snippet].some((field) => field.toLowerCase().includes(term)),
  )
})

function openConversation(conv: Conversation) {
  if (conv.unread > 0) {
    conv.read = true
    conv.unread = 0
    $q.notify({ message: `Marked conversation with ${conv.name} as read`, color: 'teal-9', position: 'top' })
    return
  }
  $q.notify({ message: `Opening chat with ${conv.name} (mock)`, color: 'teal-9', position: 'top' })
}
</script>

<style scoped>
.messages-page {
  background: #f4f5f7;
  min-height: 100vh;
}

.messages-shell {
  padding-bottom: 96px;
}

.msgs-header {
  padding-top: 20px;
  padding-bottom: 8px;
}

.msgs-title {
  font-size: 28px;
  font-weight: 800;
  color: #111827;
}

.msgs-subtitle {
  font-size: 13px;
  color: #6B7280;
  margin-top: 2px;
}

.msgs-search {
  background: #FFFFFF;
  border-radius: 12px;
}

.msgs-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.conv-card {
  border-radius: 18px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.04);
  cursor: pointer;
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}

.conv-card:active {
  transform: scale(0.98);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.06);
}

.conv-inquiring {
  background: #FBF7FF;
  border: 1px solid #E9D8FD;
}

.conv-current {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.avatar-wrap {
  position: relative;
}

.conv-avatar {
  font-size: 16px;
  font-weight: 800;
}

.active-dot {
  position: absolute;
  right: 0;
  bottom: 2px;
  width: 14px;
  height: 14px;
  background: #22C55E;
  border: 2px solid #FFFFFF;
  border-radius: 50%;
}

.unread-badge {
  position: absolute;
  top: -4px;
  right: -4px;
  min-width: 18px;
  height: 18px;
  padding: 0 4px;
  background: #EF4444;
  color: #FFFFFF;
  border: 2px solid #FFFFFF;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}

.conv-body {
  min-width: 0;
}

.conv-head {
  gap: 8px;
}

.conv-name {
  font-size: 15px;
  font-weight: 800;
  color: #1F2937;
}

.conv-pill {
  font-size: 11px;
  font-weight: 700;
  padding: 3px 10px;
  border-radius: 999px;
}

.pill-inquiring {
  background: #F3E8FF;
  color: #7C3AED;
}

.pill-current {
  background: #D7F0EC;
  color: #00897B;
}

.conv-time {
  font-size: 11px;
  color: #9CA3AF;
  white-space: nowrap;
  margin-left: 8px;
}

.conv-context {
  font-size: 12px;
  font-weight: 600;
  margin-top: 4px;
}

.context-inquiring {
  color: #7C3AED;
}

.context-current {
  color: #6B7280;
}

.conv-snippet {
  font-size: 13px;
  margin-top: 3px;
  line-height: 1.4;
}

.snippet-unread {
  color: #374151;
}

.snippet-read {
  color: #9CA3AF;
}

.empty-state {
  text-align: center;
  color: #9CA3AF;
  font-size: 14px;
  padding: 32px 0;
}

@media (min-width: 768px) {
  .messages-shell {
    max-width: 760px;
    margin: 0 auto;
  }
}
</style>
