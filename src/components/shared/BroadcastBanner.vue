<template>
  <transition name="fcard">
    <div v-if="current" class="fcard broadcast" :class="{ 'fcard--stacked': queue.length > 1 }" role="status">
      <button type="button" class="fcard-main" @click="open">
        <span class="fcard-tile fcard-tile--primary"><IconifyIcon icon="lucide:megaphone" width="17" /></span>
        <span class="fcard-text">
          <span class="fcard-title">{{ current.title }}</span>
          <span class="fcard-body">{{ current.summary || current.body }}</span>
          <span class="fcard-meta">
            {{ current.accommodation_id ? current.accommodations?.name ?? 'Your accommodation' : 'OSAS' }}<template v-if="queue.length > 1"> · 1 of {{ queue.length }}</template>
          </span>
        </span>
      </button>
      <button type="button" class="fcard-x" aria-label="Dismiss" @click="dismiss">
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

type Broadcast = {
  id: string
  title: string
  body: string
  summary: string | null
  /** Null for an OSAS broadcast; a house notice names the house it is from. */
  accommodation_id: string | null
  accommodations: { name: string } | null
}

const SEEN_KEY = 'accommo:seen-broadcasts'
/** Nobody works through a stack deeper than this in a banner. */
const LIMIT = 5

const router = useRouter()
const queue = ref<Broadcast[]>([])
/** Resolved once from the cached session: refresh() runs on every realtime event. */
const me = ref('')
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
  // RLS limits this to live, in-date announcements aimed at this reader, so
  // there is nothing to filter here beyond what has already been dismissed —
  // except the reader's own notices. A landlord/landlady can read the announcements they
  // sent to their own house (they have to, to see their own list), and without
  // this the banner announced a landlord/landlady's notice back at them the moment they
  // pressed Send. The database fan-out has always skipped the author; only this
  // banner did not.
  let query = supabase
    .from('announcements')
    .select('id, title, body, summary, accommodation_id, accommodations(name)')
    .order('published_at', { ascending: false })
    .limit(LIMIT)
  if (me.value) query = query.neq('author_id', me.value)

  const { data } = await query

  const live = data ?? []
  const seen = new Set(readSeen())
  queue.value = live.filter((a) => !seen.has(a.id))
  // Only ids that are still live are kept, so the list cannot grow forever.
  writeSeen(readSeen().filter((id) => live.some((a) => a.id === id)))
}

onMounted(async () => {
  const { data: session } = await supabase.auth.getSession()
  me.value = session?.session?.user?.id ?? ''
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
