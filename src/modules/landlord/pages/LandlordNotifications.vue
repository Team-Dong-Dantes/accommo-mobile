<template>
  <q-page class="notifications-page">
    <main class="notifications-content" aria-labelledby="notifications-title">
      <header class="notifications-header">
        <div>
          <h1 id="notifications-title" class="sr-only">Notifications</h1>
          <p class="unread-summary" aria-live="polite">
            {{ unreadCount === 1 ? '1 unread notification' : `${unreadCount} unread notifications` }}
          </p>
        </div>
        <q-btn
          flat
          no-caps
          dense
          class="mark-read-button"
          label="Mark all read"
          :disable="unreadCount === 0 || markingAll"
          :loading="markingAll"
          aria-label="Mark all notifications as read"
          @click="markAllRead"
        />
      </header>

      <div v-if="loading" class="notification-skeletons" role="status" aria-label="Loading notifications">
        <span class="sr-only">Loading notifications</span>
        <div v-for="index in 4" :key="index" class="skeleton-row" aria-hidden="true">
          <q-skeleton type="QAvatar" size="40px" />
          <div class="skeleton-copy">
            <q-skeleton type="text" width="58%" />
            <q-skeleton type="text" width="88%" />
          </div>
        </div>
      </div>

      <section v-else-if="error" class="feedback-state" role="alert" aria-live="assertive">
        <span class="feedback-icon feedback-icon--danger" aria-hidden="true">
          <IconifyIcon icon="lucide:cloud-alert" width="24" />
        </span>
        <h2>Notifications could not load</h2>
        <p>{{ error }}</p>
        <q-btn no-caps unelevated class="retry-button" label="Retry" @click="loadNotifications" />
      </section>

      <section v-else-if="notifications.length === 0" class="feedback-state">
        <span class="feedback-icon" aria-hidden="true">
          <IconifyIcon icon="lucide:bell" width="24" />
        </span>
        <h2>You are all caught up</h2>
        <p>Updates about your properties will appear here.</p>
      </section>

      <div v-else class="notification-groups">
        <section v-for="group in groupedNotifications" :key="group.label" class="notification-group" :aria-labelledby="group.id">
          <h2 :id="group.id" class="group-label">{{ group.label }}</h2>
          <q-list class="notification-list">
            <q-item
              v-for="notification in group.notifications"
              :key="notification.id"
              tag="button"
              clickable
              v-ripple
              class="notification-row"
              :class="[`notification-row--${notification.tone}`, { 'notification-row--unread': !notification.read }]"
              :aria-label="notificationLabel(notification)"
              @click="openNotification(notification)"
            >
              <q-item-section avatar>
                <span class="notification-icon" aria-hidden="true">
                  <IconifyIcon :icon="notification.icon" width="20" />
                </span>
              </q-item-section>
              <q-item-section>
                <q-item-label class="notification-title">{{ notification.title }}</q-item-label>
                <q-item-label v-if="notification.body" caption class="notification-body">{{ notification.body }}</q-item-label>
                <q-item-label caption class="notification-time">{{ formatTimestamp(notification.createdAt) }}</q-item-label>
              </q-item-section>
              <q-item-section side top>
                <span v-if="!notification.read" class="unread-dot" aria-label="Unread" />
                <IconifyIcon v-else-if="notification.linkUrl" icon="lucide:chevron-right" width="18" class="chevron" aria-hidden="true" />
              </q-item-section>
            </q-item>
          </q-list>
        </section>
      </div>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useQuasar } from 'quasar';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';

type NotificationTone = 'primary' | 'success' | 'warning' | 'danger' | 'info';

interface NotificationRow {
  id: string;
  title: string;
  body: string | null;
  type: string;
  link_url: string | null;
  read_at: string | null;
  created_at: string | null;
}

interface NotificationItem {
  id: string;
  title: string;
  body: string;
  linkUrl: string | null;
  createdAt: string | null;
  read: boolean;
  icon: string;
  tone: NotificationTone;
}

interface NotificationGroup {
  id: string;
  label: string;
  notifications: NotificationItem[];
}

