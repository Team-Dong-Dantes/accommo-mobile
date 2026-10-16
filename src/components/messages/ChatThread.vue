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

    <ChatComposer />
  </div>
</template>

<script setup lang="ts">
import ApplicationCard from '@/components/messages/ApplicationCard.vue'
import ChatComposer from './thread/ChatComposer.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import ListingPicker from '@/components/messages/ListingPicker.vue'
import MessageBubble from '@/components/messages/MessageBubble.vue'
import MessageMenu from '@/components/messages/MessageMenu.vue'
import PhotoViewer from '@/components/shared/PhotoViewer.vue'
import { openExternal } from '@/utils/openExternal'
import { provideChatThread } from './thread/chatThread'

// The thread's state lives in ./thread/; this component is its markup.
const props = defineProps<{ conversationId: string; role: 'manager' | 'student'; roomId?: string | undefined }>()
const emit = defineEmits<{ close: []; profile: [userId: string] }>()

const {
  openProfile,
  loading,
  loadingOlder,
  hasMore,
  error,
  pickerOpen,
  scroller,
  me,
  otherId,
  messages,
  other,
  listings,
  landlordId,
  menu,
  applicationCard,
  viewerUrl,
  grouped,
  replyOf,
  jumpTo,
  openListing,
  loadOlder,
  shareListing,
  openMenu,
  menuActions,
  onPick,
  onMenuReact,
  react,
  postSystemMessage,
} = provideChatThread({ props, emit })
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
</style>
