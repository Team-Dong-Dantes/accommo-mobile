<template>
  <q-page class="notif">
    <div v-if="store.loading && !store.ready" class="stack">
      <q-skeleton type="rect" height="34px" class="sk" />
      <q-skeleton type="rect" height="72px" class="sk" />
      <q-skeleton type="rect" height="72px" class="sk" />
      <q-skeleton type="rect" height="72px" class="sk" />
    </div>

    <div v-else-if="store.error && !store.items.length" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load notifications</p>
        <p class="err-sub">{{ store.error }}</p>
        <q-btn
          unelevated
          rounded
          no-caps
          dense
          color="primary"
          label="Try again"
          class="q-mt-sm q-px-md"
          @click="reload"
        />
      </q-card>
    </div>

    <div v-else-if="!store.items.length" class="empty">
      <span class="empty-icon"><IconifyIcon icon="lucide:bell" width="26" /></span>
      <p class="empty-title">No notifications yet</p>
      <p class="empty-text">{{ emptyMessage }}</p>
    </div>

    <div v-else class="stack">
      <div class="strip">
        <span class="strip-count">
          {{ store.unread ? `${store.unread} unread` : 'All caught up' }}
        </span>
        <button v-if="store.unread" type="button" class="strip-act" @click="store.markAllRead()">
          Mark all read
        </button>
      </div>

      <section v-for="group in groups" :key="group.label" class="sec">
        <h2 class="sec-title">{{ group.label }}</h2>
        <div class="list">
          <component
            :is="row.route ? 'button' : 'div'"
            v-for="row in group.rows"
            :key="row.id"
            :type="row.route ? 'button' : undefined"
            class="item"
            :class="{ 'item--unread': !row.read, 'item--flat': !row.route }"
            @click="open(row)"
          >
            <span class="item-icon" :class="`item-icon--${row.tone}`">
              <IconifyIcon :icon="row.icon" width="16" />
            </span>
            <span class="item-body">
              <span class="item-title">{{ row.title }}</span>
              <span class="item-text">{{ row.body }}</span>
            </span>
            <span class="item-side">
              <span class="item-when">{{ row.when }}</span>
              <span v-if="!row.read" class="item-dot" aria-label="Unread" />
            </span>
          </component>
        </div>
      </section>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { useNotificationsStore } from '@/stores/notifications'
import {
  notifLook,
  resolveNotifLink,
  dayBucket,
  BUCKET_LABEL,
  since,
  type Role,
} from '@/utils/notifications'

const props = defineProps<{ role: Role; emptyMessage: string }>()

const router = useRouter()
const store = useNotificationsStore()

interface Row {
  id: string
  title: string
  body: string
  when: string
  icon: string
  tone: string
  read: boolean
  route: string | null
}

const groups = computed(() => {
  const buckets: { label: string; rows: Row[] }[] = BUCKET_LABEL.map((label) => ({
    label,
    rows: [],
  }))

  for (const n of store.items) {
    const look = notifLook(n.type)
    buckets[dayBucket(n.created_at)]?.rows.push({
      id: n.id,
      title: n.title,
      body: n.body,
      when: since(n.created_at),
      icon: look.icon,
      tone: look.tone,
      read: Boolean(n.read_at),
      route: resolveNotifLink(n.link_url, n.type, props.role),
    })
  }

  return buckets.filter((b) => b.rows.length)
})

function open(row: Row) {
  void store.markRead(row.id)
  if (row.route) void router.push(row.route)
}

async function reload() {
  const { data } = await supabase.auth.getUser()
  if (data?.user) await store.start(data.user.id)
}

onMounted(reload)
</script>

<style scoped>
.notif {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px var(--m-page-gutter) 20px;
}
.sk {
  border-radius: var(--m-radius);
}

.card {
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.card--pad {
  padding: 18px 14px;
}
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
}

/* Unread summary + bulk action */
.strip {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 0 2px;
}
.strip-count {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.strip-act {
  min-height: 32px;
  padding: 0 4px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 5px;
}
.sec-title {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.list {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.item {
  display: flex;
  width: 100%;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
/* Rows with nowhere to go still mark themselves read, but must not look tappable. */
.item--flat {
  cursor: default;
}
.item--unread {
  border-color: color-mix(in srgb, var(--m-primary) 26%, var(--m-border));
  background: var(--m-primary-soft);
}

.item-icon {
  display: grid;
  width: 28px;
  height: 28px;
  flex: 0 0 28px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
}
.item-icon--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.item-icon--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.item-icon--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.item-icon--info {
  background: var(--m-info-soft);
  color: var(--m-info);
}
.item--unread .item-icon {
  background: #fff;
}

.item-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 2px;
}
.item-title {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
  line-height: 1.25;
  text-wrap: pretty;
}
.item-text {
  color: var(--m-text);
  font-size: 12px;
  line-height: 1.35;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.item-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 5px;
}
.item-when {
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
  white-space: nowrap;
}
.item-dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--m-primary);
}

/* Empty */
.empty {
  display: flex;
  min-height: 60vh;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 24px var(--m-page-gutter);
  text-align: center;
}
.empty-icon {
  display: grid;
  width: 54px;
  height: 54px;
  place-items: center;
  margin-bottom: 6px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary);
}
.empty-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
.empty-text {
  margin: 0;
  max-width: 280px;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}
</style>