const TYPE_META: Record<string, { icon: string; tone: NotificationTone }> = {
  rent: { icon: 'lucide:wallet-cards', tone: 'primary' },
  payment: { icon: 'lucide:circle-check', tone: 'success' },
  repair: { icon: 'lucide:wrench', tone: 'warning' },
  maintenance: { icon: 'lucide:wrench', tone: 'warning' },
  inquiry: { icon: 'lucide:message-circle', tone: 'info' },
  lease: { icon: 'lucide:file-text', tone: 'info' },
  announcement: { icon: 'lucide:megaphone', tone: 'primary' },
  alert: { icon: 'lucide:triangle-alert', tone: 'danger' },
};

const router = useRouter();
const $q = useQuasar();
const loading = ref(true);
const error = ref<string | null>(null);
const markingAll = ref(false);
const notifications = ref<NotificationItem[]>([]);

const unreadCount = computed(() => notifications.value.filter((notification) => !notification.read).length);
const groupedNotifications = computed<NotificationGroup[]>(() => {
  const groups: NotificationGroup[] = [
    { id: 'today', label: 'Today', notifications: [] },
    { id: 'this-week', label: 'Earlier this week', notifications: [] },
    { id: 'earlier', label: 'Earlier', notifications: [] },
  ];
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const weekStart = new Date(today);
  weekStart.setDate(today.getDate() - ((today.getDay() + 6) % 7));

  notifications.value.forEach((notification) => {
    const createdAt = notification.createdAt ? new Date(notification.createdAt) : null;
    if (createdAt && !Number.isNaN(createdAt.getTime()) && createdAt >= today) groups[0]!.notifications.push(notification);
    else if (createdAt && !Number.isNaN(createdAt.getTime()) && createdAt >= weekStart) groups[1]!.notifications.push(notification);
    else groups[2]!.notifications.push(notification);
  });

  return groups.filter((group) => group.notifications.length > 0);
});

function formatTimestamp(value: string | null): string {
  if (!value) return 'Recently';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Recently';

  const today = new Date();
  const isToday = date.toDateString() === today.toDateString();
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  if (isToday) return date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  if (date.toDateString() === yesterday.toDateString()) return 'Yesterday';
  return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
}

function notificationLabel(notification: NotificationItem): string {
  const status = notification.read ? '' : 'Unread. ';
  const destination = notification.linkUrl ? ' Opens notification.' : ' Marks notification as read.';
  return `${status}${notification.title}. ${notification.body} ${formatTimestamp(notification.createdAt)}.${destination}`;
}

async function loadNotifications() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;
    if (!user) {
      void router.push('/login');
      return;
    }

    const { data, error: queryError } = await supabase
      .from('notifications')
      .select('id, title, body, type, link_url, read_at, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);
    if (queryError) throw queryError;

    notifications.value = ((data ?? []) as unknown as NotificationRow[]).map((row) => {
      const meta = TYPE_META[row.type] ?? { icon: 'lucide:bell', tone: 'primary' as NotificationTone };
      return {
        id: row.id,
        title: row.title,
        body: row.body ?? '',
        linkUrl: row.link_url,
        createdAt: row.created_at,
        read: row.read_at !== null,
        ...meta,
      };
    });
  } catch (loadError) {
    notifications.value = [];
    error.value = loadError instanceof Error ? loadError.message : 'Please check your connection and try again.';
  } finally {
    loading.value = false;
  }
}

function openNotification(notification: NotificationItem) {
  if (!notification.read) {
    notification.read = true;
    void persistRead(notification);
  }
  if (notification.linkUrl) void router.push(notification.linkUrl);
}

async function persistRead(notification: NotificationItem) {
  const { error: updateError } = await supabase
    .from('notifications')
    .update({ read_at: new Date().toISOString() })
    .eq('id', notification.id);
  if (updateError) {
    notification.read = false;
    $q.notify({ message: 'Could not mark this notification as read. Please try again.', color: 'negative', position: 'top' });
  }
}

