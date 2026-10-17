<template>
  <q-page class="history-page" :class="{ 'page-wide': split }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded shape — the way back live already above a card
           showing one tab at a time, with its own search. -->
      <div v-if="loading && split" class="stack">
        <div class="desk-back-row">
          <button type="button" class="desk-panel-back" :aria-label="backLabel" @click="goBack">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </button>
          <span class="desk-panel-title">{{ backLabel }}</span>
        </div>
        <div class="desk-card desk-card--tabbed">
          <div class="desk-col">
            <q-skeleton type="rect" height="40px" class="sk sk-search" />
            <q-skeleton type="rect" height="90px" class="sk" />
            <q-skeleton type="rect" height="90px" class="sk" />
          </div>
        </div>
      </div>

      <div v-else-if="loading" class="stack">
        <q-skeleton type="rect" height="40px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your history" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <!-- Desktop: the way back sits just above the card, as on an
             accommodation; the app header stays the plain one (see OWN_BACK
             in MainLayout). -->
        <div v-if="split" class="desk-back-row">
          <button type="button" class="desk-panel-back" :aria-label="backLabel" @click="goBack">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </button>
          <span class="desk-panel-title">{{ backLabel }}</span>
        </div>
        <div class="m-tabbed">
          <div class="tabs" role="tablist" aria-label="History">
            <button
              v-for="t in TABS"
              :key="t.key"
              type="button"
              role="tab"
              class="m-tab"
              :class="{ 'm-tab--on': tab === t.key }"
              :aria-selected="tab === t.key"
              @click="tab = t.key"
            >
              {{ t.label }}
            </button>
          </div>

          <!-- Desktop: still tabs, not halves side by side — three lists squeezed
               into a third of the card each were too narrow to read. -->
          <div :class="split ? 'desk-card desk-card--tabbed' : 'panel'">
            <component :is="panelsIs" v-bind="panelsProps" :class="split ? 'desk-contents' : 'm-panels'">
              <component :is="panelIs" v-for="t in TABS" v-show="!split || tab === t.key" :key="t.key" :name="t.key" :class="split ? 'desk-col' : 'tab-panel'">
                <!-- Desktop: each tab searches and filters only itself. -->
                <SearchDock
                  v-if="split"
                  v-model="queries[t.key]"
                  inline
                  class="desk-search"
                  :no-filters="t.key === 'boarders'"
                  :filter-count="filterCount(t.key)"
                  :placeholder="placeholders[t.key]"
                  search-label="Search"
                  @open-filters="openFilters(t.key)"
                />
                <BoarderHistoryTab v-if="t.key === 'boarders'" :money="money" :reviews="written" :query="queries.boarders" />
                <ManagerRatingsTab v-else-if="t.key === 'reviews'" :reviews="reviews" :query="queries.reviews" :date-filter="reviewDateFilter" />
                <ManagerPaymentsTab v-else :payments="payments" :leases="money.leases" :query="queries.payments" :status="filter" />
              </component>
            </component>
          </div>
        </div>
      </div>
</q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band
         on a tab-shell page — but History is a subpage (no FAB, no bottom
         nav), so it just spans the full width instead of reserving FAB room.
         Outside the pull-to-refresh wrapper on purpose: it transforms its
         content while you pull, which would drag this fixed dock along. -->
    <SearchDock
      v-if="!loading && !error && !split"
      v-model="queries[tab]"
      :no-filters="tab === 'boarders'"
      :filter-count="filterCount(tab)"
      :placeholder="placeholders[tab]"
      search-label="Search"
      @open-filters="openFilters(tab)"
    />

    <BottomSheet v-model="filtersOpen" title="Filters" @clear="clearFilters">
      <!-- One section: the open tab's on a phone, the half's own on desktop. -->
      <div v-if="sheetFor === 'reviews'" class="sheet-block">
        <span class="sheet-label">Date</span>
        <div class="m-chips">
          <button
            v-for="f in REVIEW_DATE_FILTERS"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': reviewDateFilter === f.key }"
            @click="reviewDateFilter = f.key"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
      <div v-if="sheetFor === 'payments'" class="sheet-block">
        <span class="sheet-label">Status</span>
        <div class="m-chips">
          <button
            v-for="f in PAYMENT_FILTERS"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': filter === f.key }"
            @click="filter = f.key"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
    </BottomSheet>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onActivated } from 'vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useLiveData } from '@/utils/useLiveData'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { fetchLandlordMoney, type LandlordMoney } from '@/api/landlordMoney'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import BoarderHistoryTab from '@/components/manager/BoarderHistoryTab.vue'
