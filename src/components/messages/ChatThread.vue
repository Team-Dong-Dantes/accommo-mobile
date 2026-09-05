<template>
  <div class="chat">
    <header class="bar">
      <button type="button" class="bar-back" aria-label="Back to messages" @click="emit('close')">
        <IconifyIcon icon="lucide:arrow-left" width="20" />
      </button>
      <span class="bar-avatar">{{ other.initials }}</span>
      <span class="bar-id">
        <span class="bar-name">{{ other.name }}</span>
        <span class="bar-role">{{ other.role }}</span>
      </span>
    </header>

    <div v-if="application" class="app-card">
      <div class="app-card-body">
        <IconifyIcon icon="lucide:file-check-2" width="16" />
        <span class="app-card-text">Application for {{ application.roomLabel }}</span>
      </div>
      <div v-if="role === 'manager'" class="app-card-actions">
        <button type="button" class="app-btn app-btn--ghost" :disabled="deciding" @click="decideApplication('rejected')">
          Decline
        </button>
        <button type="button" class="app-btn" :disabled="deciding" @click="decideApplication('active')">
          Accept
        </button>
      </div>
      <span v-else class="app-card-status">Awaiting response</span>
    </div>

    <div v-else-if="applyRoom" class="app-card">
      <div class="app-card-body">
        <IconifyIcon icon="lucide:file-check-2" width="16" />
        <span class="app-card-text">{{ applyRoom.label }} · {{ formatPeso(applyRoom.rent) }}/mo</span>
      </div>
      <label class="app-field">
        <span class="app-field-label">Move-in date</span>
        <input v-model="applyForm.startDate" type="date" class="app-date" :min="todayStr()" />
      </label>
      <button type="button" class="app-btn app-btn--submit" :disabled="applying" @click="submitApplication">
        {{ applying ? 'Submitting…' : 'Submit application' }}
      </button>
    </div>

    <div v-else-if="applyUnavailable" class="app-card">
      <span class="app-card-text">This room is no longer available.</span>
    </div>

    <div ref="scroller" class="feed">
      <div v-if="loading" class="feed-note">Loading…</div>
      <div v-else-if="error" class="feed-note feed-note--bad">{{ error }}</div>
      <div v-else-if="!messages.length" class="feed-note">
        Say hello — this is the start of your conversation.
      </div>

      <template v-for="group in grouped" :key="group.day">
        <div class="day"><span>{{ group.day }}</span></div>
        <div
          v-for="msg in group.items"
          :key="msg.id"
          class="msg"
          :class="{ 'msg--mine': msg.mine, 'msg--pending': msg.pending }"
        >
          <span class="msg-bubble">{{ msg.body }}</span>
          <span class="msg-meta">
            {{ msg.time }}
            <IconifyIcon
              v-if="msg.mine"
              :icon="msg.pending ? 'lucide:clock' : msg.read ? 'lucide:check-check' : 'lucide:check'"
              width="13"
              :class="{ 'tick-read': msg.read }"
            />
          </span>
        </div>
      </template>
    </div>

    <form class="composer" @submit.prevent="send">
      <textarea
        v-model="outgoing"
        class="composer-input"
        rows="1"
        placeholder="Message…"
        :disabled="sending"
        @keydown.enter.exact.prevent="send"
      />
      <button
        type="submit"
        class="composer-send"
        :disabled="!outgoing.trim() || sending"
        aria-label="Send"
      >
        <IconifyIcon icon="lucide:send-horizontal" width="18" />
      </button>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, nextTick, onMounted, onUnmounted } from 'vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { initialsOf, parseServerTime, formatDate, formatPeso } from '@/utils/format'
import { useMessagesStore } from '@/stores/messages'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import { respondToApplication } from '@/utils/applications'

const props = defineProps<{ conversationId: string; role: 'manager' | 'student'; roomId?: string | undefined }>()
const emit = defineEmits<{ close: [] }>()

interface Msg {
  id: string
  body: string
  senderId: string
  sentAt: string
  status: string
  pending?: boolean
}

const store = useMessagesStore()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const sending = ref(false)
const outgoing = ref('')
const scroller = ref<HTMLElement | null>(null)
const me = ref('')
const otherId = ref('')
const messages = ref<Msg[]>([])
const other = reactive({ name: 'Conversation', initials: '?', role: '' })

