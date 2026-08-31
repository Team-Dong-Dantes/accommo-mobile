<template>
  <q-page class="bg-grey-1 q-pb-md">
    <!-- Conversation list view -->
    <div v-if="!activeConversation" class="q-pa-md">
      <div class="row items-center justify-between">
        <div>
          <div class="text-h4 text-weight-bold" style="letter-spacing: -0.5px">Messages</div>
          <div class="text-grey-6 q-mb-md">Landlord conversations</div>
        </div>
        <q-btn
          unelevated color="teal-8" icon="edit" label="New"
          class="rounded-borders text-weight-bold" no-caps @click="startNewConversation"
        />
      </div>

      <template v-if="loading">
        <q-skeleton type="rect" height="64px" v-for="i in 3" :key="i" class="q-mb-sm" style="border-radius:14px" />
      </template>

      <template v-else-if="error">
        <div class="text-negative text-center q-py-xl">{{ error }}</div>
      </template>

      <template v-else>
        <div v-if="conversations.length === 0" class="text-center text-grey-6 q-py-xl">
          <q-icon name="forum" size="48px" color="grey-4" />
          <div class="text-subtitle2 text-weight-medium q-mt-sm">No conversations yet</div>
          <div class="text-caption q-mt-xs">Your messages with landlords will appear here.</div>
        </div>

        <q-list v-else class="bg-white custom-card" bordered separator>
          <q-item
            v-for="chat in conversations"
            :key="chat.id"
            clickable v-ripple class="q-py-md"
            @click="openConversation(chat.id)"
          >
            <q-item-section avatar>
              <q-avatar :color="chat.avatarColor" text-color="white" size="48px">{{ chat.initials }}</q-avatar>
              <q-badge v-if="chat.unread" color="teal-8" floating rounded>{{ chat.unread }}</q-badge>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ chat.name }}</q-item-label>
              <q-item-label caption>{{ chat.lastMessage || 'Start a conversation' }}</q-item-label>
            </q-item-section>
            <q-item-section side top>
              <q-item-label caption>{{ chat.time }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </template>
    </div>

    <!-- Chat window -->
    <div v-else class="column" style="height: calc(100vh - 50px);">
      <!-- Chat header -->
      <div class="row items-center q-pa-sm bg-white" style="border-bottom: 1px solid #eee;">
        <q-btn flat round dense icon="arrow_back" @click="activeConversation = null" />
        <q-avatar :color="activeChat.avatarColor" text-color="white" size="40px" class="q-ml-sm">{{ activeChat.initials }}</q-avatar>
        <div class="q-ml-sm">
          <div class="text-subtitle2 text-weight-bold">{{ activeChat.name }}</div>
        </div>
      </div>

      <!-- Messages -->
      <q-scroll-area ref="scrollArea" class="col" style="flex:1;">
        <div class="q-pa-md">
          <div v-if="messagesLoading" class="text-center q-py-xl">
            <q-spinner color="teal-8" size="32px" />
          </div>
          <template v-else>
            <div v-if="messages.length === 0" class="text-center text-grey-6 q-py-xl">
              No messages yet. Say hello!
            </div>
            <div v-for="(msg, i) in messages" :key="msg.id">
              <!-- Date divider (optional) -->
              <div class="row justify-center q-my-sm" v-if="i === 0 || dayDiff(messages[i-1]?.sentAt, msg.sentAt)">
                <div class="text-caption text-grey-6 q-px-sm q-py-xs" style="background:#eee;border-radius:10px;">
                  {{ formatDay(msg.sentAt) }}
                </div>
              </div>
              <div class="row" :class="msg.isMine ? 'justify-end' : 'justify-start'">
                <div
                  class="q-pa-sm q-mb-xs message-bubble"
                  :class="msg.isMine ? 'bubble-mine' : 'bubble-theirs'"
                  style="max-width:75%"
                >
                  <div class="text-body2">{{ msg.body }}</div>
                  <div class="text-caption" style="font-size:10px;opacity:0.7;text-align:right">
                    {{ formatTime(msg.sentAt) }}
                  </div>
                </div>
              </div>
            </div>
          </template>
        </div>
      </q-scroll-area>

      <!-- Composer -->
      <div class="row items-center q-pa-sm bg-white" style="border-top: 1px solid #eee;">
        <q-input
          v-model="newMessage"
          dense
          outlined
          rounded
          placeholder="Type a message..."
          class="col"
          bg-color="white"
          @keyup.enter="sendMessage"
        />
        <q-btn
          unelevated round color="teal-8" icon="send"
          class="q-ml-sm" :disable="!newMessage.trim() || sending"
          @click="sendMessage"
        />
      </div>
    </div>

    <!-- New Conversation Dialog -->
    <q-dialog v-model="newConvoDialog" position="bottom">
      <q-card class="dialog-card full-width">
        <q-card-section class="row items-center justify-between">
          <div class="text-subtitle1 text-weight-bold">New Message</div>
          <q-btn flat round dense icon="close" @click="newConvoDialog = false" />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <div class="text-caption text-grey-6 q-mb-sm">Choose who to message</div>
          <template v-if="newConvoLoading">
            <div class="text-center q-py-md"><q-spinner color="teal-8" size="24px" /></div>
          </template>
          <template v-else-if="landlords.length === 0">
            <div class="text-center text-grey-6 q-py-md">No landlords available to message.</div>
          </template>
          <template v-else>
            <q-list>
              <q-item
                v-for="l in landlords"
                :key="l.id"
                clickable v-ripple
                @click="startChatWith(l.id, l.name)"
              >
                <q-item-section avatar>
                  <q-avatar color="teal-8" text-color="white">{{ initialsOf(l.name) }}</q-avatar>
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-weight-medium">{{ l.name }}</q-item-label>
                  <q-item-label caption>Landlord</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </template>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue';
import { useRoute } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';

interface ConversationRow {
  id: string;
  user_a_id: string;
  user_b_id: string;
  last_message: string | null;
  last_time: string | null;
  unread_a: number;
  unread_b: number;
}

interface ConversationItem {
  id: string;
  name: string;
  initials: string;
  avatarColor: string;
  lastMessage: string;
  time: string;
  unread: number;
  otherUserId: string;
}

interface MessageRow {
  id: string;
  conversation_id: string;
  sender_id: string;
  body: string;
  sent_at: string;
}

interface MessageItem {
  id: string;
  body: string;
  sentAt: string;
  isMine: boolean;
}

const $q = useQuasar();
const route = useRoute();

const loading = ref(true);
const error = ref<string | null>(null);
const conversations = ref<ConversationItem[]>([]);
const currentUserId = ref<string | null>(null);

// Chat state
const activeConversation = ref<string | null>(null);
const activeChat = ref<ConversationItem>({ id: '', name: '', initials: '', avatarColor: '', lastMessage: '', time: '', unread: 0, otherUserId: '' });
const messages = ref<MessageItem[]>([]);
const messagesLoading = ref(false);
const newMessage = ref('');
const sending = ref(false);

// New conversation state
const newConvoDialog = ref(false);
const newConvoLoading = ref(false);
const landlords = ref<{ id: string; name: string }[]>([]);

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'U';
  if (parts.length === 1) return (parts[0] ?? '').slice(0, 2).toUpperCase();
  return ((parts[0]?.[0] ?? '') + (parts[parts.length - 1]?.[0] ?? '')).toUpperCase();
}

