<template>
  <div class="mail">
    <header class="bar">
      <button type="button" class="bar-back" aria-label="Back to tickets" @click="emit('close')">
        <IconifyIcon icon="lucide:arrow-left" width="20" />
      </button>
      <span class="bar-title">Ticket</span>
      <span class="bar-chip" :class="`bar-chip--${statusColor(TICKET_STATUS, ticket.status)}`">
        {{ statusText(TICKET_STATUS, ticket.status) }}
      </span>
    </header>

    <div ref="scroller" class="scroll">
      <!-- Subject lives in the body, not the app bar: a permit subject line is
           often two lines long and the bar could only ellipsis it. -->
      <div class="head">
        <h1 class="head-subject">{{ ticket.subject || 'Untitled ticket' }}</h1>
        <p class="head-meta">#{{ shortId }} · {{ titleCase(ticket.category) }} · Opened {{ stamp(ticket.reportedAt) }}</p>
      </div>

      <div class="msgs">
        <article
          v-for="(e, i) in entries"
          :key="e.id"
          class="msg"
          :class="{ 'msg--pending': e.pending, 'msg--shut': !isOpen(e.id, i) }"
        >
          <button type="button" class="msg-top" :aria-expanded="isOpen(e.id, i)" @click="toggle(e.id, i)">
            <span class="msg-avatar" :class="e.mine ? 'msg-avatar--me' : 'msg-avatar--osas'">
              <IconifyIcon :icon="e.mine ? 'lucide:user' : 'lucide:shield-check'" width="15" />
            </span>
            <span class="msg-id">
              <span class="msg-who">{{ e.mine ? 'You' : 'OSAS' }}</span>
              <!-- Collapsed rows carry the first line of the body, the way a
                   mail client previews a quoted message. -->
              <span v-if="!isOpen(e.id, i)" class="msg-peek">{{ e.body }}</span>
            </span>
            <span class="msg-when">{{ e.pending ? 'Sending…' : stamp(e.createdAt) }}</span>
          </button>

          <template v-if="isOpen(e.id, i)">
            <p class="msg-body">{{ e.body }}</p>
            <div v-if="e.attachments.length" class="att">
              <button
                v-for="url in e.attachments"
                :key="url"
                type="button"
                class="att-item"
                @click="openFile(url)"
              >
                <img v-if="!isPdf(url)" :src="resolveAsset(url)" alt="" class="att-img" />
                <span v-else class="att-file"><IconifyIcon icon="lucide:file-text" width="18" /></span>
              </button>
            </div>
          </template>
        </article>

        <p v-if="loading" class="note">Loading replies…</p>
        <p v-else-if="!messages.length" class="note">
          OSAS has not replied yet. You can add more detail below.
        </p>
      </div>
    </div>

    <!-- Reply is docked to the bottom of the screen so it's reachable without
         scrolling the thread to its end. -->
    <form class="reply" @submit.prevent="send">
      <textarea
        v-model="draft"
        class="reply-input"
        rows="2"
        placeholder="Reply to OSAS…"
        :disabled="sending"
      />
      <div class="reply-actions">
        <button type="submit" class="reply-send" :disabled="!draft.trim() || sending">
          <IconifyIcon icon="lucide:send-horizontal" width="15" />
          {{ sending ? 'Sending…' : 'Send' }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, useTemplateRef } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { dayLabel, clockTime, statusText, statusColor, TICKET_STATUS } from '@/utils/format'
import { resolveAsset, isPdf } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'

/** The ticket fields both OSAS pages already hold for their list rows. */
export interface ThreadTicket {
  id: string
  subject: string
  description: string
  category: string
  status: string
  reportedAt: string
  photoUrls: string[]
}

const props = defineProps<{ ticket: ThreadTicket }>()
const emit = defineEmits<{ close: [] }>()

interface Msg {
  id: string
  body: string
  createdAt: string
  attachments: string[]
  mine: boolean
  pending?: boolean
}

const notify = useNotify()
const loading = ref(true)
const sending = ref(false)
const draft = ref('')
const messages = ref<Msg[]>([])
const scroller = useTemplateRef<HTMLElement>('scroller')

/** Ids the reader has hand-opened; the newest entry is open regardless. */
const unfolded = ref<string[]>([])

const shortId = computed(() => props.ticket.id.replace(/-/g, '').slice(0, 6).toUpperCase())

// The report and the replies are one list: it's the same kind of thing, and the
// collapsing rule below reads much worse split across two templates.
const entries = computed<Msg[]>(() => [
  {
    id: 'report',
    body: props.ticket.description || 'No description given.',
    createdAt: props.ticket.reportedAt,
    attachments: props.ticket.photoUrls ?? [],
    mine: true,
  },
  ...messages.value,
])

// Short threads stay fully open — folding two entries hides content and saves
// no scrolling. Past that only the newest is open, like a mail thread.
function isOpen(id: string, index: number) {
  if (entries.value.length <= 2) return true
  if (index === entries.value.length - 1) return true
  return unfolded.value.includes(id)
}

function toggle(id: string, index: number) {
  if (entries.value.length <= 2 || index === entries.value.length - 1) return
  const at = unfolded.value.indexOf(id)
  if (at === -1) unfolded.value.push(id)
  else unfolded.value.splice(at, 1)
}

