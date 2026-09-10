<template>
  <q-page class="ann">
    <div v-if="loading" class="stack">
      <q-skeleton type="text" width="35%" height="13px" />
      <q-skeleton type="text" width="80%" height="26px" />
      <q-skeleton type="rect" height="160px" class="sk" />
    </div>

    <EmptyState
      v-else-if="error || !row"
      icon="lucide:megaphone-off"
      title="Announcement unavailable"
      :message="error || 'It may have expired or been taken down.'"
    />

    <template v-else>
      <article class="doc">
        <div class="from">
          <span class="from-badge" :class="{ 'from-badge--house': isHouse }">
            <img v-if="houseImage" :src="houseImage" alt="" />
            <IconifyIcon v-else :icon="isHouse ? 'lucide:building-2' : 'lucide:shield-check'" width="12" />
          </span>
          {{ sender }}
        </div>

        <h1 class="title">{{ row.title }}</h1>

        <p class="posted">{{ notYetPosted ? 'Scheduled' : 'Posted ' + ago(row.published_at) }}</p>

        <hr class="rule" />

        <!-- Facts as one quiet line of prose, not a grid: most notices carry
             a date and a place, and that is a sentence, not a form. -->
        <p v-if="facts" class="facts">{{ facts }}</p>
        <p v-if="due" class="due" :class="{ 'due--soon': dueSoon }">
          <IconifyIcon icon="lucide:hourglass" width="13" />
          Due {{ due.on }} · {{ due.left }}
        </p>

        <p v-if="showSummary" class="lede">{{ row.summary }}</p>

        <img v-if="poster" :src="poster" class="poster" alt="" />

        <div class="body">
          <p v-for="(para, i) in paragraphs" :key="i">
            <template v-for="(part, j) in para" :key="j">
              <a v-if="part.href" :href="part.href" target="_blank" rel="noopener noreferrer">{{ part.text }}</a>
              <template v-else>{{ part.text }}</template>
            </template>
          </p>
        </div>
      </article>

      <section v-if="more.length" class="more">
        <hr class="rule" />
        <h2 class="more-title">More from {{ sender }}</h2>
        <button v-for="m in more" :key="m.id" type="button" class="more-row" @click="go(m.id)">
          <span class="more-text">{{ m.title }}</span>
          <span class="more-when">{{ ago(m.published_at) }}</span>
        </button>
      </section>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { useNotificationsStore } from '@/stores/notifications'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { ago } from '@/utils/profile'
import { linkifyParts } from '@/utils/linkify'
import EmptyState from '@/components/shared/EmptyState.vue'

type Row = {
  id: string
  title: string
  body: string
  summary: string | null
  published_at: string | null
  event_at: string | null
  event_end: string | null
  deadline_at: string | null
  location: string | null
  image_url: string | null
  accommodation_id: string | null
  accommodation: { name: string | null; accommodation_images: { url: string }[] | null } | null
}

const SELECT =
  'id, title, body, summary, published_at, event_at, event_end, deadline_at, location, image_url, accommodation_id, accommodation:accommodations(name, accommodation_images(url))'

const route = useRoute()
const router = useRouter()
const notifications = useNotificationsStore()

const row = ref<Row | null>(null)
const more = ref<{ id: string; title: string; published_at: string | null }[]>([])
const loading = ref(true)
const error = ref('')

const role = computed<'manager' | 'student'>(() =>
  route.path.startsWith('/manager') ? 'manager' : 'student',
)
const isHouse = computed(() => Boolean(row.value?.accommodation_id))
const sender = computed(() =>
  isHouse.value ? row.value?.accommodation?.name || 'Your accommodation' : 'System Admin',
)
const houseImage = computed(() => {
  const url = row.value?.accommodation?.accommodation_images?.[0]?.url
  return url ? resolveAsset(url) : null
})
const poster = computed(() => (row.value?.image_url ? resolveAsset(row.value.image_url) : ''))

// Readers never reach a scheduled announcement — RLS hides it until its time —
// so this only ever shows to the author, who should not be told it was posted.
const notYetPosted = computed(() => {
  const at = row.value?.published_at
  return !at || new Date(at).getTime() > Date.now()
})

