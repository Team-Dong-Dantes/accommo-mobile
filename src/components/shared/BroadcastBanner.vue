<template>
  <transition name="broadcast">
    <div v-if="current" class="broadcast" role="status">
      <button type="button" class="broadcast-main" @click="open">
        <span class="broadcast-icon"><IconifyIcon icon="lucide:megaphone" width="15" /></span>
        <span class="broadcast-text">
          <span class="broadcast-title">{{ current.title }}</span>
          <span class="broadcast-sub">{{ current.summary || current.body }}</span>
        </span>
        <span v-if="queue.length > 1" class="broadcast-count">{{ queue.length }}</span>
      </button>
      <button type="button" class="broadcast-x" aria-label="Dismiss" @click="dismiss">
        <IconifyIcon icon="lucide:x" width="15" />
      </button>
    </div>
  </transition>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { supabase } from '@/utils/supabase'

// Live OSAS/manager broadcasts, as a strip floating directly under the header
// rather than a toast: a notice worth publishing is worth more than eight
// seconds, and a banner can be dismissed deliberately instead of expiring while
// unread. It is absolutely positioned against the header, so it overlays the
// page instead of pushing it down — every screen keeps its own layout.
//
// Subscribed to the table, so publishing reaches an app that is already open
// instead of waiting for the next launch. Realtime applies RLS per subscriber,
// which is why the payload itself is ignored and the visible set is simply
// re-read: a row only becomes visible once it is live and aimed at this reader.
//
// Dismissals are remembered per device, so a notice shows until it is actually
// waved away and then stops nagging on every launch. The authoritative copy is
// the notification row, which stays in the bell either way.

const props = defineProps<{ role: 'manager' | 'student' }>()

type Broadcast = { id: string; title: string; body: string; summary: string | null }

const SEEN_KEY = 'accommo:seen-broadcasts'
/** Nobody works through a stack deeper than this in a banner. */
const LIMIT = 5

const router = useRouter()
const queue = ref<Broadcast[]>([])
const current = computed(() => queue.value[0] ?? null)

function readSeen(): string[] {
  try {
    return JSON.parse(localStorage.getItem(SEEN_KEY) ?? '[]') as string[]
  } catch {
    return []
  }
}

function writeSeen(ids: string[]) {
  try {
    localStorage.setItem(SEEN_KEY, JSON.stringify(ids))
  } catch {
    // Private mode: the banner simply comes back next launch.
  }
}

let channel: RealtimeChannel | null = null

async function refresh() {
  // RLS already limits this to live, in-date announcements aimed at this
  // reader — including the ones a manager sent to their own tenants — so there
  // is nothing to filter here beyond what has already been dismissed.
  const { data } = await supabase
    .from('announcements')
    .select('id, title, body, summary')
    .order('published_at', { ascending: false })
    .limit(LIMIT)

  const live = data ?? []
  const seen = new Set(readSeen())
  queue.value = live.filter((a) => !seen.has(a.id))
  // Only ids that are still live are kept, so the list cannot grow forever.
  writeSeen(readSeen().filter((id) => live.some((a) => a.id === id)))
}

onMounted(async () => {
  await refresh()

  // The demo/unconfigured client has no realtime; the banner still works, it
  // just waits for the next launch.
  if (typeof supabase.channel !== 'function') return
  channel = supabase
    .channel('announcements:live')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'announcements' }, () => {
      void refresh()
    })
    .subscribe()
})

onUnmounted(() => {
  if (channel) {
    void supabase.removeChannel(channel)
    channel = null
  }
})

function markSeen(id: string) {
  const seen = readSeen()
  if (!seen.includes(id)) writeSeen([...seen, id])
}

function dismiss() {
  const row = current.value
  if (!row) return
  markSeen(row.id)
  queue.value = queue.value.slice(1)
}

function open() {
  const row = current.value
  if (!row) return
  markSeen(row.id)
  queue.value = queue.value.slice(1)
  void router.push(`/${props.role}/announcement/${row.id}`)
}
</script>

<style scoped>
.broadcast {
  /* The header is fixed, so `top: 100%` parks this just under whichever header
     variant is on screen — main or sub-page — without contributing any height
     to it. The page below keeps its own layout and scrolls under the banner. */
  position: absolute;
  z-index: 1;
  top: 100%;
  right: 12px;
  left: 12px;
  display: flex;
  align-items: stretch;
  overflow: hidden;
  border: 1px solid color-mix(in srgb, var(--m-info) 30%, var(--m-border));
  border-radius: var(--m-radius);
  background: var(--m-info-soft);
  box-shadow: 0 6px 18px rgb(0 0 0 / 12%);
  -webkit-backdrop-filter: blur(12px) saturate(150%);
  backdrop-filter: blur(12px) saturate(150%);
}
.broadcast-main {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 9px;
  padding: 8px 10px;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.broadcast-icon {
  display: grid;
  width: 24px;
  height: 24px;
  flex: 0 0 24px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-info);
}
.broadcast-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.broadcast-title {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.broadcast-sub {
  overflow: hidden;
  color: var(--m-text);
  font-size: 11px;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.broadcast-count {
  flex: 0 0 auto;
  padding: 1px 7px;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-info);
  font-size: 10.5px;
  font-weight: 700;
}
.broadcast-x {
  display: grid;
  flex: 0 0 auto;
  padding: 0 10px;
  place-items: center;
  border: 0;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
}
.broadcast-enter-active,
.broadcast-leave-active { transition: opacity .18s ease, transform .18s ease; }
.broadcast-enter-from,
.broadcast-leave-to { opacity: 0; transform: translateY(-6px); }

@media (prefers-reduced-motion: reduce) {
  .broadcast-enter-active,
  .broadcast-leave-active { transition: none; }
}
</style>
