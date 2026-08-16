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
        <q-tab label="All" icon="mail" />
        <q-tab label="Unread" icon="unread" />
        <q-tab label="Read" icon="visibility" />
      </q-tabs>

      <div class="q-pa-md">
        <div v-if="notifications.length === 0" class="text-center text-grey-7 q-py-8">
          No notifications yet.
        </div>

        <q-list
          v-if="notifications.length > 0"
          bordered
          separator
          class="rounded-borders bg-white"
        >
          <q-item v-for="notification in notifications" :key="notification.id">
            <q-item-section>
              <q-item-label>
                {{ notification.title }}
              </q-item-label>
              <q-item-label caption>
                {{ notification.body }}
                <q-badge
                  v-if="!notification.read_at"
                  color="red"
                  small
                  class="q-ml-sm"
                />
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge
                v-if="!notification.read_at"
                color="amber"
                small
                label="Unread"
              />
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '@/stores/auth'

import { supabase } from '@/shared/utils/supabase'

const router = useRouter()
const route = useRoute()
const $q = useQuasar()
const authStore = useAuthStore()

const userRole = ref<'landlord' | 'student' | '' = 'landlord'
const leftDrawerOpen = ref(false)

const notificationsTab = ref('All')

// Demo notifications data
const notifications = ref([
  {
    id: 'notif-1',
    title: 'Payment Received',
    body: 'Juan Dela Cruz paid ₱5,000 for March 2024',
    read_at: null,
  },
  {
    id: 'notif-2',
    title: 'Maintenance Request',
    body: 'Room 3A needs plumbing repair',
    read_at: new Date().toISOString(),
  },
  {
    id: 'notif-3',
    title: 'New Inquiry',
    body: 'Maria Santos inquired about room availability',
    read_at: null,
  },
])

// Computed: unread count
const unreadCount = computed(() => notifications.value.filter((n) => !n.read_at).length)
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