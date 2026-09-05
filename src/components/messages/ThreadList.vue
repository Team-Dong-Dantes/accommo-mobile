<template>
  <div class="wrap">
    <div v-if="store.loading && !store.ready" class="stack">
      <q-skeleton type="rect" height="64px" class="sk" />
      <q-skeleton type="rect" height="64px" class="sk" />
      <q-skeleton type="rect" height="64px" class="sk" />
    </div>

    <div v-else-if="store.error && !store.threads.length" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your messages</p>
        <p class="err-sub">{{ store.error }}</p>
      </q-card>
    </div>

    <div v-else-if="!store.threads.length" class="empty">
      <span class="empty-icon"><IconifyIcon icon="lucide:message-circle" width="26" /></span>
      <p class="empty-title">No conversations yet</p>
      <p class="empty-text">{{ emptyMessage }}</p>
    </div>

    <div v-else-if="!visibleThreads.length" class="empty">
      <span class="empty-icon"><IconifyIcon icon="lucide:search-x" width="26" /></span>
      <p class="empty-title">Nothing matches</p>
      <p class="empty-text">Try a different search or filter.</p>
    </div>

    <div v-else class="stack">
      <button
        v-for="thread in visibleThreads"
        :key="thread.id"
        type="button"
        class="thread"
        @click="emit('open', thread.id)"
      >
        <span class="thread-avatar">{{ thread.otherInitials }}</span>
        <span class="thread-body">
          <span class="thread-top">
            <span class="thread-name">{{ thread.otherName }}</span>
            <span class="thread-when">{{ since(thread.lastTime) }}</span>
          </span>
          <span class="thread-bottom">
            <span class="thread-last" :class="{ 'thread-last--none': !thread.lastMessage }">
              {{ thread.lastMessage || 'No messages yet' }}
            </span>
            <span v-if="thread.unread" class="thread-badge">{{ thread.unread }}</span>
          </span>
        </span>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useMessagesStore } from '@/stores/messages'
import { since } from '@/utils/notifications'

const props = withDefaults(
  defineProps<{ emptyMessage: string; query?: string; filter?: 'all' | 'unread' }>(),
  { query: '', filter: 'all' },
)
const emit = defineEmits<{ open: [string] }>()

const store = useMessagesStore()

const visibleThreads = computed(() => {
  const q = props.query.trim().toLowerCase()
  return store.threads.filter((t) => {
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
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
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
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
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
.thread-when {
  flex: 0 0 auto;
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

.empty {
  display: flex;
  min-height: 60vh;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 24px var(--m-page-gutter);
  text-align: center;
}
.empty-icon {
  display: grid;
  width: 54px;
  height: 54px;
  place-items: center;
  margin-bottom: 6px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary);
}
.empty-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
.empty-text {
  margin: 0;
  max-width: 280px;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}
</style>
