<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <div>
          <h4 class="q-my-none text-weight-bold">Notifications</h4>
          <p class="text-subtitle1 text-white-7 q-mb-none">
            Alerts regarding payments and repairs
          </p>
        </div>
        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </div>
    </div>

    <div class="content-section q-pa-md">
      <q-tabs
        v-model="notificationsTab"
        type="tabs"
        background-color="transparent"
        text-color="teal-9"
        ink-bar-color="teal-9"
        class="tab-style"
      >
        <q-tab name="All" label="All" icon="mail" />
        <q-tab name="Unread" :label="unreadLabel" icon="unread" />
        <q-tab name="Read" label="Read" icon="visibility" />
      </q-tabs>

      <div v-if="isLoading" class="text-center text-grey-7 q-py-8">
        <q-spinner size="36px" color="teal-8" />
      </div>

      <div v-else-if="loadError" class="q-pa-md">
        <q-banner class="bg-red-1 text-red-8 rounded-borders">{{ loadError }}</q-banner>
      </div>

      <div v-else-if="filteredNotifications.length === 0" class="text-center text-grey-7 q-py-8">
        No notifications yet.
      </div>

      <q-list
        v-else
        bordered
        separator
        class="rounded-borders bg-white"
      >
        <q-item
          v-for="notification in filteredNotifications"
          :key="notification.id"
          clickable
          @click="openNotification(notification)"
        >
          <q-item-section>
            <q-item-label>{{ notification.title }}</q-item-label>
            <q-item-label caption>
              {{ notification.body }}
              <q-badge v-if="!notification.read_at" color="red" small class="q-ml-sm" />
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge v-if="!notification.read_at" color="amber" small label="Unread" />
          </q-item-section>
        </q-item>
      </q-list>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/shared/utils/supabase'

const router = useRouter()
const authStore = useAuthStore()

const notifications = ref<any[]>([])
const isLoading = ref(false)
const loadError = ref<string | null>(null)
const notificationsTab = ref<'All' | 'Unread' | 'Read'>('All')

function handleLogout() {
  authStore.clearCachedRole()
  void supabase.auth.signOut()
  void router.push('/login')
}

// Real, landlord-scoped notifications (RLS: user_id = auth.uid()).
async function loadNotifications() {
  isLoading.value = true
  loadError.value = null
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) return
    const { data, error } = await supabase
      .from('notifications')
      .select('id, type, title, body, link_url, read_at')
      .eq('user_id', user.id)
      .order('id', { ascending: false })
    if (error) throw error
    notifications.value = (data ?? []) as any[]
  } catch (e: any) {
    loadError.value = e?.message || 'Failed to load notifications'
  } finally {
    isLoading.value = false
  }
}

const unreadCount = computed(() => notifications.value.filter((n) => !n.read_at).length)
const unreadLabel = computed(() => (unreadCount.value ? `Unread (${unreadCount.value})` : 'Unread'))

const filteredNotifications = computed(() => {
  if (notificationsTab.value === 'Unread') return notifications.value.filter((n) => !n.read_at)
  if (notificationsTab.value === 'Read') return notifications.value.filter((n) => !!n.read_at)
  return notifications.value
})

// Tapping a notification marks it read (best-effort) and opens its link if present.
async function markRead(id: string) {
  const target = notifications.value.find((n) => n.id === id)
  if (!target || target.read_at) return
  const ts = new Date().toISOString()
  target.read_at = ts
  const { error } = await supabase
    .from('notifications')
    .update({ read_at: ts } as any)
    .eq('id', id)
  if (error) console.warn('[notifications] mark read failed:', error.message)
}

function openNotification(n: any) {
  void markRead(n.id)
  if (n.link_url) void router.push(n.link_url)
}

onMounted(loadNotifications)
</script>

<style scoped>
.header-section {
  background: #004d40;
  border-radius: 0 0 28px 28px;
  margin-bottom: -40px;
}

.text-white-7 {
  color: rgba(255, 255, 255, 0.7);
}

.content-section {
  position: relative;
  z-index: 1;
}

.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.tab-style .q-tab {
  padding: 12px 24px;
  font-weight: 500;
  font-size: 14px;
}

.tab-style .ink-bar {
  background: #00897B !important;
}
</style>