const showSummary = computed(() => {
  const s = row.value?.summary?.trim()
  if (!s) return false
  return !row.value?.body.trim().toLowerCase().startsWith(s.toLowerCase().slice(0, 40))
})

const paragraphs = computed(() =>
  (row.value?.body ?? '')
    .split(/\n{2,}/)
    .map((p) => p.trim())
    .filter(Boolean)
    .map(linkifyParts),
)

function when(iso: string | null | undefined): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleString('en-PH', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
}

// "Sep 15, 8:00 AM – Sep 19, 5:00 PM · All accredited houses"
const facts = computed(() => {
  const r = row.value
  if (!r) return ''
  const parts: string[] = []
  if (r.event_at) parts.push(r.event_end ? `${when(r.event_at)} – ${when(r.event_end)}` : when(r.event_at))
  if (r.location) parts.push(r.location)
  return parts.join(' · ')
})

const due = computed(() => {
  const at = row.value?.deadline_at
  if (!at) return null
  const days = Math.ceil((new Date(at).getTime() - Date.now()) / 86400000)
  const left = days < 0 ? 'passed' : days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days`
  return { on: when(at), left, days }
})
const dueSoon = computed(() => (due.value?.days ?? 99) <= 3)

onMounted(async () => {
  const id = String(route.params.id ?? '')
  const { data, error: err } = await supabase.from('announcements').select(SELECT).eq('id', id).maybeSingle()
  if (err) error.value = err.message
  else row.value = data as unknown as Row | null
  loading.value = false
  if (!row.value) return

  // Opening it is reading it — the same record the reach figure counts.
  const notif = notifications.items.find((n) => n.ref_id === row.value?.id)
  if (notif && !notif.read_at) void notifications.markRead(notif.id)

  const query = supabase
    .from('announcements')
    .select('id, title, published_at')
    .neq('id', id)
    .order('published_at', { ascending: false })
    .limit(3)
  const { data: rest } = row.value.accommodation_id
    ? await query.eq('accommodation_id', row.value.accommodation_id)
    : await query.is('accommodation_id', null)
  more.value = rest ?? []
})

function go(id: string) {
  void router.push(`/${role.value}/announcement/${id}`)
}
</script>

<style scoped>
.ann { padding: 16px 18px 30px; }
.stack { display: flex; flex-direction: column; gap: 10px; }
.sk { border-radius: var(--m-radius); }

.from {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--m-info);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.from-badge {
  display: grid;
  overflow: hidden;
  width: 18px;
  height: 18px;
  flex: 0 0 18px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-info-soft);
}
.from-badge--house { background: var(--m-primary-soft); color: var(--m-primary); }
.from-badge img { width: 100%; height: 100%; object-fit: cover; }

.title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 23px;
  font-weight: 750;
  line-height: 1.2;
  letter-spacing: -0.015em;
  text-wrap: pretty;
}

.posted {
  margin: 6px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}

.rule {
  margin: 14px 0;
  border: 0;
  border-top: 1px solid var(--m-border);
}

.facts {
  margin: 0;
  color: var(--m-text);
  font-size: 12.5px;
  font-weight: 650;
  line-height: 1.45;
}
.due {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 5px 0 0;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 700;
}
.due--soon { color: var(--m-warning); }

.lede {
  margin: 14px 0 0;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 600;
  line-height: 1.5;
}

.poster {
  width: 100%;
  margin-top: 14px;
  border-radius: var(--m-radius);
  object-fit: cover;
}

.body { margin-top: 12px; color: var(--m-text); font-size: 14px; line-height: 1.68; }
.body p { margin: 0 0 12px; white-space: pre-wrap; }
.body p:last-child { margin-bottom: 0; }
.body a { color: var(--m-info); font-weight: 600; overflow-wrap: anywhere; }

/* More */
.more { margin-top: 12px; }
.more-title {
  margin: 0 0 8px;
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.more-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.more-row + .more-row { border-top: 1px solid var(--m-border); }
.more-text {
  overflow: hidden;
  min-width: 0;
  flex: 1 1 auto;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.more-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 600; }
</style>