interface RoomBrief { id: string; label: string; rent: number; minStay: number }
const application = ref<{ leaseId: string; roomLabel: string } | null>(null)
const applyRoom = ref<RoomBrief | null>(null)
const applyUnavailable = ref(false)
const applyForm = reactive({ startDate: todayStr() })
const applying = ref(false)
const deciding = ref(false)

let channel: RealtimeChannel | null = null

function todayStr(): string {
  return new Date().toISOString().slice(0, 10)
}

function addMonths(dateStr: string, months: number): string {
  const d = new Date(dateStr)
  d.setMonth(d.getMonth() + months)
  return d.toISOString().slice(0, 10)
}

const applyEndDate = computed(() => addMonths(applyForm.startDate || todayStr(), applyRoom.value?.minStay || 12))

const grouped = computed(() => {
  const out: { day: string; items: (Msg & { mine: boolean; read: boolean; time: string })[] }[] = []
  for (const m of messages.value) {
    const day = dayLabel(m.sentAt)
    let bucket = out[out.length - 1]
    if (!bucket || bucket.day !== day) {
      bucket = { day, items: [] }
      out.push(bucket)
    }
    bucket.items.push({
      ...m,
      mine: m.senderId === me.value,
      read: m.status === 'read',
      time: parseServerTime(m.sentAt).toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' }),
    })
  }
  return out
})

function dayLabel(iso: string) {
  const date = parseServerTime(iso)
  const start = new Date()
  start.setHours(0, 0, 0, 0)
  if (date.getTime() >= start.getTime()) return 'Today'
  if (date.getTime() >= start.getTime() - 86400000) return 'Yesterday'
  return date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
}

async function toBottom() {
  await nextTick()
  const el = scroller.value
  if (el) el.scrollTop = el.scrollHeight
}

async function send() {
  const body = outgoing.value.trim()
  if (!body || sending.value) return

  sending.value = true
  outgoing.value = ''

  // Optimistic: the bubble appears at once and is replaced by the row the
  // insert returns, so a slow network never looks like a dropped message.
  const tempId = `pending-${Date.now()}`
  messages.value.push({
    id: tempId,
    body,
    senderId: me.value,
    sentAt: new Date().toISOString(),
    status: 'sent',
    pending: true,
  })
  void toBottom()

  try {
    const { data, error: sendError } = await supabase
      .from('messages')
      .insert({ conversation_id: props.conversationId, sender_id: me.value, body })
      .select('id, body, sender_id, sent_at, status')
      .single()
    if (sendError) throw sendError

    const at = messages.value.findIndex((m) => m.id === tempId)
    const saved: Msg = {
      id: data.id,
      body: data.body,
      senderId: data.sender_id,
      sentAt: data.sent_at,
      status: data.status,
    }
    if (at !== -1) messages.value[at] = saved
  } catch (e) {
    messages.value = messages.value.filter((m) => m.id !== tempId)
    outgoing.value = body
    error.value = errorMessage(e, 'Message not sent.')
  } finally {
    sending.value = false
  }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) return
    me.value = user.id

    const { data: convo, error: convoError } = await supabase
      .from('conversations')
      // Must stay one literal for postgrest-js to type the result.
      // eslint-disable-next-line max-len
      .select('user_a_id,user_b_id,a:users!conversations_user_a_id_fkey(full_name,initials,role),b:users!conversations_user_b_id_fkey(full_name,initials,role)')
      .eq('id', props.conversationId)
      .maybeSingle()
    if (convoError) throw convoError

    if (convo) {
      const mine = convo.user_a_id === user.id
      otherId.value = mine ? convo.user_b_id : convo.user_a_id
      const person = (mine ? convo.b : convo.a) as unknown as {
        full_name: string | null
        initials: string | null
        role: string | null
      } | null
      other.name = person?.full_name || 'Conversation'
      other.initials = person?.initials || initialsOf(other.name)
      other.role = person?.role === 'accommodation_manager' ? 'Accommodation manager' : 'Student'
    }

    const { data: rows, error: rowsError } = await supabase
      .from('messages')
      .select('id, body, sender_id, sent_at, status')
      .eq('conversation_id', props.conversationId)
      .order('sent_at', { ascending: true })
      .limit(200)
    if (rowsError) throw rowsError

    messages.value = (rows ?? []).map((m) => ({
      id: m.id,
      body: m.body,
      senderId: m.sender_id,
      sentAt: m.sent_at,
      status: m.status,
    }))

    // Zeroes my counter and flips the other side's messages to read, which
    // reaches their device as a realtime UPDATE and lights their ticks.
    await supabase.rpc('mark_conversation_read', { p_conversation: props.conversationId })
    store.clearUnread(props.conversationId)

    void toBottom()
    void loadApplicationState()
  } catch (e) {
    error.value = errorMessage(e, 'Could not open this conversation.')
  } finally {
    loading.value = false
  }
}

