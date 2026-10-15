<template>
  <div class="wrap">
    <div v-if="store.loading && !store.ready" class="stack">
      <div v-for="n in 5" :key="n" class="thread">
        <q-skeleton type="circle" size="42px" />
        <span class="thread-body">
          <span class="thread-top">
            <q-skeleton type="text" width="45%" height="14px" />
            <q-skeleton type="text" width="28px" height="11px" />
          </span>
          <q-skeleton type="text" width="75%" height="12px" />
        </span>
      </div>
    </div>

    <div v-else-if="store.error && !store.threads.length" class="stack">
      <ErrorCard title="Couldn't load your messages" :detail="store.error" />
    </div>

    <EmptyState
      v-else-if="!store.threads.length"
      icon="lucide:message-circle"
      title="No conversations yet"
      :message="emptyMessage"
    />

    <EmptyState
      v-else-if="!visibleThreads.length"
      icon="lucide:search-x"
      title="Nothing matches"
      message="Try a different search or filter."
    />

    <div v-else class="stack">
      <button
        v-for="thread in visibleThreads"
        :key="thread.id"
        type="button"
        class="thread"
        :class="{ 'thread--menu': menu?.id === thread.id }"
        v-on="press.on(thread.id)"
        @click="!press.swallow() && emit('open', thread.id)"
      >
        <span class="thread-avatar" :class="thread.otherColor ? [`bg-${thread.otherColor}`, 'text-white'] : []">
          <img v-if="thread.otherAvatarUrl" :src="thread.otherAvatarUrl" alt="" class="thread-avatar-img" @error="thread.otherAvatarUrl = null" />
          <template v-else>{{ thread.otherInitials }}</template>
        </span>
        <span class="thread-body">
          <span class="thread-top">
            <span class="thread-name">{{ thread.otherName }}</span>
            <span class="thread-when">
              <IconifyIcon v-if="thread.muted" icon="lucide:bell-off" width="12" aria-label="Muted" />
              <IconifyIcon v-if="thread.pinned" icon="lucide:pin" width="12" aria-label="Pinned" />
              {{ since(thread.lastTime) }}
            </span>
          </span>
          <span class="thread-bottom">
            <span class="thread-last" :class="{ 'thread-last--none': !preview(thread).real }">
              {{ preview(thread).text }}
            </span>
            <span v-if="thread.unread" class="thread-badge">{{ thread.unread }}</span>
          </span>
        </span>
      </button>
    </div>

    <!-- Out to <body>, above the bottom nav and FAB, which outrank the page. -->
    <Teleport to="body">
      <div v-if="menu" class="thread-menu-layer">
        <MessageMenu :anchor="menu.rect" :actions="menuActions" @close="menu = null" @pick="onPick" />
      </div>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useMessagesStore, isArchived, type Thread, type ThreadPref } from '@/stores/messages'
import { since } from '@/utils/notifications'
import { longPress } from '@/utils/chat'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import MessageMenu, { type MenuAction } from '@/components/messages/MessageMenu.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'

const props = withDefaults(
  defineProps<{ emptyMessage: string; query?: string; filter?: 'all' | 'unread' | 'archived' }>(),
  { query: '', filter: 'all' },
)
const emit = defineEmits<{ open: [string] }>()

const store = useMessagesStore()
const notify = useNotify()

// Pin, mute and archive are each person's own; the other side never sees them.
const menu = ref<{ id: string; rect: DOMRect } | null>(null)
const press = longPress<string>((id, el) => {
  menu.value = { id, rect: el.getBoundingClientRect() }
})

const menuActions = computed<MenuAction[]>(() => {
  const t = store.threads.find((x) => x.id === menu.value?.id)
  if (!t) return []
  return [
    { key: 'pin', label: t.pinned ? 'Unpin' : 'Pin', icon: t.pinned ? 'lucide:pin-off' : 'lucide:pin' },
    { key: 'mute', label: t.muted ? 'Unmute' : 'Mute', icon: t.muted ? 'lucide:bell' : 'lucide:bell-off' },
    { key: 'archive', label: isArchived(t) ? 'Unarchive' : 'Archive', icon: 'lucide:archive' },
  ]
})

function onPick(key: string) {
  const t = store.threads.find((x) => x.id === menu.value?.id)
  menu.value = null
  if (!t) return
  const patch: ThreadPref =
    key === 'pin' ? { pinned: !t.pinned }
    : key === 'mute' ? { muted: !t.muted }
    : { archivedAt: isArchived(t) ? null : new Date().toISOString() }
  store.setPref(t.id, patch).catch((e: unknown) => notify.error(errorMessage(e, 'Could not update that conversation.')))
}

/**
 * What the inbox row says under the name.
 *
 * A photo carries no text, so conversations.last_message is empty for one — the
 * row used to read "No messages yet" on a thread that plainly had messages. The
 * wording has to be decided here rather than in the database, because "You sent
 * a photo" versus "Maria sent a photo" depends on who is looking, and the
 * column is shared by both participants.
 *
 * `send()` refuses a message with neither text nor a file, so an empty body with
 * a sender behind it can only have been an attachment. No extra flag needed.
 */
function preview(thread: Thread): { text: string; real: boolean } {
  if (thread.lastMessage) return { text: thread.lastMessage, real: true }
  if (!thread.lastSenderId) return { text: 'No messages yet', real: false }
  return {
    text: thread.lastSenderId === store.userId ? 'You sent a photo' : `${thread.otherName} sent a photo`,
    real: true,
  }
}

const visibleThreads = computed(() => {
  const q = props.query.trim().toLowerCase()
  return store.threads.filter((t) => {
    if (isArchived(t) !== (props.filter === 'archived')) return false
    if (props.filter === 'unread' && !t.unread) return false
    if (!q) return true
    return t.otherName.toLowerCase().includes(q) || t.lastMessage.toLowerCase().includes(q)
  })
})
</script>

<style scoped>
.wrap {
  min-height: 100%;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 3px;
  /* Clears the docked search, which sits on the FAB's baseline. */
  padding: 8px var(--m-page-gutter) 126px;
}
.sk {
  border-radius: var(--m-radius);
}
.card {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}

.thread {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 11px;
  padding: 10px 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.thread-avatar {
  display: grid;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.thread-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.thread-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 2px;
}
.thread-top,
.thread-bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.thread-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.thread--menu {
  border-color: var(--m-primary);
}
.thread-menu-layer {
  position: fixed;
  z-index: 3000;
}
.thread-when {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
}
.thread-last {
  min-width: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.thread-last--none {
  font-style: italic;
}
.thread-badge {
  display: grid;
  min-width: 20px;
  height: 20px;
  flex: 0 0 auto;
  place-items: center;
  padding: 0 6px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
}

</style>
