<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <div class="row justify-between items-end q-mb-md">
        <div>
          <div class="text-grey-6 text-caption">{{ unreadCount }} unread</div>
        </div>
        <q-btn
          flat color="teal-8" label="Mark all read"
          no-caps class="text-weight-bold bg-teal-1 rounded-borders q-px-sm"
          dense :disable="unreadCount === 0 || markingAll"
          @click="markAllRead"
        />
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
          <div class="text-caption q-mt-xs">Rent reminders and updates will appear here.</div>
        </div>

        <div v-else class="q-gutter-y-sm">
          <q-card
            v-for="n in notifications"
            :key="n.id"
            flat bordered
            class="custom-card cursor-pointer"
            :class="{ 'notification-unread': !n.read }"
            @click="openNotification(n)"
          >
            <q-item class="q-pa-md">
              <q-item-section avatar top>
                <q-avatar :color="n.avatarColor" :text-color="n.avatarTextColor" :icon="n.icon" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-bold">{{ n.title }}</q-item-label>
                <q-item-label caption class="q-mt-xs">{{ n.body }}</q-item-label>
              </q-item-section>
              <q-item-section side top class="items-end">
                <div v-if="!n.read" class="bg-teal-8 q-mt-xs" style="width: 8px; height: 8px; border-radius: 50%;" />
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
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';

interface NotificationRow {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type: string;
  link_url: string | null;
  read_at: string | null;
}

interface NotificationItem {
  id: string;
  title: string;
  body: string;
  type: string;
  linkUrl: string | null;
  read: boolean;
  icon: string;
  avatarColor: string;
  avatarTextColor: string;
}

const router = useRouter();
const $q = useQuasar();

const loading = ref(true);
const error = ref<string | null>(null);
const markingAll = ref(false);
const notifications = ref<NotificationItem[]>([]);

const unreadCount = computed(() => notifications.value.filter((n) => !n.read).length);

const TYPE_STYLE: Record<string, { icon: string; avatarColor: string; avatarTextColor: string }> = {
  rent: { icon: 'credit_card', avatarColor: 'teal-1', avatarTextColor: 'teal-8' },
  repair: { icon: 'build', avatarColor: 'orange-1', avatarTextColor: 'orange' },
  payment: { icon: 'check_circle', avatarColor: 'green-1', avatarTextColor: 'green' },
  maintenance: { icon: 'home_repair_service', avatarColor: 'blue-1', avatarTextColor: 'blue' },
  announcement: { icon: 'campaign', avatarColor: 'purple-1', avatarTextColor: 'purple' },
  general: { icon: 'notifications', avatarColor: 'grey-2', avatarTextColor: 'grey-8' },
};

async function loadNotifications() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }

    const { data, error: queryError } = await supabase
      .from('notifications')
      .select('id, user_id, title, body, type, link_url, read_at')
      .eq('user_id', user.id);

    if (queryError) throw queryError;

    const rows = (data ?? []) as unknown as NotificationRow[];

    notifications.value = rows.map((n) => {
      const style: { icon: string; avatarColor: string; avatarTextColor: string } =
        TYPE_STYLE[n.type] ?? { icon: 'notifications', avatarColor: 'grey-2', avatarTextColor: 'grey-8' };
      return {
        id: n.id,
        title: n.title,
        body: n.body,
        type: n.type,
        linkUrl: n.link_url,
        read: n.read_at !== null,
        icon: style.icon,
        avatarColor: style.avatarColor,
        avatarTextColor: style.avatarTextColor,
      };
    });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load notifications';
    notifications.value = [];
  } finally {
    loading.value = false;
  }
}

async function openNotification(n: NotificationItem) {
  // Mark as read
  if (!n.read) {
    const { error } = await supabase
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('id', n.id);
    if (!error) n.read = true;
  }

  // Navigate if there's a link
  if (n.linkUrl) {
    void router.push(n.linkUrl);
  }
}

async function markAllRead() {
  markingAll.value = true;
  try {
    const unreadIds = notifications.value.filter((n) => !n.read).map((n) => n.id);
    if (unreadIds.length === 0) return;

    const { error } = await supabase
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .in('id', unreadIds);

    if (error) throw error;
    notifications.value.forEach((n) => { n.read = true; });
    $q.notify({ message: 'All notifications marked as read.', color: 'teal-8', position: 'top', classes: 'custom-notify' });
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to update', color: 'negative', position: 'top' });
  } finally {
    markingAll.value = false;
  }
}

onMounted(loadNotifications);
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.notification-unread {
  background: #f0fdfa;
  border-left: 3px solid #00897b;
}
</style>
