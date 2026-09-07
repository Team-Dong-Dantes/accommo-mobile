<template>
  <q-page class="history-page">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="40px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your history</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="tabbed">
        <div class="tabs">
          <button type="button" class="tab" :class="{ 'tab--on': tab === 'reviews' }" @click="tab = 'reviews'">
            Reviews
          </button>
          <button type="button" class="tab" :class="{ 'tab--on': tab === 'payments' }" @click="tab = 'payments'">
            Payments
          </button>
        </div>

        <div class="panel">
          <q-tab-panels v-model="tab" animated swipeable class="panels">
            <q-tab-panel name="reviews" class="tab-panel">
              <template v-if="reviews.length">
                <div class="rating-summary">
                  <StarRating :model-value="avgRating" :size="18" />
                  <span class="rating-count">{{ avgRating.toFixed(1) }} · {{ reviews.length }} review{{ reviews.length === 1 ? '' : 's' }}</span>
                </div>
                <div class="chips">
                  <button
                    v-for="f in REVIEW_FILTERS"
                    :key="f.key"
                    type="button"
                    class="chip"
                    :class="{ 'chip--on': reviewFilter === f.key }"
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
                      <span class="review-author">{{ r.authorName }} <span class="review-source">· {{ r.source }}</span></span>
                      <StarRating :model-value="r.rating" :size="13" />
                      <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chevron" />
                    </div>
                    <p v-if="r.comment" class="review-comment">{{ r.comment }}</p>
                  </button>
                </div>
                <p v-else class="empty-message">Nothing matches your search or filters.</p>
              </template>
              <p v-else class="empty-message">No reviews yet.</p>
            </q-tab-panel>

            <q-tab-panel name="payments" class="tab-panel">
              <template v-if="payments.length">
                <div v-if="paymentProperties.length > 1" class="chips">
                  <button
                    type="button"
                    class="chip"
                    :class="{ 'chip--on': propertyFilter === 'all' }"
                    @click="propertyFilter = 'all'"
                  >
                    All
                  </button>
                  <button
                    v-for="name in paymentProperties"
                    :key="name"
                    type="button"
                    class="chip"
                    :class="{ 'chip--on': propertyFilter === name }"
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
                <p v-else class="empty-message">Nothing matches your search or filters.</p>
              </template>
              <p v-else class="empty-message">No payments yet.</p>
            </q-tab-panel>
          </q-tab-panels>
        </div>
      </div>
    </div>

    <!-- Search sits on the FAB's baseline so the two read as one control band
         on a tab-shell page — but History is a subpage (no FAB, no bottom
         nav), so it just spans the full width instead of reserving FAB room. -->
    <div v-if="!loading && !error" class="dock">
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input
          v-model="query"
          class="dock-input"
          type="search"
          :placeholder="tab === 'payments' ? 'Search tenant, room or month' : 'Search reviews'"
          aria-label="Search"
        />
      </div>
      <button
        type="button"
        class="dock-btn"
        :class="{ 'dock-btn--on': (tab === 'reviews' ? reviewDateFilter : filter) !== 'all' }"
        aria-label="Filters"
        @click="filtersOpen = true"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
        <span v-if="(tab === 'reviews' ? reviewDateFilter : filter) !== 'all'" class="dock-dot">1</span>
      </button>
    </div>

    <q-dialog v-model="filtersOpen" position="bottom">
      <div class="sheet">
        <div class="sheet-head">
          <h2 class="sheet-title">Filters</h2>
          <button type="button" class="sheet-clear" @click="tab === 'reviews' ? (reviewDateFilter = 'all') : (filter = 'all')">Reset</button>
        </div>
        <div v-if="tab === 'reviews'" class="sheet-block">
          <span class="sheet-label">Date</span>
          <div class="chips">
            <button
              v-for="f in REVIEW_DATE_FILTERS"
              :key="f.key"
              type="button"
              class="chip"
              :class="{ 'chip--on': reviewDateFilter === f.key }"
              @click="reviewDateFilter = f.key"
            >
              {{ f.label }}
            </button>
          </div>
        </div>
        <div v-else class="sheet-block">
          <span class="sheet-label">Status</span>
          <div class="chips">
            <button
              v-for="f in PAYMENT_FILTERS"
              :key="f.key"
              type="button"
              class="chip"
              :class="{ 'chip--on': filter === f.key }"
              @click="filter = f.key"
            >
              {{ f.label }}
            </button>
          </div>
        </div>
        <button type="button" class="sheet-done" @click="filtersOpen = false">Done</button>
      </div>
    </q-dialog>

    <q-dialog v-model="reviewDetailOpen" position="bottom">
      <q-card v-if="reviewDetailTarget" class="detail-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="detail-title">
          {{ reviewDetailTarget.authorName }} <span class="review-source">· {{ reviewDetailTarget.source }}</span>
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
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import StarRating from '@/components/shared/StarRating.vue'
import { formatPeso, formatMonth, formatDate, initialsOf, PAYMENT_STATUS, statusText, statusColor } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'