async function fetchUserName(id: string): Promise<string> {
  const { data } = await supabase.from('users').select('full_name, role').eq('id', id).maybeSingle();
  const u = data as unknown as { full_name: string | null; role: string | null } | null;
  return u?.full_name ?? (u?.role === 'landlord' ? 'Landlord' : 'Unknown');
}

async function loadConversations() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    currentUserId.value = user.id;

    const { data, error: queryError } = await supabase
      .from('conversations')
      .select('id, user_a_id, user_b_id, last_message, last_time, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
      .order('last_time', { ascending: false });

    if (queryError) throw queryError;

    const rows = (data ?? []) as unknown as ConversationRow[];

    // Resolve the other participant's name for each conversation
    const items: ConversationItem[] = [];
    for (const c of rows) {
      const otherId = c.user_a_id === user.id ? c.user_b_id : c.user_a_id;
      const unread = c.user_a_id === user.id ? c.unread_a : c.unread_b;
      const name = await fetchUserName(otherId);
      items.push({
        id: c.id,
        name,
        initials: initialsOf(name),
        avatarColor: 'teal-8',
        lastMessage: c.last_message ?? '',
        time: c.last_time ? new Date(c.last_time).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) : '',
        unread,
        otherUserId: otherId,
      });
    }
    conversations.value = items;
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load messages';
    conversations.value = [];
  } finally {
    loading.value = false;
  }
}