/**
 * A student holds at most one non-terminal lease at a time, and there is one
 * conversation per (student, manager) pair — so the pending application "for
 * this thread", if any, is just the student's pending lease with this manager.
 */
async function loadApplicationState() {
  const studentId = props.role === 'student' ? me.value : otherId.value
  const managerId = props.role === 'student' ? otherId.value : me.value
  if (!studentId || !managerId) return

  const { data: pending } = await supabase
    .from('leases')
    .select('id,rooms(label,room_number)')
    .eq('student_id', studentId)
    .eq('accommodation_manager_id', managerId)
    .eq('status', 'pending')
    .maybeSingle()

  if (pending) {
    const r = pending.rooms as unknown as { label: string | null; room_number: string | null } | null
    application.value = {
      leaseId: pending.id,
      roomLabel: r?.label || (r?.room_number ? `Room ${r.room_number}` : 'this room'),
    }
    return
  }

  application.value = null
  if (props.roomId && props.role === 'student') await loadApplyRoom(props.roomId)
}

async function loadApplyRoom(roomId: string) {
  const { data } = await supabase
    .from('rooms')
    .select(
      'id,label,room_number,monthly_rent,status,accommodations(accommodation_manager_id,accommodation_policies(min_stay))',
    )
    .eq('id', roomId)
    .maybeSingle()

  const acc = data?.accommodations as unknown as {
    accommodation_manager_id: string | null
    accommodation_policies: unknown
  } | null

  if (!data || !acc || acc.accommodation_manager_id !== otherId.value || data.status !== 'available') {
    applyRoom.value = null
    applyUnavailable.value = Boolean(data)
    return
  }

  const policyRows = acc.accommodation_policies as unknown
  const policyRow = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as { min_stay: number | null } | null

  applyForm.startDate = todayStr()
  applyRoom.value = {
    id: data.id,
    label: data.label || (data.room_number ? `Room ${data.room_number}` : 'Room'),
    rent: Number(data.monthly_rent ?? 0),
    minStay: policyRow?.min_stay ?? 12,
  }
}

async function postSystemMessage(body: string) {
  const { data, error: sendError } = await supabase
    .from('messages')
    .insert({ conversation_id: props.conversationId, sender_id: me.value, body })
    .select('id, body, sender_id, sent_at, status')
    .single()
  if (sendError) throw sendError
  messages.value.push({
    id: data.id,
    body: data.body,
    senderId: data.sender_id,
    sentAt: data.sent_at,
    status: data.status,
  })
  void toBottom()
}

async function submitApplication() {
  if (applying.value || !applyRoom.value) return
  applying.value = true
  try {
    const { data: studentProfile } = await supabase
      .from('student_profiles')
      .select('osas_verified_at')
      .eq('user_id', me.value)
      .maybeSingle()
    if (!studentProfile?.osas_verified_at) {
      notify.warning('Get OSAS-verified before applying for a room.')
      return
    }

    const room = applyRoom.value
    const { data: created, error: insertError } = await supabase
      .from('leases')
      .insert({
        room_id: room.id,
        student_id: me.value,
        accommodation_manager_id: otherId.value,
        start_date: applyForm.startDate,
        end_date: applyEndDate.value,
        monthly_rent: room.rent,
        status: 'pending',
      })
      .select('id')
      .single()
    if (insertError) throw insertError

    void createNotification(
      otherId.value,
      'New application',
      `Applied for ${room.label}`,
      'lease',
      `/manager/messages?to=${me.value}`,
    )

    await postSystemMessage(`Applied for ${room.label} — move-in ${formatDate(applyForm.startDate)}.`)
    application.value = { leaseId: created.id, roomLabel: room.label }
    applyRoom.value = null
    notify.success('Application submitted.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your application.'))
  } finally {
    applying.value = false
  }
}

