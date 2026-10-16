<template>
  <!-- Laid out like Concerns: on a tablet or computer the list sits beside the
       announcement you pick (see `.page-split` / `.desk-split` in app.scss). -->
  <q-page
    class="ann-page"
    :class="isTablet ? { 'page-split': true, 'page-wide desk-split': isDesktop } : 'ann-page--phone'"
  >
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: search pinned at the top of the list, not floating over it. -->
      <SearchDock
        v-if="isDesktop && !loading && mine.length"
        v-model="query"
        inline
        class="desk-search"
        :filter-count="filterCount"
        placeholder="Search announcements"
        search-label="Search announcements"
        @open-filters="filtersOpen = true"
      />
      <div v-if="loading" class="stack">
        <q-skeleton type="rect" height="120px" class="sk" />
        <q-skeleton type="rect" height="70px" class="sk" />
      </div>

      <EmptyState
        v-else-if="!accommodations.length"
        icon="lucide:building-2"
        title="No accommodation yet"
        message="Add an accommodation first — announcements go to the boarders of one of your houses."
      />

      <div v-else class="stack">
        <section class="sec">
          <EmptyState
            v-if="!mine.length"
            variant="compact"
            icon="lucide:megaphone"
            title="Nothing sent yet"
            message="Notices you send your boarders are listed here."
          />
          <EmptyState
            v-else-if="!visible.length"
            variant="compact"
            icon="lucide:search-x"
            title="Nothing matches"
            message="Try a different search or filter."
          />
          <div v-for="a in visible" :key="a.id" class="item" :class="{ 'item--on': a.id === selectedId }">
            <!-- Opens beside the list on a tablet or computer; a phone keeps
                 the plain list it always had. -->
            <component
              :is="isTablet ? 'button' : 'div'"
              :type="isTablet ? 'button' : undefined"
              class="item-text"
              @click="isTablet && (selectedId = a.id)"
            >
              <span class="item-title">{{ a.title }}</span>
              <span class="item-meta">{{ houseName(a.accommodation_id) }} · {{ statusOf(a) }}</span>
            </component>
            <button type="button" class="item-act" aria-label="Remove announcement" @click="remove(a)">
              <IconifyIcon icon="lucide:trash-2" width="16" />
            </button>
          </div>
        </section>
      </div>

      <!-- Tablet and computer: the action is the footer of the list panel. -->
      <div v-if="isTablet && !loading && accommodations.length" class="new-bar desk-foot">
        <button type="button" class="fab fab--inline" @click="composeOpen = true">
          <IconifyIcon icon="lucide:megaphone" width="17" />
          New announcement
        </button>
      </div>
    </q-pull-to-refresh>

    <!-- Desktop: the form takes the right half, beside the list, rather than
         covering the whole screen. Its own close button puts the half back. -->
    <AnnouncementCompose
      v-if="composeOpen && isDesktop"
      class="desk-compose"
      :accommodations="accommodations"
      :submitting="sending"
      @close="composeOpen = false"
      @submit="send"
    />

    <SplitDetail
      v-else-if="isTablet"
      v-model:open="detailOpen"
      icon="lucide:megaphone"
      hint="Pick an announcement to read it"
    >
      <q-card v-if="selected" flat class="detail-sheet">
        <h2 class="detail-title">{{ selected.title }}</h2>
        <p class="detail-meta">{{ houseName(selected.accommodation_id) }} · {{ statusOf(selected) }}</p>
        <img v-if="selected.image_url" :src="selected.image_url" alt="" class="detail-img" />
        <p v-if="selected.summary" class="detail-summary">{{ selected.summary }}</p>
        <p class="detail-body">{{ selected.body }}</p>
        <div v-if="selected.event_at || selected.deadline_at || selected.location" class="detail-facts">
          <div v-if="selected.event_at" class="fact">
            <span class="fact-label">When</span>
            <span>{{ formatDate(selected.event_at) }}<template v-if="selected.event_end"> – {{ formatDate(selected.event_end) }}</template></span>
          </div>
          <div v-if="selected.deadline_at" class="fact">
            <span class="fact-label">Deadline</span>
            <span>{{ formatDate(selected.deadline_at) }}</span>
          </div>
          <div v-if="selected.location" class="fact">
            <span class="fact-label">Where</span>
            <span>{{ selected.location }}</span>
          </div>
        </div>
        <button type="button" class="detail-remove" @click="remove(selected)">
          <IconifyIcon icon="lucide:trash-2" width="15" />
          Remove announcement
        </button>
      </q-card>
    </SplitDetail>

    <!-- Outside the pull container: a fixed action must not travel with the
         gesture. Hidden while composing, since the overlay covers it anyway.
         Search rides the same band, with New announcement as its leading
         action (as Report a concern does on the student's Concerns). -->
    <SearchDock
      v-if="!isTablet && !loading && accommodations.length && !composeOpen"
      v-model="query"
      :filter-count="filterCount"
      :no-filters="!mine.length"
      placeholder="Search announcements"
      search-label="Search announcements"
      @open-filters="filtersOpen = true"
    >
      <template #action>
        <button type="button" class="dock-btn" aria-label="New announcement" @click="composeOpen = true">
          <IconifyIcon icon="lucide:megaphone" width="17" />
          <span class="dock-btn-label">New announcement</span>
        </button>
      </template>
    </SearchDock>

    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      @clear="status = 'all'; houseId = 'all'"
    >
      <div v-if="accommodations.length > 1" class="sheet-block">
        <span class="sheet-label">Property</span>
        <div class="m-chips">
          <button type="button" class="m-chip" :class="{ 'm-chip--on': houseId === 'all' }" @click="houseId = 'all'">
            All
          </button>
          <button
            v-for="h in accommodations"
            :key="h.id"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': houseId === h.id }"
            @click="houseId = h.id"
          >
            {{ h.name }}
          </button>
        </div>
      </div>
      <div class="sheet-block">
        <span class="sheet-label">Status</span>
        <div class="m-chips">
          <button
            v-for="f in STATUS_FILTERS"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': status === f.key }"
            @click="status = f.key"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
    </BottomSheet>

    <AnnouncementCompose
      v-if="composeOpen && !isDesktop"
      :accommodations="accommodations"
      :submitting="sending"
      @close="composeOpen = false"
      @submit="send"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { errorMessage } from '@/utils/errors'
import { formatDate } from '@/utils/format'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import EmptyState from '@/components/shared/EmptyState.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import SplitDetail from '@/components/shared/SplitDetail.vue'
import AnnouncementCompose, { type AnnouncementDraft } from '@/components/manager/AnnouncementCompose.vue'

// A landlord/landlady announcing to their own tenants. OSAS broadcasts leave
// accommodation_id null; setting it is what makes an announcement a house
// notice, and RLS uses that same column to decide who may write and read it.

type Accommodation = { id: string; name: string }
type Mine = {
  id: string
  title: string
  accommodation_id: string | null
  published_at: string | null
  expires_at: string | null
  summary: string | null
  body: string
  event_at: string | null
  event_end: string | null
  deadline_at: string | null
  location: string | null
  image_url: string | null
}

// Everything the list and the detail beside it show.
const MINE_COLUMNS =
  'id, title, accommodation_id, published_at, expires_at, summary, body, event_at, event_end, deadline_at, location, image_url'

const notify = useNotify()

const loading = ref(true)
const sending = ref(false)
const composeOpen = ref(false)
const userId = ref('')
const accommodations = ref<Accommodation[]>([])
const mine = ref<Mine[]>([])

// The announcement open beside the list (tablet and computer only).
const selectedId = ref('')
const selected = computed(() => mine.value.find((a) => a.id === selectedId.value) ?? null)
const detailOpen = computed({
  get: () => Boolean(selected.value),
  set: (open: boolean) => {
    if (!open) selectedId.value = ''
  },
})

function houseName(id: string | null) {
  return accommodations.value.find((a) => a.id === id)?.name ?? 'Your accommodation'
}

const STATUS_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'sent', label: 'Sent' },
  { key: 'scheduled', label: 'Scheduled' },
  { key: 'ended', label: 'Ended' },
  { key: 'draft', label: 'Draft' },
] as const
type StatusKey = Exclude<(typeof STATUS_FILTERS)[number]['key'], 'all'>