async function openConversation(id: string) {
  const chat = conversations.value.find((c) => c.id === id);
  if (!chat) return;
  activeChat.value = chat;
  activeConversation.value = id;
  messagesLoading.value = true;

  const { data, error: msgError } = await supabase
    .from('messages')
    .select('id, conversation_id, sender_id, body, sent_at')
    .eq('conversation_id', id)
    .order('sent_at', { ascending: true });

  if (msgError) {
    $q.notify({ message: msgError.message, color: 'negative', position: 'top' });
  }

  const rows = (data ?? []) as unknown as MessageRow[];
  messages.value = rows.map((m) => ({
    id: m.id,
    body: m.body,
    sentAt: m.sent_at,
    isMine: m.sender_id === currentUserId.value,
  }));

  messagesLoading.value = false;
  scrollToBottom();

  // Mark this conversation as read for the current user.
  if (currentUserId.value) {
    const me = currentUserId.value;
    const { data: convo } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id')
      .eq('id', id)
      .maybeSingle();
    if (convo) {
      const c = convo as unknown as { user_a_id: string; user_b_id: string };
      if (c.user_a_id === me) {
        await supabase.from('conversations').update({ unread_a: 0 }).eq('id', id);
      } else {
        await supabase.from('conversations').update({ unread_b: 0 }).eq('id', id);
      }
      const idx = conversations.value.findIndex((x) => x.id === id);
      const existing = conversations.value[idx];
      if (idx >= 0 && existing) conversations.value[idx] = { ...existing, unread: 0 };
    }
  }
}

async function sendMessage() {
  const body = newMessage.value.trim();
  if (!body || !activeConversation.value || !currentUserId.value) return;

  const convoId = activeConversation.value;
  const me = currentUserId.value;
  sending.value = true;
  try {
    const { error: insertError } = await supabase.from('messages').insert({
      conversation_id: convoId,
      sender_id: me,
      body,
    });
    if (insertError) throw insertError;

    // Keep the parent conversation's preview in sync and notify the recipient.
    const { data: convo } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id, unread_a, unread_b')
      .eq('id', convoId)
      .maybeSingle();
    const nowDate = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const now = `${nowDate.getFullYear()}-${pad(nowDate.getMonth() + 1)}-${pad(nowDate.getDate())}T${pad(nowDate.getHours())}:${pad(nowDate.getMinutes())}:${pad(nowDate.getSeconds())}`;
    if (convo) {
      const c = convo as unknown as { user_a_id: string; user_b_id: string; unread_a: number; unread_b: number };
      if (c.user_a_id === me) {
        await supabase
          .from('conversations')
          .update({ last_message: body, last_time: now, unread_b: (c.unread_b ?? 0) + 1 })
          .eq('id', convoId);
      } else {
        await supabase
          .from('conversations')
          .update({ last_message: body, last_time: now, unread_a: (c.unread_a ?? 0) + 1 })
          .eq('id', convoId);
      }
    } else {
      await supabase.from('conversations').update({ last_message: body, last_time: now }).eq('id', convoId);
    }

    // Notify the other participant so the recipient gets an in-app notification.
    const { data: convoInfo } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id')
      .eq('id', convoId)
      .maybeSingle();
    if (convoInfo) {
      const ci = convoInfo as unknown as { user_a_id: string; user_b_id: string };
      const otherId = ci.user_a_id === me ? ci.user_b_id : ci.user_a_id;
      if (otherId) {
        await supabase.from('notifications').insert({
          id: crypto.randomUUID(),
          user_id: otherId,
          title: 'New message',
          body,
          type: 'message',
          read_at: null,
        } as any);
      }
    }

    // Reflect the reply in the local conversation list immediately.
    const timeLabel = new Date().toLocaleDateString('en-PH', { month: 'short', day: 'numeric' });
    const idx = conversations.value.findIndex((c) => c.id === convoId);
    const item = conversations.value[idx];
    if (idx >= 0 && item) {
      const updated: ConversationItem = { ...item, lastMessage: body, time: timeLabel, unread: 0 };
      conversations.value.splice(idx, 1);
      conversations.value.unshift(updated);
    }

    newMessage.value = '';

    // Refresh the message thread
    const { data } = await supabase
      .from('messages')
      .select('id, conversation_id, sender_id, body, sent_at')
      .eq('conversation_id', convoId)
      .order('sent_at', { ascending: true });

    const rows = (data ?? []) as unknown as MessageRow[];
    messages.value = rows.map((m) => ({
      id: m.id,
      body: m.body,
      sentAt: m.sent_at,
      isMine: m.sender_id === me,
    }));

    scrollToBottom();
  } catch (e) {
    $q.notify({
      message: e instanceof Error ? e.message : 'Failed to send',
      color: 'negative',
      position: 'top',
    });
  } finally {
    sending.value = false;
  }
}

