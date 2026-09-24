<template>
  <q-page class="history-page" :class="{ 'page-wide': split }">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <q-skeleton type="rect" height="40px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your history" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <!-- Desktop: one search above the card; it searches both halves. -->
        <SearchDock
          v-if="split"
          v-model="query"
          inline
          class="desk-search desk-search--above"
          :filter-count="deskFilterCount"
          placeholder="Search ratings, tenants, rooms or months"
          search-label="Search"
          @open-filters="filtersOpen = true"
        />
        <div class="m-tabbed">
          <div v-if="!split" class="tabs">
            <button type="button" class="m-tab" :class="{ 'm-tab--on': tab === 'reviews' }" @click="tab = 'reviews'">
              Ratings
            </button>
            <button type="button" class="m-tab" :class="{ 'm-tab--on': tab === 'payments' }" @click="tab = 'payments'">
              Payments
            </button>
          </div>

          <div :class="split ? 'desk-card' : 'panel'">
            <component :is="panelsIs" v-bind="panelsProps" :class="split ? 'desk-contents' : 'm-panels'">
              <component :is="panelIs" name="reviews" :class="split ? 'desk-col' : 'tab-panel'">
                <h2 v-if="split" class="desk-col-title">Ratings</h2>
                <template v-if="reviews.length">
                  <div class="rating-summary">
                    <StarRating :model-value="avgRating" :size="18" />
                    <span class="rating-count">{{ avgRating.toFixed(1) }} · {{ reviews.length }} rating{{ reviews.length === 1 ? '' : 's' }}</span>
                  </div>
                  <div class="m-chips">
                    <button
                      v-for="f in REVIEW_FILTERS"
                      :key="f.key"
                      type="button"
                      class="m-chip"
                      :class="{ 'm-chip--on': reviewFilter === f.key }"
                      @click="reviewFilter = f.key"
                    >
                      {{ f.label }}
                    </button>
                  </div>
                  <div v-if="visibleReviews.length" class="group">
                    <button
                      v-for="r in visibleReviews"
                      :key="r.id"
                      type="button"
                      class="review-row"
                      @click="reviewDetailTarget = r; reviewDetailOpen = true"
                    >
                      <div class="review-top">
                        <span class="review-author">Anonymous <span class="review-source">· {{ r.source }}</span></span>
                        <StarRating :model-value="r.rating" :size="13" />
                        <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chevron" />
                      </div>
                      <p v-if="r.comment" class="review-comment">{{ r.comment }}</p>
                    </button>
                  </div>
                  <EmptyState v-else variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search or filter." />
                </template>
                <EmptyState v-else variant="compact" icon="lucide:star" title="No ratings yet" message="Ratings from past tenants will show up here." />
              </component>

              <component :is="panelIs" name="payments" :class="split ? 'desk-col' : 'tab-panel'">
                <h2 v-if="split" class="desk-col-title">Payments</h2>
                <template v-if="payments.length">
                  <div v-if="paymentProperties.length > 1" class="m-chips">
                    <button
                      type="button"
                      class="m-chip"
                      :class="{ 'm-chip--on': propertyFilter === 'all' }"
                      @click="propertyFilter = 'all'"
                    >
                      All
                    </button>
                    <button
                      v-for="name in paymentProperties"
                      :key="name"
                      type="button"
                      class="m-chip"
                      :class="{ 'm-chip--on': propertyFilter === name }"
                      @click="propertyFilter = name"
                    >
                      {{ name }}
                    </button>
                  </div>
                  <div v-if="visiblePayments.length" class="group">
                    <button
                      v-for="p in visiblePayments"
                      :key="p.id"
                      type="button"
                      class="pay-row"
                      @click="router.push(`/manager/tenant/${p.leaseId}`)"
                    >
                      <span class="pay-avatar" :class="p.avatarColor ? [`bg-${p.avatarColor}`, 'text-white'] : []">
                        <img v-if="p.avatarUrl" :src="p.avatarUrl" alt="" class="pay-avatar-img" @error="p.avatarUrl = null" />
                        <template v-else>{{ initialsOf(p.studentName) }}</template>
                      </span>
                      <span class="pay-body">
                        <span class="pay-name">{{ p.studentName }}</span>
                        <span class="pay-sub">{{ p.roomLabel }} · {{ formatMonth(p.month) }}</span>
                      </span>
                      <span class="pay-side">
                        <span class="pay-amount">{{ formatPeso(p.amount) }}</span>
                        <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                          {{ statusText(PAYMENT_STATUS, p.status) }}
                        </span>
                      </span>
                      <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chevron" />
                    </button>
                  </div>
                  <EmptyState v-else variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search or filter." />
                </template>
                <EmptyState v-else variant="compact" icon="lucide:receipt" title="No payments yet" message="Payments you log against a tenant will be listed here." />
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
      v-model="query"
      :filter-count="(tab === 'reviews' ? reviewDateFilter : filter) !== 'all' ? 1 : 0"
      :placeholder="tab === 'payments' ? 'Search tenant, room or month' : 'Search ratings'"
      search-label="Search"
      @open-filters="filtersOpen = true"
    />

    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      @clear="clearFilters"
    >
      <!-- One section per tab on a phone; both on desktop, where both halves
           are on screen at once. -->
      <div v-if="split || tab === 'reviews'" class="sheet-block">
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
      <div v-if="split || tab === 'payments'" class="sheet-block">
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

    <q-dialog v-model="reviewDetailOpen" position="bottom">
      <q-card v-if="reviewDetailTarget" class="detail-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="detail-title">
          Anonymous <span class="review-source">· {{ reviewDetailTarget.source }}</span>
        </h3>
        <StarRating :model-value="reviewDetailTarget.rating" :size="20" />
        <p v-if="reviewDetailTarget.comment" class="detail-text">{{ reviewDetailTarget.comment }}</p>
        <p class="detail-sub">{{ formatDate(reviewDetailTarget.createdAt) }}</p>
        <q-btn unelevated rounded no-caps color="primary" class="detail-close" label="Close" @click="reviewDetailOpen = false" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useLiveData } from '@/utils/useLiveData'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import StarRating from '@/components/shared/StarRating.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { formatPeso, formatMonth, formatDate, initialsOf, PAYMENT_STATUS, statusText, statusColor } from '@/utils/format'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'