function statusKey(a: Mine): StatusKey {
  if (!a.published_at) return 'draft'
  if (new Date(a.published_at).getTime() > Date.now()) return 'scheduled'
  if (a.expires_at && new Date(a.expires_at).getTime() < Date.now()) return 'ended'
  return 'sent'
}

function statusOf(a: Mine) {
  const key = statusKey(a)
  if (key === 'draft') return 'Draft'
  if (key === 'ended') return 'Ended'
  return `${key === 'scheduled' ? 'Scheduled' : 'Sent'} ${formatDate(a.published_at)}`
}

const query = ref('')
const status = ref<(typeof STATUS_FILTERS)[number]['key']>('all')
const houseId = ref('all')
const filtersOpen = ref(false)
const filterCount = computed(() => Number(status.value !== 'all') + Number(houseId.value !== 'all'))

const visible = computed(() => {
  const q = query.value.trim().toLowerCase()
  return mine.value.filter((a) => {
    if (status.value !== 'all' && statusKey(a) !== status.value) return false
    if (houseId.value !== 'all' && a.accommodation_id !== houseId.value) return false
    if (!q) return true
    return [a.title, a.summary, a.body, a.location, houseName(a.accommodation_id)].some((t) => t?.toLowerCase().includes(q))
  })
})

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
      .eq('landlord_id', userId.value)
      .order('name'),
    supabase
      .from('announcements')
      .select(MINE_COLUMNS)
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
      .select(MINE_COLUMNS)
    if (error) throw error

    mine.value = [...((data ?? []) as Mine[]), ...mine.value]
    composeOpen.value = false
    const houses = draft.accommodationIds.length
    notify.success(
      draft.publishAt
        ? houses > 1 ? `Scheduled for ${houses} houses.` : 'Scheduled.'
        : houses > 1 ? `Sent to ${houses} houses.` : 'Sent to your boarders.',
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
  if (selectedId.value === a.id) selectedId.value = ''
  notify.success('Removed. Notifications already delivered stay in your boarders\' inbox.')
}
</script>

