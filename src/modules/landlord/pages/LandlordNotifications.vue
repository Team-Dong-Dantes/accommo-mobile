<template>
  <q-page class="notif-page">
    <div class="header-shell q-px-md q-pt-lg q-pb-md row items-center no-wrap">
      <div class="col">
        <div class="page-title">Notifications</div>
        <div class="page-subtitle">{{ unreadCount }} unread</div>
      </div>
      <q-btn flat no-caps class="mark-read-btn" label="Mark all read" @click="markAllRead" />
    </div>

    <div class="q-px-md">
      <q-list separator class="notif-list">
      <q-item v-for="item in notifications" :key="item.id" class="notif-item">
        <q-item-section avatar>
          <q-icon :name="item.icon" :style="{ color: item.color }" size="24px" />
        </q-item-section>

        <q-item-section>
          <q-item-label class="notif-item-title">{{ item.title }}</q-item-label>
          <q-item-label caption class="notif-item-sub">{{ item.subtext }}</q-item-label>
          <q-item-label caption class="notif-item-time">{{ item.timestamp }}</q-item-label>
        </q-item-section>

        <q-item-section side top>
          <span v-if="item.unread" class="unread-dot" />
        </q-item-section>
        </q-item>
      </q-list>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

interface NotificationItem {
  id: number
  icon: string
  color: string
  title: string
  subtext: string
  timestamp: string
  unread: boolean
}

const notifications = ref<NotificationItem[]>([
  {
    id: 1,
    icon: 'credit_card',
    color: '#16a34a',
    title: 'Rent Payment Received',
    subtext: 'Maria Santos paid April rent of P3,500',
    timestamp: '2h ago',
    unread: true,
  },
  {
    id: 2,
    icon: 'build',
    color: '#ea580c',
    title: 'New Repair Request',
    subtext: 'Jose Reyes: Aircon not cooling in Room 2-B',
    timestamp: '4h ago',
    unread: true,
  },
  {
    id: 3,
    icon: 'groups',
    color: '#7e22ce',
    title: 'New Inquiry',
    subtext: 'A student inquired about Room 101',
    timestamp: '1d ago',
    unread: false,
  },
  {
    id: 4,
    icon: 'error',
    color: '#dc2626',
    title: 'Overdue Rent Alert',
    subtext: 'Ana Villanueva April rent is now overdue',
    timestamp: '2d ago',
    unread: false,
  },
  {
    id: 5,
    icon: 'groups',
    color: '#ea580c',
    title: 'Lease Expiring Soon',
    subtext: 'Jose Reyes lease ends Jul 31',
    timestamp: '5d ago',
    unread: false,
  },
])

const markAllRead = () => {
  notifications.value = notifications.value.map(item => ({ ...item, unread: false }))
}

const unreadCount = computed(() => notifications.value.filter(item => item.unread).length)
</script>

<style scoped>
.notif-page {
  padding-bottom: 96px;
  background: #f4f5f7;
  min-height: 100vh;
}
.header-shell {
  background: #f4f5f7;
}
.page-title {
  color: #111827;
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.05em;
}
.page-subtitle {
  color: #6b7280;
  font-size: 13px;
  font-weight: 600;
  margin-top: 4px;
}
.mark-read-btn {
  color: #0d9488;
  font-weight: 700;
  text-transform: none;
}
.notif-list {
  background: #FFFFFF;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 22px;
  overflow: hidden;
}
.notif-item {
  padding: 14px 12px;
}
.notif-item-title {
  font-size: 15px;
  font-weight: 700;
  color: #111827;
}
.notif-item-sub {
  font-size: 13px;
  color: #4b5563;
  margin-top: 2px;
}
.notif-item-time {
  font-size: 11px;
  color: #9ca3af;
  margin-top: 2px;
}
.unread-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #0d9488;
  display: inline-block;
}
</style>
