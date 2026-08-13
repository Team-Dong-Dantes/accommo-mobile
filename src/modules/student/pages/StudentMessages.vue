<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <div class="text-h4 text-weight-bold" style="letter-spacing: -0.5px">Messages</div>
      <div class="text-grey-6 q-mb-md">Landlord conversations</div>

      <q-input v-model="messageSearchQuery" outlined dense placeholder="Search conversations..." bg-color="white" class="q-mb-md rounded-input" />

      <q-list class="bg-white custom-card" bordered separator>
        <q-item v-for="chat in recentChats" :key="chat.id" clickable v-ripple class="q-py-md">
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
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';

interface ChatItem {
  id: number;
  name: string;
  initials: string;
  avatarColor: string;
  lastMessage: string;
  time: string;
  unread: number;
}

const messageSearchQuery = ref('');

const recentChats: ChatItem[] = [
  { id: 1, name: 'Mario Santos', initials: 'MS', avatarColor: 'teal-8', lastMessage: "Sure, I'll fix the faucet tomorrow morning.", time: '2m ago', unread: 2 },
  { id: 2, name: 'Ana Banawa', initials: 'AB', avatarColor: 'orange-7', lastMessage: 'Are you staying for the sem break?', time: '1h ago', unread: 0 },
  { id: 3, name: 'Property Admin', initials: 'PA', avatarColor: 'blue-8', lastMessage: 'Your payment has been verified. Thank you!', time: '2d ago', unread: 0 },
];
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