<style scoped>
/* Phone only: room round the list and under it for the floating button. The
   split layouts (tablet, desktop) set their own spacing. */
.ann-page--phone { padding: 12px 12px calc(86px + env(safe-area-inset-bottom, 0px)); }
.page-split .stack { padding: 12px; }

/* The announcement open beside the list. */
.item--on { border-color: var(--m-primary); background: var(--m-primary-soft); }
.item-text {
  padding: 0;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
}
button.item-text { cursor: pointer; }
.detail-sheet {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 18px;
  background: var(--m-surface);
}
.detail-title { margin: 0; color: var(--m-ink); font-size: 18px; font-weight: 700; }
.detail-meta { margin: 0; color: var(--m-muted); font-size: 12px; font-weight: 600; }
.detail-img { width: 100%; max-height: 260px; object-fit: cover; border-radius: var(--m-radius); }
.detail-summary { margin: 0; color: var(--m-ink); font-size: 14px; font-weight: 600; }
.detail-body { margin: 0; color: var(--m-text); font-size: 14px; line-height: 1.55; white-space: pre-line; }
.detail-facts {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
}
.fact { display: flex; justify-content: space-between; gap: 12px; padding: 9px 12px; font-size: 13px; }
.fact + .fact { border-top: 1px solid var(--m-border); }
.fact-label { color: var(--m-muted); font-weight: 600; }
.detail-remove {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  margin-top: 6px;
  padding: 8px 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: transparent;
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}

/* Desktop: "New announcement" pinned to the foot of the list's half — at the
   bottom of the half even when the list is short (margin-top: auto in a column
   that is at least the half's height), and stuck there when it is long. */
.page-split :deep(.q-pull-to-refresh__content) {
  display: flex;
  min-height: 100%;
  flex-direction: column;
}
.new-bar {
  position: sticky;
  bottom: 0;
  margin-top: auto;
  z-index: 3;
  padding: 10px 12px 12px;
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
/* .new-bar in front: .fab (the phone's floating button) is declared further down
   with the same weight and would otherwise pin this one to the window. */
.new-bar .fab--inline {
  position: static;
  width: 100%;
  justify-content: center;
  box-shadow: none;
}
.stack { display: flex; flex-direction: column; gap: 12px; }
.sk { border-radius: var(--m-radius); }

.sec { display: flex; flex-direction: column; gap: 6px; }
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
  left: var(--m-page-gutter);
  bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  z-index: 60;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 52px;
  padding: 0 18px;
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
