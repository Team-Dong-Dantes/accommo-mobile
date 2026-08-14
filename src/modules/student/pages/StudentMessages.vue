<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <div class="text-h4 text-weight-bold" style="letter-spacing: -0.5px">Messages</div>
      <div class="text-grey-6 q-mb-md">Landlord conversations</div>

      <q-input v-model="messageSearchQuery" outlined dense placeholder="Search conversations..." bg-color="white" class="q-mb-md rounded-input" />

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
          <div class="text-caption q-mt-xs">Messages with your landlord will appear here.</div>
        </div>

        <q-list v-else class="bg-white custom-card" bordered separator>
          <q-item v-for="chat in filteredConversations" :key="chat.id" clickable v-ripple class="q-py-md">
            <q-item-section avatar>
              <q-avatar :color="chat.avatarColor" text-color="white" size="48px">{{ chat.initials }}</q-avatar>
              <q-badge v-if="chat.unread" color="teal-8" floating rounded>{{ chat.unread }}</q-badge>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ chat.name }}</q-item-label>
              <q-item-label caption>{{ chat.lastMessage }}</q-item-label>
            </q-item-section>
            <q-item-section side top>
              <q-item-label caption>{{ chat.time }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { supabase } from '@/shared/utils/supabase';

interface ChatItem {
  id: string;
  name: string;
  initials: string;
  avatarColor: string;
  lastMessage: string;
  time: string;
  unread: number;
}

const messageSearchQuery = ref('');
const loading = ref(true);
const error = ref<string | null>(null);
const conversations = ref<ChatItem[]>([]);

const filteredConversations = computed(() => {
  const q = messageSearchQuery.value.trim().toLowerCase();
  if (!q) return conversations.value;
  return conversations.value.filter((c) =>
    c.name.toLowerCase().includes(q) || c.lastMessage.toLowerCase().includes(q)
  );
});

async function loadConversations() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    // Conversations where the student is user_a or user_b
    const { data, error: queryError } = await supabase
      .from('conversations')
      .select('id, last_message, last_time, unread_a, unread_b, user_a_id, user_b_id')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
      .order('last_time', { ascending: false });

    if (queryError) throw queryError;

    const rows = (data ?? []) as unknown as Array<{
      id: string;
      last_message: string | null;
      last_time: string | null;
      unread_a: number;
      unread_b: number;
      user_a_id: string;
      user_b_id: string;
    }>;

    conversations.value = rows.map((c) => {
      const unread = c.user_a_id === user.id ? c.unread_a : c.unread_b;
      return {
        id: c.id,
        name: 'Landlord',
        initials: 'LL',
        avatarColor: 'teal-8',
        lastMessage: c.last_message ?? 'No messages yet',
        time: c.last_time ? new Date(c.last_time).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) : '',
        unread,
      };
    });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load messages';
  } finally {
    loading.value = false;
  }
}

onMounted(loadConversations);
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}
.rounded-input :deep(.q-field__control) {
  border-radius: 12px;
}
</style>