interface Review {
  id: string
  rating: number
  comment: string
  createdAt: string
  source: string
  kind: 'user' | 'property'
}
interface PaymentRow {
  id: string
  leaseId: string
  studentName: string
  avatarColor: string | null
  avatarUrl: string | null
  roomLabel: string
  accommodationName: string
  month: string
  amount: number
  status: string
}

const route = useRoute()
const router = useRouter()

const loading = ref(true)
const error = ref('')
const tab = ref(route.query.tab === 'payments' ? 'payments' : 'reviews')
// Desktop lays the tabs out as the halves of a card instead (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)

const reviews = ref<Review[]>([])
const payments = ref<PaymentRow[]>([])
const reviewDetailOpen = ref(false)
const reviewDetailTarget = ref<Review | null>(null)
const avgRating = computed(() => (reviews.value.length ? reviews.value.reduce((n, r) => n + r.rating, 0) / reviews.value.length : 0))

// Search applies to whichever tab is open; the status filter only means
// anything on Payments, so it's the only tab that reads it.
const query = ref('')
const filtersOpen = ref(false)

// Source (About me / Properties) and property-scope are cheap, always-useful
// toggles — kept inline above each list instead of behind the filter button,
// which is reserved for the filters that need a sheet to hold real options
// (a status set, a date range).
const reviewFilter = ref<'all' | 'user' | 'property'>('all')
const REVIEW_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'user', label: 'About me' },
  { key: 'property', label: 'Properties' },
] as const
const propertyFilter = ref('all')
const paymentProperties = computed(() => [...new Set(payments.value.map((p) => p.accommodationName).filter(Boolean))])

// Behind the filter button: reviews get a date range, payments keep their
// status set — both have more than a couple of real options.
const reviewDateFilter = ref<'all' | '30d' | '90d' | 'year'>('all')
const REVIEW_DATE_FILTERS = [
  { key: 'all', label: 'All time' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 3 months' },
  { key: 'year', label: 'This year' },
] as const
const filter = ref<'all' | 'paid' | 'pending_verification' | 'rejected' | 'due' | 'overdue'>('all')
const PAYMENT_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'paid', label: 'Paid' },
  { key: 'pending_verification', label: 'Pending' },
  { key: 'rejected', label: 'Rejected' },
  { key: 'due', label: 'Due' },
  { key: 'overdue', label: 'Overdue' },
] as const

