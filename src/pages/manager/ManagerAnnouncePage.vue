<template>
  <q-page class="ann-page">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <q-skeleton type="rect" height="120px" class="sk" />
        <q-skeleton type="rect" height="70px" class="sk" />
      </div>

      <EmptyState
        v-else-if="!accommodations.length"
        icon="lucide:building-2"
        title="No accommodation yet"
        message="Add an accommodation first — announcements go to the tenants of one of your houses."
      />

      <div v-else class="stack">
        <section class="sec">
          <h2 class="sec-title">Your announcements</h2>
          <EmptyState
            v-if="!mine.length"
            variant="compact"
            icon="lucide:megaphone"
            title="Nothing sent yet"
            message="Notices you send your tenants are listed here."
          />
          <div v-for="a in mine" :key="a.id" class="item">
            <div class="item-text">
              <span class="item-title">{{ a.title }}</span>
              <span class="item-meta">{{ houseName(a.accommodation_id) }} · {{ statusOf(a) }}</span>
            </div>
            <button type="button" class="item-act" @click="remove(a)">
              <IconifyIcon icon="lucide:trash-2" width="16" />
            </button>
          </div>
        </section>
      </div>
    </q-pull-to-refresh>

    <!-- Outside the pull container: a fixed action must not travel with the
         gesture. Hidden while composing, since the overlay covers it anyway. -->
    <button
      v-if="!loading && accommodations.length && !composeOpen"
      type="button"
      class="fab"
      @click="composeOpen = true"
    >
      <IconifyIcon icon="lucide:megaphone" width="17" />
      New announcement
    </button>

    <AnnouncementCompose
      v-if="composeOpen"
      :accommodations="accommodations"
      :submitting="sending"
      @close="composeOpen = false"
      @submit="send"
    />
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { errorMessage } from '@/utils/errors'
import { formatDate } from '@/utils/format'
import EmptyState from '@/components/shared/EmptyState.vue'
import AnnouncementCompose, { type AnnouncementDraft } from '@/components/manager/AnnouncementCompose.vue'

// A manager announcing to their own tenants. OSAS broadcasts leave
// accommodation_id null; setting it is what makes an announcement a house
// notice, and RLS uses that same column to decide who may write and read it.

type Accommodation = { id: string; name: string }
type Mine = {
  id: string
  title: string
  accommodation_id: string | null
  published_at: string | null
  expires_at: string | null
}

const notify = useNotify()

const loading = ref(true)
const sending = ref(false)
const composeOpen = ref(false)
const userId = ref('')
const accommodations = ref<Accommodation[]>([])
const mine = ref<Mine[]>([])

function houseName(id: string | null) {
  return accommodations.value.find((a) => a.id === id)?.name ?? 'Your accommodation'
}

function statusOf(a: Mine) {
  if (!a.published_at) return 'Draft'
  const published = new Date(a.published_at)
  if (published.getTime() > Date.now()) return `Scheduled ${formatDate(a.published_at)}`
  if (a.expires_at && new Date(a.expires_at).getTime() < Date.now()) return 'Ended'
  return `Sent ${formatDate(a.published_at)}`
}

/** `silent` skips the skeleton, so a pull-to-refresh spinner is the only chrome. */
async function load(silent = false) {
  if (!silent) loading.value = true
  const { data } = await authUser()
  userId.value = data?.user?.id ?? ''
  if (!userId.value) {
    loading.value = false
    return
  }

  const [{ data: houses }, { data: rows }] = await Promise.all([
    supabase
      .from('accommodations')
      .select('id, name')
      .eq('accommodation_manager_id', userId.value)
      .order('name'),
    supabase
      .from('announcements')
      .select('id, title, accommodation_id, published_at, expires_at')
      .not('accommodation_id', 'is', null)
      .order('published_at', { ascending: false, nullsFirst: true }),
  ])

  accommodations.value = houses ?? []
  mine.value = (rows ?? []) as Mine[]
  loading.value = false
}

function onPull(done: () => void) {
  void load(true).finally(done)
}

onMounted(load)

// AnnouncementCompose owns the form, its validation and the tenant count; this
// only does the insert. The overlay closes on success and stays open on failure,
// so a rejected notice is never silently lost.
async function send(draft: AnnouncementDraft) {
  sending.value = true
  try {
    const publishAt = draft.publishAt ? new Date(draft.publishAt).toISOString() : new Date().toISOString()
    // One row per house: a notice is addressed to an accommodation, and each
    // set of tenants reads (and dismisses) its own. Sent as a single insert so
    // it is all-or-nothing — two houses notified and a third silently missed
    // would be worse than an error.
    const rows = draft.accommodationIds.map((accommodationId) => ({
      title: draft.title.trim(),
      summary: draft.summary.trim() || null,
      body: draft.body.trim(),
      // Tenants are students; the audience column is ignored for house
      // notices, which are addressed by accommodation instead.
      audience: 'students' as const,
      accommodation_id: accommodationId,
      event_at: draft.eventAt ? new Date(draft.eventAt).toISOString() : null,
      event_end: draft.eventEnd ? new Date(draft.eventEnd).toISOString() : null,
      deadline_at: draft.deadlineAt ? new Date(draft.deadlineAt).toISOString() : null,
      location: draft.location.trim() || null,
      image_url: draft.imageUrl || null,
      author_id: userId.value,
      published_at: publishAt,
      expires_at: draft.expiresAt ? new Date(`${draft.expiresAt}T23:59:59`).toISOString() : null,
    }))

    const { data, error } = await supabase
      .from('announcements')
      .insert(rows)
      .select('id, title, accommodation_id, published_at, expires_at')
    if (error) throw error

    mine.value = [...((data ?? []) as Mine[]), ...mine.value]
    composeOpen.value = false
    const houses = draft.accommodationIds.length
    notify.success(
      draft.publishAt
        ? houses > 1 ? `Scheduled for ${houses} houses.` : 'Scheduled.'
        : houses > 1 ? `Sent to ${houses} houses.` : 'Sent to your tenants.',
    )
  } catch (e) {
    notify.error(errorMessage(e, 'Could not send that announcement.'))
  } finally {
    sending.value = false
  }
}

async function remove(a: Mine) {
  const { error } = await supabase.from('announcements').delete().eq('id', a.id)
  if (error) {
    notify.error(error.message)
    return
  }
  mine.value = mine.value.filter((row) => row.id !== a.id)
  notify.success('Removed. Notifications already delivered stay in your tenants\' inbox.')
}
</script>

<style scoped>
.ann-page { padding: 12px 12px calc(86px + env(safe-area-inset-bottom, 0px)); }
.stack { display: flex; flex-direction: column; gap: 12px; }
.sk { border-radius: var(--m-radius); }

.sec { display: flex; flex-direction: column; gap: 6px; }
.sec-title { margin: 0 2px; color: var(--m-ink); font-size: 14px; font-weight: 700; }
.item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.item-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.item-title {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.item-meta { color: var(--m-muted); font-size: 11px; font-weight: 600; }
.item-act {
  flex: 0 0 auto;
  border: 0;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
}
/* Matches the floating .dock band on the concerns pages: same bottom offset,
   same safe-area handling, so the action sits where the eye already expects
   a primary control on these screens. */
.fab {
  position: fixed;
  right: var(--m-page-gutter);
  bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  z-index: 60;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 46px;
  padding: 0 20px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  box-shadow: var(--m-shadow);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
</style>