async function markAllRead() {
  const unread = notifications.value.filter((notification) => !notification.read);
  if (unread.length === 0) return;

  markingAll.value = true;
  unread.forEach((notification) => { notification.read = true; });
  try {
    const { error: updateError } = await supabase
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .in('id', unread.map((notification) => notification.id));
    if (updateError) throw updateError;
  } catch {
    unread.forEach((notification) => { notification.read = false; });
    $q.notify({ message: 'Could not mark notifications as read. Please try again.', color: 'negative', position: 'top' });
  } finally {
    markingAll.value = false;
  }
}

onMounted(() => { void loadNotifications(); });
</script>

<style scoped>
.notifications-page { min-height: 100vh; padding: var(--m-space-4) var(--m-page-gutter) 96px; background: var(--m-bg); }
.notifications-content { width: 100%; max-width: 620px; margin: 0 auto; }
.notifications-header { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--m-space-3); margin-bottom: var(--m-space-5); }
.group-label { margin: 0; color: var(--m-primary-dark); font-size: 11px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
h1 { margin: var(--m-space-1) 0 0; color: var(--m-ink); font-size: 28px; line-height: 1.15; letter-spacing: -.04em; }
.unread-summary { margin: 0; color: var(--m-muted); font-size: 13px; font-weight: 600; }
.mark-read-button { min-height: 44px; margin-top: var(--m-space-1); padding: 0 var(--m-space-2); border-radius: var(--m-radius-sm); color: var(--m-primary-dark); font-size: 13px; font-weight: 750; }
.mark-read-button:focus-visible, .notification-row:focus-visible, .retry-button:focus-visible { outline: 3px solid var(--m-primary); outline-offset: 2px; }
.notification-groups { display: grid; gap: var(--m-space-5); }
.group-label { margin-bottom: var(--m-space-2); padding-left: var(--m-space-1); color: var(--m-muted); }
.notification-list { overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); box-shadow: var(--m-shadow); }
.notification-row { width: 100%; min-height: 76px; padding: var(--m-space-3); border: 0; border-bottom: 1px solid var(--m-border); background: var(--m-surface); color: var(--m-text); text-align: left; }
.notification-row:last-child { border-bottom: 0; }
.notification-row--unread { background: var(--m-primary-soft); box-shadow: inset 3px 0 0 var(--m-primary); }
.notification-row:not(.notification-row--unread):hover { background: var(--m-bg); }
.notification-icon, .feedback-icon { display: grid; width: 40px; height: 40px; place-items: center; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); color: var(--m-primary-dark); }
.notification-row--success .notification-icon { background: var(--m-success-soft); color: var(--m-success); }
.notification-row--warning .notification-icon { background: var(--m-warning-soft); color: var(--m-warning); }
.notification-row--danger .notification-icon, .feedback-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.notification-row--info .notification-icon { background: var(--m-info-soft); color: var(--m-info); }
.notification-title { color: var(--m-ink); font-size: 14px; font-weight: 750; line-height: 1.3; }
.notification-body { display: -webkit-box; margin-top: 2px; overflow: hidden; color: var(--m-text); font-size: 13px; line-height: 1.35; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
.notification-time { margin-top: 4px; color: var(--m-muted); font-size: 11px; font-weight: 650; }
.unread-dot { display: block; width: 8px; height: 8px; margin-top: 5px; border-radius: 50%; background: var(--m-primary-dark); }
.chevron { margin-top: 1px; color: var(--m-muted); }
.notification-skeletons { display: grid; gap: var(--m-space-2); }
.skeleton-row { display: flex; align-items: center; gap: var(--m-space-3); min-height: 76px; padding: var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.skeleton-copy { display: grid; flex: 1; gap: var(--m-space-2); }
.feedback-state { display: grid; justify-items: center; max-width: 360px; margin: var(--m-space-8) auto; text-align: center; }
.feedback-state h2 { margin: var(--m-space-3) 0 var(--m-space-1); color: var(--m-ink); font-size: 18px; line-height: 1.3; }
.feedback-state p { margin: 0; color: var(--m-muted); font-size: 14px; line-height: 1.5; }
.retry-button { min-height: 44px; margin-top: var(--m-space-4); padding: 0 var(--m-space-4); border-radius: var(--m-radius-sm); background: var(--m-primary-dark); color: var(--m-surface); font-weight: 750; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
</style>