async function decideApplication(next: 'active' | 'rejected') {
  if (deciding.value || !application.value) return
  deciding.value = true
  try {
    const { leaseId, roomLabel } = application.value
    await respondToApplication(leaseId, otherId.value, roomLabel, next)
    await postSystemMessage(
      next === 'active' ? `Accepted your application for ${roomLabel}.` : `Declined your application for ${roomLabel}.`,
    )
    application.value = null
    notify.success(next === 'active' ? 'Application accepted.' : 'Application declined.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this application.'))
  } finally {
    deciding.value = false
  }
}

function listen() {
  if (typeof supabase.channel !== 'function') return
  channel = supabase
    .channel(`messages:${props.conversationId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'messages',
        filter: `conversation_id=eq.${props.conversationId}`,
      },
      (payload) => {
        if (payload.eventType === 'INSERT') {
          const row = payload.new as {
            id: string
            body: string
            sender_id: string
            sent_at: string
            status: string
          }
          if (messages.value.some((m) => m.id === row.id)) return
          messages.value.push({
            id: row.id,
            body: row.body,
            senderId: row.sender_id,
            sentAt: row.sent_at,
            status: row.status,
          })
          void toBottom()
          // Their message arrived while the thread is open, so it is read.
          if (row.sender_id !== me.value) {
            void supabase.rpc('mark_conversation_read', {
              p_conversation: props.conversationId,
            })
          }
        } else if (payload.eventType === 'UPDATE') {
          const row = payload.new as { id: string; status: string }
          const found = messages.value.find((m) => m.id === row.id)
          if (found) found.status = row.status
        }
      },
    )
    .subscribe()
}

onMounted(async () => {
  await load()
  listen()
})

onUnmounted(() => {
  if (channel) {
    void supabase.removeChannel(channel)
    channel = null
  }
})
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
.bar-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
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

.app-card {
  display: flex;
  flex: 0 0 auto;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 12px;
  padding: 10px var(--m-page-gutter);
  border-bottom: 1px solid var(--m-border);
  background: var(--m-primary-soft);
}
.app-card-body {
  display: flex;
  align-items: center;
  gap: 7px;
  color: var(--m-primary-dark);
}
.app-card-text {
  font-size: 12.5px;
  font-weight: 700;
}
.app-card-status {
  margin-left: auto;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.app-card-actions {
  display: flex;
  margin-left: auto;
  gap: 8px;
}
.app-field {
  display: flex;
  flex: 1 1 100%;
  align-items: center;
  gap: 8px;
}
.app-field-label {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.app-date {
  min-height: 36px;
  padding: 0 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13px;
}
.app-btn {
  min-height: 34px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.app-btn:disabled {
  opacity: 0.6;
}
.app-btn--ghost {
  background: var(--m-surface);
  color: var(--m-text);
  border: 1px solid var(--m-border);
}
.app-btn--submit {
  flex: 1 1 100%;
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

.msg {
  display: flex;
  max-width: 82%;
  flex-direction: column;
  align-items: flex-start;
  align-self: flex-start;
  gap: 2px;
}
.msg--mine {
  align-items: flex-end;
  align-self: flex-end;
}
.msg--pending {
  opacity: 0.65;
}
.msg-bubble {
  padding: 8px 12px;
  border: 1px solid var(--m-border);
  border-radius: 16px 16px 16px 4px;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 13.5px;
  line-height: 1.4;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.msg--mine .msg-bubble {
  border-color: transparent;
  border-radius: 16px 16px 4px 16px;
  background: var(--m-primary);
  color: #fff;
}
.msg-meta {
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 0 3px;
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 600;
}
.tick-read {
  color: var(--m-info);
}

.composer {
  display: flex;
  flex: 0 0 auto;
  align-items: flex-end;
  gap: 8px;
  padding: 8px var(--m-page-gutter) calc(8px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.composer-input {
  flex: 1 1 auto;
  max-height: 110px;
  min-height: 44px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: 22px;
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  line-height: 1.35;
  resize: none;
}
.composer-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.composer-send {
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.composer-send:disabled {
  opacity: 0.45;
}
</style>