import ManagerRatingsTab from '@/components/manager/ManagerRatingsTab.vue'
import ManagerPaymentsTab from '@/components/manager/ManagerPaymentsTab.vue'
import type { DateFilter, PayRow, Review } from '@/components/manager/managerHistory'

type TabKey = 'boarders' | 'reviews' | 'payments'
const TABS: { key: TabKey; label: string }[] = [
  { key: 'boarders', label: 'Boarder history' },
  { key: 'reviews', label: 'Ratings' },
  { key: 'payments', label: 'Payments' },
]
const placeholders: Record<TabKey, string> = {
  boarders: 'Search boarder or room',
  reviews: 'Search ratings',
  payments: 'Search boarder, room or month',
}

const route = useRoute()
const router = useRouter()
// Back to wherever History was opened from (Settings, or a View-all link);
// Settings on a fresh load with nothing behind it. Read on every visit, not
// once at setup: the page is kept alive, so where it was opened from changes.
const BACK_LABELS: Record<string, string> = {
  '/manager/settings': 'settings',
  '/manager/tenants': 'my boarders',
  '/manager/notifications': 'notifications',
}
const backPath = ref<string | null>(null)
function readBack() {
  backPath.value = window.history.state?.back ?? null
}
readBack()
onActivated(readBack)
const backLabel = computed(() => {
  if (!backPath.value) return 'Back to settings'
  const name = BACK_LABELS[backPath.value.split('?')[0] ?? '']
  return name ? `Back to ${name}` : 'Back'
})
function goBack() {
  if (backPath.value) router.back()
  else void router.push('/manager/settings')
}

const loading = ref(true)
const error = ref('')
// Boarder history is the front door; ?tab=payments (and reviews) still land
// where older links pointed.
const tabFromRoute = (): TabKey => (route.query.tab === 'payments' ? 'payments' : route.query.tab === 'reviews' ? 'reviews' : 'boarders')
const tab = ref<TabKey>(tabFromRoute())
// The page is kept alive, so a later visit with a different ?tab= must follow it.
watch(() => route.query.tab, () => {
  if (route.path === '/manager/profile/history') tab.value = tabFromRoute()
})
// Desktop puts the panels in a card, still one tab at a time (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)

const reviews = ref<Review[]>([])
const payments = ref<PayRow[]>([])
const money = ref<LandlordMoney>({ leases: [], ledger: [], payments: [], billUtility: {}, billed: new Set(), rooms: [] })
// The ratings this landlord/landlady wrote about past boarders, by lease.
const written = ref<Record<string, { rating: number; comment: string }>>({})

// One search per tab — the open tab's on a phone, each half's own on desktop.
const queries = reactive<Record<TabKey, string>>({ boarders: '', reviews: '', payments: '' })
const filtersOpen = ref(false)
// Which list the filter sheet is for: the open tab, or the half it was opened from.
const sheetFor = ref<TabKey>('reviews')
function openFilters(t: TabKey) {
  sheetFor.value = t
  filtersOpen.value = true
}

// Behind the filter button: ratings get a date range, payments a status set —
// both have more than a couple of real options. Source (About you / a property)
// stays inline above the ratings, and the year and property pickers sit in
// each tab, since those are cheap toggles.
const reviewDateFilter = ref<DateFilter>('all')
const REVIEW_DATE_FILTERS = [
  { key: 'all', label: 'All time' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 3 months' },
  { key: 'year', label: 'This year' },
] as const
// Only finished payments are listed (paid, forgiven, rejected); the rest is on Monthly rent.
const filter = ref<'all' | 'paid' | 'waived' | 'rejected'>('all')
const PAYMENT_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'paid', label: 'Paid' },
  { key: 'waived', label: 'Forgiven' },
  { key: 'rejected', label: 'Rejected' },
] as const

function filterCount(t: TabKey) {
  if (t === 'reviews') return reviewDateFilter.value !== 'all' ? 1 : 0
  if (t === 'payments') return filter.value !== 'all' ? 1 : 0
  return 0
}

watch(tab, () => {
  queries.boarders = ''
  queries.reviews = ''
  queries.payments = ''
  filter.value = 'all'
  reviewDateFilter.value = 'all'
})