function dayDiff(a: string | undefined, b: string): boolean {
  if (!a) return true;
  const da = new Date(a).toDateString();
  const db = new Date(b).toDateString();
  return da !== db;
}

function formatDay(ts: string): string {
  const d = new Date(ts);
  const today = new Date().toDateString();
  const yday = new Date(Date.now() - 86400000).toDateString();
  if (d.toDateString() === today) return 'Today';
  if (d.toDateString() === yday) return 'Yesterday';
  return d.toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' });
}

function formatTime(ts: string): string {
  return new Date(ts).toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' });
}

const scrollArea = ref<{ setScrollPosition: (v: number) => void } | null>(null);
async function scrollToBottom() {
  await nextTick();
  scrollArea.value?.setScrollPosition(10000);
}

async function startNewConversation() {
  newConvoDialog.value = true;
  newConvoLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('users')
      .select('id, full_name')
      .eq('role', 'landlord');

    if (error) throw error;

    const rows = (data ?? []) as unknown as Array<{ id: string; full_name: string | null }>;
    landlords.value = rows.map((u) => ({ id: u.id, name: u.full_name ?? 'Landlord' }));
  } catch {
    landlords.value = [];
  } finally {
    newConvoLoading.value = false;
  }
}

// Find an existing conversation with the given user, or create one.
async function ensureConversation(otherUserId: string): Promise<string | null> {
  if (!currentUserId.value) return null;
  const me = currentUserId.value;

  // Look for an existing conversation
  const { data: existing } = await supabase
    .from('conversations')
    .select('id')
    .or(`and(user_a_id.eq.${me},user_b_id.eq.${otherUserId}),and(user_a_id.eq.${otherUserId},user_b_id.eq.${me})`)
    .limit(1);

  if (existing && (existing as unknown[]).length > 0) {
    const first = (existing as unknown as { id: string }[])[0];
    if (first) return first.id;
  }

  // Otherwise create one
  const { data: created, error } = await supabase
    .from('conversations')
    .insert({
      user_a_id: me,
      user_b_id: otherUserId,
      last_message: null,
      last_time: new Date().toISOString(),
      unread_a: 0,
      unread_b: 0,
    })
    .select('id')
    .single();

  if (error) throw error;
  return (created as { id: string }).id;
}

async function startChatWith(otherUserId: string, name: string) {
  newConvoDialog.value = false;
  try {
    const convoId = await ensureConversation(otherUserId);
    if (!convoId) return;

    // Refresh the conversation list and open the chat
    await loadConversations();
    activeChat.value = {
      id: convoId,
      name,
      initials: initialsOf(name),
      avatarColor: 'teal-8',
      lastMessage: '',
      time: '',
      unread: 0,
      otherUserId,
    };
    activeConversation.value = convoId;
    messages.value = [];
    messagesLoading.value = false;
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to start chat', color: 'negative', position: 'top' });
  }
}

async function handleLandlordQuery() {
  const lid = route.query.landlord as string | undefined;
  if (!lid) return;

  const { data } = await supabase.from('users').select('full_name').eq('id', lid).maybeSingle();
  const name = (data as unknown as { full_name: string | null } | null)?.full_name ?? 'Landlord';
  await startChatWith(lid, name);
}

onMounted(async () => {
  await loadConversations();
  await handleLandlordQuery();
});
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.dialog-card {
  border-radius: 20px 20px 0 0;
}

.message-bubble {
  border-radius: 16px;
}

.bubble-mine {
  background: #00897b;
  color: white;
  border-bottom-right-radius: 4px;
}

.bubble-theirs {
  background: white;
  color: #333;
  border-bottom-left-radius: 4px;
}
</style>
