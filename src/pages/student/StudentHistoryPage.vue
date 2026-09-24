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
        <!-- Desktop: one search above the card; it searches every half. -->
        <SearchDock
          v-if="split"
          v-model="query"
          inline
          class="desk-search desk-search--above"
          :filter-count="deskFilterCount"
          placeholder="Search stays, ratings and payments"
          search-label="Search"
          @open-filters="filtersOpen = true"
        />
        <div class="m-tabbed">
          <div v-if="!split" class="tabs">
            <button type="button" class="m-tab" :class="{ 'm-tab--on': tab === 'history' }" @click="tab = 'history'">
              Boarding history
            </button>
            <button type="button" class="m-tab" :class="{ 'm-tab--on': tab === 'reviews' }" @click="tab = 'reviews'">
              Ratings
            </button>
            <button type="button" class="m-tab" :class="{ 'm-tab--on': tab === 'payments' }" @click="tab = 'payments'">
              Payments
            </button>
          </div>

          <div :class="split ? 'desk-card' : 'panel'">
            <component :is="panelsIs" v-bind="panelsProps" :class="split ? 'desk-contents' : 'm-panels'">
              <component :is="panelIs" name="history" :class="split ? 'desk-col' : 'tab-panel'">
                <h2 v-if="split" class="desk-col-title">Boarding history</h2>
                <div v-if="visibleHistory.length" class="group">
                  <div v-for="row in visibleHistory" :key="row.id" class="history-row">
                    <button type="button" class="history-info" @click="openHistoryDetail(row)">
                      <span class="history-text">
                        <span class="history-name">{{ row.name }}</span>
                        <span class="history-meta">{{ row.meta }}</span>
                      </span>
                      <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chevron" />
                    </button>
                    <div class="history-side">
                      <span class="history-when">{{ row.period }}</span>
                      <span v-if="row.reviewed" class="history-rated">Rated ✓</span>
                      <button v-else-if="row.leaseId" type="button" class="history-rate" @click="openReview(row)">Rate stay</button>
                    </div>
                  </div>
                </div>
                <EmptyState v-else-if="history.length" variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search or filter." />
                <EmptyState v-else variant="compact" icon="lucide:history" title="No stays yet" message="Once a stay ends, it lands here and you can rate it." />
              </component>

              <!-- Desktop: ratings sit below payments in the right half, moved there by
                   the Teleport (inside the panel, so QTabPanels still finds it). -->
              <component :is="panelIs" name="reviews" class="tab-panel" :class="{ 'desk-hidden': split }">
                <Teleport :to="paymentsCol" :disabled="!split || !paymentsCol">
                <div class="desk-moved">
                <h2 v-if="split" class="desk-col-title">Ratings</h2>
                <template v-if="visibleReviews.length">
                  <div class="rating-summary">
                    <StarRating :model-value="avgManagerRating" :size="18" />
                    <span class="rating-count">{{ avgManagerRating.toFixed(1) }} · {{ reviewsFromManagers.length }} rating{{ reviewsFromManagers.length === 1 ? '' : 's' }}</span>
                  </div>
                  <div class="group">
                    <button v-for="r in visibleReviews" :key="r.id" type="button" class="review-row" @click="openReviewDetail(r)">
                      <div class="review-top">
                        <span class="review-author">A past manager</span>
                        <StarRating :model-value="r.rating" :size="13" />
                        <IconifyIcon icon="lucide:chevron-right" width="15" class="row-chevron" />
                      </div>
                      <p v-if="r.comment" class="review-comment">{{ r.comment }}</p>
                    </button>
                  </div>
                </template>
                <EmptyState v-else-if="reviewsFromManagers.length" variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search or filter." />
                <EmptyState v-else variant="compact" icon="lucide:star" title="No ratings yet" message="Ratings a landlord/landlady leaves after a stay will show up here." />
              </div>
                </Teleport>
              </component>

              <component :is="panelIs" :ref="setPaymentsCol" name="payments" :class="split ? 'desk-col' : 'tab-panel'">
                <h2 v-if="split" class="desk-col-title">Payments</h2>
                <div v-if="visiblePayments.length" class="group">
                  <button v-for="p in visiblePayments" :key="p.id" type="button" class="pay-row" @click="openPaymentDetail(p)">
                    <span class="pay-icon"><IconifyIcon icon="lucide:receipt" width="16" /></span>
                    <span class="pay-body">
                      <span class="pay-month">{{ formatMonth(p.month) }}</span>
                      <span class="pay-method">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }} · {{ p.roomLabel }}, {{ p.accommodationName }}</span>
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
                <EmptyState v-else-if="payments.length" variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search or filter." />
                <EmptyState v-else variant="compact" icon="lucide:receipt" title="No payments yet" message="Rent payments you make will be recorded here." />
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
      :filter-count="activeFilter !== 'all' ? 1 : 0"
      :placeholder="tab === 'payments' ? 'Search month or method' : tab === 'reviews' ? 'Search ratings' : 'Search boarding history'"
      search-label="Search"
      @open-filters="filtersOpen = true"
    />

    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      @clear="clearFilters"
    >
      <!-- One section per tab on a phone; every section on desktop, where
           every half is on screen at once. -->
      <div v-if="split || tab === 'history'" class="sheet-block">
        <span class="sheet-label">Rated</span>
        <div class="m-chips">
          <button
            v-for="f in HISTORY_FILTERS"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': historyFilter === f.key }"
            @click="historyFilter = f.key"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
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

    <!-- Boarding history detail -->
    <q-dialog v-model="historyDetailOpen" position="bottom">
      <q-card v-if="historyDetailTarget" class="detail-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="detail-title">{{ historyDetailTarget.name }}</h3>
        <div class="group">
          <div class="rule">
            <span class="rule-label">Room type</span>
            <span class="rule-value">{{ historyDetailTarget.roomType || '—' }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Move-in</span>
            <span class="rule-value">{{ formatDate(historyDetailTarget.periodStart) }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Move-out</span>
            <span class="rule-value">{{ formatDate(historyDetailTarget.periodEnd) }}</span>
          </div>
          <div v-if="historyDetailTarget.endReason" class="rule">
            <span class="rule-label">Reason</span>
            <span class="rule-value">{{ titleCase(historyDetailTarget.endReason) }}</span>
          </div>
        </div>
        <q-btn
          v-if="!historyDetailTarget.reviewed && historyDetailTarget.leaseId"
          unelevated
          rounded
          no-caps
          color="primary"
          class="detail-close"
          label="Rate this stay"
          @click="historyDetailOpen = false; openReview(historyDetailTarget)"
        />
        <span v-else-if="historyDetailTarget.reviewed" class="history-rated">Rated ✓</span>
        <q-btn flat rounded no-caps color="grey-7" label="Close" @click="historyDetailOpen = false" />
      </q-card>
    </q-dialog>

    <!-- Review detail -->
    <q-dialog v-model="reviewDetailOpen" position="bottom">
      <q-card v-if="reviewDetailTarget" class="detail-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="detail-title">A past landlord/landlady</h3>
        <StarRating :model-value="reviewDetailTarget.rating" :size="20" />
        <p v-if="reviewDetailTarget.comment" class="detail-text">{{ reviewDetailTarget.comment }}</p>
        <p class="detail-sub">{{ formatDate(reviewDetailTarget.createdAt) }}</p>
        <q-btn unelevated rounded no-caps color="primary" class="detail-close" label="Close" @click="reviewDetailOpen = false" />
      </q-card>
    </q-dialog>

    <!-- Payment detail -->
    <q-dialog v-model="paymentDetailOpen" position="bottom">
      <q-card v-if="paymentDetailTarget" class="detail-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="detail-title">{{ formatMonth(paymentDetailTarget.month) }}</h3>
        <span class="detail-chip" :class="`detail-chip--${statusColor(PAYMENT_STATUS, paymentDetailTarget.status)}`">
          {{ statusText(PAYMENT_STATUS, paymentDetailTarget.status) }}
        </span>

        <div class="group">
          <div class="rule">
            <span class="rule-label">Amount</span>
            <span class="rule-value">{{ formatPeso(paymentDetailTarget.amount) }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Method</span>
            <span class="rule-value">{{ PAYMENT_METHOD_LABEL[paymentDetailTarget.method] || paymentDetailTarget.method }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Boarding house</span>
            <span class="rule-value">{{ paymentDetailTarget.accommodationName }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Room</span>
            <span class="rule-value">{{ paymentDetailTarget.roomLabel }}</span>
          </div>
          <div v-if="paymentDetailTarget.txnReference" class="rule">
            <span class="rule-label">Reference number</span>
            <span class="rule-value">{{ paymentDetailTarget.txnReference }}</span>
          </div>
          <div v-if="paymentDetailTarget.verifiedByName" class="rule">
            <span class="rule-label">Reviewed by</span>
            <span class="rule-value">
              {{ paymentDetailTarget.verifiedByName }}{{ paymentDetailTarget.paidAt ? ` · ${formatDate(paymentDetailTarget.paidAt)}` : '' }}
            </span>
          </div>
        </div>

        <template v-if="paymentDetailTarget.status === 'rejected' && paymentDetailTarget.rejectionReason">
          <p class="detail-label detail-label--danger">Rejection reason</p>
          <p class="detail-text">{{ paymentDetailTarget.rejectionReason }}</p>
        </template>

        <template v-if="paymentDetailTarget.description">
          <p class="detail-label">Note</p>
          <p class="detail-text">{{ paymentDetailTarget.description }}</p>
        </template>

        <template v-if="paymentDetailTarget.proofUrl">
          <p class="detail-label">Proof of payment</p>
          <img :src="resolveAsset(paymentDetailTarget.proofUrl)" alt="Proof of payment" class="proof-img" />
        </template>

        <q-btn unelevated rounded no-caps color="primary" class="detail-close" label="Close" @click="paymentDetailOpen = false" />
      </q-card>
    </q-dialog>

    <!-- Rate stay -->
    <q-dialog v-model="reviewOpen" position="bottom">
      <q-card v-if="reviewTarget" class="review-sheet">
        <h3 class="review-title">Rate your stay at {{ reviewTarget.name }}</h3>

        <div class="review-field">
          <span class="review-field-label">The place</span>
          <StarRating v-model="reviewForm.accRating" interactive :size="26" />
          <textarea v-model="reviewForm.accComment" class="review-textarea" rows="2" placeholder="What was it like? (optional)" />
        </div>

        <div class="review-field">
          <span class="review-field-label">The landlord/landlady</span>
          <StarRating v-model="reviewForm.managerRating" interactive :size="26" />
          <textarea v-model="reviewForm.managerComment" class="review-textarea" rows="2" placeholder="How were they to deal with? (optional)" />
        </div>

        <q-btn unelevated rounded no-caps color="primary" class="review-submit" :loading="submittingReview" label="Submit" @click="submitReview" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useLiveData } from '@/utils/useLiveData'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import StarRating from '@/components/shared/StarRating.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { period } from '@/utils/profile'
import { formatPeso, formatMonth, formatDate, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'

interface HistoryRow {
  id: string
  name: string
  meta: string
  period: string
  roomType: string
  endReason: string
  periodStart: string
  periodEnd: string
  accommodationId: string | null
  leaseId: string | null
  managerId: string | null
  reviewed: boolean
}
interface ManagerReview {
  id: string
  rating: number
  comment: string
  createdAt: string
}
interface PaymentRow {
  id: string
  month: string
  amount: number
  status: string
  method: string
  roomLabel: string
  accommodationName: string
  description: string
  txnReference: string
  proofUrl: string
  paidAt: string | null
  verifiedByName: string
  rejectionReason: string
}

const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const tab = ref('history')
// Desktop lays the tabs out as the halves of a card instead (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)
// The right half is the payments panel itself; ratings are moved in below them.
const paymentsCol = ref<HTMLElement | null>(null)
function setPaymentsCol(el: unknown) {
  paymentsCol.value = el instanceof HTMLElement ? el : null
}

const userId = ref('')
const studentName = ref('')

const history = ref<HistoryRow[]>([])
const reviewsFromManagers = ref<ManagerReview[]>([])
const payments = ref<PaymentRow[]>([])

const avgManagerRating = computed(() => {
  if (!reviewsFromManagers.value.length) return 0
  return reviewsFromManagers.value.reduce((n, r) => n + r.rating, 0) / reviewsFromManagers.value.length
})

// Search applies to whichever tab is open; each tab has its own filter
// dimension, keyed off `tab` so the dock/sheet can stay generic.
const query = ref('')
const filter = ref<'all' | 'paid' | 'pending_verification' | 'rejected' | 'due' | 'overdue'>('all')
const filtersOpen = ref(false)
const PAYMENT_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'paid', label: 'Paid' },
  { key: 'pending_verification', label: 'Pending' },
  { key: 'rejected', label: 'Rejected' },
  { key: 'due', label: 'Due' },
  { key: 'overdue', label: 'Overdue' },
] as const

const historyFilter = ref<'all' | 'rated' | 'unrated'>('all')
const HISTORY_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'rated', label: 'Rated' },
  { key: 'unrated', label: 'Not rated' },
] as const

const reviewDateFilter = ref<'all' | '30d' | '90d' | 'year'>('all')
const REVIEW_DATE_FILTERS = [
  { key: 'all', label: 'All time' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 3 months' },
  { key: 'year', label: 'This year' },
] as const

function withinDateFilter(iso: string, key: typeof reviewDateFilter.value): boolean {
  if (key === 'all') return true
  const then = new Date(iso).getTime()
  if (key === '30d') return Date.now() - then <= 30 * 86400000
  if (key === '90d') return Date.now() - then <= 90 * 86400000
  return new Date(iso).getFullYear() === new Date().getFullYear()
}

const activeFilter = computed(() => (tab.value === 'history' ? historyFilter.value : tab.value === 'reviews' ? reviewDateFilter.value : filter.value))

const visibleHistory = computed(() => {
  let list = history.value
  if (historyFilter.value !== 'all') list = list.filter((h) => (historyFilter.value === 'rated' ? h.reviewed : !h.reviewed))
  const q = query.value.trim().toLowerCase()
  if (q) list = list.filter((h) => `${h.name} ${h.meta}`.toLowerCase().includes(q))
  return list
})
const visibleReviews = computed(() => {
  let list = reviewsFromManagers.value
  if (reviewDateFilter.value !== 'all') list = list.filter((r) => withinDateFilter(r.createdAt, reviewDateFilter.value))
  const q = query.value.trim().toLowerCase()
  if (q) list = list.filter((r) => `${r.comment}`.toLowerCase().includes(q))
  return list
})
const visiblePayments = computed(() => {
  let list = payments.value
  if (filter.value !== 'all') list = list.filter((p) => p.status === filter.value)
  const q = query.value.trim().toLowerCase()
  if (q) {
    list = list.filter((p) =>
      `${formatMonth(p.month)} ${PAYMENT_METHOD_LABEL[p.method] || p.method} ${p.roomLabel} ${p.accommodationName}`.toLowerCase().includes(q),
    )
  }
  return list
})

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

const historyDetailOpen = ref(false)
const historyDetailTarget = ref<HistoryRow | null>(null)
function openHistoryDetail(row: HistoryRow) {
  historyDetailTarget.value = row
  historyDetailOpen.value = true
}

const reviewDetailOpen = ref(false)
const reviewDetailTarget = ref<ManagerReview | null>(null)
function openReviewDetail(r: ManagerReview) {
  reviewDetailTarget.value = r
  reviewDetailOpen.value = true
}

const paymentDetailOpen = ref(false)
const paymentDetailTarget = ref<PaymentRow | null>(null)
function openPaymentDetail(p: PaymentRow) {
  paymentDetailTarget.value = p
  paymentDetailOpen.value = true
}

const reviewOpen = ref(false)
const submittingReview = ref(false)
const reviewTarget = ref<HistoryRow | null>(null)
const reviewForm = reactive({ accRating: 0, accComment: '', managerRating: 0, managerComment: '' })

function openReview(row: HistoryRow) {
  reviewTarget.value = row
  reviewForm.accRating = 0
  reviewForm.accComment = ''
  reviewForm.managerRating = 0
  reviewForm.managerComment = ''
  reviewOpen.value = true
}

async function submitReview() {
  const row = reviewTarget.value
  if (submittingReview.value || !row?.leaseId || !row.managerId || !row.accommodationId) return
  if (!reviewForm.accRating || !reviewForm.managerRating) {
    notify.error('Rate both the place and the manager.')
    return
  }
  submittingReview.value = true
  try {
    // Both halves in one transaction. As two sequential inserts, a failure on
    // the second left the first committed — and since a stay counts as rated
    // once either row exists, the student could never supply the missing half.
    const { error: reviewError } = await supabase.rpc('submit_student_review', {
      p_lease_id: row.leaseId,
      p_accommodation_id: row.accommodationId,
      p_landlord_id: row.managerId,
      p_acc_rating: reviewForm.accRating,
      p_acc_comment: reviewForm.accComment,
      p_manager_rating: reviewForm.managerRating,
      p_manager_comment: reviewForm.managerComment,
    })
    if (reviewError) throw reviewError

    // Anonymous both ways: the landlord/landlady is told a review arrived, not who wrote
    // it or what they scored — the star count would identify it on their list.
    void createNotification(
      row.managerId,
      'New rating',
      'A past tenant rated their stay.',
      'review',
      '/manager/profile/history',
    )

    const target = history.value.find((h) => h.id === row.id)
    if (target) target.reviewed = true
    reviewOpen.value = false
    notify.success('Thanks for the feedback!')
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not submit your rating.')
  } finally {
    submittingReview.value = false
  }
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
    userId.value = user.id

    const [
      { data: userRow },
      { data: past },
      { data: endedLeases },
      { data: myWrittenReviews },
      { data: reviewsAboutMe },
      { data: paymentRows },
    ] = await Promise.all([
      supabase.from('users').select('full_name').eq('id', user.id).maybeSingle(),
      supabase
        .from('boarding_history')
        .select('id, accommodation_id, accommodation_name, room_type, period_start, period_end, end_reason')
        .eq('student_id', user.id)
        .order('period_start', { ascending: false }),
      supabase
        .from('leases')
        .select('id, landlord_id, rooms(accommodation_id)')
        .eq('student_id', user.id)
        .in('status', ['ended', 'terminated']),
      // Which stays this student has already rated. One view instead of two
      // table reads, and it is scoped to the caller by the view itself.
      supabase.from('review_written_leases').select('lease_id').in('kind', ['accommodation', 'manager']),
      // Reviews landlords/landladies left about this student — anonymous, so no name join:
      // the landlord/landlady's identity is not exposed by the view at all.
      supabase
        .from('review_inbox')
        .select('id, rating, comment, created_at')
        .eq('kind', 'tenant')
        .order('created_at', { ascending: false }),
      supabase
        .from('payments')
        .select(
          'id, month, amount, status, method, description, txn_reference, proof_url, paid_at, rejection_reason, verified_by_user:users!payments_verified_by_fkey(full_name), leases!inner(student_id, rooms(room_number, label, accommodations(name)))',
        )
        .eq('leases.student_id', user.id)
        .order('month', { ascending: false }),
    ])

    studentName.value = userRow?.full_name || ''

    const leaseByAccommodation = new Map<string, { leaseId: string; managerId: string }>()
    for (const l of endedLeases ?? []) {
      const accId = (l.rooms as unknown as { accommodation_id: string } | null)?.accommodation_id
      if (accId && !leaseByAccommodation.has(accId)) {
        leaseByAccommodation.set(accId, { leaseId: l.id, managerId: l.landlord_id })
      }
    }
    const reviewedLeaseIds = new Set((myWrittenReviews ?? []).map((r) => r.lease_id))

    history.value = (past || []).map((h) => {
      const match = h.accommodation_id ? leaseByAccommodation.get(h.accommodation_id) : undefined
      return {
        id: h.id,
        name: h.accommodation_name || 'Accommodation',
        meta: [h.room_type, h.end_reason].filter(Boolean).join(' · ') || 'Stay',
        period: period(h.period_start, h.period_end),
        roomType: h.room_type || '',
        endReason: h.end_reason || '',
        periodStart: h.period_start,
        periodEnd: h.period_end,
        accommodationId: h.accommodation_id,
        leaseId: match?.leaseId ?? null,
        managerId: match?.managerId ?? null,
        reviewed: match ? reviewedLeaseIds.has(match.leaseId) : false,
      }
    })

    reviewsFromManagers.value = (reviewsAboutMe ?? []).map((r) => ({
      id: r.id ?? '',
      rating: r.rating ?? 0,
      comment: r.comment || '',
      createdAt: r.created_at ?? '',
    }))

    payments.value = (paymentRows ?? []).map((p) => {
      const payLease = p.leases as unknown as {
        rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
      }
      const payRoom = payLease.rooms
      const verifier = p.verified_by_user as unknown as { full_name: string | null } | null
      return {
        id: p.id,
        month: p.month,
        amount: Number(p.amount),
        status: p.status,
        method: p.method,
        roomLabel: payRoom?.label || (payRoom?.room_number ? `Room ${payRoom.room_number}` : 'Your room'),
        accommodationName: payRoom?.accommodations?.name || 'Your accommodation',
        description: p.description || '',
        txnReference: p.txn_reference || '',
        proofUrl: p.proof_url || '',
        paidAt: p.paid_at,
        verifiedByName: verifier?.full_name || '',
        rejectionReason: p.rejection_reason || '',
      }
    })
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

watch(tab, () => {
  query.value = ''
  filter.value = 'all'
  historyFilter.value = 'all'
  reviewDateFilter.value = 'all'
})

// The sheet's Clear: the open tab's filter on a phone, all of them on desktop.
function clearFilters() {
  if (split.value || tab.value === 'history') historyFilter.value = 'all'
  if (split.value || tab.value === 'reviews') reviewDateFilter.value = 'all'
  if (split.value || tab.value === 'payments') filter.value = 'all'
}
const deskFilterCount = computed(() =>
  [historyFilter.value, reviewDateFilter.value, filter.value].filter((f) => f !== 'all').length,
)

// Not kept alive and with no realtime watch behind it, so a pull is the only
// way to see anything that changed since the screen was opened.
function onPull(done: () => void) {
  void refresh().finally(done)
}

// Kept alive across navigation (see MainLayout KEEP_ALIVE_PAGES), so returning
// to this screen no longer refetches the whole history every time. No realtime
// watch on purpose: this is a record of things that already happened, and the
// two-minute TTL plus pull-to-refresh is all the freshness it needs.
const { refresh } = useLiveData({ key: 'student-history', load, ttl: 120_000 })

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
.rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .rule:first-child {
  border-top: 0;
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
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.detail-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.detail-close {
  min-height: 46px;
  margin-top: 6px;
  font-weight: 700;
}
.proof-img {
  width: 100%;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
.detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.detail-label--danger {
  color: var(--m-danger);
}
.detail-chip {
  align-self: flex-start;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.detail-chip--amber,
.detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.detail-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
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

.history-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .history-row:first-child {
  border-top: 0;
}
.history-info {
  display: flex;
  flex: 1;
  min-width: 0;
  align-items: center;
  gap: 8px;
  border: 0;
  background: transparent;
  padding: 0;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.history-text {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.row-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.history-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--m-ink);
}
.history-meta {
  font-size: 11px;
  color: var(--m-muted);
}
.history-when {
  font-size: 11px;
  color: var(--m-muted);
  white-space: nowrap;
}
.history-side {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}
.history-rated {
  color: var(--m-success);
  font-size: 11px;
  font-weight: 700;
}
.history-rate {
  padding: 3px 10px;
  border: 1px solid var(--m-primary);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 11px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
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
.pay-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pay-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.pay-month {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.pay-method {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
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

.review-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 14px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.review-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.review-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.review-field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.review-textarea {
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  resize: vertical;
}
.review-submit {
  min-height: 48px;
  font-weight: 700;
}

/* Docked search — this page is a subpage (no bottom nav, no FAB), so it
   spans the full width instead of reserving room for a FAB that isn't here. */

/* Filter sheet */
</style>
