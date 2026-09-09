<template>
  <q-page class="history-page">
    <q-pull-to-refresh @refresh="onPull">
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
          <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load()" />
        </q-card>
      </div>

      <div v-else class="stack">
        <div class="tabbed">
          <div class="tabs">
            <button type="button" class="tab" :class="{ 'tab--on': tab === 'history' }" @click="tab = 'history'">
              Boarding history
            </button>
            <button type="button" class="tab" :class="{ 'tab--on': tab === 'reviews' }" @click="tab = 'reviews'">
              Reviews
            </button>
            <button type="button" class="tab" :class="{ 'tab--on': tab === 'payments' }" @click="tab = 'payments'">
              Payments
            </button>
          </div>

          <div class="panel">
            <q-tab-panels v-model="tab" animated swipeable class="panels">
              <q-tab-panel name="history" class="tab-panel">
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
              </q-tab-panel>

              <q-tab-panel name="reviews" class="tab-panel">
                <template v-if="visibleReviews.length">
                  <div class="rating-summary">
                    <StarRating :model-value="avgManagerRating" :size="18" />
                    <span class="rating-count">{{ avgManagerRating.toFixed(1) }} · {{ reviewsFromManagers.length }} review{{ reviewsFromManagers.length === 1 ? '' : 's' }}</span>
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
                <EmptyState v-else variant="compact" icon="lucide:star" title="No reviews yet" message="Reviews a manager leaves after a stay will show up here." />
              </q-tab-panel>

              <q-tab-panel name="payments" class="tab-panel">
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
              </q-tab-panel>
            </q-tab-panels>
          </div>
        </div>
      </div>

    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band
         on a tab-shell page — but History is a subpage (no FAB, no bottom
         nav), so it just spans the full width instead of reserving FAB room.
         Outside the pull-to-refresh wrapper on purpose: it transforms its
         content while you pull, which would drag this fixed dock along. -->
    <div v-if="!loading && !error" class="dock">
      <button
        type="button"
        class="dock-btn"
        :class="{ 'dock-btn--on': activeFilter !== 'all' }"
        aria-label="Filters"
        @click="filtersOpen = true"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
        <span v-if="activeFilter !== 'all'" class="dock-dot">1</span>
      </button>
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input
          v-model="query"
          class="dock-input"
          type="search"
          :placeholder="tab === 'payments' ? 'Search month or method' : tab === 'reviews' ? 'Search reviews' : 'Search boarding history'"
          aria-label="Search"
        />
      </div>
    </div>

    <q-dialog v-model="filtersOpen" position="bottom">
      <div class="sheet">
        <div class="sheet-head">
          <h2 class="sheet-title">Filters</h2>
          <button
            type="button"
            class="sheet-clear"
            @click="tab === 'history' ? (historyFilter = 'all') : tab === 'reviews' ? (reviewDateFilter = 'all') : (filter = 'all')"
          >
            Reset
          </button>
        </div>
        <div v-if="tab === 'history'" class="sheet-block">
          <span class="sheet-label">Rated</span>
          <div class="chips">
            <button
              v-for="f in HISTORY_FILTERS"
              :key="f.key"
              type="button"
              class="chip"
              :class="{ 'chip--on': historyFilter === f.key }"
              @click="historyFilter = f.key"
            >
              {{ f.label }}
            </button>
          </div>
        </div>
        <div v-else-if="tab === 'reviews'" class="sheet-block">
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
        <h3 class="detail-title">A past manager</h3>
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
          <span class="review-field-label">The manager</span>
          <StarRating v-model="reviewForm.managerRating" interactive :size="26" />
          <textarea v-model="reviewForm.managerComment" class="review-textarea" rows="2" placeholder="How were they to deal with? (optional)" />
        </div>

        <q-btn unelevated rounded no-caps color="primary" class="review-submit" :loading="submittingReview" label="Submit" @click="submitReview" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import StarRating from '@/components/shared/StarRating.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
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
      p_accommodation_manager_id: row.managerId,
      p_acc_rating: reviewForm.accRating,
      p_acc_comment: reviewForm.accComment,
      p_manager_rating: reviewForm.managerRating,
      p_manager_comment: reviewForm.managerComment,
    })
    if (reviewError) throw reviewError

    // Anonymous both ways: the manager is told a review arrived, not who wrote
    // it or what they scored — the star count would identify it on their list.
    void createNotification(
      row.managerId,
      'New review',
      'A past tenant left a review of their stay.',
      'review',
      '/manager/profile/history',
    )

    const target = history.value.find((h) => h.id === row.id)
    if (target) target.reviewed = true
    reviewOpen.value = false
    notify.success('Thanks for the feedback!')
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not submit your review.')
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
        .select('id, accommodation_manager_id, rooms(accommodation_id)')
        .eq('student_id', user.id)
        .in('status', ['ended', 'terminated']),
      // Which stays this student has already rated. One view instead of two
      // table reads, and it is scoped to the caller by the view itself.
      supabase.from('review_written_leases').select('lease_id').in('kind', ['accommodation', 'manager']),
      // Reviews managers left about this student — anonymous, so no name join:
      // the manager's identity is not exposed by the view at all.
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
        leaseByAccommodation.set(accId, { leaseId: l.id, managerId: l.accommodation_manager_id })
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

// Not kept alive and with no realtime watch behind it, so a pull is the only
// way to see anything that changed since the screen was opened.
function onPull(done: () => void) {
  void load(true).finally(done)
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
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 8px;
  height: 44px;
  padding: 0 14px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
}
.dock-field:focus-within {
  border-color: var(--m-primary);
}
.dock-icon {
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input::placeholder {
  color: var(--m-muted);
  opacity: 0.85;
}
.dock-input:focus {
  outline: none;
}
.dock-btn {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 50%;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
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
</style>