interface Review {
  id: string
  rating: number
  comment: string
  createdAt: string
  authorName: string
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
  if (q) list = list.filter((r) => `${r.authorName} ${r.source} ${r.comment}`.toLowerCase().includes(q))
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

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: accommodations } = await supabase
      .from('accommodations')
      .select('id')
      .eq('accommodation_manager_id', user.id)
    const accommodationIds = (accommodations || []).map((a) => a.id)

    const [{ data: managerReviews }, { data: accReviews }, { data: paymentRows }] = await Promise.all([
      supabase
        .from('accommodation_manager_reviews')
        .select('id, rating, comment, created_at, users!accommodation_manager_reviews_student_id_fkey(full_name)')
        .eq('accommodation_manager_id', user.id)
        .order('created_at', { ascending: false }),
      accommodationIds.length
        ? supabase
            .from('accommodation_reviews')
            .select('id, rating, comment, created_at, accommodations(name), users!accommodation_reviews_student_id_fkey(full_name)')
            .in('accommodation_id', accommodationIds)
            .order('created_at', { ascending: false })
        : Promise.resolve({ data: [] as never[] }),
      supabase
        .from('payments')
        .select(
          'id, month, amount, status, leases!inner(id, accommodation_manager_id, users!leases_student_id_fkey(full_name, avatar_color, avatar_url), rooms(room_number, label, accommodations(name)))',
        )
        .eq('leases.accommodation_manager_id', user.id)
        .order('month', { ascending: false }),
    ])

    const fromManager = (managerReviews ?? []).map((r) => ({
      id: r.id,
      rating: r.rating,
      comment: r.comment || '',
      createdAt: r.created_at,
      authorName: (r.users as unknown as { full_name: string | null } | null)?.full_name || 'A student',
      source: 'You',
      kind: 'user' as const,
    }))
    const fromAcc = (accReviews ?? []).map((r) => ({
      id: r.id,
      rating: r.rating,
      comment: r.comment || '',
      createdAt: r.created_at,
      authorName: (r.users as unknown as { full_name: string | null } | null)?.full_name || 'A student',
      source: (r.accommodations as unknown as { name: string | null } | null)?.name || 'A property',
      kind: 'property' as const,
    }))
    reviews.value = [...fromManager, ...fromAcc].sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))

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
        avatarUrl: lease.users?.avatar_url ? resolveAsset(lease.users.avatar_url) : null,
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

onMounted(load)
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

/* Same rounded-top pill tabs fused into a bordered panel used by
   AccommodationDetail.vue / TenantProfile.vue / ManagerTenantsPage.vue —
   the default tabbed-section design for this app. */
.tabbed {
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
.tab {
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-bottom: none;
  border-radius: 10px 10px 0 0;
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  transition: background-color 0.15s ease, color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  background: var(--m-surface);
  color: var(--m-primary-dark);
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
.panels {
  background: transparent;
}
.panels :deep(.q-tab-panel) {
  padding: 0;
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
.empty-message {
  margin: 0;
  font-size: 13px;
  color: var(--m-muted);
  text-align: center;
  padding: 16px 0;
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
.dock {
  position: fixed;
  bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  left: var(--m-page-gutter);
  right: var(--m-page-gutter);
  z-index: 60;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dock-field {
  position: relative;
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
}
.dock-icon {
  position: absolute;
  left: 13px;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  height: 44px;
  padding: 0 14px 0 35px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.dock-btn {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 50%;
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.dock-btn--on {
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.dock-dot {
  position: absolute;
  top: -2px;
  right: -2px;
  display: grid;
  min-width: 17px;
  height: 17px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}

/* Filter sheet */
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 14px;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
  background: var(--m-surface);
}
.sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.sheet-clear {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.sheet-block {
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.sheet-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.chip {
  padding: 6px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.sheet-done {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}

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
