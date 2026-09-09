<template>
  <q-page class="tprof">
    <div v-if="loading" class="stack">
      <div class="hero"><q-skeleton type="rect" height="170px" square /></div>
      <div class="body-card">
        <div class="head">
          <q-skeleton type="circle" size="84px" style="margin-top: -42px; margin-bottom: 4px;" />
          <q-skeleton type="text" width="130px" height="17px" />
          <q-skeleton type="text" width="72px" height="18px" />
          <q-skeleton type="text" width="160px" height="12px" />
        </div>
      </div>
      <div class="tabs">
        <q-skeleton type="rect" width="72px" height="38px" class="sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="sk-tab" />
      </div>
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this tenant</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load()" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="tabbed">
        <div class="hero">
          <img v-if="coverUrl" :src="coverUrl" alt="" class="hero-img" />
          <div class="hero-scrim" />
          <button type="button" class="hero-msg" aria-label="Message tenant" @click="router.push(`/manager/messages?to=${lease.studentId}`)">
            <IconifyIcon icon="lucide:message-circle" width="16" />
          </button>
        </div>

        <div class="body-card">
          <div class="head">
            <span class="head-avatar">
              <img v-if="lease.studentAvatarUrl" :src="lease.studentAvatarUrl" alt="" class="head-avatar-img" @error="lease.studentAvatarUrl = null" />
              <template v-else>{{ lease.studentInitials }}</template>
            </span>
            <span class="head-name">{{ lease.studentName }}</span>
            <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, lease.status)}`">
              {{ statusText(LEASE_STATUS, lease.status) }}
            </span>
            <span class="head-sub">{{ lease.roomLabel }} · {{ lease.accommodationName }}</span>
          </div>
        </div>

        <div class="tabs">
          <button
            v-for="t in TABS"
            :key="t.key"
            type="button"
            class="tab"
            :class="{ 'tab--on': tab === t.key }"
            @click="tab = t.key"
          >
            {{ t.label }}
          </button>
        </div>

        <div class="panel">
          <q-tab-panels v-model="tab" animated swipeable class="panels">
            <q-tab-panel name="overview" class="sec">
            <!-- Decisions -->
            <div v-if="lease.status === 'pending'" class="decide-box">
              <div v-if="decisionReasonFor === 'reject'" class="decide-reason">
                <label class="decide-reason-label">
                  Reason for declining
                  <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="Let the student know why…" />
                </label>
                <div class="decide-reason-actions">
                  <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
                  <button
                    type="button"
                    class="decide-btn decide-btn--danger"
                    :disabled="deciding || !decisionReason.trim()"
                    @click="decide('rejected')"
                  >
                    {{ deciding ? 'Declining…' : 'Confirm decline' }}
                  </button>
                </div>
              </div>
              <div v-else class="decide">
                <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = 'reject'; decisionReason = ''">
                  Decline
                </button>
                <button type="button" class="decide-btn" :disabled="deciding" @click="decide('active')">
                  Accept
                </button>
              </div>
            </div>
            <div v-else-if="lease.status === 'leave_requested'" class="decide-box">
              <div v-if="decisionReasonFor === 'keep'" class="decide-reason">
                <label class="decide-reason-label">
                  Reason for keeping the tenant
                  <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="Let the student know why…" />
                </label>
                <div class="decide-reason-actions">
                  <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
                  <button
                    type="button"
                    class="decide-btn decide-btn--danger"
                    :disabled="deciding || !decisionReason.trim()"
                    @click="declineLeave"
                  >
                    {{ deciding ? 'Sending…' : 'Confirm' }}
                  </button>
                </div>
              </div>
              <div v-else class="decide">
                <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = 'keep'; decisionReason = ''">
                  Keep tenant
                </button>
                <button type="button" class="decide-btn" :disabled="deciding" @click="approveLeave">
                  Approve leave
                </button>
              </div>
            </div>
            <div v-else-if="(lease.status === 'ended' || lease.status === 'terminated') && tenantReview" class="decide-box rated">
              <StarRating :model-value="tenantReview.rating" :size="16" />
              <span class="rated-label">You rated this tenant</span>
            </div>
            <div v-else-if="lease.status === 'ended' || lease.status === 'terminated'" class="decide-box decide">
              <button type="button" class="decide-btn" @click="openReview">Rate this tenant</button>
            </div>

            <div class="sec-head">
              <h2 class="sec-title">Stay</h2>
            </div>
            <div class="group">
              <div class="rule">
                <span class="rule-label">Move-in</span>
                <span class="rule-value">{{ formatDate(lease.startDate) }}</span>
              </div>
              <div class="rule">
                <span class="rule-label">Lease ends</span>
                <span class="rule-value">{{ formatDate(lease.endDate) }}</span>
              </div>
              <div class="rule">
                <span class="rule-label">Monthly rent</span>
                <span class="rule-value">{{ formatPeso(lease.monthlyRent) }}</span>
              </div>
            </div>

            <template v-if="lease.email || lease.phone">
              <div class="sec-head">
                <h2 class="sec-title">Contact</h2>
              </div>
              <div class="group">
                <div v-if="lease.email" class="rule">
                  <span class="rule-label">Email</span>
                  <span class="rule-value">{{ lease.email }}</span>
                </div>
                <div v-if="lease.phone" class="rule">
                  <span class="rule-label">Phone</span>
                  <span class="rule-value">{{ lease.phone }}</span>
                </div>
              </div>
            </template>
          </q-tab-panel>

          <q-tab-panel name="payments" class="sec">
            <div class="sec-head">
              <h2 class="sec-title">Payments</h2>
              <button v-if="payments.length > 3" type="button" class="sec-link" @click="paymentsExpanded = !paymentsExpanded">
                {{ paymentsExpanded ? 'Show less' : `Show all (${payments.length})` }}
              </button>
            </div>

            <div v-if="payments.length" class="group">
              <button v-for="p in visiblePayments" :key="p.id" type="button" class="pay-row pay-row--tap" @click="openPaymentDetail(p)">
                <div class="pay-row-main">
                  <span class="pay-row-month">{{ formatMonth(p.month) }}</span>
                  <span class="pay-row-amount">{{ formatPeso(p.amount) }}</span>
                </div>
                <div class="pay-row-sub">
                  <span class="pay-row-method">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }}</span>
                  <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                    {{ statusText(PAYMENT_STATUS, p.status) }}
                  </span>
                </div>
                <span v-if="p.status === 'pending_verification'" class="pay-row-review">
                  Tap to review
                  <IconifyIcon icon="lucide:chevron-right" width="13" />
                </span>
              </button>
            </div>
            <EmptyState
              v-else
              variant="compact"
              icon="lucide:receipt"
              title="No payments yet"
              message="Log a payment for this tenant from the tenants list to start their history."
            />
          </q-tab-panel>

          <q-tab-panel name="history" class="sec">
            <h2 class="sec-title">Boarding history</h2>
            <div v-if="history.length" class="group">
              <div v-for="h in history" :key="h.id" class="rule">
                <span class="rule-label">{{ h.accommodationName }} · {{ h.roomType || 'Room' }}</span>
                <span class="rule-value">{{ formatDate(h.periodStart) }} – {{ formatDate(h.periodEnd) }}</span>
              </div>
            </div>
            <p v-else class="none">No prior stays on record.</p>
          </q-tab-panel>
          </q-tab-panels>
        </div>
      </div>
    </div>

    <q-dialog v-model="reviewOpen" position="bottom">
      <q-card class="pay-sheet">
        <h3 class="pay-title">Rate {{ lease.studentName }}</h3>
        <StarRating v-model="reviewForm.rating" interactive :size="26" />
        <label class="pay-field">
          <span class="pay-label">Notes (optional)</span>
          <textarea v-model="reviewForm.comment" class="pay-input review-textarea" rows="3" placeholder="How was this tenant to have?" />
        </label>
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="pay-submit"
          :loading="submittingReview"
          label="Submit"
          @click="submitTenantReview"
        />
      </q-card>
    </q-dialog>

    <!-- Payment review — verifying only ever happens from here, never
         straight off the row, so a proof/reference actually gets looked at. -->
    <q-dialog v-model="paymentDetailOpen" position="bottom">
      <q-card v-if="selectedPayment" class="pay-sheet">
        <h3 class="pay-title">{{ formatMonth(selectedPayment.month) }}</h3>
        <span class="pay-detail-chip" :class="`pay-detail-chip--${statusColor(PAYMENT_STATUS, selectedPayment.status)}`">
          {{ statusText(PAYMENT_STATUS, selectedPayment.status) }}
        </span>

        <div class="group">
          <div class="pay-detail-rule">
            <span class="pay-detail-rule-label">Amount</span>
            <span class="pay-detail-rule-value">{{ formatPeso(selectedPayment.amount) }}</span>
          </div>
          <div class="pay-detail-rule">
            <span class="pay-detail-rule-label">Method</span>
            <span class="pay-detail-rule-value">{{ PAYMENT_METHOD_LABEL[selectedPayment.method] || selectedPayment.method }}</span>
          </div>
          <div v-if="selectedPayment.txnReference" class="pay-detail-rule">
            <span class="pay-detail-rule-label">Reference number</span>
            <span class="pay-detail-rule-value">{{ selectedPayment.txnReference }}</span>
          </div>
          <div v-if="selectedPayment.verifiedByName" class="pay-detail-rule">
            <span class="pay-detail-rule-label">Reviewed by</span>
            <span class="pay-detail-rule-value">
              {{ selectedPayment.verifiedByName }}{{ selectedPayment.paidAt ? ` · ${formatDate(selectedPayment.paidAt)}` : '' }}
            </span>
          </div>
        </div>

        <template v-if="selectedPayment.status === 'rejected' && selectedPayment.rejectionReason">
          <p class="pay-detail-label">Rejection reason</p>
          <p class="pay-detail-text">{{ selectedPayment.rejectionReason }}</p>
        </template>

        <template v-if="selectedPayment.description">
          <p class="pay-detail-label">Note</p>
          <p class="pay-detail-text">{{ selectedPayment.description }}</p>
        </template>

        <template v-if="selectedPayment.proofUrl">
          <p class="pay-detail-label">Proof of payment</p>
          <img :src="resolveAsset(selectedPayment.proofUrl)" alt="Proof of payment" class="pay-detail-proof-img" />
        </template>

        <template v-if="selectedPayment.status === 'pending_verification'">
          <div v-if="rejectingId === selectedPayment.id" class="pay-reject-form">
            <label class="pay-detail-label">
              Reason
              <textarea v-model="rejectReason" class="pay-reject-textarea" rows="2" placeholder="Why is this being rejected?" />
            </label>
            <div class="pay-reject-actions">
              <button type="button" class="pay-reject-cancel" @click="rejectingId = ''">Cancel</button>
              <button
                type="button"
                class="pay-reject-confirm"
                :disabled="verifying === selectedPayment.id || !rejectReason.trim()"
                @click="rejectPayment(selectedPayment.id)"
              >
                {{ verifying === selectedPayment.id ? 'Rejecting…' : 'Confirm reject' }}
              </button>
            </div>
          </div>
          <div v-else class="pay-detail-actions">
            <q-btn
              unelevated
              rounded
              no-caps
              color="primary"
              class="pay-submit"
              :loading="verifying === selectedPayment.id"
              label="Mark verified"
              @click="verifyPayment(selectedPayment.id); paymentDetailOpen = false"
            />
            <button type="button" class="pay-reject-btn" @click="rejectingId = selectedPayment.id; rejectReason = ''">
              Reject
            </button>
          </div>
        </template>

        <q-btn flat rounded no-caps color="grey-7" label="Close" @click="paymentDetailOpen = false" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { formatPeso, formatDate, formatMonth, initialsOf, LEASE_STATUS, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'
import { createNotification } from '@/boot/notify'
import { useNotify } from '@/utils/notify'
import { respondToApplication } from '@/utils/applications'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import StarRating from '@/components/shared/StarRating.vue'
import EmptyState from '@/components/shared/EmptyState.vue'

const TABS = [
  { key: 'overview', label: 'Overview' },
  { key: 'payments', label: 'Payments' },
  { key: 'history', label: 'History' },
] as const

const route = useRoute()
const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const deciding = ref(false)
const tab = ref<(typeof TABS)[number]['key']>('overview')

const lease = reactive({
  status: '',
  studentId: '',
  studentName: '',
  studentInitials: '?',
  studentAvatarUrl: '' as string | null,
  email: '',
  phone: '',
  roomLabel: '',
  accommodationId: '',
  accommodationName: '',
  roomType: '',
  startDate: '',
  endDate: '',
  monthlyRent: 0,
})
const coverUrl = ref('')
const payments = ref<
  {
    id: string
    month: string
    amount: number
    status: string
    method: string
    description: string
    txnReference: string
    proofUrl: string
    paidAt: string | null
    verifiedByName: string
    rejectionReason: string
  }[]
>([])
const paymentsExpanded = ref(false)
const visiblePayments = computed(() => (paymentsExpanded.value ? payments.value : payments.value.slice(0, 3)))
const history = ref<{ id: string; accommodationName: string; roomType: string | null; periodStart: string; periodEnd: string }[]>([])
const tenantReview = ref<{ rating: number; comment: string } | null>(null)

const leaseId = computed(() => String(route.params.leaseId || ''))

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('leases')
      .select(
        'id,status,start_date,end_date,monthly_rent,student_id,room_id,users!leases_student_id_fkey(full_name,initials,email,phone,avatar_url),rooms(label,room_number,room_type,accommodation_id,accommodations(name,accommodation_images(url,sort_order)))',
      )
      .eq('id', leaseId.value)
      .maybeSingle()
    if (loadError) throw loadError
    if (!data) {
      error.value = 'This tenant record could not be found.'
      return
    }

    const student = data.users as unknown as { full_name: string | null; initials: string | null; email: string | null; phone: string | null; avatar_url: string | null } | null
    const room = data.rooms as unknown as {
      label: string | null
      room_number: string | null
      room_type: string | null
      accommodation_id: string
      accommodations: { name: string | null; accommodation_images: { url: string; sort_order: number | null }[] | null } | null
    } | null

    lease.status = data.status
    lease.studentId = data.student_id
    lease.studentName = student?.full_name || 'A student'
    lease.studentInitials = student?.initials || initialsOf(lease.studentName)
    lease.studentAvatarUrl = student?.avatar_url ? resolveAsset(student.avatar_url) : null
    lease.email = student?.email || ''
    lease.phone = student?.phone || ''
    lease.roomLabel = room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room')
    lease.accommodationId = room?.accommodation_id || ''
    lease.accommodationName = room?.accommodations?.name || 'Accommodation'
    lease.roomType = room?.room_type || ''

    const cover = [...(room?.accommodations?.accommodation_images ?? [])].sort(
      (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
    )[0]
    coverUrl.value = cover?.url ? resolveAsset(cover.url) : ''
    lease.startDate = data.start_date
    lease.endDate = data.end_date
    lease.monthlyRent = Number(data.monthly_rent ?? 0)

    const [{ data: paymentRows }, { data: historyRows }] = await Promise.all([
      supabase
        .from('payments')
        .select(
          'id,month,amount,status,method,description,txn_reference,proof_url,paid_at,rejection_reason,verified_by_user:users!payments_verified_by_fkey(full_name)',
        )
        .eq('lease_id', leaseId.value)
        .order('month', { ascending: false }),
      supabase
        .from('boarding_history')
        .select('id,accommodation_name,room_type,period_start,period_end')
        .eq('student_id', data.student_id)
        .order('period_start', { ascending: false }),
    ])
    payments.value = (paymentRows ?? []).map((p) => ({
      id: p.id,
      month: p.month,
      amount: Number(p.amount),
      status: p.status,
      method: p.method,
      description: p.description || '',
      txnReference: p.txn_reference || '',
      proofUrl: p.proof_url || '',
      paidAt: p.paid_at,
      verifiedByName: (p.verified_by_user as { full_name: string | null } | null)?.full_name || '',
      rejectionReason: p.rejection_reason || '',
    }))
    history.value = (historyRows ?? []).map((h) => ({
      id: h.id,
      accommodationName: h.accommodation_name || 'Accommodation',
      roomType: h.room_type,
      periodStart: h.period_start,
      periodEnd: h.period_end,
    }))

    if (data.status === 'ended' || data.status === 'terminated') {
      // The review this manager wrote, read back through the "written by me"
      // view. `unique (lease_id)` now guarantees at most one row, which is what
      // maybeSingle() always assumed — a second row used to make it throw.
      const { data: reviewRow } = await supabase
        .from('review_written_leases')
        .select('rating,comment')
        .eq('kind', 'tenant')
        .eq('lease_id', leaseId.value)
        .maybeSingle()
      tenantReview.value = reviewRow ? { rating: reviewRow.rating ?? 0, comment: reviewRow.comment || '' } : null
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

const decisionReasonFor = ref<'' | 'reject' | 'keep'>('')
const decisionReason = ref('')

async function decide(next: 'active' | 'rejected') {
  if (deciding.value) return
  if (next === 'rejected' && !decisionReason.value.trim()) return
  deciding.value = true
  try {
    await respondToApplication(leaseId.value, lease.studentId, lease.roomLabel, next, next === 'rejected' ? decisionReason.value.trim() : undefined)
    lease.status = next
    notify.success(next === 'active' ? 'Application accepted.' : 'Application declined.')
    decisionReasonFor.value = ''
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this application.'))
  } finally {
    deciding.value = false
  }
}

async function approveLeave() {
  if (deciding.value) return
  deciding.value = true
  try {
    const today = new Date().toISOString().slice(0, 10)
    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'ended', ended_reason: 'leave_approved', end_date: today })
      .eq('id', leaseId.value)
    if (updateError) throw updateError

    // This row is what the student's History screen lists, and rating a stay
    // hangs off that list — so if it fails to write, the student can never
    // review this stay. It used to be fired and forgotten; the approval itself
    // has already gone through, so say what happened rather than claim the
    // whole thing failed.
    const { error: historyError } = await supabase.from('boarding_history').insert({
      student_id: lease.studentId,
      accommodation_id: lease.accommodationId,
      accommodation_name: lease.accommodationName,
      room_type: lease.roomType || null,
      period_start: lease.startDate,
      period_end: today,
      end_reason: 'leave_approved',
    })

    lease.status = 'ended'

    // Approving the leave is what opens reviewing for the student (the RLS
    // insert policies require an ended or terminated lease), so the notice
    // invites the review and lands on the screen that has the button, rather
    // than on the profile root where they'd have to go looking.
    void createNotification(
      lease.studentId,
      'Leave request approved',
      `Your move-out from ${lease.roomLabel} was approved. You can now rate your stay.`,
      'lease',
      '/student/profile/history',
    )

    if (historyError) {
      notify.warning('Leave approved, but the stay was not added to their history — they will not be able to rate it.')
    } else {
      notify.success('Leave request approved.')
    }
  } catch (e) {
    notify.error(errorMessage(e, 'Could not approve the leave request.'))
  } finally {
    deciding.value = false
  }
}

async function declineLeave() {
  const reason = decisionReason.value.trim()
  if (deciding.value || !reason) return
  deciding.value = true
  try {
    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'active', leave_requested_at: null })
      .eq('id', leaseId.value)
    if (updateError) throw updateError
    lease.status = 'active'
    void createNotification(lease.studentId, 'Leave request declined', `Your request to leave ${lease.roomLabel} was declined. Reason: ${reason}`, 'lease', '/student/stay')
    notify.success('Leave request declined.')
    decisionReasonFor.value = ''
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update the leave request.'))
  } finally {
    deciding.value = false
  }
}

const verifying = ref('')
const paymentDetailOpen = ref(false)
const selectedPayment = ref<(typeof payments.value)[number] | null>(null)
function openPaymentDetail(p: (typeof payments.value)[number]) {
  selectedPayment.value = p
  paymentDetailOpen.value = true
}

async function verifyPayment(paymentId: string) {
  if (verifying.value) return
  verifying.value = paymentId
  try {
    const { data: authData } = await authUser()
    const paidAt = new Date().toISOString()
    const { error: updateError } = await supabase
      .from('payments')
      .update({ status: 'paid', paid_at: paidAt, verified_by: authData?.user?.id || null })
      .eq('id', paymentId)
    if (updateError) throw updateError

    const row = payments.value.find((p) => p.id === paymentId)
    if (row) {
      row.status = 'paid'
      row.paidAt = paidAt
      row.verifiedByName = 'You'
    }

    void createNotification(lease.studentId, 'Payment verified', `Your payment for ${lease.roomLabel} was marked as paid.`, 'payment', '/student/payments')
    notify.success('Payment verified.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not verify this payment.'))
  } finally {
    verifying.value = ''
  }
}

const rejectingId = ref('')
const rejectReason = ref('')

async function rejectPayment(paymentId: string) {
  const reason = rejectReason.value.trim()
  if (verifying.value || !reason) return
  verifying.value = paymentId
  try {
    const { data: authData } = await authUser()
    const { error: updateError } = await supabase
      .from('payments')
      .update({ status: 'rejected', rejection_reason: reason, verified_by: authData?.user?.id || null })
      .eq('id', paymentId)
    if (updateError) throw updateError

    const row = payments.value.find((p) => p.id === paymentId)
    if (row) {
      row.status = 'rejected'
      row.rejectionReason = reason
      row.verifiedByName = 'You'
    }

    void createNotification(lease.studentId, 'Payment rejected', `Your payment for ${lease.roomLabel} was rejected. Reason: ${reason}`, 'payment', '/student/payments')
    notify.success('Payment rejected.')
    rejectingId.value = ''
    paymentDetailOpen.value = false
  } catch (e) {
    notify.error(errorMessage(e, 'Could not reject this payment.'))
  } finally {
    verifying.value = ''
  }
}

const reviewOpen = ref(false)
const submittingReview = ref(false)
const reviewForm = reactive({ rating: 0, comment: '' })

function openReview() {
  reviewForm.rating = 0
  reviewForm.comment = ''
  reviewOpen.value = true
}

async function submitTenantReview() {
  if (submittingReview.value) return
  if (!reviewForm.rating) {
    notify.error('Give a star rating.')
    return
  }
  submittingReview.value = true
  try {
    const { data: authData } = await authUser()
    const managerId = authData?.user?.id
    if (!managerId) throw new Error('Not signed in.')

    const { error: insertError } = await supabase.from('tenant_reviews').insert({
      lease_id: leaseId.value,
      student_id: lease.studentId,
      accommodation_manager_id: managerId,
      rating: reviewForm.rating,
      comment: reviewForm.comment.trim() || null,
    })
    if (insertError) throw insertError

    // The student is told they were reviewed, but never by whom — reviews are
    // anonymous in both directions, so no manager or accommodation name here.
    void createNotification(
      lease.studentId,
      'You received a review',
      'A manager left a review after one of your past stays.',
      'review',
      '/student/profile/history',
    )

    tenantReview.value = { rating: reviewForm.rating, comment: reviewForm.comment.trim() }
    reviewOpen.value = false
    notify.success('Review submitted.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your review.'))
  } finally {
    submittingReview.value = false
  }
}

// Kept alive per lease id (see MainLayout's KEEP_ALIVE_PAGES + the
// route.fullPath key), so lease and payment changes push here instead of the
// page re-asking on return. utils/useLiveData.ts owns the whole policy — the
// key folds in the lease id so each tenant gets its own freshness clock.
useLiveData({
  key: () => `manager-tenant:${leaseId.value}`,
  load,
  watch: () =>
    leaseId.value
      ? [
          { table: 'leases', filter: `id=eq.${leaseId.value}` },
          { table: 'payments', filter: `lease_id=eq.${leaseId.value}` },
        ]
      : [],
})
</script>

<style scoped>
.tprof {
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
  padding: 8px var(--m-page-gutter) 0;
}
.sk-tab {
  border-radius: 10px 10px 0 0;
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

.tabbed {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
}
/* Cover band — bleeds to the very top of the page (cancels .stack's own
   top padding via .tabbed's negative margin) and to both edges. No text
   sits on it; the avatar straddling its bottom edge is the only thing
   that touches it directly. */
.hero {
  position: relative;
  flex: 0 0 auto;
  height: 170px;
  overflow: hidden;
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.hero-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.18) 0%, rgba(0, 0, 0, 0) 70%);
}
.hero-msg {
  position: absolute;
  top: 10px;
  right: var(--m-page-gutter);
  z-index: 2;
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.55);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

/* Profile info only — the avatar pulls up into the hero via a negative
   margin so it straddles the seam, cover-photo style. Tabs and their
   content live in separate elements below, not nested in this card. */
.body-card {
  position: relative;
  margin: -85px var(--m-page-gutter) 0;
  padding: 0 var(--m-page-gutter) 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
}
.head {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding-top: 8px;
  text-align: center;
}
.head-avatar {
  display: grid;
  width: 84px;
  height: 84px;
  place-items: center;
  overflow: hidden;
  margin-top: -42px;
  margin-bottom: 4px;
  border: 4px solid var(--m-surface);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 800;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.12);
}
.head-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.head-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.head-chip {
  margin-top: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.head-chip--teal {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.head-chip--amber,
.head-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.head-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.head-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.head-sub {
  margin-top: 4px;
  color: var(--m-muted);
  font-size: 12.5px;
}

/* Rounded-top pill tabs rising into the bordered panel below — same
   tab-folder shape as accommodation detail, recolored for a plain white
   card instead of a photo backdrop (no gradient sits behind these). */
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  /* -2px, not -1px: see ManagerTenantsPage.vue's .tabs comment — an exact 1px
     overlap can round the wrong way on real (non-@1x) device pixel ratios
     and leave a hairline gap under the active tab. */
  margin: 14px var(--m-page-gutter) -2px;
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
/* Its own card, distinct from .body-card above — not a shared surface. The
   active tab's background matches this panel's, so the -1px overlap above
   fuses them with no visible seam, while unselected tabs still show the
   border. Bleeds to the page edges and fills to the bottom, same as
   accommodation detail's own .panel. */
.panel {
  display: flex;
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 0 var(--m-page-gutter) 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.panels { background: transparent; }
.panels :deep(.q-tab-panel) { padding: 0; }

/* Same treatment as accommodation detail's status-box — its own bordered
   card for anything decision-related, not a bare row of buttons. */
.decide-box {
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.decide {
  display: flex;
  gap: 8px;
}
.rated {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 8px 0;
}
.rated-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.decide-btn {
  flex: 1;
  min-height: 44px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.decide-btn:disabled {
  opacity: 0.6;
}
.decide-btn--ghost {
  background: var(--m-bg);
  color: var(--m-text);
  border: 1px solid var(--m-border);
}
.decide-btn--danger {
  background: var(--m-danger);
}
.decide-reason {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.decide-reason-label {
  display: flex;
  flex-direction: column;
  gap: 4px;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.decide-reason-textarea {
  min-height: 60px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  text-transform: none;
  letter-spacing: normal;
  font-weight: 400;
  resize: vertical;
}
.decide-reason-actions {
  display: flex;
  gap: 8px;
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
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
.sec-link {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
/* Cancels .body-card's own side padding so this card reaches its left and
   right edges instead of sitting doubly inset (card padding + card padding). */
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
.rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}
.rule-verify {
  display: block;
  margin-top: 3px;
  margin-left: auto;
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
.rule-verify:disabled {
  opacity: 0.6;
}

.pay-row {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.pay-row--tap {
  width: 100%;
  border-left: 0;
  border-right: 0;
  border-bottom: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.pay-row-review {
  display: flex;
  align-items: center;
  gap: 1px;
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 700;
}
.group > .pay-row:first-child {
  border-top: 0;
}
.pay-row-main,
.pay-row-sub {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.pay-row-month,
.pay-row-amount {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.pay-row-method {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.pay-chip {
  flex: 0 0 auto;
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 10.5px;
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
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}

.pay-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.pay-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.pay-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.pay-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.pay-submit {
  min-height: 48px;
  font-weight: 700;
}
.pay-detail-actions {
  display: flex;
  gap: 8px;
}
.pay-detail-actions .pay-submit {
  flex: 1;
  margin: 0;
}
.pay-reject-btn {
  flex: 0 0 auto;
  min-height: 48px;
  padding: 0 18px;
  border: 1px solid var(--m-danger);
  border-radius: 999px;
  background: var(--m-danger-soft);
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.pay-reject-form {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pay-reject-textarea {
  display: block;
  width: 100%;
  min-height: 60px;
  margin-top: 4px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  resize: vertical;
}
.pay-reject-actions {
  display: flex;
  gap: 8px;
}
.pay-reject-cancel {
  flex: 0 0 auto;
  min-height: 44px;
  padding: 0 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pay-reject-confirm {
  flex: 1;
  min-height: 44px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pay-reject-confirm:disabled {
  opacity: 0.6;
}
.review-textarea {
  min-height: 70px;
  padding: 10px 12px;
  resize: vertical;
}

.pay-detail-chip {
  align-self: flex-start;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.pay-detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-detail-chip--amber,
.pay-detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-detail-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.pay-detail-rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .pay-detail-rule:first-child {
  border-top: 0;
}
.pay-detail-rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.pay-detail-rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}
.pay-detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.pay-detail-proof-img {
  width: 100%;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
</style>
