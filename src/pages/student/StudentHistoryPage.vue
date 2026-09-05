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
      <q-tabs v-model="tab" class="tabs" active-color="primary" indicator-color="primary" dense align="left">
        <q-tab name="history" label="Boarding history" />
        <q-tab name="reviews" label="Reviews" />
        <q-tab name="payments" label="Payments" />
      </q-tabs>

      <q-tab-panels v-model="tab" animated class="panels">
        <q-tab-panel name="history" class="panel">
          <div class="panel-card">
            <div v-if="history.length">
              <div v-for="row in history" :key="row.id" class="history-row">
                <div class="history-info">
                  <span class="history-name">{{ row.name }}</span>
                  <span class="history-meta">{{ row.meta }}</span>
                </div>
                <div class="history-side">
                  <span class="history-when">{{ row.period }}</span>
                  <span v-if="row.reviewed" class="history-rated">Rated ✓</span>
                  <button v-else-if="row.leaseId" type="button" class="history-rate" @click="openReview(row)">Rate stay</button>
                </div>
              </div>
            </div>
            <p v-else class="empty-message">You haven't boarded anywhere yet.</p>
          </div>
        </q-tab-panel>

        <q-tab-panel name="reviews" class="panel">
          <div class="panel-card">
            <div v-if="reviewsFromManagers.length">
              <div class="rating-summary">
                <StarRating :model-value="avgManagerRating" :size="18" />
                <span class="rating-count">{{ avgManagerRating.toFixed(1) }} · {{ reviewsFromManagers.length }} review{{ reviewsFromManagers.length === 1 ? '' : 's' }}</span>
              </div>
              <div v-for="r in reviewsFromManagers" :key="r.id" class="review-row">
                <div class="review-top">
                  <span class="review-author">{{ r.authorName }}</span>
                  <StarRating :model-value="r.rating" :size="13" />
                </div>
                <p v-if="r.comment" class="review-comment">{{ r.comment }}</p>
              </div>
            </div>
            <p v-else class="empty-message">No reviews from managers yet.</p>
          </div>
        </q-tab-panel>

        <q-tab-panel name="payments" class="panel">
          <div class="panel-card">
            <div v-if="payments.length">
              <div v-for="p in payments" :key="p.id" class="pay-row">
                <span class="pay-icon"><IconifyIcon icon="lucide:receipt" width="16" /></span>
                <span class="pay-body">
                  <span class="pay-month">{{ formatMonth(p.month) }}</span>
                  <span class="pay-method">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }}</span>
                </span>
                <span class="pay-side">
                  <span class="pay-amount">{{ formatPeso(p.amount) }}</span>
                  <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                    {{ statusText(PAYMENT_STATUS, p.status) }}
                  </span>
                </span>
              </div>
            </div>
            <p v-else class="empty-message">No payment records yet.</p>
          </div>
        </q-tab-panel>
      </q-tab-panels>
    </div>

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
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import StarRating from '@/components/shared/StarRating.vue'
import { period } from '@/utils/profile'
import { formatPeso, formatMonth, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'

interface HistoryRow {
  id: string
  name: string
  meta: string
  period: string
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
  authorName: string
}
interface PaymentRow {
  id: string
  month: string
  amount: number
  status: string
  method: string
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
    const { error: accError } = await supabase.from('accommodation_reviews').insert({
      lease_id: row.leaseId,
      student_id: userId.value,
      accommodation_id: row.accommodationId,
      rating: reviewForm.accRating,
      comment: reviewForm.accComment.trim() || null,
    })
    if (accError) throw accError

    const { error: managerError } = await supabase.from('accommodation_manager_reviews').insert({
      lease_id: row.leaseId,
      student_id: userId.value,
      accommodation_manager_id: row.managerId,
      rating: reviewForm.managerRating,
      comment: reviewForm.managerComment.trim() || null,
    })
    if (managerError) throw managerError

    void createNotification(
      row.managerId,
      'New review',
      `${studentName.value || 'A student'} left a ${reviewForm.managerRating}★ review after staying at ${row.name}.`,
      'review',
      '/manager/profile',
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
    userId.value = user.id

    const [
      { data: userRow },
      { data: past },
      { data: endedLeases },
      { data: myAccReviews },
      { data: myManagerReviews },
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
      supabase.from('accommodation_reviews').select('lease_id').eq('student_id', user.id),
      supabase.from('accommodation_manager_reviews').select('lease_id').eq('student_id', user.id),
      supabase
        .from('tenant_reviews')
        .select('id, rating, comment, created_at, users!tenant_reviews_accommodation_manager_id_fkey(full_name)')
        .eq('student_id', user.id)
        .order('created_at', { ascending: false }),
      supabase
        .from('payments')
        .select('id, month, amount, status, method, leases!inner(student_id)')
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
    const reviewedLeaseIds = new Set([
      ...((myAccReviews ?? []).map((r) => r.lease_id)),
      ...((myManagerReviews ?? []).map((r) => r.lease_id)),
    ])

    history.value = (past || []).map((h) => {
      const match = h.accommodation_id ? leaseByAccommodation.get(h.accommodation_id) : undefined
      return {
        id: h.id,
        name: h.accommodation_name || 'Accommodation',
        meta: [h.room_type, h.end_reason].filter(Boolean).join(' · ') || 'Stay',
        period: period(h.period_start, h.period_end),
        accommodationId: h.accommodation_id,
        leaseId: match?.leaseId ?? null,
        managerId: match?.managerId ?? null,
        reviewed: match ? reviewedLeaseIds.has(match.leaseId) : false,
      }
    })

    reviewsFromManagers.value = (reviewsAboutMe ?? []).map((r) => ({
      id: r.id,
      rating: r.rating,
      comment: r.comment || '',
      createdAt: r.created_at,
      authorName: (r.users as unknown as { full_name: string | null } | null)?.full_name || 'A manager',
    }))

    payments.value = (paymentRows ?? []).map((p) => ({
      id: p.id,
      month: p.month,
      amount: Number(p.amount),
      status: p.status,
      method: p.method,
    }))
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
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 10px var(--m-page-gutter) 24px;
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

.tabs {
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.panels {
  background: transparent;
}
.panel {
  padding: 0;
}
.panel-card {
  padding: 12px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.empty-message {
  margin: 0;
  font-size: 13px;
  color: var(--m-muted);
  text-align: center;
  padding: 16px 0;
}

.history-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 0;
  border-bottom: 1px solid var(--m-border);
}
.history-row:last-child {
  border-bottom: 0;
  padding-bottom: 0;
}
.history-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
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
  padding-bottom: 8px;
  border-bottom: 1px solid var(--m-border);
}
.rating-count {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.review-row {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 8px 0;
  border-bottom: 1px solid var(--m-border);
}
.review-row:last-child {
  border-bottom: 0;
  padding-bottom: 0;
}
.review-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.review-author {
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
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px solid var(--m-border);
}
.pay-row:last-child {
  border-bottom: 0;
  padding-bottom: 0;
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
  color: var(--m-muted);
  font-size: 11.5px;
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
</style>
