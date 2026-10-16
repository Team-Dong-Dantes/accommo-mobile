<template>
  <transition name="fcard">
    <div
      v-if="current"
      :key="current.key"
      class="fcard fcard--notice"
      role="status"
      @touchstart.passive="onTouchStart"
      @touchend="onTouchEnd"
    >
      <button type="button" class="fcard-main" @click="open">
        <span class="fcard-tile" :class="`fcard-tile--${look.tone}`">
          <IconifyIcon :icon="look.icon" width="17" />
        </span>
        <span class="fcard-text">
          <span class="fcard-top">
            <span class="fcard-title">{{ current.title }}</span>
            <span class="fcard-when">now</span>
          </span>
          <span class="fcard-body">{{ current.body }}</span>
        </span>
      </button>
    </div>
  </transition>
</template>

<script setup lang="ts">
import { computed, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { notices, dropNotice } from '@/utils/inAppNotice'
import { notifLook, resolveNotifLink } from '@/utils/notifications'
import { useNotificationsStore } from '@/stores/notifications'

// The card for utils/inAppNotice.ts: newest first, gone on its own after a few
// seconds, tap to open, swipe up to wave away. Shares the floating-card look
// (.fcard, app.scss) with the announcement banner beside it in the header, and
// sits above it when both are up — this one is the transient of the two.

const props = defineProps<{ role: 'manager' | 'student' }>()

/** Long enough to read a line, short enough not to sit over the page. */
const SHOW_MS = 5000

const route = useRoute()
const router = useRouter()

// A message for the conversation already open is not news: dropped, not just
// skipped, or it would sit in the queue and pop up long after.
watch(
  [notices, () => route.query.c],
  ([list, open]) => {
    for (const n of list) if (n.threadId && n.threadId === open) dropNotice(n.key)
  },
  { immediate: true },
)
const current = computed(() => notices.value.at(-1) ?? null)
const look = computed(() =>
  current.value?.threadId ? { icon: 'lucide:message-circle', tone: 'info' } : notifLook(current.value?.type),
)

let timer: ReturnType<typeof setTimeout> | undefined
watch(
  current,
  (n) => {
    clearTimeout(timer)
    if (n) timer = setTimeout(() => dropNotice(n.key), SHOW_MS)
  },
  { immediate: true },
)
onUnmounted(() => clearTimeout(timer))

function open() {
  const n = current.value
  if (!n) return
  dropNotice(n.key)
  if (n.notifId) void useNotificationsStore().markRead(n.notifId)
  const to = n.threadId
    ? `/${props.role}/messages?c=${n.threadId}`
    : resolveNotifLink(n.linkUrl, n.type, props.role, n.refId) ?? `/${props.role}/notifications`
  void router.push(to)
}

let startY = 0
function onTouchStart(e: TouchEvent) {
  startY = e.touches[0]?.clientY ?? 0
}
function onTouchEnd(e: TouchEvent) {
  const endY = e.changedTouches[0]?.clientY ?? startY
  if (current.value && startY - endY > 24) dropNotice(current.value.key)
}
</script>
