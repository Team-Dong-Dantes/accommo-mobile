<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <div class="row justify-between items-end q-mb-md">
        <div>
          <div class="text-h4 text-weight-bold" style="letter-spacing: -0.5px">Notifications</div>
          <div class="text-grey-6 text-caption">{{ unreadCount }} unread</div>
        </div>
        <q-btn flat color="teal-8" label="Mark all read" no-caps class="text-weight-bold bg-teal-1 rounded-borders q-px-sm" dense @click="markAllRead" />
      </div>

      <template v-if="loading">
        <q-skeleton type="rect" height="64px" v-for="i in 3" :key="i" class="q-mb-sm" style="border-radius:14px" />
      </template>

      <template v-else-if="error">
        <div class="text-negative text-center q-py-xl">{{ error }}</div>
      </template>

      <template v-else>
        <div v-if="notifications.length === 0" class="text-center text-grey-6 q-py-xl">
          <q-icon name="notifications_none" size="48px" color="grey-4" />
          <div class="text-subtitle2 text-weight-medium q-mt-sm">No notifications</div>
          <div class="text-caption q-mt-xs">Announcements and updates will appear here.</div>
        </div>

        <div v-else class="q-gutter-y-sm">
          <q-card v-for="n in notifications" :key="n.id" flat bordered class="custom-card">
            <q-item class="q-pa-md">
              <q-item-section avatar top>
                <q-avatar :color="n.avatarColor" :text-color="n.avatarTextColor" :icon="n.icon" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-bold">{{ n.title }}</q-item-label>
                <q-item-label caption class="q-mt-xs">{{ n.body }}</q-item-label>
              </q-item-section>
              <q-item-section side top class="items-end">
                <q-item-label caption class="q-mb-xs">{{ n.time }}</q-item-label>
                <div v-if="n.unread" class="bg-teal-8" style="width: 8px; height: 8px; border-radius: 50%;" />
              </q-item-section>
            </q-item>
          </q-card>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { supabase } from '@/shared/utils/supabase';

interface NotificationItem {
  id: string;
  title: string;
  body: string;
  time: string;
  unread: boolean;
  icon: string;
  avatarColor: string;
  avatarTextColor: string;
}

const loading = ref(true);
const error = ref<string | null>(null);
const notifications = ref<NotificationItem[]>([]);

const unreadCount = computed(() => notifications.value.filter((n) => n.unread).length);

async function loadNotifications() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    const { data, error: queryError } = await supabase
      .from('announcements')
      .select('id, title, body, published_at, audience')
      .or(`audience.eq.all,audience.eq.student,audience.eq.${user.role}`)
      .order('published_at', { ascending: false });

    if (queryError) throw queryError;

    const rows = (data ?? []) as unknown as Array<{
      id: string;
      title: string;
      body: string;
      published_at: string | null;
      audience: string;
    }>;

    notifications.value = rows.map((a) => ({
      id: a.id,
      title: a.title,
      body: a.body,
      time: a.published_at ? new Date(a.published_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) : '',
      unread: true,
      icon: 'campaign',
      avatarColor: 'teal-1',
      avatarTextColor: 'teal-8',
    }));
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load notifications';
  } finally {
    loading.value = false;
  }
}

function markAllRead() {
  notifications.value.forEach((n) => { n.unread = false; });
}

onMounted(loadNotifications);
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}
</style>