function withinDateFilter(iso: string, key: typeof reviewDateFilter.value): boolean {
  if (key === 'all') return true
  const then = new Date(iso).getTime()
  if (key === '30d') return Date.now() - then <= 30 * 86400000
  if (key === '90d') return Date.now() - then <= 90 * 86400000
  return new Date(iso).getFullYear() === new Date().getFullYear()
}

const visibleReviews = computed(() => {
  let list = reviews.value
  if (reviewFilter.value !== 'all') list = list.filter((r) => r.kind === reviewFilter.value)
  if (reviewDateFilter.value !== 'all') list = list.filter((r) => withinDateFilter(r.createdAt, reviewDateFilter.value))
  const q = query.value.trim().toLowerCase()
  if (q) list = list.filter((r) => `${r.source} ${r.comment}`.toLowerCase().includes(q))
  return list
})
const visiblePayments = computed(() => {
  let list = payments.value
  if (propertyFilter.value !== 'all') list = list.filter((p) => p.accommodationName === propertyFilter.value)
  if (filter.value !== 'all') list = list.filter((p) => p.status === filter.value)
  const q = query.value.trim().toLowerCase()
  if (q) list = list.filter((p) => `${p.studentName} ${p.roomLabel} ${formatMonth(p.month)}`.toLowerCase().includes(q))
  return list
})

watch(tab, () => {
  query.value = ''
  filter.value = 'all'
  reviewFilter.value = 'all'
  reviewDateFilter.value = 'all'
  propertyFilter.value = 'all'
})

// The sheet's Clear: the open tab's filter on a phone, both on desktop.
function clearFilters() {
  if (split.value || tab.value === 'reviews') reviewDateFilter.value = 'all'
  if (split.value || tab.value === 'payments') filter.value = 'all'
}
const deskFilterCount = computed(() =>
  [reviewDateFilter.value, filter.value].filter((f) => f !== 'all').length,
)

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

    const [{ data: inboxRows }, { data: paymentRows }] = await Promise.all([
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
        .select(
          'id, month, amount, status, leases!inner(id, landlord_id, users!leases_student_id_fkey(full_name, avatar_color, avatar_url), rooms(room_number, label, accommodations(name)))',
        )
        .eq('leases.landlord_id', user.id)
        .order('month', { ascending: false }),
    ])

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

    payments.value = (paymentRows ?? []).map((p) => {
      const lease = p.leases as unknown as {
        id: string
        users: { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
        rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
      }
      const room = lease.rooms
      const accommodationName = room?.accommodations?.name || ''
      return {
        id: p.id,
        leaseId: lease.id,
        studentName: lease.users?.full_name || 'A student',
        avatarColor: lease.users?.avatar_color ?? null,
        avatarUrl: lease.users?.avatar_url ? resolveAsset(lease.users.avatar_url, AVATAR) : null,
        roomLabel: [room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room'), accommodationName]
          .filter(Boolean)
          .join(' · '),
        accommodationName,
        month: p.month,
        amount: Number(p.amount),
        status: p.status,
      }
    })
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
  padding: 14px 14px 84px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  overflow: hidden;
}

.rating-summary {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 2px;
}
.rating-count {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.review-row {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 2px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .review-row:first-child {
  border-top: 0;
}
.review-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.review-author {
  flex: 1;
  min-width: 0;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.row-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.review-source {
  color: var(--m-muted);
  font-weight: 600;
}
.review-comment {
  margin: 0;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.5;
}

.pay-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .pay-row:first-child {
  border-top: 0;
}
.pay-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}
.pay-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.pay-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.pay-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.pay-sub {
  color: var(--m-muted);
  font-size: 11.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pay-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.pay-amount {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pay-chip {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.pay-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-chip--amber,
.pay-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}

/* Docked search — this page is a subpage (no bottom nav, no FAB), so it
   spans the full width instead of reserving room for a FAB that isn't here. */

/* Filter sheet */

.sheet-grip {
  display: block;
  width: 40px;
  height: 4px;
  margin: 0 auto;
  border-radius: 999px;
  background: var(--m-border);
}
.detail-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 14px 16px 18px;
  border-radius: 16px 16px 0 0;
  background: var(--m-surface, #fff);
}
.detail-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.detail-sub {
  margin: 0;
  color: var(--m-muted);
  font-size: 11.5px;
}
.detail-close {
  min-height: 46px;
  margin-top: 6px;
  font-weight: 700;
}
</style>