function titleCase(value: string) {
  return value ? value.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) : 'Other'
}

/** Mail-style absolute stamp — "Today · 2:14 PM", "Sep 3, 2025 · 9:02 AM". */
function stamp(iso: string) {
  return `${dayLabel(iso)} · ${clockTime(iso)}`
}

function openFile(url: string) {
  if (url) window.open(resolveAsset(url), '_blank', 'noopener')
}

async function toBottom() {
  await nextTick()
  const el = scroller.value
  if (el) el.scrollTop = el.scrollHeight
}

async function load() {
  loading.value = true
  try {
    // RLS returns this ticket's public messages only — internal admin notes are
    // filtered in the database, not here.
    const { data, error } = await supabase
      .from('ticket_messages')
      .select('id, body, author_role, attachment_urls, created_at')
      .eq('ticket_id', props.ticket.id)
      .order('created_at', { ascending: true })
    if (error) throw error
    messages.value = (data ?? []).map((m) => ({
      id: m.id,
      body: m.body || '',
      createdAt: m.created_at,
      attachments: m.attachment_urls ?? [],
      mine: m.author_role !== 'agent',
    }))
  } catch (e) {
    notify.error(errorMessage(e, 'Could not load replies.'))
  } finally {
    loading.value = false
  }
}

async function send() {
  const body = draft.value.trim()
  if (!body || sending.value) return
  sending.value = true

  const tempId = `pending-${Date.now()}`
  messages.value.push({ id: tempId, body, createdAt: new Date().toISOString(), attachments: [], mine: true, pending: true })
  draft.value = ''
  await toBottom()

  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) throw new Error('Not signed in.')

    // author_role is constrained to 'student' | 'agent'; every reporter side —
    // student or accommodation manager — files under 'student'.
    const { error } = await supabase.from('ticket_messages').insert({
      ticket_id: props.ticket.id,
      author_id: user.id,
      author_role: 'student',
      body,
      is_internal: false,
    })
    if (error) throw error
    await load()
    await toBottom()
  } catch (e) {
    messages.value = messages.value.filter((m) => m.id !== tempId)
    draft.value = body
    notify.error(errorMessage(e, 'Could not send your reply.'))
  } finally {
    sending.value = false
  }
}

// Opens at the top like an email rather than scrolled to the newest message:
// the report itself is the part that needs re-reading, not the last reply.
// An OSAS reply lands in the open thread without reopening it — see
// utils/useLiveData.ts for the freshness policy this inherits.
useLiveData({
  key: () => `ticket:${props.ticket.id}`,
  load,
  watch: () => [{ table: 'ticket_messages', filter: `ticket_id=eq.${props.ticket.id}` }],
})
</script>

<style scoped>
.mail {
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
  gap: 8px;
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
.bar-title {
  flex: 1 1 auto;
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
}
.bar-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.bar-chip--amber,
.bar-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.bar-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.bar-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}

.scroll {
  flex: 1 1 auto;
  padding-bottom: 12px;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}

.head {
  padding: 16px var(--m-page-gutter) 12px;
}
.head-subject {
  margin: 0 0 4px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.28;
  overflow-wrap: anywhere;
}
.head-meta {
  margin: 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}

/* Flat full-width messages divided by hairlines — the width of the screen is
   the width of the body text, so a long report reads as a paragraph. */
.msgs {
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.msg {
  padding: 12px var(--m-page-gutter);
  border-bottom: 1px solid var(--m-border);
}
.msg--shut {
  padding-top: 8px;
  padding-bottom: 8px;
}
.msg--pending {
  opacity: 0.6;
}
.msg-top {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 8px;
  padding: 0;
  border: 0;
  background: transparent;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.msg--shut .msg-top {
  cursor: pointer;
}
.msg-avatar {
  display: grid;
  width: 26px;
  height: 26px;
  flex: 0 0 26px;
  place-items: center;
  border-radius: 999px;
}
.msg-avatar--osas {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.msg-avatar--me {
  background: var(--m-bg);
  color: var(--m-muted);
}
.msg-id {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
}
.msg-who {
  color: var(--m-ink);
  font-family: var(--m-font-body);
  font-size: 13px;
  font-weight: 700;
}
.msg-peek {
  overflow: hidden;
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.msg-when {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 11px;
  font-weight: 600;
}
.msg-body {
  margin: 6px 0 0 34px;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

.att {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: 10px 0 0 34px;
}
.att-item {
  display: block;
  width: 68px;
  height: 68px;
  padding: 0;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  cursor: pointer;
  overflow: hidden;
  -webkit-tap-highlight-color: transparent;
}
.att-img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.att-file {
  display: grid;
  width: 100%;
  height: 100%;
  place-items: center;
  color: var(--m-muted);
}

.note {
  margin: 0;
  padding: 12px var(--m-page-gutter);
  border-bottom: 1px solid var(--m-border);
  color: var(--m-muted);
  font-size: 12.5px;
}

.reply {
  flex: 0 0 auto;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.reply-input {
  display: block;
  width: 100%;
  max-height: 40vh;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  line-height: 1.45;
  resize: vertical;
}
.reply-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.reply-actions {
  display: flex;
  justify-content: flex-end;
  padding-top: 8px;
}
.reply-send {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.reply-send:disabled {
  opacity: 0.45;
}
</style>