// The sheet's Clear: only the list the sheet is for.
function clearFilters() {
  if (sheetFor.value === 'reviews') reviewDateFilter.value = 'all'
  else filter.value = 'all'
}

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: auth } = await authUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const [moneyData, { data: inboxRows }, { data: paymentRows }, { data: writtenRows }] = await Promise.all([
      fetchLandlordMoney(user.id),
      // Reviews received, about this landlord/landlady and about their accommodations.
      // `review_inbox` scopes to the caller and carries no reviewer identity —
      // reviews are anonymous to the person being reviewed, and the base tables
      // are no longer readable, so there is nothing to join a name from.
      supabase
        .from('review_inbox')
        .select('id, kind, rating, comment, created_at, accommodation_name')
        .in('kind', ['manager', 'accommodation'])
        .order('created_at', { ascending: false }),
      supabase
        .from('payments')
        .select('id, lease_id, month, amount, status, method, description, created_at, paid_at, leases!inner(landlord_id)')
        .eq('leases.landlord_id', user.id)
        .in('status', ['paid', 'waived', 'rejected'])
        .order('created_at', { ascending: false }),
      supabase.from('review_written_leases').select('lease_id, rating, comment').eq('kind', 'tenant'),
    ])

    money.value = moneyData
    written.value = Object.fromEntries(
      (writtenRows ?? []).filter((r) => r.lease_id).map((r) => [r.lease_id as string, { rating: r.rating ?? 0, comment: r.comment || '' }]),
    )

    reviews.value = (inboxRows ?? [])
      .map((r) => ({
        id: r.id ?? '',
        rating: r.rating ?? 0,
        comment: r.comment || '',
        createdAt: r.created_at ?? '',
        source: r.kind === 'manager' ? 'You' : r.accommodation_name || 'A property',
        kind: r.kind === 'manager' ? ('user' as const) : ('property' as const),
      }))
      .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))

    payments.value = (paymentRows ?? []).map((p) => ({
      id: p.id,
      leaseId: p.lease_id,
      amount: Number(p.amount),
      status: p.status,
      method: p.method,
      description: p.description,
      month: p.month,
      at: p.paid_at || p.created_at,
    }))
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

// Not kept alive and with no realtime watch behind it, so a pull is the only
// way to see anything that changed since the screen was opened.
function onPull(done: () => void) {
  void refresh().finally(done)
}

// Kept alive across navigation (see MainLayout KEEP_ALIVE_PAGES), so returning
// to this screen no longer refetches the whole history every time. No realtime
// watch on purpose: this is a record of things that already happened, and the
// two-minute TTL plus pull-to-refresh is all the freshness it needs.
const { refresh } = useLiveData({ key: 'manager-history', load, ttl: 120_000 })

</script>

<style scoped>
.history-page {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 12px;
  padding: 10px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
/* Stands in for a half's own search (.desk-search). */
.sk-search {
  border-radius: 999px;
}
.card {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}

/* Same rounded-top pill tabs fused into a bordered panel used by
   AccommodationDetail.vue / TenantProfile.vue / ManagerTenantsPage.vue —
   the default tabbed-section design for this app. */
/* QPullToRefresh wraps the page body in two plain <div>s of its own, which
   land between the q-page and .stack and break the flex chain the bottom-flush
   panel needs — .stack's flex:1 measures against a block box that just hugs its
   content, so the card stops wherever the content happens to end. Passing the
   chain through them costs nothing: neither div clips or scrolls. */
:deep(.q-pull-to-refresh),
:deep(.q-pull-to-refresh__content) {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
}
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
}
.panel {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  margin: 0 calc(var(--m-page-gutter) * -1);
  /* Extra bottom room so the last row isn't hidden under the fixed dock —
     this page has no bottom nav/FAB to clear, just the dock itself. */
  /* No side padding here: each tab carries its own (.m-panels .tab-panel).
     QTabPanels clips its overflow for the swipe, so with the 14px on this box
     the tabs' full-width sections (margin: 0 -14px — Ratings, Payments, the
     past-boarders list) were cut off at both edges. */
  padding: 14px 0 84px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
/* Beats _controls.scss's `.m-panels .q-tab-panel { padding: 0 }`. */
.m-panels .tab-panel {
  padding: 0 14px;
}
/* Docked search — this page is a subpage (no bottom nav, no FAB), so it
   spans the full width instead of reserving room for a FAB that isn't here. */

/* Filter sheet */
</style>
