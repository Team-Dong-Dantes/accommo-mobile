<template>
  <q-page class="notif-page">
    <div class="header-shell q-px-md q-pt-md q-pb-sm row items-center no-wrap">
      <div class="col">
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
      <div v-if="!isLoading && notifications.length === 0" class="text-grey-7 text-center q-py-lg">
        No notifications yet.
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/shared/utils/supabase'

interface NotificationItem {
  id: string
  icon: string
  color: string
  title: string
  subtext: string
  timestamp: string
  unread: boolean
}

const notifications = ref<NotificationItem[]>([])
const isLoading = ref(false)

const TYPE_META: Record<string, { icon: string; color: string }> = {
  payment: { icon: 'credit_card', color: '#16a34a' },
  maintenance: { icon: 'build', color: '#ea580c' },
  inquiry: { icon: 'groups', color: '#7e22ce' },
  alert: { icon: 'error', color: '#dc2626' },
  lease: { icon: 'groups', color: '#ea580c' },
}

function timeAgo(iso: string | null): string {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'Just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  const days = Math.floor(hrs / 24)
  return `${days}d ago`
}

async function loadNotifications() {
  isLoading.value = true
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) return
    const { data, error } = await supabase
      .from('notifications')
      .select('id, title, body, type, read_at, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50)
    if (error) throw error
    notifications.value = (data ?? []).map((n: any) => {
      const meta = TYPE_META[n.type] || { icon: 'notifications', color: '#0d9488' }
      return {
        id: n.id,
        icon: meta.icon,
        color: meta.color,
        title: n.title,
        subtext: n.body || '',
        timestamp: timeAgo(n.created_at),
        unread: !n.read_at,
      }
    })
  } catch (e) {
    console.error('loadNotifications error:', e)
  } finally {
    isLoading.value = false
  }
}

const markAllRead = async () => {
  notifications.value = notifications.value.map((item) => ({ ...item, unread: false }))
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (user) {
    await supabase
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('user_id', user.id)
  }
}

const unreadCount = computed(() => notifications.value.filter((item) => item.unread).length)

onMounted(() => {
  void loadNotifications()
})
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
